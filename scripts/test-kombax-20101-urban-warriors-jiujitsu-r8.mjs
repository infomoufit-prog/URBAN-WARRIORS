import {readFile,stat,readdir} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const info=p=>stat(new URL(`../${p}`,import.meta.url));
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20101 R8: ${msg}`);console.log(`OK 20101 R8: ${msg}`)};
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const [events,repos,migration,index,sw,css,packageJson]=await Promise.all([
  read('web/js/modules/kombax-events.js'),read('web/js/core/repositories.js'),read('supabase/migrations/180_kombax_events_urban_warriors_jiujitsu_demo_20101_r8.sql'),read('web/index.html'),read('web/service-worker.js'),read('web/css/kombax-events.css'),read('package.json')
]);
const assetDir=new URL('../web/assets/demo-events/urban-warriors-jiujitsu-interclub/',import.meta.url);
const files=(await readdir(assetDir)).filter(x=>x.endsWith('.webp')).sort();
assert(files.length===15,`evento incluye exactamente 15 imágenes (${files.length})`);
assert(files.every(x=>x.endsWith('.webp')),'todos los assets del evento usan WEBP optimizado');
let total=0;for(const file of files){const s=await stat(new URL(file,assetDir));total+=s.size;assert(s.size<450_000,`${file} queda por debajo de 450 KB (${s.size})`);}
assert(total<3_500_000,`batería visual completa queda por debajo de 3.5 MB (${total})`);
assert(events.includes("URBAN_WARRIORS_JIUJITSU_DEMO_SLUG='urban-warriors-interclub-jiu-jitsu-palafolls-demo'"),'frontend identifica el segundo demo por slug estable');
assert((events.match(/urban-warriors-jiujitsu-interclub\//g)||[]).length>=1,'instalador carga assets desde carpeta dedicada');
assert(events.includes('URBAN_WARRIORS_JIUJITSU_DEMO_ASSETS=Object.freeze([')&&events.includes("orden:15"),'catálogo frontend cubre 15 piezas ordenadas');
assert(events.includes('kx-install-urban-jiujitsu-demo')&&events.includes('installUrbanWarriorsJiuJitsuDemoEvent'),'owner dispone de instalador independiente no destructivo');
assert(events.includes('maybeAutoInstallUrbanWarriorsJiuJitsuAlbum')&&events.includes('if(!demo){await installUrbanWarriorsJiuJitsuDemoEvent({openAfter:false,silent:true});return;}'),'evento y álbum se auto-instalan en primer acceso owner y se reparan sin duplicar media');
assert(repos.includes("app_kombax_demo_urban_warriors_jiujitsu_seed_v180"),'repositorio llama al bootstrap R8 específico');
assert(migration.includes("'interclub','Urban Warriors · Interclub de Jiu-Jitsu · Palafolls'")&&migration.includes("creador_tipo='club'"),'seed crea un Interclub perteneciente al club real');
assert(migration.includes("lower(trim(c.slug))='urban-warriors'")&&!migration.includes("11111111-1111-4111-8111-111111111111"),'seed resuelve Urban Warriors por identidad estable sin ID hardcodeado');
assert(migration.includes("capacidad_clave='events.public.organize'")&&migration.includes('URBAN_WARRIORS_EVENTS_NOT_ENABLED'),'bootstrap exige entitlement real de Events');
assert(migration.includes("'Benjamín 8-10 · -30 kg'")&&migration.includes("'Juvenil 16-17 · -70 kg'")&&migration.includes("'Adulto · cinturón negro · -82 kg'"),'Fight Card cubre menores desde 8 años, juveniles y adultos');
assert(migration.includes("'Adulto femenino · cinturón morado'")&&migration.includes("destacado,creado_por)\n  values(v_event,a,b,'Jiu-Jitsu','Adulto · cinturón negro'"),'hay dos combates estelares adulto masculino y femenino');
assert(!events.includes('urban-warriors-jiujitsu-interclub/video')&&!files.some(x=>/\.(mp4|webm|mov)$/i.test(x)),'evento R8 no incorpora vídeo');
assert(revisionAtLeast(index,8)&&revisionAtLeast(sw,8,'media-r'),'cache-busting R8+ evita reutilizar assets anteriores');
assert(css.includes('.kx-demo-event-panel-urban'),'panel QA del segundo evento mantiene jerarquía visual Events');
assert(packageJson.includes('test:20101:r8'),'package expone test específico R8');
console.log('PASS 20101 R8 Urban Warriors Jiu-Jitsu Event');
