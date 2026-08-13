import { readFile } from 'node:fs/promises';

const migration=await readFile(new URL('../supabase/migrations/023_restore_rc10_gateway_v166.sql',import.meta.url),'utf8');
const rollback=await readFile(new URL('../supabase/rollbacks/023_restore_rc10_gateway_v166.sql',import.meta.url),'utf8');

for(const operation of ['notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','comunidad.publicar']){
  if(!migration.includes(operation))throw new Error(`023 no verifica ${operation}`);
}
if(!migration.includes('app_mutate_v160_pre_restore_023'))throw new Error('023 no conserva punto de rollback');
if(!migration.includes('app_mutate_v160_v166'))throw new Error('023 no recupera la función RC10 preservada');
if(!migration.includes('revoke all on function public.app_mutate_v160_pre_restore_023'))throw new Error('El backup debe quedar sin ejecución pública');
if(!migration.includes('app_diagnostico_instalacion_v166()'))throw new Error('023 no termina con diagnóstico');
if(!rollback.includes('app_mutate_v160_pre_restore_023'))throw new Error('Falta rollback de 023');
if(/drop table|truncate|delete from/i.test(migration))throw new Error('023 no puede modificar datos');

console.log('OK 023: recuperación RC10 aislada, verificable y reversible');
