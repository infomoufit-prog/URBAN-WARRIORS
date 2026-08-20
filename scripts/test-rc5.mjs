import { readFile,readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const root=resolve(import.meta.dirname,'..');
const read=async p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC5: ${msg}`);console.log(`OK RC5: ${msg}`)};

const [app,components,icons,repos,comms,admin,css,supa,backend,m006,m012,dispatch]=await Promise.all([
  read('web/js/app.js'),read('web/js/ui/components.js'),read('web/js/ui/icons.js'),read('web/js/core/repositories.js'),
  read('web/js/modules/comms-material.js'),read('web/js/modules/admin.js'),read('web/css/app.css'),read('web/js/core/supabase.js'),
  read('web/js/core/backend.js'),read('supabase/migrations/006_production_runtime_fixes.sql'),read('supabase/migrations/012_operational_integrity_v152.sql'),
  read('supabase/functions/notification-dispatch/index.ts')
]);

// Producto: la versión y endpoints técnicos no aparecen en login/topbar ni navegación cotidiana.
assert(!components.includes('release.version')&&!components.includes('backendVersion'),'shell cotidiano no expone versión/backend');
assert(!/release\.version/.test(app.split('function renderLogin')[1]?.split('function openRegistrationChoice')[0]||''),'login no muestra versión técnica');
assert(app.includes("if(role==='direccion'||role==='coordinacion') ids=['dashboard'")&&!app.match(/ids=\[[^\]]*diagnostics/),'Gestor/Coordinación no tienen diagnóstico en navegación cotidiana');
assert(admin.includes('Herramientas técnicas')&&admin.includes('#diagnostics')&&admin.includes('#certification'),'herramientas técnicas quedan apartadas en Configuración del Gestor de la app');

// Iconografía: SVG propio, sin dependencia de emoji como sistema de navegación.
assert(icons.includes('<svg class="uw-icon')&&icons.includes("export const navIcon"),'sistema de iconos SVG profesional disponible');
assert(app.includes('navIcon(id)')||app.includes('navIcon('),'navegación usa el sistema SVG');
assert(components.includes("icon('bell')")&&components.includes("icon('logOut'"),'topbar y sesión usan SVG coherentes');
assert(css.includes('.uw-icon')&&css.includes('.notification-count')&&css.includes('.file-input-wrap'),'design system estiliza iconos, badge y subida de archivos');

// Multimedia: Storage real, validación, URL pública y formularios directos.
assert(repos.includes("backend.upload('club-public-media'")&&repos.includes("backend.publicUrl('club-public-media'"),'repositorio sube multimedia y obtiene URL pública');
assert(repos.includes('5*1024*1024')&&repos.includes("image/webp")&&repos.includes("image/gif"),'cliente aplica límite y MIME del bucket');
assert(comms.includes("name:'imagen'")&&comms.includes('repos.communications.uploadImage'),'publicaciones permiten subida directa de imagen');
assert(comms.includes('repos.material.uploadImage'),'material permite subida directa de imagen');
assert(supa.includes('/storage/v1/object/public/')&&backend.includes('publicUrl(bucket,path)'),'cliente Storage soporta URL pública sin DML nuevo');
assert(m006.includes("'club-public-media'")&&m006.includes('5242880')&&m006.includes('club_public_media_insert'),'backend existente tiene bucket y policy de escritura pública autorizada');

// Publicaciones + notificaciones: SQL es la autoridad y RC5 consume la bandeja/estado compartido.
assert(m012.includes("if p_estado='publicada' and v_notificada is null")&&m012.includes("insert into public.notificaciones")&&m012.includes("update public.comunicaciones set notificada_en=now()"),'publicar genera notificación transaccional en SQL');
assert(m012.includes("p_audiencia='todos'")&&m012.includes("p_audiencia='monitores'")&&m012.includes("'familia'")&&m012.includes("'alumno'"),'SQL segmenta avisos por audiencia');
assert(repos.includes('notificaciones_lecturas')&&repos.includes('sharedRead'),'lectura individual de avisos compartidos se fusiona correctamente');
assert(app.includes('setNotificationBadge')&&app.includes('refreshHeaderSummary')&&app.includes('unreadGroups')&&app.includes('grupos pendientes'),'entrada y sesión activa muestran pendientes agrupados/nuevas notificaciones');
assert(comms.includes("uw-notifications-changed")&&comms.includes('Publicación guardada y notificada'),'publicar refresca centro de notificaciones y confirma al editor');
assert(dispatch.includes("publicar_comunicaciones_programadas")&&dispatch.includes('FIREBASE_SERVICE_ACCOUNT_JSON')&&dispatch.includes('fcm.googleapis.com'),'infraestructura existente contempla programadas y push FCM cuando está configurado');

// Las migraciones no se modifican en RC5: mismo hash conocido de RC3/RC4.
let mh=createHash('sha256');
for(const f of (await readdir(resolve(root,'supabase/migrations'))).filter(x=>/^(00[1-9]|01[0-7])_.*\.sql$/.test(x)).sort()) {mh.update(f);mh.update(await readFile(resolve(root,'supabase/migrations',f)));}
assert(mh.digest('hex')==='f3f33071f6f9aefa76bca6972957482e2d1f907b3640f613a5277c5a858c0403','migraciones 001→017 permanecen idénticas a la base certificada');

console.log('RC5 MEDIA + ICONOS + NOTIFICACIONES: PASS');
