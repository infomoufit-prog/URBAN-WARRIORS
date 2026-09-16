import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20091 EVENTS ORGANIZATIONS: ${msg}`);console.log(`OK 20091: ${msg}`)};
const [migration,repo,ui,css,config,gradle,sw,internal,manifest]=await Promise.all([
 read('supabase/migrations/160_kombax_events_organizations_20091.sql'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-events.js'),read('web/css/kombax-events.css'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('web/js/modules/events.js'),read('web/assets/events/template-manifest.json')
]);
assert(migration.includes('kombax_evento_entidades')&&migration.includes('app_kombax_eventos_mutate_v160'),'modelo y gateway Fase 2 presentes');
assert(!migration.includes('from public.eventos_competicion')&&!migration.includes('join public.eventos_competicion'),'Fase 2 no lee eventos internos');
assert((migration.includes("'federacion_institucional','events.public.organize'")||migration.includes("('events.public.organize')"))&&migration.includes('app_kombax_reconcile_entitlements_v071'),'federación institucional preparada y reconciliada para organizar');
assert(migration.includes("events.public.organize")&&migration.includes("Disponible con Club Premium")&&migration.includes("Profesional Pro"),'entitlements diferenciados y sin promoción automática de Club Básico');
const eventGatewayVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_mutate_v(\d+)/g)].map(m=>Number(m[1])));
const eventDetailVersion=Math.max(0,...[...repo.matchAll(/app_kombax_evento_publico_detalle_v(\d+)/g)].map(m=>Number(m[1])));
assert(eventDetailVersion>=160&&eventGatewayVersion>=160&&repo.includes('organizerContexts'),'repositorio mantiene Fase 2 integrado en versión actual o superior');
assert(ui.includes('Organización y partners')&&ui.includes('Invitaciones de organización')&&ui.includes('openKombaxPublicProfile'),'UI enlaza organización y perfiles públicos');
assert(ui.includes('COLABORACIÓN')&&ui.includes('Nunca mezcla los eventos privados de Mi Club')&&repo.includes("event.entity.respond"),'colaboración sigue visible y separación con Mi Club permanece explícita');
assert(css.includes('kx-event-organization-glow')&&css.includes('kx-event-entity-section')&&css.includes('prefers-reduced-motion'),'identidad motion Fase 2 accesible');
assert(internal.includes('repos.events')&&!internal.includes('repos.kombaxEvents'),'Mi Club > Eventos permanece en repositorio interno');
assert(manifest.includes('organization-lockup.svg')&&manifest.includes('sponsor-strip.svg'),'assets visuales locales Fase 2 incluidos');
const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);const swBuild=Number(sw.match(/-(\d+)'/)?.[1]||0);
assert(configBuild>=20091&&androidBuild>=20091&&swBuild>=20091,'versionado mantiene Fase 2 desde 20.091');
console.log('PASS 20091 KOMBAX Public Events & Organizations');
