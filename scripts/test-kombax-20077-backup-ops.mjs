import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const m141=read('supabase/migrations/141_kombax_backup_export_gateway_20077.sql');
const m142=read('supabase/migrations/142_kombax_backup_run_tracking_20077.sql');
const exporter=read('supabase/functions/backup-export-20077/index.ts');
const verifier=read('supabase/functions/backup-verify-20077/index.ts');
const netlify=read('netlify.toml');

assert.match(m141,/kombax_backup_export_tokens_v141/);
assert.match(m141,/token_hash text not null unique/);
assert.match(m141,/enable row level security/i);
assert.match(m141,/revoke all .* anon, authenticated/i);
assert.match(m141,/grant select, insert, update, delete .* service_role/i);

assert.match(m142,/kombax_backup_runs_v142/);
assert.match(m142,/status in \('created','verified','failed'\)/);
assert.match(m142,/verification_failures/);
assert.match(m142,/manifest_sha256/);
assert.match(m142,/enable row level security/i);
assert.match(m142,/revoke all .* anon, authenticated/i);

for(const src of [exporter,verifier]){
  assert.match(src,/x-kombax-backup-token/,'capacidad de backup solo por cabecera');
  assert.doesNotMatch(src,/searchParams\.get\(["']token["']\)/,'el token no viaja por URL');
  assert.match(src,/SUPABASE_DB_URL/);
  assert.match(src,/SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(src,/sb_secret_[A-Za-z0-9_-]+|eyJ[A-Za-z0-9_-]{20,}/,'sin secretos incrustados');
}

assert.match(exporter,/BACKUP_BUCKET\s*=\s*["']kombax-backups["']/);
assert.match(exporter,/createBucket\(BACKUP_BUCKET,\s*\{\s*public:\s*false\s*\}/);
assert.match(exporter,/refresh_tokens/);
assert.match(exporter,/one_time_tokens/);
assert.match(exporter,/kombax_backup_export_tokens_v141/);
assert.match(exporter,/kombax_backup_runs_v142/);
assert.match(exporter,/storageArtifacts/);
assert.match(exporter,/manifest_sha256/);
assert.match(exporter,/crypto\.subtle\.digest\(["']SHA-256["']/);

assert.match(verifier,/kombax_backup_runs_v142/);
assert.match(verifier,/status.*verified/si);
assert.match(verifier,/expected_artifacts/);
assert.match(verifier,/verification_failures/);
assert.match(verifier,/actual === expected/);
assert.match(verifier,/download\(path\)/);

assert.match(netlify,/from = "https:\/\/urban01\.netlify\.app\/\*"[\s\S]*to = "https:\/\/kombax\.es\/:splat"/);
assert.match(netlify,/from = "https:\/\/main--urban01\.netlify\.app\/\*"[\s\S]*to = "https:\/\/kombax\.es\/:splat"/);

console.log('KOMBAX 20077 backup/verify operational controls: PASS');
