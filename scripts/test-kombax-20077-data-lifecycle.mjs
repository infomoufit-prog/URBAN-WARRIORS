import { readFile } from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [repos,training,members,catalog,comms,lifecycle,m133,m134,m135,m136,m137,m138,admin,config,gradle]=await Promise.all([
  read('web/js/core/repositories.js'),read('web/js/modules/training.js'),read('web/js/modules/groups-members.js'),read('web/js/modules/dashboard-catalog.js'),read('web/js/modules/comms-material.js'),read('web/js/modules/lifecycle.js'),read('supabase/migrations/133_kombax_global_data_lifecycle_history_20077.sql'),read('supabase/migrations/134_kombax_permanent_delete_20077.sql'),read('supabase/migrations/135_kombax_metrics_store_collect_20077.sql'),read('supabase/migrations/136_kombax_metrics_readers_20077.sql'),read('supabase/migrations/137_kombax_retention_cron_20077.sql'),read('supabase/migrations/138_kombax_metrics_backfill_truth_20077.sql'),read('web/js/modules/platform-admin.js'),read('web/config.js'),read('android/app/build.gradle')
]);
const assert=(ok,msg)=>{if(!ok)throw new Error(msg)};
for(const ui of [training,members,catalog,comms])assert(!/Eliminar todo/.test(ui),'La UX normal no debe ofrecer “Eliminar todo”.');
assert(repos.includes("'alumno.eliminar_forzado'")&&repos.includes("'grupo.eliminar_forzado'"),'Se conserva compatibilidad interna de limpieza E2E.');
assert(m133.includes('KOMBAX_DESTRUCTIVE_DELETE_OWNER_MFA_REQUIRED'),'Falta guard de Owner MFA para borrado profundo.');
assert(m133.includes('LIFECYCLE_RESTORE_EXPIRED'),'Falta bloqueo real de restauración caducada.');
assert(m133.includes('app_ciclo_mantenimiento_global_v133'),'Falta mantenimiento global de papelera.');
assert(lifecycle.includes('30 días')&&lifecycle.includes('histórico'),'Archivo/papelera debe explicar retención segura.');

assert(m134.includes('app_ciclo_eliminar_preview_v133'),'Falta previsualización de impacto antes de eliminar definitivamente.');
assert(m134.includes('app_ciclo_eliminar_definitivo_v133'),'Falta eliminación definitiva controlada.');
assert(m135.includes('kombax_metrics_club_daily_v133')&&m135.includes('kombax_metrics_platform_daily_v133'),'Falta capa de métricas agregadas.');
assert(m136.includes('app_kombax_metrics_platform_v133')&&m136.includes('app_kombax_metrics_club_v133'),'Faltan lectores de métricas Owner/club.');
assert(m137.includes('app_kombax_retention_purge_v133'),'Falta purga automática por retención.');
assert(m137.includes('app_kombax_data_maintenance_v133'),'Falta mantenimiento diario integrado.');
assert(m137.includes('kombax-data-lifecycle-daily-v133')&&m137.includes('20 2 * * *'),'Falta cron diario de mantenimiento.');
assert(lifecycle.includes('Eliminar definitivamente')&&lifecycle.includes('ELIMINAR'),'La UI de papelera debe ofrecer eliminación definitiva con confirmación fuerte.');
assert(repos.includes('app_ciclo_eliminar_preview_v133')&&repos.includes('app_ciclo_eliminar_definitivo_v133'),'El repositorio no conecta la eliminación definitiva segura.');
assert(repos.includes('app_kombax_metrics_platform_v133'),'El repositorio Owner no conecta KOMBAX Analytics.');
assert(admin.includes('KOMBAX Analytics')&&admin.includes('MÉTRICAS Y CONSUMO'),'Falta panel de métricas y consumo en Owner.');
assert(m135.includes('storage_bytes')&&m135.includes('payments_amount')&&m135.includes('showcase_leads')&&m135.includes('social_messages'),'Las métricas no cubren consumo/negocio transversal.');
assert(m138.includes('metric_date<current_date')&&m138.includes('case when p_date=current_date then v_storage_objects else 0 end'),'El backfill no debe inventar consumo histórico de Storage.');
assert(m138.includes('creado_en::date<=p_date'),'Las métricas de estado histórico deben respetar la fecha del snapshot.');

const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);
const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]);
assert(configBuild>=20077,'config.js debe conservar como mínimo las garantías de build 20077.');
assert(androidBuild===configBuild,'Web y Android deben compartir el mismo número de build.');
for(const bad of ['limit=5000','limit=3000','limit=2000'])assert(!repos.includes(bad),`Queda una carga masiva ${bad} en repositorios.`);
console.log(`PASS KOMBAX ${configBuild} · data lifecycle & history hardening`);
