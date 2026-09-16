import {readFile,access} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20093 EVENTS SOCIAL & VIRAL: ${msg}`);console.log(`OK 20093: ${msg}`)};
const [migration,repo,events,visuals,social,app,css,gateway,config,gradle,sw,manifest,m160]=await Promise.all([
 read('supabase/migrations/162_kombax_events_social_viral_20093.sql'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-events.js'),read('web/js/modules/kombax-event-visuals.js'),read('web/js/modules/kombax-social.js'),read('web/js/app.js'),read('web/css/kombax-events.css'),read('web/js/modules/gateway.js'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('web/assets/events/template-manifest.json'),read('supabase/migrations/160_kombax_events_organizations_20091.sql')
]);
assert(migration.includes('kombax_evento_interes')&&migration.includes('kombax_evento_social_links'),'engagement y puente Social presentes');
assert(migration.includes('app_kombax_evento_publico_slug_v162')&&migration.includes('app_kombax_eventos_mutate_v162'),'deep-link público y gateway v162 presentes');
assert(!/from\s+public\.(eventos_competicion|evento_participantes|evento_combates)/i.test(migration),'Fase 4 no lee eventos internos de Mi Club');
assert(migration.includes('enable row level security')&&migration.includes('revoke all on public.kombax_evento_interes')&&migration.includes('revoke all on public.kombax_evento_social_links'),'tablas Fase 4 RPC-only con RLS');
const eventGatewayVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_mutate_v(\d+)/g)].map(m=>Number(m[1])));
assert(eventGatewayVersion>=162&&repo.includes('detailBySlug')&&repo.includes('event.social.link'),'repositorio mantiene gateway Social/Viral v162 o superior');
assert(repo.includes('app_kombax_eventos_social_links_v162')&&social.includes('kx-social-event-link'),'Social hidrata referencias de Eventos sin duplicar fuente');
assert(events.includes('renderPublicKombaxEventLanding')&&app.includes("entryParams.get('event')"),'landing pública por deep-link integrada antes del login');
for(const marker of ['generateEventGraphic','qrMatrix','qrSvg','shareGraphic','1080','1920'])assert(visuals.includes(marker),`Visual Engine local incluye ${marker}`);
assert(!/api\.qrserver|googleapis|openai|replicate|stability\.ai/i.test(visuals),'Visual Engine/QR no depende de API externa');
for(const asset of ['event-share-square','event-share-story','fight-share-square','fight-share-story','result-share-square','result-share-story']){await access(new URL(`../web/assets/events/templates/${asset}.svg`,import.meta.url));assert(manifest.includes(asset),`asset local ${asset} registrado`);}
assert(css.includes('kx-public-event-landing')&&css.includes('kx-event-viral-strip')&&css.includes('prefers-reduced-motion'),'UX viral animada y accesible incluida');
assert(gateway.includes("id:'espectador'")&&gateway.includes('disabled:true'),'Espectador sigue cerrado hasta su gate de edad/privacidad');
assert(m160.includes('order by public.app_kombax_eventos_sujeto_puede_organizar_v160'),'corrección PostgreSQL real de migración 160 incorporada al ZIP');
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0);assert(b>=20093&&a>=20093&&w>=20093,'versionado conserva Fase 4 desde 20.093');
console.log('PASS 20093 KOMBAX Events Social & Viral');
