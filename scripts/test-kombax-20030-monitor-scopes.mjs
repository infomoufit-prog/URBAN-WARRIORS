import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const exists=async p=>{try{await access(resolve(root,p));return true}catch{return false}};
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20030: ${msg}`);console.log(`OK KOMBAX 20030: ${msg}`)};

const [cfg,index,sw,gradle,sql57,pre57,verify57,test57,rollback57,app,repos,scopes,members,finance,dashboard,icons,css,release56]=await Promise.all([
  read('web/config.js'),read('web/index.html'),read('web/service-worker.js'),read('android/app/build.gradle'),
  read('supabase/migrations/057_club_work_scopes_finance_privacy.sql'),
  read('supabase/verification/preflight_057_work_scopes.sql'),
  read('supabase/verification/verify_057_work_scopes.sql'),
  read('supabase/verification/test_057_work_scopes_transactional.sql'),
  read('supabase/rollbacks/057_club_work_scopes_finance_privacy_rollback.sql'),
  read('web/js/app.js'),read('web/js/core/repositories.js'),read('web/js/modules/work-scopes.js'),
  read('web/js/modules/groups-members.js'),read('web/js/modules/finance.js'),read('web/js/modules/dashboard-catalog.js'),
  read('web/js/ui/icons.js'),read('web/css/kombax-premium.css'),read('supabase/migrations/056_kombax_release_contract.sql')
]);

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
assert(build>=20030&&androidBuild>=20030,'Web y Android conservan o superan build 20030');
assert(index.includes(`?v=${build}`)&&sw.includes(String(build))&&Number(release56.match(/'build',\s*(\d+)/)?.[1]||0)>=20030,'runtime, service worker y release contract conservan versionado 20030+');
for(const p of ['supabase/migrations/057_club_work_scopes_finance_privacy.sql','supabase/verification/preflight_057_work_scopes.sql','supabase/verification/verify_057_work_scopes.sql','supabase/verification/test_057_work_scopes_transactional.sql','supabase/rollbacks/057_club_work_scopes_finance_privacy_rollback.sql']) assert(await exists(p),`${p} presente`);

for(const table of ['club_ambitos_trabajo','club_ambito_equipo','club_ambito_socios','club_ambito_grupos']) assert(sql57.includes(`public.${table}`),`057 crea/usa ${table}`);
assert(sql57.includes('uq_ambito_socio_principal_v057')&&sql57.includes('where activo and principal'),'un alumno tiene como máximo un ámbito principal activo');
assert(sql57.includes("finance_level in ('none','status','portfolio','collect','receipts')"),'niveles financieros son explícitos y de mínimo privilegio');
assert(sql57.includes('app_kombax_puede_gestionar_ambitos_v057')&&sql57.includes('app_kombax_es_monitor_restringido_v057'),'057 separa administración de ámbitos y monitor restringido');
assert(sql57.includes('monitor_asignado_a_grupo_v057')&&sql57.includes('monitor_puede_ver_socio_v057'),'asignación multi-monitor se resuelve en backend');
assert(sql57.includes('app_kombax_monitor_puede_asistencia_registro_v057')&&sql57.includes('app_kombax_monitor_puede_seguimiento_v057'),'asistencia y seguimiento tienen guards granulares');
assert(sql57.includes('app_kombax_mis_alumnos_v057')&&sql57.includes('app_kombax_mi_cartera_v057')&&sql57.includes('app_kombax_mi_progreso_v057'),'monitor usa proyecciones seguras de alumnos, cartera y progreso');
assert(sql57.includes('app_kombax_monitor_cobro_v057')&&sql57.includes("not in ('collect','receipts')"),'registro de cobros exige permiso financiero específico');
assert(sql57.includes('app_kombax_ambito_mutate_v057')&&sql57.includes("'ambito.team.set'")&&sql57.includes("'ambito.student.set'")&&sql57.includes("'ambito.group.set'"),'Gestor/Coordinación administran equipo, alumnos y grupos por RPC');
assert(sql57.includes('update public.club_ambito_socios set principal=false')&&sql57.includes('socio_id=v_socio'),'al cambiar ámbito principal se limpia el principal anterior');

const puedeVerStart=sql57.indexOf('create or replace function public.puede_ver_socio');
const puedeVerEnd=sql57.indexOf('create or replace function public.puede_ver_grupo',puedeVerStart);
const puedeVerBody=sql57.slice(puedeVerStart,puedeVerEnd);
assert(puedeVerStart>=0&&!/monitor_puede_ver_socio|rol='monitor'|rol = 'monitor'/.test(puedeVerBody),'puede_ver_socio queda reservado a acceso administrativo/familiar, no monitor');
const sociosPolicy=sql57.slice(sql57.indexOf('create policy socios_lectura'),sql57.indexOf('-- Los monitores solo pueden enumerar sus grupos'))
assert(sql57.includes('drop policy if exists socios_lectura')&&sociosPolicy.includes('create policy socios_lectura')&&!/monitor_puede|rol=['\"]monitor/i.test(sociosPolicy),'monitor no obtiene SELECT de la fila administrativa completa de socios');
assert(sql57.includes('create policy member_documents_read')&&sql57.includes('puede_aportar_pago_socio')&&!sql57.slice(sql57.indexOf('create policy member_documents_read'),sql57.indexOf('create policy member_documents_insert')).includes('puede_ver_socio'),'Storage de documentos privados no hereda el acceso deportivo del monitor');
assert(sql57.includes('create policy recibos_cuota_lectura')&&!sql57.slice(sql57.indexOf('create policy recibos_cuota_lectura'),sql57.indexOf('drop policy if exists member_documents_read')).includes('puede_ver_socio'),'recibos no heredan acceso operativo del monitor');
assert(sql57.includes('create policy reservas_sesion_lectura')&&sql57.includes('monitor_puede_ver_socio_v057'),'reservas quedan limitadas al ámbito del monitor');
assert(sql57.includes('create policy series_sesiones_lectura_rc10')&&sql57.includes('monitor_asignado_a_grupo_v057'),'series de sesiones quedan limitadas a grupos asignados');
assert(sql57.includes('create policy asistencia_gestion')&&sql57.includes('app_kombax_monitor_puede_asistencia_registro_v057'),'escritura de asistencia exige sesión/alumno dentro del ámbito');
assert(sql57.includes('create policy seguimiento_gestion')&&sql57.includes('app_kombax_monitor_puede_seguimiento_v057'),'seguimiento exige permiso específico del ámbito');
assert(sql57.includes('app_mutate_v160_pre_work_scopes_057')&&sql57.includes('MONITOR_SCOPE_REQUIRED'),'gateway de sesiones bloquea operaciones fuera del ámbito y conserva wrapper anterior');
assert(sql57.includes("current_setting('request.jwt.claim.role',true)")&&sql57.includes("='service_role'")&&sql57.includes('app_generar_sesiones_recurrentes'),'generación recurrente distingue service_role/elevados de monitor restringido');

assert(pre57.includes('app_kombax_release_contract_v056')&&pre57.includes('not_applied_yet'),'preflight 057 exige 056 y evita doble aplicación');
assert(verify57.includes('raw_student_row_private_ok')&&verify57.includes('document_storage_private_ok')&&verify57.includes('receipts_private_ok')&&verify57.includes('session_gateway_scoped_ok'),'verify 057 certifica privacidad de socios, documentos, recibos y gateway');
assert(/rollback;/i.test(test57)&&/MONITOR_A|Monitor A/i.test(test57)&&/MONITOR_B|Monitor B/i.test(test57),'test 057 exige separación real entre dos monitores y revierte la prueba');
assert(rollback57.includes('app_mutate_v160_pre_work_scopes_057')&&rollback57.includes('drop table if exists public.club_ambito_grupos'),'rollback 057 restaura gateway previo y elimina tablas nuevas');

assert(app.includes("scopes:'Ámbitos y privacidad'")&&app.includes('scopes:renderWorkScopes'),'navegación expone administración de ámbitos');
assert(app.includes("role==='monitor'&&id==='members'?'Mis alumnos'")&&app.includes("role==='monitor'&&id==='finance'?'Mi cartera'"),'monitor ve navegación contextual Mis alumnos / Mi cartera');
assert(scopes.includes('Ámbitos y privacidad')&&scopes.includes('finance_level')&&scopes.includes('ver_contacto')&&scopes.includes('gestionar_asistencia')&&scopes.includes('gestionar_seguimiento'),'editor de ámbitos permite configurar privacidad operativa y financiera');
assert(scopes.includes("['direccion','secretaria','economia','comunicacion','monitor']")||scopes.includes("['direccion','secretaria','economia','comunicacion','monitor','coordinacion']"),'asignación de ámbito filtra personal operativo y no alumnos');
assert(members.includes('renderMonitorMembers')&&members.includes('repos.scopes.students()')&&members.includes('datos administrativos, familiares, documentales y financieros permanecen separados'),'vista de monitor usa RPC segura y explica aislamiento de datos');
assert(finance.includes('renderMonitorFinance')&&finance.includes('repos.scopes.finance()')&&finance.includes('Solo estado de pago')&&finance.includes('repos.scopes.collect'),'Mi cartera respeta nivel financiero y cobro controlado');
assert(repos.includes('app_kombax_mis_alumnos_v057')&&repos.includes('app_kombax_mi_cartera_v057')&&repos.includes('app_kombax_monitor_cobro_v057'),'repositorio utiliza RPC 057 en lugar de tablas administrativas para monitor');
assert(dashboard.includes('Mis alumnos')||dashboard.includes('Mis grupos'),'dashboard del monitor mantiene navegación operativa propia');
assert(icons.includes("scopes:'shieldCheck'")&&css.includes('.work-scope-card'),'UI incluye iconografía y estilos de ámbitos');
assert(!/if\s*\([^)]*email[^)]*\)/i.test(scopes+members+finance),'permisos de ámbitos no dependen de email hardcodeado');

assert(/^\s*(?:--[^\n]*\n\s*)*begin;/i.test(sql57)&&/notify pgrst,'reload schema';\s*commit;\s*$/i.test(sql57),'057 es transaccional y recarga schema');
assert((sql57.match(/\$\$/g)||[]).length%2===0,'057 mantiene $$ equilibrados');
assert(!/returns\s+table\([^)]*\bposition\s+integer/i.test(sql57),'057 no reintroduce conflicto SQL con position');
console.log('KOMBAX BUILD 20030 MONITOR SCOPES + FINANCE PRIVACY STATIC: PASS');
