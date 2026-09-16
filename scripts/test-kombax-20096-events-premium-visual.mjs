import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20096 EVENTS PREMIUM VISUAL: ${msg}`);console.log(`OK 20096: ${msg}`)};
const [config,sw,index,css,events,icons,gradle,main,health,mesh,fightSq,fightStory,eventSq,eventStory,fightShareSq,fightShareStory,resultSq,resultStory]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/css/kombax-events.css'),read('web/js/modules/kombax-events.js'),read('web/js/ui/icons.js'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts'),read('web/assets/events/kombax-events-neon-mesh.svg'),read('web/assets/events/templates/fight-card-square.svg'),read('web/assets/events/templates/fight-card-story.svg'),read('web/assets/events/templates/event-share-square.svg'),read('web/assets/events/templates/event-share-story.svg'),read('web/assets/events/templates/fight-share-square.svg'),read('web/assets/events/templates/fight-share-story.svg'),read('web/assets/events/templates/result-share-square.svg'),read('web/assets/events/templates/result-share-story.svg')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20096&&a>=20096&&w>=20096&&h>=20096,'identidad 20096 o superior consistente en web/PWA/Android/health local');
assert(/kombax-events\.css\?v=20(?:096|09[7-9]|1\d{2,})/.test(index),'cache-busting de Eventos conserva versión 20096 o superior');
assert(icons.includes("arena:'")&&icons.includes("'kombax-events':'arena'"),'KOMBAX Eventos usa icono de arena propio');
assert(events.includes('CATEGORY_ICON')&&events.includes("velada:'flame'")&&events.includes("campeonato:'trophy'")&&events.includes("torneo:'medal'"),'categorías usan iconografía semántica específica');
assert((events.includes('kx-events-neon-field')&&events.includes('kx-arena-spark'))||events.includes("brandHero({area:'events'"),'hero conserva identidad visual premium propia o evoluciona al Brand Hero compartido');
assert(css.includes('--ke-cyan:#49f3ff')&&css.includes('--ke-violet:#a85cff')&&css.includes('kombax-events-neon-mesh.svg'),'paleta premium añade neón cian/violeta sobre rojo KOMBAX');
assert(css.includes('@keyframes kxPremiumBackdrop')&&css.includes('@keyframes kxNeonDriftA')&&css.includes('@keyframes kxArenaSpark'),'motion premium tiene animaciones ambientales dedicadas');
assert(css.includes('@media(prefers-reduced-motion:reduce)')&&css.includes('.kx-events-neon-field span')&&css.includes('.kx-arena-spark'),'motion respeta prefers-reduced-motion');
assert(css.includes('@media(pointer:coarse)')&&css.includes('touch-action:manipulation'),'interacciones táctiles están optimizadas para móvil');
assert(mesh.includes('#49f3ff')&&mesh.includes('#a85cff')&&mesh.includes('#ff3347'),'asset local de fondo contiene malla neón multicolor');
for(const [name,svg] of [['fight-square',fightSq],['fight-story',fightStory],['event-square',eventSq],['event-story',eventStory],['fight-share-square',fightShareSq],['fight-share-story',fightShareStory],['result-square',resultSq],['result-story',resultStory]]){
  assert(svg.includes('#49f3ff')&&svg.includes('#ff3045'),`${name} adopta lenguaje rojo + neón local`);
}
assert(!/\bfetch\s*\(/.test(events),'UI Eventos mantiene transporte centralizado sin fetch directo');
assert(/KOMBAXApp\/2\.0\.0-rc\.13\/20(?:096|09[7-9]|1\d{2,})/.test(main),'User-Agent Android identifica build 20096 o superior');
console.log('PASS 20096 KOMBAX Events Premium Visual Identity');
