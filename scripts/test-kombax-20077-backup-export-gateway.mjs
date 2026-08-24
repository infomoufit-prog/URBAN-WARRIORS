import fs from 'node:fs';
import assert from 'node:assert/strict';
const exportFn=fs.readFileSync(new URL('../supabase/functions/backup-export-20077/index.ts',import.meta.url),'utf8');
const verifyFn=fs.readFileSync(new URL('../supabase/functions/backup-verify-20077/index.ts',import.meta.url),'utf8');
const mig141=fs.readFileSync(new URL('../supabase/migrations/141_kombax_backup_export_gateway_20077.sql',import.meta.url),'utf8');
const mig142=fs.readFileSync(new URL('../supabase/migrations/142_kombax_backup_run_tracking_20077.sql',import.meta.url),'utf8');
for(const fn of [exportFn,verifyFn]){
  assert.match(fn,/x-kombax-backup-token/);
  assert.doesNotMatch(fn,/searchParams\.get\(['"]token['"]\)/);
  assert.match(fn,/token_hash/);
  assert.match(fn,/expires_at>now\(\)/);
  assert.match(fn,/uses<max_uses/);
  assert.match(fn,/cache-control/);
}
assert.match(exportFn,/kombax-backups/);
assert.match(exportFn,/refresh_tokens/);
assert.match(exportFn,/where o\.bucket_id<>\$\{BACKUP_BUCKET\}/);
assert.match(verifyFn,/verification_failures/);
for(const mig of [mig141,mig142]){
  assert.match(mig,/enable row level security/i);
  assert.match(mig,/revoke all on table .* from public, anon, authenticated/i);
}
console.log('PASS KOMBAX 20077 backup export/verify hardening');
