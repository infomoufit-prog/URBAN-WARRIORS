import { readFile,stat } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC10: ${msg}`);console.log(`OK RC10: ${msg}`)};
const [cfg,repos,community,training,comms,finance,admin,portal,app,backend,components,help,sql,dispatch,reminders,pkg,gradle,sw,mainActivity]=await Promise.all([
  read('web/config.js'),read('web/js/core/repositories.js'),read('web/js/modules/community.js'),read('web/js/modules/training.js'),read('web/js/modules/comms-material.js'),read('web/js/modules/finance.js'),read('web/js/modules/admin.js'),read('web/js/modules/portal.js'),read('web/js/app.js'),read('web/js/core/backend.js'),read('web/js/ui/components.js'),read('web/js/modules/help-legal.js'),read('supabase/migrations/022_rc10_final_mvp_v166.sql'),read('supabase/functions/notification-dispatch/index.ts'),read('supabase/functions/payment-reminders/index.ts'),read('package.json'),read('android/app/build.gradle'),read('web/service-worker.js'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java')
]);
assert(cfg.includes("version: '2.0.0-rc.12'")&&cfg.includes('build: 20012')&&cfg.includes("app_diagnostico_final_v166"),'versionado RC10 / diagnóstico v166');
for(const op of ['notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','sesion.serie.guardar','sesion.excepcion.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar','comunidad.publicar','comunidad.eliminar','comunidad.moderar','perfil.avatar','legal.aceptar']) assert(sql.includes(`'${op}'`)&&repos.includes(`'${op}'`),`operación RC10 gobernada ${op}`);
assert(sql.includes('create table if not exists public.publicaciones_comunidad')&&sql.includes("interval '30 days'")&&sql.includes('v_count>=5')&&sql.includes('v_count>=3')&&sql.includes('15.2'),'Comunidad: 3/5 publicaciones, vídeo 15 s y retención 30 días');
assert(community.includes('3 publicaciones')||community.includes('publicaciones usadas')||community.includes('publicaciones este mes'),'UI Comunidad muestra cuota mensual');
assert(community.includes('duration>15.2')&&community.includes("startsWith('video/')"),'cliente valida vídeo máximo 15 segundos');
assert(dispatch.includes("from('publicaciones_comunidad')")&&dispatch.includes("community-media")&&dispatch.includes('expira_en'),'Edge Function elimina Comunidad caducada y su media');
assert(sql.includes('create table if not exists public.series_sesiones')&&sql.includes('app_generar_sesiones_recurrentes')&&sql.includes("'sesion.excepcion.guardar'"),'sesiones recurrentes y excepciones instaladas');
assert(sql.includes('serie_id=null')&&sql.includes('Serie finalizada por el club')&&sql.includes('Conservada al editar la serie'),'edición/finalización de series preserva histórico y limpia futuro seguro');
assert(training.includes('Sesiones recurrentes')&&training.includes('Cambios / cancelar')&&training.includes('saveSeries'),'UI de recurrencias y excepciones activa');
assert(comms.includes('markAll')&&comms.includes('markGroup')&&comms.includes('Requiere acción'),'notificaciones agrupadas y acciones masivas');
assert(sql.includes('create table if not exists public.preferencias_notificacion')&&!dispatch.includes('allowedByPreference')&&!reminders.includes('pushFinanceDisabled'),'estructura legacy de preferencias preservada, pero el despacho push ya no depende de casillas del alumno');
assert(sql.includes('create or replace view public.v_estado_cuenta_socio')&&finance.includes('Historial financiero')&&finance.includes('Tasa de cobro')&&finance.includes('Por validar'),'Tesorería incluye historial anual y métricas operativas');
assert(repos.includes("uploadAvatar")&&admin.includes('Foto de perfil')&&portal.includes('Foto de perfil')&&components.includes('data-session-avatar'),'perfil privado con avatar integrado');
assert(sql.includes("'condiciones_uso'")&&sql.includes("'privacidad'")&&sql.includes("'comunidad'")&&sql.includes("'derechos_imagen'")&&sql.includes('aceptaciones_legales')&&sql.includes('clubes_seed_legal_rc10'),'textos legales versionados, aceptación persistida y alta futura de clubes cubierta');
assert(app.includes("name:'terms'")&&app.includes("name:'privacy'")&&app.includes("name:'image_rights'")&&app.includes('legal-preview')&&backend.includes('pendingLegal'),'registro muestra y conserva aceptación legal');
assert(help.includes('Manual de usuario')&&help.includes('Manual de equipo')&&help.includes('Cartel')&&help.includes("['direccion','coordinacion','secretaria']"),'Ayuda y recursos restringen cartel al equipo autorizado');
for(const f of ['web/assets/docs/Manual_Usuario_Urban_Warriors.pdf','web/assets/docs/Manual_Equipo_Urban_Warriors.pdf','web/assets/docs/Cartel_Guia_Rapida_Usuarios.png']){const st=await stat(resolve(root,f));assert(st.size>1000,`${f} existe y tiene contenido`)}
assert(dispatch.includes('app_generar_sesiones_recurrentes')&&dispatch.includes('FIREBASE_SERVICE_ACCOUNT_JSON'),'dispatcher mantiene horizonte recurrente y FCM');
assert(app.includes('syncNativePushToken')&&mainActivity.includes('routeFragment')&&mainActivity.includes('onNewIntent'),'Android resincroniza token FCM y abre la ruta de una push al tocarla');
assert(reminders.includes(".in('tipo', ['cuota','aviso_cobro','pago','validacion_pago','recibo'])"),'worker de cobros solo despacha notificaciones financieras');
assert(sql.includes('app_diagnostico_instalacion_v166')&&sql.trimEnd().endsWith('select * from public.app_diagnostico_instalacion_v166();'),'SQL 022 termina con diagnóstico seguro para SQL Editor');
assert(admin.includes('E2E_RC10_')&&admin.includes('Crear serie recurrente y ocurrencia')&&admin.includes('Publicar y borrar en Comunidad'),'E2E del navegador cubre recurrencia y Comunidad');
assert(pkg.includes('test-rc10.mjs')&&gradle.includes('versionCode 20012')&&gradle.includes("versionName '2.0.0-rc.12'")&&sw.includes('rc12-20012'),'tests, Android y service worker versionados RC10');
console.log('RC10 FINAL MVP: PASS');
