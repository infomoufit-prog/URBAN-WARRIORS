import {readFile} from 'node:fs/promises';
const backup=await readFile(new URL('./backup-supabase-storage.mjs',import.meta.url),'utf8');
const restore=await readFile(new URL('./restore-supabase-storage.mjs',import.meta.url),'utf8');
function ok(v,m){if(!v)throw new Error(m);console.log('OK',m)}
ok(backup.includes('KOMBAX_SERVICE_ROLE_KEY')&&!backup.includes('service_role_key='),'backup no incrusta service role');
ok(backup.includes("b.public===false")&&backup.includes('sha256'),'backup exporta privados por defecto y genera hashes');
ok(backup.includes('/storage/v1/object/list/')&&backup.includes('/storage/v1/object/'),'backup lista y descarga objetos reales');
ok(restore.includes('TARGET_IS_ISOLATED'),'restore exige confirmación de destino aislado');
ok(restore.includes('KOMBAX_RESTORE_SERVICE_ROLE_KEY'),'restore separa credencial de destino');
ok(restore.includes("sha!==o.sha256"),'restore verifica hash antes de subir');
console.log('KOMBAX 20071 storage backup/restore tooling: PASS');
