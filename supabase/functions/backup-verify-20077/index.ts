import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.7";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const BUILD = 20077;
const BUCKET = "kombax-backups";
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

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") return json(405, { ok: false, error: "method_not_allowed" });

  const url = new URL(req.url);
  const token = (req.headers.get("x-kombax-backup-token") || "").trim();
  const snapshotId = (url.searchParams.get("snapshot") || "").trim();
  if (token.length < 48 || token.length > 256) return json(401, { ok: false, error: "backup_capability_required" });
  if (!/^20077-[0-9TZ-]{20,60}$/.test(snapshotId)) return json(400, { ok: false, error: "snapshot_invalid" });

  const dbUrl = Deno.env.get("SUPABASE_DB_URL") || "";
  const baseUrl = (Deno.env.get("SUPABASE_URL") || "").replace(/\/+$/, "");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!dbUrl || !baseUrl || !serviceRole) return json(503, { ok: false, error: "verification_backend_unavailable" });

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
    const manifestDownload = await supabase.storage.from(BUCKET).download(`${snapshotId}/manifest.json`);
    if (manifestDownload.error || !manifestDownload.data) {
      throw new Error(`manifest_download:${manifestDownload.error?.message || "missing"}`);
    }

    const manifestBytes = new Uint8Array(await manifestDownload.data.arrayBuffer());
    const manifestText = new TextDecoder().decode(manifestBytes);
    const manifest = JSON.parse(manifestText);
    const manifestHash = await sha256(manifestBytes);
    if (manifest?.snapshot_id !== snapshotId || manifest?.build !== BUILD) throw new Error("manifest_identity_mismatch");

    const databaseArtifacts = Array.isArray(manifest.database_artifacts) ? manifest.database_artifacts : [];
    const storageArtifacts = Array.isArray(manifest.storage_artifacts) ? manifest.storage_artifacts : [];
    const artifacts = [...databaseArtifacts, ...storageArtifacts];
    const failures: Array<Record<string, unknown>> = [];
    let actualBytes = 0;
    let verified = 0;

    for (const group of batches(artifacts, 5)) {
      const results = await Promise.all(group.map(async (artifact: any) => {
        const path = String(artifact.path || "");
        const expected = String(artifact.sha256 || "");
        const download = await supabase.storage.from(BUCKET).download(path);
        if (download.error || !download.data) return { path, ok: false, error: download.error?.message || "missing" };
        const bytes = new Uint8Array(await download.data.arrayBuffer());
        const actual = await sha256(bytes);
        return {
          path,
          ok: actual === expected,
          expected,
          actual,
          bytes: bytes.byteLength,
          expected_bytes: Number(artifact.bytes || 0),
        };
      }));
      for (const result of results) {
        actualBytes += Number((result as any).bytes || 0);
        if ((result as any).ok) verified += 1;
        else failures.push(result);
      }
    }

    const expectedCount = artifacts.length;
    const expectedBytes = artifacts.reduce((sum: number, item: any) => sum + Number(item.bytes || 0), 0);
    const ok = failures.length === 0 && verified === expectedCount && actualBytes === expectedBytes;
    await sql`
      insert into public.kombax_backup_runs_v142(
        snapshot_id,build,status,database_files,storage_objects,total_bytes,manifest_sha256,
        verification_failures,verified_at,detail
      ) values(
        ${snapshotId},${BUILD},${ok ? "verified" : "failed"},${databaseArtifacts.length},${storageArtifacts.length},
        ${expectedBytes},${manifestHash},${failures.length},now(),
        ${sql.json({ expected_count: expectedCount, verified_count: verified, expected_bytes: expectedBytes, actual_bytes: actualBytes, failures })}
      )
      on conflict(snapshot_id) do update set
        status=excluded.status,
        database_files=excluded.database_files,
        storage_objects=excluded.storage_objects,
        total_bytes=excluded.total_bytes,
        manifest_sha256=excluded.manifest_sha256,
        verification_failures=excluded.verification_failures,
        verified_at=excluded.verified_at,
        detail=excluded.detail
    `;

    return json(ok ? 200 : 409, {
      ok,
      build: BUILD,
      snapshot_id: snapshotId,
      manifest_sha256: manifestHash,
      database_files: databaseArtifacts.length,
      storage_objects: storageArtifacts.length,
      verified_artifacts: verified,
      expected_artifacts: expectedCount,
      total_bytes: expectedBytes,
      failures: failures.length,
    });
  } catch (error) {
    const raw = error instanceof Error ? error.message : String(error);
    const safe = raw
      .replace(/postgres(?:ql)?:\/\/[^\s]+/gi, "[redacted]")
      .replace(/[A-Za-z0-9_-]{40,}/g, "[redacted]")
      .slice(0, 240);
    console.error("backup-verify-20077", safe);
    try {
      await sql`
        insert into public.kombax_backup_runs_v142(snapshot_id,build,status,verification_failures,verified_at,detail)
        values(${snapshotId},${BUILD},'failed',1,now(),${sql.json({ error: safe })})
        on conflict(snapshot_id) do update set
          status='failed',verification_failures=1,verified_at=now(),detail=excluded.detail
      `;
    } catch {}
    return json(500, { ok: false, error: "backup_verification_failed", detail: safe });
  } finally {
    await sql.end({ timeout: 2 }).catch(() => {});
  }
});
