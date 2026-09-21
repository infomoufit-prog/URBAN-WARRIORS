import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20092 FIGHTERS & FIGHT CARDS: ${msg}`);console.log(`OK 20092: ${msg}`)};
const [migration,repo,ui,css,config,gradle,sw,internal,manifest,square,story,placeholder]=await Promise.all([
 read('supabase/migrations/161_kombax_events_fighters_fight_cards_20092.sql'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-events.js'),read('web/css/kombax-events.css'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('web/js/modules/events.js'),read('web/assets/events/template-manifest.json'),read('web/assets/events/templates/fight-card-square.svg'),read('web/assets/events/templates/fight-card-story.svg'),read('web/assets/events/templates/fighter-placeholder.svg')
]);
assert(migration.includes('kombax_evento_participantes_publicos')&&migration.includes('kombax_evento_combates_publicos'),'modelo público separado de participantes y combates presente');
assert(!/from\s+public\.(eventos_competicion|evento_participantes|evento_combates)/i.test(migration)&&!migration.includes('references public.eventos_competicion'),'Fase 3 no lee ni referencia eventos internos de Mi Club');
assert(migration.includes('app_kombax_evento_participantes_v161')&&migration.includes('app_kombax_evento_combates_v161')&&migration.includes('app_kombax_eventos_mutate_v161'),'RPC seguras Fase 3 presentes');
assert(migration.includes("EVENT_COMPETITOR_SELF_ONLY")&&migration.includes("public.app_kombax_eventos_puede_actuar_social_v160"),'participación pública protege identidad y evita suplantación básica');
assert(migration.includes("estado_inscripcion='aceptada'")&&migration.includes("f.visible_publico"),'lectura pública solo expone participantes aceptados y combates visibles');
const eventDetailVersion=Math.max(0,...[...repo.matchAll(/app_kombax_evento_publico_detalle_v(\d+)/g)].map(m=>Number(m[1])));
assert(eventDetailVersion>=161&&repo.includes("event.participant.submit")&&repo.includes("event.fight.save"),'repositorio Fase 3 integrado');
assert(ui.includes('FIGHT CARD')&&ui.includes('Inscribir participante')&&ui.includes('Crear combate')&&ui.includes('fighter-placeholder.svg'),'UX Fighters & Fight Cards integrada');
assert(ui.includes('sin exponer datos privados del club')&&ui.includes('Nunca mezcla los eventos privados de Mi Club'),'UI explicita privacidad y separación de dominio');
for(const marker of ['kx-fight-card','kx-fight-vs','kxFightVsLive','kxFightAura','prefers-reduced-motion'])assert(css.includes(marker),`motion/visual system incluye ${marker}`);
for(const asset of ['fight-card-square','fight-card-story','fighter-placeholder'])assert(manifest.includes(asset),`manifest local incluye ${asset}`);
assert(square.includes('KOMBAX EVENTS')&&story.includes('STORY · FIGHT CARD')&&placeholder.includes('KOMBAX FIGHTER'),'assets SVG locales válidos y brand-safe');
assert(internal.includes('repos.events')&&!internal.includes('repos.kombaxEvents'),'Mi Club > Eventos sigue usando repositorio interno separado');
const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);const swBuild=Number(sw.match(/-(\d+)'/)?.[1]||0);
assert(configBuild>=20092&&androidBuild>=20092&&swBuild>=20092,'versionado 20.092 o superior consistente');
console.log('PASS 20092 KOMBAX Fighters & Fight Cards');
