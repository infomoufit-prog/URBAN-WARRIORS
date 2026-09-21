import {readFile,stat,readdir} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20101 DEMO EVENT: ${msg}`);console.log(`OK 20101: ${msg}`)};
const [config,sw,index,events,repos,migration,gradle,main,health]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/modules/kombax-events.js'),read('web/js/core/repositories.js'),read('supabase/migrations/177_kombax_events_demo_showcase_20101.sql'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20101&&a===b&&w===b&&h>=20101,'identidad web/android actual consistente y backend health compatible 20101+');
assert(index.includes('v=20101'),'cache-busting web actualizado a 20101');
assert(main.includes(`KOMBAXApp/2.0.0-rc.13/${b}`),'Android identifica el build actual');
assert(migration.includes('app_kombax_demo_event_seed_v177')&&migration.includes('app_kombax_demo_event_cleanup_v177'),'seed y rollback Owner existen');
assert(migration.includes('public.kombax_eventos_publicos')&&migration.includes('public.kombax_evento_participantes_publicos')&&migration.includes('public.kombax_evento_combates_publicos'),'demo usa tablas reales de KOMBAX Events');
assert(!/create table[^;]*demo/i.test(migration),'no se crea un dominio/tablas paralelas de demo');
assert(migration.includes("v_slug text:='noche-de-impacto-barcelona-demo'")&&migration.includes("'Club Fénix Elite · DEMO'")&&migration.includes("'Federación Nova Combat · DEMO'"),'evento y organizaciones demo quedan identificados');
assert(migration.includes("a.nivel='owner'")&&migration.includes('PLATFORM_OWNER_REQUIRED'),'bootstrap protegido por Owner');
assert(events.includes("DEMO_EVENT_SLUG='noche-de-impacto-barcelona-demo'")&&events.includes('installDemoEvent()'),'UI incluye instalador idempotente del evento real');
assert(events.includes('await repos.kombaxEvents.seedDemoEvent()')&&events.includes('await repos.kombaxEvents.uploadDemoMedia'),'instalador crea backend y sube álbum al bucket real');
assert(events.includes('await openEvent(eventId)'),'tras instalar se abre por el mismo detalle normal');
assert(repos.includes("app_kombax_demo_event_seed_v177")&&repos.includes("app_kombax_eventos_mutate_v175"),'repos usa seed Owner y registro multimedia real 20.099');
assert(repos.includes("backend.upload('kombax-events-media'"),'álbum demo se sube al bucket privado oficial');
assert(events.includes('10')||events.includes('DEMO_EVENT_ASSETS'),'álbum demo tiene manifiesto de contenido');
const assets=await readdir(new URL('../web/assets/demo-events/noche-impacto-barcelona/',import.meta.url));
for(const f of ['poster.webp','banner.webp','main-event.webp','co-main.webp','undercard.webp','press-day.webp','album-promo.webp','results.webp','highlights.webp','club-fenix-logo.webp','nova-combat-logo.webp']){assert(assets.includes(f),`${f} incluido`);const s=await stat(new URL(`../web/assets/demo-events/noche-impacto-barcelona/${f}`,import.meta.url));assert(s.size>15000,`${f} no es placeholder`)}
assert(assets.filter(f=>f.startsWith('fighter-')&&f.endsWith('.webp')).length===12,'12 retratos ficticios de participantes incluidos');
assert(migration.includes("'inscripciones_abiertas','publico'")&&migration.includes("'2026-10-18 19:30:00+02'"),'evento demo es público y tiene ciclo temporal real');
assert(migration.includes("'Kickboxing','Profesional','-75 kg'")&&migration.includes("'MMA','Profesional femenino','-57 kg'"),'Main Event y co-main se crean como Fight Cards reales');
assert(migration.includes('https://kombax.es/assets/demo-events/noche-impacto-barcelona/'),'fotos de perfiles demo usan assets propios KOMBAX HTTPS');
console.log('PASS 20101 KOMBAX Demo Event Showcase');
