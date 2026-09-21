import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R40: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const social=await txt('web/js/modules/kombax-social.js');
const events=await txt('web/js/modules/kombax-events.js');
const repos=await txt('web/js/core/repositories.js');
const fed=await txt('web/js/modules/federation-licenses.js');
const docs=await txt('web/js/modules/documents.js');
const ui=await txt('web/js/ui/components.js');
const index=await txt('web/index.html');
const sw=await txt('web/service-worker.js');
const m235=await txt('supabase/migrations/235_kombax_social_network_visibility_r40.sql');
const m236=await txt('supabase/migrations/236_kombax_event_visibility_r40.sql');
const brand=await txt('web/js/modules/brand-business.js').catch(()=> '');
const pkg=JSON.parse(await txt('package.json'));

ok(await exists('docs/06_HISTORY/PLANS/PLAN_IMPLEMENTACION_R40.md'),'plan R40 existe');
ok(await exists('docs/06_HISTORY/PLANS/PROMPT_INTERNO_IMPLEMENTACION_R40.md'),'prompt interno R40 existe');
ok(await exists('supabase/migrations/235_kombax_social_network_visibility_r40.sql'),'migración Social R40 existe');
ok(await exists('supabase/migrations/236_kombax_event_visibility_r40.sql'),'migración Events R40 existe');
ok(/globalIds=\[personalId,'social','kombax-events','showcase'\]/.test(ui),'navegación global R39 se preserva');
ok(/sectionOrder=\['Inicio','Gestión del club','Eventos del club','Economía','Comunicaciones','Federaciones y licencias','Administración','Equipo y permisos','Asistencia','Configuración del club','Mi cuenta'\]/.test(ui),'orden interno Mi Club R39 se preserva');

ok(social.includes("pageHeader('Mi red','Contactos y conexiones KOMBAX. Tu red es privada:"),'Mi red tiene descriptor privado claro');
ok(social.includes('Añadir a mi red'),'Mi red muestra CTA Añadir a mi red');
ok(social.includes("id=\"kx-add-network\""),'CTA de red tiene control propio');
ok(social.includes('Buscar contactos'),'Mi red permite buscar contactos');
ok(social.includes('requestRelation'),'solicitud de relación conserva consentimiento');
ok(social.includes('Ni tu red ni su tamaño se muestran públicamente'),'se explicita privacidad del grafo social');
ok(social.includes('Mi red es privada, requiere consentimiento'),'confirmación conserva privacidad y consentimiento');
ok(social.includes('No rompe relaciones, mensajes ni Events.'),'exclusión de contenido no rompe ecosistema KOMBAX');

ok(m235.includes("'red','clubes_seleccionados','kombax_excepto'"),'backend amplía audiencias Social');
ok(m235.includes('kombax_social_post_visibility_clubs_v235'),'tabla privada de reglas por club existe');
ok(m235.includes("rule text not null check(rule in ('include','exclude'))"),'reglas distinguen incluir y excluir');
ok(m235.includes('enable row level security'),'RLS Social R40 activa');
ok(m235.includes('using(false) with check(false)'),'tabla de reglas niega acceso directo');
ok(m235.includes('revoke all on table public.kombax_social_post_visibility_clubs_v235 from public,anon,authenticated'),'acceso directo Social revocado');
ok(m235.includes('app_kombax_social_usuario_controla_social_v235'),'helper de control de identidad existe');
ok(m235.includes('app_kombax_social_usuario_en_club_rules_v235'),'helper de reglas por club existe');
ok(m235.includes("'Todo KOMBAX'"),'audiencia Todo KOMBAX disponible');
ok(m235.includes("'Mi red'"),'audiencia Mi red disponible');
ok(m235.includes("'Clubes seleccionados…'"),'audiencia Clubes seleccionados disponible');
ok(m235.includes("'Todo KOMBAX excepto clubes…'"),'audiencia por exclusión disponible');
ok(m235.includes("'Solo mi club'"),'audiencia Solo mi club preservada');
ok(m235.includes('KOMBAX_POST_AUDIENCE_CLUB_LIMIT_50'),'backend limita selección Social a 50 clubes');
ok(m235.includes("v_audience='kombax_excepto'"),'mutación procesa exclusiones');
ok(m235.includes("v_audience='clubes_seleccionados'"),'mutación procesa inclusiones');
ok(m235.includes('app_kombax_social_puede_ver_publicacion_v083'),'lectura Social aplica política de visibilidad');

ok(repos.includes('audiencia_club_ids:Array.isArray(options.audiencia_club_ids)'), 'repositorio envía clubes incluidos');
ok(repos.includes('audiencia_excluded_club_ids:Array.isArray(options.audiencia_excluded_club_ids)'), 'repositorio envía clubes excluidos');
ok(social.includes("['clubes_seleccionados','kombax_excepto'].includes(m)"),'publisher muestra selector granular');
ok(social.includes("m==='kombax_excepto'?'Excluir estos clubes':'Visible para estos clubes'"),'publisher explica incluir/excluir');

