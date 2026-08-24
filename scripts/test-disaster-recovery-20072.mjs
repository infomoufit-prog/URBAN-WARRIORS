import {readFile} from 'node:fs/promises';
function ok(v,m){if(!v)throw new Error(m);console.log('OK',m)}
const full=await readFile(new URL('./backup-kombax-full.ps1',import.meta.url),'utf8');
const dbRestore=await readFile(new URL('./restore-supabase-db.ps1',import.meta.url),'utf8');
const storageBackup=await readFile(new URL('./backup-supabase-storage.mjs',import.meta.url),'utf8');
const storageRestore=await readFile(new URL('./restore-supabase-storage.mjs',import.meta.url),'utf8');
ok(full.includes('backup-supabase-free.ps1'),'backup completo incluye PostgreSQL');
ok(full.includes('backup-supabase-storage.mjs')&&full.includes('--all'),'backup completo incluye todos los buckets Storage');
ok(full.includes('FULL_BACKUP_MANIFEST.json')&&full.includes('SHA256'),'backup completo genera manifiesto de integridad');
ok(!full.match(/sb_secret|service_role\s*=\s*['\"]/i),'script no incrusta secreto');
ok(dbRestore.includes('TARGET_IS_ISOLATED')&&dbRestore.includes('KOMBAX_RESTORE_DATABASE_URL'),'restore DB exige destino aislado y credencial separada');
ok(dbRestore.includes('pg_restore --clean --if-exists --no-owner --no-privileges'),'restore DB usa pg_restore controlado');
ok(storageBackup.includes('--all')&&storageRestore.includes('TARGET_IS_ISOLATED'),'tooling Storage admite backup total y bloquea restore live');
console.log('KOMBAX 20072 disaster recovery tooling: PASS');
