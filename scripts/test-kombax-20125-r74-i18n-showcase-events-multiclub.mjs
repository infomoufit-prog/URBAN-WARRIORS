import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R74: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
function sqlCodeOnly(s){return s.replace(/\/\*[\s\S]*?\*\//g,'').replace(/--.*$/gm,'')}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const showcase=await txt('web/js/modules/showcase.js');
const connections=await txt('web/js/modules/event-connections.js');
const kxEvents=await txt('web/js/modules/kombax-events.js');
const repos=await txt('web/js/core/repositories.js');
const app=await txt('web/js/app.js');
const perms=await txt('web/js/core/permissions.js');
const dash=await txt('web/js/modules/dashboard-catalog.js');
const config=await txt('web/config.js');
const sw=await txt('web/service-worker.js');
const gradle=await txt('android/app/build.gradle');
const health=await txt('supabase/functions/health/index.ts');
const mainActivity=await txt('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const m260=await txt('supabase/migrations/260_kombax_showcase_club_autoprovision.sql');
const m261=await txt('supabase/migrations/261_kombax_events_multiclub_authorized_connections.sql');
const m263=await txt('supabase/migrations/263_kombax_events_multiclub_fk_indexes_r74.sql');

const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(currentBuild>=20134,'release acumulativa no retrocede del baseline R81');
ok(androidBuild===currentBuild,'Android y Web comparten build');
ok(sw.includes(`kombax-build-${currentBuild}`),'service worker usa el build actual');
ok(health.includes(`build:${currentBuild}`),'health source identifica el build actual');
ok(mainActivity.includes(`/${currentBuild}`),'WebView Android identifica el build actual');
ok(await exists('supabase/migrations/260_kombax_showcase_club_autoprovision.sql'),'migración 260 Showcase autoprovision existe');
ok(await exists('supabase/migrations/261_kombax_events_multiclub_authorized_connections.sql'),'migración 261 Events multiclub existe');
ok(await exists('supabase/migrations/263_kombax_events_multiclub_fk_indexes_r74.sql'),'migración 263 hardening de índices existe');
ok(/const \[nameTranslation,descriptionTranslation\]=await Promise\.all/.test(showcase),'descriptionTranslation se define antes de usarse');
ok(/export async function renderMyShowcase\(\)[\s\S]*showcase\.privateCenter\.unavailableTitle[\s\S]*showcase-private-explore[\s\S]*return;/.test(showcase)&&/export async function renderShowcase\(\)[\s\S]*activeView='catalog'[\s\S]*loadCatalog\(false\)/.test(showcase),'Mi Showcase conserva su ruta privada y Explorar Showcase conserva el catálogo público');
ok(/app_kombax_showcase_ensure_club_v045/.test(m260)&&/app_puede_gestionar_perfil_club_v035/.test(m260),'autoprovision Showcase exige gestión autorizada del club');
ok(/active_plan_r64/.test(m260)&&/premium/.test(m260)&&/club_pro/.test(m260),'autoprovision Showcase respeta plan elegible');
ok(/on conflict\(marca_id,perfil_id\)/.test(m260)&&/on conflict \(club_id\)/.test(m260),'autoprovision Showcase es idempotente para proveedor y gestor');
ok(!/11111111-1111-4111-8111-111111111111/.test(m260)&&!/urban.?warriors/i.test(m260),'Showcase no está hardcodeado a Urban Warriors');
ok(!/stripe/i.test(sqlCodeOnly(m260)),'migración Showcase no modifica Stripe');
ok(/drop constraint if exists kombax_event_connections_v220_public_event_id_key/.test(m261),'Events elimina cardinalidad pública 1:1 previa');
ok(/unique index if not exists uq_kombax_event_connection_public_club_v261[\s\S]*public_event_id,owner_club_id/.test(m261),'Events permite multiclub sin duplicar una conexión por club/evento público');
ok(/authorization_status[\s\S]*pending[\s\S]*approved[\s\S]*rejected[\s\S]*revoked/.test(m261),'Events implementa ciclo de autorización del organizador');
ok(/app_kombax_evento_puede_gestionar_v160/.test(m261)&&/authorization\.set/.test(m261),'organizador público autorizado decide las conexiones');
ok(/participants\.sync/.test(m261)&&/kombax_event_connection_participant_shares_v261/.test(m261),'transferencia de participantes es explícita y referencial');
ok(/internal_participant_id uuid not null references public\.evento_participantes/.test(m261)&&/license_id uuid references public\.kombax_federation_licenses_v200/.test(m261),'participantes y licencias reutilizan registros existentes');
ok(/revoke all on table public\.kombax_event_connection_participant_shares_v261 from public,anon,authenticated/.test(m261)&&/using\(false\) with check\(false\)/.test(m261),'tabla de intercambio no expone acceso directo');
ok(!/stripe|ticket_qr|qr_code/i.test(sqlCodeOnly(m261)),'migración multiclub no toca Stripe, QR ni Ticketing');
ok(!/11111111-1111-4111-8111-111111111111/.test(m261)&&!/urban.?warriors/i.test(m261),'Events multiclub no está hardcodeado a Urban Warriors');
ok(/listForPublic:[\s\S]*app_kombax_event_connections_for_public_v261/.test(repos)&&/participants:[\s\S]*app_kombax_event_connection_participants_v261/.test(repos),'repositorio expone gestión pública y participantes autorizados');
ok(/openPublicEventConnectionManager/.test(kxEvents)&&/events\.actions\.clubConnections/.test(kxEvents),'Centro del Evento expone conexiones de clubes al organizador');
ok(/authorization\.set/.test(connections)&&/participants\.sync/.test(connections)&&/publicOrganizerRule/.test(connections),'UI exige autorización y sincronización explícita');
ok(/has\(session,'eventManage'\)/.test(app),'Mis eventos usa permiso canónico, no lista de roles hardcodeada');
ok(/admin\.roles\.direction/.test(perms)&&/admin\.roles\.coordination/.test(perms),'etiquetas de rol salen de i18n');
ok(!/Pasar asistencia|Gestor de la app · Panel global|Todo el gimnasio, en una sola app\.|pendientes de revisar|Sin monitor asignado|Sin grupos activos|Sin sesiones próximas/.test(dash),'dashboard ya no contiene los textos españoles detectados');
ok(/idx_event_connections_requested_by_v261/.test(m263)&&/idx_event_connections_authorized_by_v261/.test(m263)&&/idx_event_connection_participant_internal_v261/.test(m263)&&/idx_event_connection_participant_shared_by_v261/.test(m263),'hardening cubre FKs nuevas de R74');
for(const lang of ['en','es','fr','pt','it','de','th','fil']){
  const ev=await txt(`web/js/i18n/locales/${lang}/events.js`);
  const sh=await txt(`web/js/i18n/locales/${lang}/showcase.js`);
  ok(/clubConnections/.test(ev)&&/publicOrganizerRule/.test(ev)&&/referenceOnly/.test(ev),`${lang} incluye copy Events multiclub`);
  ok(/privateCenter/.test(sh)&&/unavailableTitle/.test(sh),`${lang} incluye estado privado de Mi Showcase`);
}
console.log(`R74 I18N + SHOWCASE + EVENTS MULTICLUB: PASS ${pass}/${pass}`);
