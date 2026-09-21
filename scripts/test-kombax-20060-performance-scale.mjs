import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);const read=p=>readFile(new URL(p,root),'utf8');
const [cfg,gradle,app,repos,backend,poller,social,portal,dashboard,migration,rollback,verification,budget]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('web/js/app.js'),read('web/js/core/repositories.js'),read('web/js/core/backend.js'),read('web/js/core/adaptive-poller.js'),read('web/js/modules/kombax-social.js'),read('web/js/modules/portal.js'),read('web/js/modules/dashboard-catalog.js'),read('supabase/migrations/105_kombax_platform_performance_20060.sql'),read('supabase/rollbacks/105_kombax_platform_performance_20060_rollback.sql'),read('supabase/verification/105_kombax_platform_performance_20060_verification.sql'),read('PLATFORM_PERFORMANCE_BUDGET_20060.md')
]);
const ok=(v,m)=>{if(!v)throw new Error(`20060: ${m}`);console.log('OK '+m)};
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]);const android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]);
ok(build>=20060&&android===build,'build web y Android mantienen línea 20060+');
ok(poller.includes("addEventListener('online'")&&poller.includes("addEventListener('offline'")&&poller.includes("visibilitychange")&&poller.includes('Math.pow(2,failures)')&&poller.includes('jitterRatio'),'scheduler adaptativo aplica reconexión, segundo plano, backoff y jitter');
ok(/app_kombax_header_summary_v10[56]/.test(app+repos),'cabecera consume resumen agregado v105+');
ok(!app.includes('repos.notifications.list({force')&&!app.includes('setInterval(()=>refreshNotifications'),'monitor de cabecera no descarga el centro completo ni usa intervalo fijo');
ok(app.includes('activeMs:45000')&&/hiddenMs:(180000|0)/.test(app)&&app.includes('maxMs:600000'),'monitor Club mantiene frecuencia controlada y backoff');
ok(social.includes('createAdaptivePoller(()=>syncNew(false)')&&social.includes('activeMs:2500')&&social.includes('hiddenMs:0')&&/maxMs:(20000|30000)/.test(social),'chat conserva baja latencia visible y pausa/backoff fuera de primer plano');
ok(backend.includes('const readInflight=new Map()')&&backend.includes('dedupeRead(')&&backend.includes('stableArgs'),'lecturas idénticas simultáneas se coalescen por usuario/club');
ok(repos.includes("cachedRead('dashboard:load'")&&!repos.includes("safe('asistencias',`select=id,socio_id,sesion_id,estado"),'dashboard evita consultas no consumidas y reutiliza snapshot corto');
ok(dashboard.includes('notificationSummary?.club_unread_items')&&!dashboard.includes('d.notifs'),'dashboard usa resumen de avisos, no centro completo');
ok(portal.includes('loadPortalDashboard')&&portal.includes('loadPortalSchedule')&&portal.includes('loadPortalProfile')&&!portal.includes('async function loadPortal(){'),'portal carga solo los dominios de cada pantalla');
ok(migration.includes('idx_notificaciones_club_active_feed_v105')&&migration.includes('app_kombax_header_summary_v105'),'migración añade índice y resumen de cabecera');
ok(migration.includes("security definer")&&migration.includes("set search_path to 'public','auth'")&&migration.includes('revoke all')&&migration.includes('grant execute'),'RPC v105 mantiene cierre explícito y search_path fijo');
ok(rollback.includes('drop function if exists public.app_kombax_header_summary_v105')&&verification.includes('anon_closed'),'rollback y verificación 105 disponibles');
ok(budget.includes('50 / 100 / 250 / 500 / 1.000')&&budget.includes('p95'),'presupuesto de rendimiento documenta objetivos y carga staging');
console.log('KOMBAX BUILD 20060 · PLATFORM PERFORMANCE & SCALE HARDENING: PASS');
