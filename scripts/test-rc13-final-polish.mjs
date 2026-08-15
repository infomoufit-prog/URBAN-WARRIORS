import { readFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';
import { weekRange, sortSessionsForWeek } from '../web/js/core/utils.js';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 FINAL POLISH 20020: ${msg}`);console.log(`OK RC13 FINAL POLISH 20020: ${msg}`)};

const [training,portal,app,community,help,css,manifest,gradle,config,sw,colors,adaptive]=await Promise.all([
  read('web/js/modules/training.js'),read('web/js/modules/portal.js'),read('web/js/app.js'),read('web/js/modules/community.js'),read('web/js/modules/help-legal.js'),read('web/css/app.css'),read('web/manifest.webmanifest'),read('android/app/build.gradle'),read('web/config.js'),read('web/service-worker.js'),read('android/app/src/main/res/values/colors.xml'),read('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
]);

const known=weekRange(0,new Date('2026-08-15T12:00:00'));
assert(known.start==='2026-08-10'&&known.end==='2026-08-16','semana natural se calcula de lunes a domingo');
const next=weekRange(1,new Date('2026-08-15T12:00:00'));
assert(next.start==='2026-08-17'&&next.end==='2026-08-23','navegación a semana siguiente conserva rango natural');
const ordered=sortSessionsForWeek([
  {id:'past-old',fecha:'2026-08-11',hora_inicio:'18:00'},
  {id:'future-later',fecha:'2026-08-16',hora_inicio:'18:00'},
  {id:'past-near',fecha:'2026-08-15',hora_inicio:'10:00'},
  {id:'future-near',fecha:'2026-08-15',hora_inicio:'17:00'}
],0,new Date('2026-08-15T12:00:00')).map(x=>x.id);
assert(ordered.join(',')==='future-near,future-later,past-near,past-old','esta semana muestra primero la próxima sesión y después las siguientes; el histórico queda detrás');
assert(training.includes('weekRange(sessionWeekOffset)')&&training.includes("id=\"session-week-prev\"")&&training.includes("card('Sesiones de la semana'"),'gestión de Sesiones trabaja por semana con navegación anterior/actual/siguiente');
assert(portal.includes('weekRange(portalWeekOffset)')&&portal.includes("id=\"portal-week-next\"")&&portal.includes("card('Sesiones de la semana'"),'portal de alumno/familia consulta sesiones por semana sin descargar visualmente todo el horizonte');
assert(portal.includes("badge('Sesión pasada','neutral')")&&portal.includes('sessionKey>=nowKey'),'portal no permite confirmar/cancelar una sesión que ya pasó');
assert(portal.includes("card('Próxima sesión'")&&portal.includes("sessionAttendanceAction(next)")&&portal.includes("Tu próxima sesión seguirá visible arriba"),'portal mantiene visible y accionable la próxima sesión aunque pertenezca a la semana siguiente');
assert(portal.includes('portal-reserve-next')&&portal.includes('portal-cancel-next'),'dashboard permite confirmar o cancelar asistencia directamente sobre la próxima clase');

assert(app.includes("community:'Comunidad del Club'"),'navegación distingue Comunidad del Club');
assert(community.includes("pageHeader('Comunidad del Club'")&&community.includes('COMUNIDAD DEL CLUB ·'),'feed interno se identifica explícitamente como Comunidad del Club');
assert(help.includes('Normas de Comunidad del Club'),'privacidad/ayuda identifica las normas del feed interno');
assert(portal.includes("card('Social Community'")&&portal.includes('COMUNIDAD GENERAL · SERVICIO SOCIAL OPCIONAL')&&portal.includes('Activar Social Community'),'servicio social futuro se presenta como Social Community / Comunidad General');

assert(css.includes('.club-public-logo{border-radius:50%')&&css.includes('.brand-block img,.login-visual img,.login-mini-brand img{border-radius:50%'),'logos de club se recortan en marco circular y ocupan el área visual');
const m=JSON.parse(manifest);const maskable=m.icons.filter(x=>String(x.purpose||'').includes('maskable'));
assert(maskable.length===2&&maskable.some(x=>x.sizes==='192x192')&&maskable.some(x=>x.sizes==='512x512'),'PWA incluye iconos maskable para evitar el recuadro dentro del marco del launcher');
for(const file of ['web/assets/icons/icon-maskable-192.png','web/assets/icons/icon-maskable-512.png','android/app/src/main/res/drawable/ic_launcher_foreground.png','android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml'])await access(resolve(root,file));
assert(adaptive.includes('<adaptive-icon')&&adaptive.includes('@color/launcher_background')&&adaptive.includes('@drawable/ic_launcher_foreground')&&colors.includes('launcher_background'),'Android usa adaptive icon con fondo y foreground propios');

assert(config.includes('build: 20020')&&gradle.includes('versionCode 20020')&&sw.includes('rc13-20020'),'runtime, Android y caché identifican build 20020');
console.log('RC13 BUILD 20020 FINAL POLISH: PASS');
