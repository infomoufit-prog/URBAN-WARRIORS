import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.7";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const BUILD = 20077;
const BACKUP_BUCKET = "kombax-backups";
const AUTH_SKIP = new Set([
  "refresh_tokens",
  "sessions",
  "one_time_tokens",
  "flow_state",
  "mfa_challenges",
  "mfa_amr_claims",
  "saml_relay_states",
  "oauth_client_states",
  "schema_migrations",
]);
const STORAGE_SKIP = new Set(["migrations", "s3_multipart_uploads", "s3_multipart_uploads_parts"]);
const RESPONSE_HEADERS = {
  "cache-control": "no-store, max-age=0",
  pragma: "no-cache",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "x-kombax-build": String(BUILD),
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...RESPONSE_HEADERS, "content-type": "application/json; charset=utf-8" },
  });
const stringify = (value: unknown) => JSON.stringify(value, (_key, item) => typeof item === "bigint" ? item.toString() : item);
const quoteIdent = (value: string) => `"${value.replaceAll('"', '""')}"`;
const sha256 = async (input: string | ArrayBuffer | Uint8Array) => {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input instanceof Uint8Array
    ? input
    : new Uint8Array(input);
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)))
    .map((item) => item.toString(16).padStart(2, "0"))
    .join("");
};
const batches = <T>(items: T[], size: number) =>
  Array.from({ length: Math.ceil(items.length / size) }, (_, index) => items.slice(index * size, (index + 1) * size));

