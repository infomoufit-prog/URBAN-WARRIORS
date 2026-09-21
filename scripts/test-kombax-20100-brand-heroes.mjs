import {readFile,stat} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20100 BRAND HEROES: ${msg}`);console.log(`OK 20100: ${msg}`)};
const [config,sw,index,hero,social,events,showcase,css,platform,gradle,main,health]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/ui/brand-hero.js'),read('web/js/modules/kombax-social.js'),read('web/js/modules/kombax-events.js'),read('web/js/modules/showcase.js'),read('web/css/kombax-brand-heroes.css'),read('web/js/core/platform.js'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20100&&a>=20100&&w>=20100&&h>=20100,'identidad Brand Heroes 20100+ consistente');
assert(/kombax-brand-heroes\.css\?v=20(?:100|1\d{2})/.test(index),'CSS de Brand Heroes permanece versionado en builds posteriores');
assert(platform.includes("symbol:'./assets/brand/kombax-symbol-white.png'"),'se conserva el símbolo oficial existente de KOMBAX');
assert(!hero.toLowerCase().includes('wolf')&&!hero.toLowerCase().includes('lobo'),'componente no inventa lobo ni logo alternativo');
assert(hero.includes('KOMBAX_BRAND.symbol')&&hero.includes("social:{label:'SOCIAL'")&&hero.includes("events:{label:'EVENTS'")&&hero.includes("showcase:{label:'SHOWCASE'"),'un único componente comparte el logo oficial en las tres capas');
assert(hero.includes('FROM HYPE TO HISTORY'),'Events conserva el claim aprobado FROM HYPE TO HISTORY');
assert(social.includes("brandHero({area:'social'")&&social.includes('Tu red.')&&social.includes('Tu legado.'),'Social integra hero definitivo');
assert(events.includes("brandHero({area:'events'")&&events.includes('El espectáculo no empieza en el ring.')&&events.includes('Empieza aquí.'),'Events integra el slogan visual aprobado');
assert(showcase.includes("brandHero({area:'showcase'")&&showcase.includes('Muestra. Promociona.')&&showcase.includes('Destaca.'),'Showcase integra hero definitivo');
assert(events.includes('id="kx-events-explore"')&&events.includes('organizerAction()'),'Events conserva acciones funcionales Explorar/Crear');
for(const f of ['hero-social.webp','hero-events.webp','hero-showcase.webp']){const s=await stat(new URL(`../web/assets/brand-heroes/${f}`,import.meta.url));assert(s.size>30000,`${f} es un asset real y no placeholder`)}
assert(css.includes('@keyframes kxHeroBreathe')&&css.includes('@keyframes kxHeroParticle')&&css.includes('kxHeroEdge'),'Brand Heroes tienen motion ambiental propio');
assert(css.includes('@media(prefers-reduced-motion:reduce)'),'motion respeta accesibilidad reduced-motion');
assert(css.includes('@media(max-width:620px)')&&(css.includes('object-position:68% 18%!important')||css.includes('object-position:50% 18%!important')||css.includes('object-position:60% 18%!important')||css.includes('object-position:67% 20%!important')),'hero tiene encuadre móvil específico');
assert(css.includes('linear-gradient(90deg,rgba(3,4,6,.985)'),'fotografía queda bajo máscara de legibilidad para copy HTML');
assert(/KOMBAXApp\/2\.0\.0-rc\.13\/20(?:100|1\d{2})/.test(main),'Android conserva identidad Brand Heroes 20100+');
console.log('PASS 20100 KOMBAX Brand Heroes');
