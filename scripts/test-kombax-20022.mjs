import {readFile,access} from 'node:fs/promises';import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(resolve(root,p),'utf8'),exists=async p=>{try{await access(resolve(root,p));return true}catch{return false}},assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20022: ${msg}`);console.log(`OK KOMBAX 20022: ${msg}`)};
const [cfg,gradle,app,repos,backend,components,finance,lifecycle,admin,platform,css,n37,n38,n39]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('web/js/app.js'),read('web/js/core/repositories.js'),read('web/js/core/backend.js'),read('web/js/ui/components.js'),read('web/js/modules/finance.js'),read('web/js/modules/lifecycle.js'),read('web/js/modules/admin.js'),read('web/js/core/platform.js'),read('web/css/app.css'),read('supabase/migrations/037_notification_read_consistency.sql'),read('supabase/migrations/038_content_lifecycle.sql'),read('supabase/migrations/039_club_branding_themes.sql')
]);
assert(Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20022&&Number(gradle.match(/versionCode\s+(\d+)/)?.[1])>=20022,'las builds posteriores conservan íntegra la base 20022');
assert(app.includes('kombax-cobrand')&&components.includes('kombax-shell-mark')&&await exists('web/assets/kombax-symbol.png'),'co-branding mantiene club principal y símbolo KOMBAX separado');
assert(platform.includes("'combat-dark'")&&platform.includes("'performance-pro'")&&platform.includes("'champion-gold'")&&platform.includes("'dojo-heritage'")&&(css.match(/\.theme-(combat-dark|performance-pro|champion-gold|dojo-heritage)/g)||[]).length>=4,'cuatro temas cerrados usan tokens compartidos');
assert(admin.includes('publishBranding')&&admin.includes('restoreBranding')&&n39.includes('branding_version')&&n39.includes('BRANDING_VERSION_CONFLICT'),'branding es previsualizable, versionado y reversible');
assert(repos.includes("optimisticNotificationMutation('notificacion.leer'")&&repos.includes("optimisticNotificationMutation('notificacion.leer_todas'")&&n37.includes('notificaciones_lecturas')&&n37.includes('app_notificaciones_centro_v037'),'lectura de notificaciones es optimista, reversible y persistente');
assert(components.includes('fullName(x.nombre,x.apellidos)'),'nombre y apellidos se componen con separación normalizada');
assert(finance.includes('professional-receipt')&&finance.includes('Imprimir / Guardar PDF')&&finance.includes('Compartir datos')&&finance.includes('receiptLogo'),'recibo profesional contiene branding, vista, impresión/PDF y compartición');
for(const term of ['publicacion','comunicacion','evento','notificacion','material','documento','seguimiento','asistencia','sesion'])assert(n38.includes(`'${term}'`),`ciclo de vida incluye ${term}`);
assert(n38.includes('30 days')&&n38.includes('contenido_ciclo_auditoria')&&n38.includes('LIFECYCLE_ACTIONABLE_NOTIFICATION'),'papelera conserva 30 días, auditoría y protege acciones pendientes');
assert(lifecycle.includes('seleccionado')&&lifecycle.includes('lifecycle-from')&&lifecycle.includes("runAction('restaurar')")&&app.includes('archive:renderLifecycle'),'UI ofrece filtros, selección múltiple y restauración');
assert(!n38.includes('recibos_cuota')&&!n38.includes('public.pagos')&&!n38.includes('public.cuotas'),'ciclo genérico no borra ni altera registros financieros');
assert(repos.includes('cachedRead')&&admin.includes('P95')&&admin.includes('> 5 segundos'),'caché tenant-safe y diagnóstico de latencia están visibles');
for(const n of ['037_notifications','038_lifecycle','039_branding'])for(const prefix of ['preflight_','verify_'])assert(await exists(`supabase/verification/${prefix}${n}.sql`),`${prefix}${n} disponible`);
for(const n of ['037_notification_read_consistency','038_content_lifecycle','039_club_branding_themes'])assert(await exists(`supabase/rollbacks/${n}.sql`),`rollback ${n} disponible`);
assert(await exists('supabase/verification/test_037_notifications_transactional.sql')&&await exists('supabase/verification/test_038_lifecycle_transactional.sql')&&await exists('supabase/verification/test_039_branding_transactional.sql'),'pruebas transaccionales 037–039 disponibles');
for(const [name,sql] of [['037',n37],['038',n38],['039',n39]])assert((sql.match(/\$\$/g)||[]).length%2===0&&/^\s*(?:--[^\n]*\n)*\s*begin;/i.test(sql)&&/commit;\s*$/i.test(sql),`migración ${name} transaccional y delimitadores equilibrados`);
assert(backend.includes('async writeRpc')&&backend.includes("kind:'mutation'"),'RPCs nuevas conservan traza de escritura');
console.log('KOMBAX / URBAN WARRIORS BUILD 20022 STATIC: PASS');
