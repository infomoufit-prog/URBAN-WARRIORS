import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20090 EVENTS FOUNDATION: ${msg}`);console.log(`OK 20090: ${msg}`)};
const [app,components,events,publicEvents,repos,platform,css,migration,manifest,config,gradle,sw]=[
 'web/js/app.js','web/js/ui/components.js','web/js/modules/events.js','web/js/modules/kombax-events.js','web/js/core/repositories.js','web/js/core/platform.js','web/css/kombax-events.css','supabase/migrations/159_kombax_events_foundation_20090.sql','web/assets/events/template-manifest.json','web/config.js','android/app/build.gradle','web/service-worker.js'
].map(read);
assert(events.includes("read('eventos_competicion'")===false,'módulo interno no contiene acceso directo a tablas (continúa vía repositorio)');
assert(repos.includes("events:{\n    list:(limit=100)=>read('eventos_competicion'")&&repos.includes("kombaxEvents:{"),'repositorios interno y público son distintos');
assert(app.includes("'kombax-events':renderKombaxEvents")&&app.includes("'kombax-events':'KOMBAX Eventos'"),'router global KOMBAX Eventos independiente');
assert(components.includes("const globalIds=[personalId,'social','kombax-events','showcase']"),'Eventos públicos vive en navegación global KOMBAX');
assert(components.includes("events:'Eventos del club'")||components.includes("'kombax-events':'KOMBAX',events:'Club'"),'shell mantiene Eventos internos bajo Mi Club');
assert(platform.includes('kombaxEvents===true'),'feature flag específico existe');
assert(publicEvents.includes('Nunca mezcla los eventos privados de Mi Club')&&publicEvents.includes('repos.kombaxEvents.list'),'UI declara y usa dominio público separado');
assert(migration.includes('create table if not exists public.kombax_eventos_publicos')&&!migration.match(/insert\s+into\s+public\.kombax_eventos_publicos[\s\S]*select[\s\S]*eventos_competicion/i),'tabla pública nueva sin migración/copia de eventos internos');
assert(migration.includes("revoke all on public.kombax_eventos_publicos from public,anon,authenticated")&&migration.includes('security definer'),'lectura pública usa RPC segura sin SELECT directo');
assert(!migration.match(/from\s+public\.eventos_competicion/i),'RPC pública jamás consulta eventos internos');
for(const animation of ['kxEventsBackgroundDrift','kxEventsRingBreathe','kxEventsLive','prefers-reduced-motion'])assert(css.includes(animation),`motion system incluye ${animation}`);
for(const asset of ['event-poster-fight','event-poster-arena','event-poster-federation','event-poster-seminar','fight-card-frame'])assert(manifest.includes(asset),`plantilla offline ${asset}`);
const configBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);const swBuild=Number(sw.match(/-(\d+)'/)?.[1]||0);
assert(configBuild>=20090&&config.includes('kombaxEvents: true'),'config mantiene Foundation desde 20090');
assert(androidBuild>=20090,'Android mantiene Foundation desde versionCode 20090');
assert(swBuild>=20090,'service worker mantiene Foundation desde 20090');
console.log('PASS 20090 KOMBAX Events Foundation');