ok(m236.includes('kombax_event_visibility_v236'),'configuración avanzada de Events existe');
ok(m236.includes('kombax_event_visibility_clubs_v236'),'tabla de clubes seleccionados Events existe');
ok(m236.includes("mode text not null check(mode in ('public','kombax','network','club','federation','selected_clubs','invitation'))"),'backend admite siete modos de visibilidad');
ok(m236.includes('enable row level security'),'RLS Events R40 activa');
ok(m236.includes('using(false) with check(false)'),'configuración Events niega acceso directo');
ok(m236.includes('revoke all on table public.kombax_event_visibility_v236 from public,anon,authenticated'),'acceso directo config Events revocado');
ok(m236.includes('app_kombax_event_can_view_v236'),'gate de descubribilidad Events existe');
ok(m236.includes('app_kombax_event_visibility_mutate_v236'),'RPC de mutación de visibilidad existe');
ok(m236.includes('KOMBAX_EVENT_VISIBILITY_CLUB_LIMIT_50'),'backend limita selección Events a 50 clubes');
ok(m236.includes("when 'public' then 'Público · web + KOMBAX'"),'etiqueta público web+KOMBAX existe');
ok(m236.includes("when 'network' then 'Mi red'"),'etiqueta Mi red existe en Events');
ok(m236.includes("when 'federation' then 'Solo federación / afiliados'"),'etiqueta Federación existe en Events');
ok(m236.includes("else 'Por invitación'"),'etiqueta invitación existe en Events');

ok(repos.includes("globalReadRpc('app_kombax_eventos_visible_page_v236'"),'discovery usa lista visible R40 primero');
ok(repos.includes("globalReadRpc('app_kombax_event_visibility_v236'"),'repositorio lee configuración avanzada');
ok(repos.includes("globalWriteRpc('app_kombax_event_visibility_mutate_v236'"),'repositorio guarda configuración avanzada');
ok(events.includes('async function openEventVisibilityManager(event)'),'UI tiene gestor avanzado de visibilidad');
ok(events.includes("{value:'public',label:'Público · web + KOMBAX'}"),'UI ofrece evento público');
ok(events.includes("{value:'kombax',label:'Todo KOMBAX'}"),'UI ofrece Todo KOMBAX');
ok(events.includes("{value:'network',label:'Mi red'}"),'UI ofrece Mi red');
ok(events.includes("{value:'club',label:'Solo un club'}"),'UI ofrece un club');
ok(events.includes("{value:'selected_clubs',label:'Clubes seleccionados'}"),'UI ofrece clubes seleccionados');
ok(events.includes("{value:'federation',label:'Federación / afiliados'}"),'UI ofrece Federación');
ok(events.includes("{value:'invitation',label:'Por invitación'}"),'UI ofrece invitación');
ok(events.includes('KOMBAX es neutral entre clubes y Federaciones'),'UI explica neutralidad KOMBAX');
ok(events.includes('data-kx-manage="visibility"'),'menú de gestión expone Visibilidad');
ok(events.includes('visibility:()=>openEventVisibilityManager(event)'),'acción de gestión abre visibilidad');

ok(fed.includes('¿Tienes licencias o federados en Excel, PDF o imágenes?'),'Federaciones y licencias promociona Migrations');
ok(fed.includes("addEventListener('click',openMigrationPreparation)"),'CTA federativo abre Migrations directo');
ok(docs.includes('¿Tienes carpetas, fichas o documentos que migrar?'),'Archivo documental promociona Migrations');
ok(docs.includes("addEventListener('click',openMigrationPreparation)"),'CTA documental abre Migrations directo');
ok(fed.includes('IA asistida')&&docs.includes('IA asistida'),'promoción explica IA asistida');

ok(!/kombax_competition_preparations_v216|kombax_weight_measurements_v216|kombax_event_official_weigh_ins_v218/.test(m235),'Social R40 no referencia preparación/pesos privados');
ok(!/kombax_competition_preparations_v216|kombax_weight_measurements_v216|kombax_event_official_weigh_ins_v218/.test(m236),'Events R40 no referencia preparación/pesos privados');
ok(brand.includes('Campañas')||brand.includes('campaign'),'Brand Business Hub R37 sigue presente');
ok(/20101r40/.test(index)&&/historical-cache-marker:20101r39/.test(index),'PWA avanza a R40 preservando marcador R39');
ok(/media-r40/.test(sw)&&/historical cache marker: media-r39/.test(sw),'service worker avanza a R40 preservando R39');
ok((pkg.scripts['test:20101:r40']||'').includes('test-kombax-20101-r40-social-events-visibility.mjs'),'package expone test R40');
ok((pkg.scripts.test||'').includes('test-kombax-20101-r40-social-events-visibility.mjs'),'regresión completa incorpora R40');

if(pass!==74)throw new Error(`FAIL R40: se esperaban 74 comprobaciones y hubo ${pass}`);
console.log(`R40 SOCIAL EVENTS VISIBILITY: PASS ${pass}/${pass}`);