async function dumpSchema(sql: any, schema: string) {
  const tables = await sql.unsafe(
    `select c.relname table_name from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname='${schema}' order by c.relname`,
  );
  const lines = [stringify({ kind: "kombax_backup_header", format: "ndjson-v1", build: BUILD, schema, generated_at: new Date().toISOString() })];
  const catalogue: Array<Record<string, unknown>> = [];

  for (const item of tables) {
    const table = String(item.table_name || "");
    if (schema === "auth" && AUTH_SKIP.has(table)) continue;
    if (schema === "storage" && STORAGE_SKIP.has(table)) continue;
    if (schema === "public" && (table === "kombax_backup_export_tokens_v141" || table === "kombax_backup_runs_v142")) continue;

    const rows = await sql.unsafe(`select to_jsonb(t) row from ${quoteIdent(schema)}.${quoteIdent(table)} t`);
    catalogue.push({ table, row_count: rows.length });
    lines.push(stringify({ kind: "table", schema, table, row_count: rows.length }));
    for (const row of rows) lines.push(stringify({ kind: "row", schema, table, data: row.row }));
  }

  const body = `${lines.join("\n")}\n`;
  return {
    body,
    bytes: new TextEncoder().encode(body).byteLength,
    sha256: await sha256(body),
    tables: catalogue,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") return json(405, { ok: false, error: "method_not_allowed" });

  const token = (req.headers.get("x-kombax-backup-token") || "").trim();
  if (token.length < 48 || token.length > 256) return json(401, { ok: false, error: "backup_capability_required" });

  const dbUrl = Deno.env.get("SUPABASE_DB_URL") || "";
  const baseUrl = (Deno.env.get("SUPABASE_URL") || "").replace(/\/+$/, "");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!dbUrl || !baseUrl || !serviceRole) return json(503, { ok: false, error: "backup_backend_unavailable" });

  const sql = postgres(dbUrl, { prepare: false, max: 1, idle_timeout: 5, connect_timeout: 6, ssl: "require" });
  try {
    const tokenHash = await sha256(token);
    const grant = await sql`
      update public.kombax_backup_export_tokens_v141
         set uses=uses+1,last_used_at=now()
       where token_hash=${tokenHash}
         and active
         and expires_at>now()
         and uses<max_uses
       returning id
    `;
    if (grant.length !== 1) return json(401, { ok: false, error: "backup_capability_invalid_or_expired" });

    const supabase = createClient(baseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
    const currentBucket = await supabase.storage.getBucket(BACKUP_BUCKET);
    if (currentBucket.error) {
      const created = await supabase.storage.createBucket(BACKUP_BUCKET, { public: false });
      if (created.error && !/already|duplicate|exists/i.test(created.error.message)) {
        throw new Error(`bucket_create:${created.error.message}`);
      }
    }

    const snapshotId = `20077-${new Date().toISOString().replace(/[:.]/g, "-")}`;
    const databaseArtifacts: Array<Record<string, unknown>> = [];

    for (const schema of ["public", "auth", "storage"]) {
      const dump = await dumpSchema(sql, schema);
      const path = `${snapshotId}/db/${schema}.ndjson`;
      const upload = await supabase.storage.from(BACKUP_BUCKET).upload(
        path,
        new TextEncoder().encode(dump.body),
        { contentType: "application/x-ndjson", upsert: false },
      );
      if (upload.error) throw new Error(`db_upload_${schema}:${upload.error.message}`);
      databaseArtifacts.push({ schema, path, bytes: dump.bytes, sha256: dump.sha256, tables: dump.tables });
    }

    const sourceObjects = await sql`
      select o.bucket_id,o.name,o.metadata,b.public
        from storage.objects o
        join storage.buckets b on b.id=o.bucket_id
       where o.bucket_id<>${BACKUP_BUCKET}
       order by o.bucket_id,o.name
    `;
    const storageArtifacts: Array<Record<string, unknown>> = [];

    for (const group of batches(Array.from(sourceObjects), 5)) {
      const copied = await Promise.all(group.map(async (object: any) => {
        const bucket = String(object.bucket_id);
        const path = String(object.name);
        const encoded = path.split("/").map(encodeURIComponent).join("/");
        const source = await fetch(`${baseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${encoded}`, {
          headers: { apikey: serviceRole, authorization: `Bearer ${serviceRole}` },
          signal: AbortSignal.timeout(25_000),
        });
        if (!source.ok) throw new Error(`object_download:${bucket}/${path}:${source.status}`);

        const bytes = await source.arrayBuffer();
        const contentType = source.headers.get("content-type") || String(object?.metadata?.mimetype || "application/octet-stream");
        const target = `${snapshotId}/storage/${bucket}/${path}`;
        const upload = await supabase.storage.from(BACKUP_BUCKET).upload(
          target,
          new Uint8Array(bytes),
          { contentType, upsert: false },
        );
        if (upload.error) throw new Error(`object_upload:${bucket}/${path}:${upload.error.message}`);
        return {
          source_bucket: bucket,
          source_path: path,
          path: target,
          bytes: bytes.byteLength,
          sha256: await sha256(bytes),
          content_type: contentType,
          metadata: object.metadata || null,
        };
      }));
      storageArtifacts.push(...copied);
    }

    const migrations = await sql`select version,statements,name from supabase_migrations.schema_migrations order by version`;
    const manifest = {
      kind: "kombax_backup_manifest",
      format: "kombax-pilot-backup-v1",
      build: BUILD,
      snapshot_id: snapshotId,
      created_at: new Date().toISOString(),
      source_project: "poggsobhtutbuagjiydc",
      database_artifacts: databaseArtifacts,
      storage_artifacts: storageArtifacts,
      migrations,
      excluded_auth_tables: Array.from(AUTH_SKIP),
      notes: [
        "Refresh tokens, active sessions, one-time tokens and transient authentication flow state are intentionally excluded.",
        "Backup bucket is private and excluded from source Storage enumeration.",
      ],
    };
    const manifestBody = `${JSON.stringify(manifest, null, 2)}\n`;
    const manifestPath = `${snapshotId}/manifest.json`;
    const manifestUpload = await supabase.storage.from(BACKUP_BUCKET).upload(
      manifestPath,
      new TextEncoder().encode(manifestBody),
      { contentType: "application/json", upsert: false },
    );
    if (manifestUpload.error) throw new Error(`manifest_upload:${manifestUpload.error.message}`);

    const databaseBytes = databaseArtifacts.reduce((sum: number, item: any) => sum + Number(item.bytes || 0), 0);
    const storageBytes = storageArtifacts.reduce((sum: number, item: any) => sum + Number(item.bytes || 0), 0);
    return json(200, {
      ok: true,
      build: BUILD,
      snapshot_id: snapshotId,
      manifest_path: manifestPath,
      manifest_sha256: await sha256(manifestBody),
      database_files: databaseArtifacts.length,
      database_bytes: databaseBytes,
      storage_objects: storageArtifacts.length,
      storage_bytes: storageBytes,
      total_bytes: databaseBytes + storageBytes,
    });
  } catch (error) {
    const raw = error instanceof Error ? error.message : String(error);
    const safe = raw
      .replace(/postgres(?:ql)?:\/\/[^\s]+/gi, "[redacted]")
      .replace(/[A-Za-z0-9_-]{40,}/g, "[redacted]")
      .slice(0, 240);
    console.error("backup-export-20077", safe);
    return json(500, { ok: false, error: "backup_export_failed", detail: safe });
  } finally {
    await sql.end({ timeout: 2 }).catch(() => {});
  }
});
