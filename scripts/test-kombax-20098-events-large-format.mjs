import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20098 EVENTS LARGE FORMAT: ${msg}`);console.log(`OK 20098: ${msg}`)};
const [config,sw,index,repo,events,css,m173,m174,v174,gradle,main,health]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-events.js'),read('web/css/kombax-events.css'),
  read('supabase/migrations/173_kombax_events_large_format_experience_20098.sql'),read('supabase/migrations/174_kombax_events_large_format_helper_acl_20098.sql'),read('supabase/verification/verify_174_events_large_format_helper_acl.sql'),
  read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20098&&a>=20098&&w>=20098&&h>=20098,'identidad local conserva 20098 o superior en web/PWA/Android/health source');
assert(Number(index.match(/kombax-events\.css\?v=(\d+)/)?.[1]||0)>=20098,'cache-busting Eventos conserva 20098 o superior');
const discoveryVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_publicos(?:_page)?_v(\d+)/g)].map(m=>Number(m[1])));
const detailVersion=Math.max(0,...[...repo.matchAll(/app_kombax_evento_publico_detalle_v(\d+)/g)].map(m=>Number(m[1])));
const slugVersion=Math.max(0,...[...repo.matchAll(/app_kombax_evento_publico_slug_v(\d+)/g)].map(m=>Number(m[1])));
assert(discoveryVersion>=173&&detailVersion>=173&&slugVersion>=173,'repositorio consume lectores públicos v173 o superiores');
const eventGatewayVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_mutate_v(\d+)/g)].map(m=>Number(m[1])));assert(eventGatewayVersion>=173&&repo.includes('workspace_club_id:session()?.club_id||null'),'gateway 173+ conserva workspace_club_id explícito');
assert(m173.includes('app_kombax_eventos_mutate_v171(p_operation,v_payload,p_request_id)'),'mutación v173 delega primero en aislamiento v171');
assert(m173.includes('tickets_url')&&m173.includes('inscripciones_abren_en')&&m173.includes('direccion')&&m173.includes('streaming_url')&&m173.includes('aforo'),'backend incluye venue, ventanas, entradas, streaming y aforo');
assert(m173.includes("^https://[^[:space:]]+$")&&m173.includes('EVENT_REGISTRATION_WINDOW_INVALID')&&m173.includes('EVENT_TICKET_WINDOW_INVALID'),'backend valida HTTPS y coherencia temporal');
assert(m173.includes('main_event_fight_id')&&m173.includes('main_event_a_nombre')&&m173.includes('main_event_b_nombre'),'discovery v173 expone teaser real de Main Event');
const sql173=m173.replace(/--[^\n]*/g,'');
assert(!/public\.eventos_competicion\b|public\.evento_participantes\b|public\.evento_combates\b/.test(sql173),'migración 173 no consulta Eventos internos de Mi Club');
assert(m174.includes('revoke all on function public.app_kombax_evento_inscripciones_estado_v173')&&m174.includes('revoke all on function public.app_kombax_evento_entradas_estado_v173'),'hardening 174 oculta helpers standalone');
assert(v174.includes('anon_registration_helper_blocked')&&v174.includes('anon_public_reader'),'verificación 174 distingue helpers internos de lectores públicos');
assert(events.includes('function eventsBrand()')&&(events.includes('DESCUBRE · VIVE · COMPARTE')||events.includes("brandHero({area:'events'")),'Eventos conserva encabezado propio o evoluciona al Brand Hero oficial');
assert(events.includes('function eventCard')&&events.includes('kx-event-card-large')&&events.includes('mainEventTeaser'),'portada usa anuncios grandes con teaser de Main Event');
assert(events.includes('Entradas a la venta')&&events.includes('Inscripciones abiertas')&&events.includes('eventStatus')&&events.includes('registrationStatus')&&events.includes('ticketStatus'),'evento, inscripción y entradas son estados independientes');
assert(events.includes('function eventPrimaryCtas')&&events.includes('Cómo llegar')&&events.includes('Inscripción externa'),'CTA públicos cubren entradas, registro y ubicación');
assert(events.includes('function eventDetailNav')&&events.includes('Información')&&events.includes('Main Event')&&events.includes('Fight Card')&&events.includes('Peleadores')&&events.includes('Organización')&&(events.includes('Highlights')||events.includes('Álbum')),'segundo nivel contiene navegación completa del evento');
assert(events.includes('function eventInfoExperience')&&events.includes('function mainEventFeature'),'detalle incluye experiencia logística y Main Event broadcast');
for(const field of ['direccion','codigo_postal','tickets_url','tickets_proveedor','tickets_abren_en','tickets_cierran_en','ticket_precio_desde','inscripcion_url','inscripciones_abren_en','inscripciones_cierran_en','inscripcion_precio_desde','streaming_url','web_oficial_url','aforo','acceso_info']) assert(events.includes(field),`editor/payload conserva ${field}`);
assert(events.includes('safeExternal')&&events.includes('target="_blank"')&&events.includes('proveedor enlazado por el organizador'),'venta/registro externos conservan enlaces seguros cuando el organizador los configura');
assert(events.includes("repos.payments.checkout('event_ticket'")&&events.includes('Venta KOMBAX')&&events.includes('Entradas y cobros'),'UI Eventos admite venta interna KOMBAX solo mediante checkout server-side/Stripe Connect');
assert(css.includes('KOMBAX RC13 build 20.098 · LARGE FORMAT EVENT EXPERIENCE')&&css.includes('.kx-events-list{display:grid!important;grid-template-columns:1fr!important'),'Eventos fuerza formato grande de una columna, distinto de Showcase');
assert(css.includes('.kx-event-card-large')&&css.includes('.kx-event-detail-nav')&&css.includes('.kx-event-main-feature'),'CSS cubre gran anuncio, segundo nivel y Main Event');
assert(css.includes('@media(max-width:620px)')&&css.includes('@media(prefers-reduced-motion:reduce)')&&css.includes('@media(pointer:coarse)'),'responsive, reduced-motion y touch quedan protegidos');
assert(Number(main.match(/KOMBAXApp\/2\.0\.0-rc\.13\/(\d+)/)?.[1]||0)>=20098,'Android identifica build 20098 o superior');
console.log('PASS 20098 KOMBAX Events Large Format Experience');
