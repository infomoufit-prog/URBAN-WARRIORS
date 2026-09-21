import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R44: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const events=await txt('web/js/modules/kombax-events.js');
const components=await txt('web/js/ui/components.js');
const repos=await txt('web/js/core/repositories.js');
const pkg=JSON.parse(await txt('package.json'));
ok(events.includes('async function resolveEventDetail'),'existe resolución de detalle independiente de la cartelera');
ok(events.includes("const discoveryEvent=cached.find(event=>sameId(event?.id,key))||null")&&events.includes('const detail=await repos.kombaxEvents.detail(key)'),'el detalle puede recuperarse por ID aunque no esté en discovery');
ok(!events.includes('let event=cached.find(e=>e.id===id);if(!event)return'),'se elimina el dead-click silencioso dependiente de caché');
ok(events.includes("toast('Este evento ya no está disponible o no tienes acceso.','error')"),'fallo de apertura informa al usuario en vez de cortar silenciosamente');
ok(events.includes('let eventOpenSeq=0')&&events.includes('if(openSeq!==eventOpenSeq)return'),'las aperturas rápidas descartan respuestas fuera de orden');
ok(events.includes("wrap.addEventListener('kx:modal-before-close',cleanup,{once:true})"),'menú de gestión limpia listeners al cerrar/reemplazar modal');
ok(events.includes("document.body.classList.remove('kx-event-management-open')"),'cierre del modal elimina estado global de gestión');
ok(components.includes("layer.dispatchEvent(new CustomEvent('kx:modal-before-close'))"),'la infraestructura modal emite el lifecycle usado por Events');
ok(events.includes('function invalidateEventDetail(id)'),'existe invalidación central de caché de detalle');
ok((events.match(/invalidateEventDetail\(/g)||[]).length>=12,'mutaciones principales invalidan el detalle obsoleto');
ok(events.includes("openEvent(saved.id,{forceRefresh:true})")&&events.includes("openEvent(fresh.id,{forceRefresh:true})"),'guardar y previsualizar fuerzan detalle fresco');
ok(events.includes("void loadDiscovery({append:false}).catch(()=>{})")&&events.includes('setTimeout(()=>saved?.id'),'la transición post-guardado ya no espera a reconstruir toda la cartelera');
ok(events.includes('const current=organizerContextForEvent(event)||enabled[0]'),'editor resuelve contexto organizador activo de forma explícita');
ok(events.includes("context.sujeto_tipo==='club'&&sameId(context.sujeto_id,workspaceId)"),'un evento gestionado desde Club prioriza el workspace exacto');
ok(events.includes('const sujeto_tipo=selectedSubjectType||current.sujeto_tipo')&&events.includes('const sujeto_id=selectedSubjectId||current.sujeto_id'),'edición conserva identidad organizadora aunque el select disabled no entre en FormData');
ok(events.includes("if(!sujeto_tipo||!sujeto_id)throw new Error('No se pudo resolver la identidad organizadora activa.')"),'no se envía event.save sin sujeto válido');
ok(events.includes("cartel_url:safeExternal(event?.cartel_url)||''")&&events.includes("banner_url:safeExternal(event?.banner_url)||''"),'rutas demo relativas no contaminan inputs HTML type=url');
ok(events.includes("cartel_url:visualUrl(values.cartel_url)||visualUrl(event?.cartel_url)||null")&&events.includes("banner_url:visualUrl(values.banner_url)||visualUrl(event?.banner_url)||null"),'guardar demo conserva visual local si no se reemplaza');
ok(!events.includes('if(demoAlbum)media=[...demoUrbanAlbumMedia(fresh,fights),...media]'),'gestor de álbum ya no mezcla media sintética demo con media persistida');
ok(events.includes('const media=Array.isArray(fresh.media)?fresh.media:[];')&&events.includes('photosUsed=Number(quota?.fotos_usadas??fallbackPhotos)'),'cuota del gestor usa solo media real/persistida');
ok(repos.includes("app_kombax_eventos_mutate_v191")&&repos.includes("app_kombax_evento_bundle_v189"),'flujo mantiene gateway y bundle productivos de Events');
ok(await exists('docs/06_HISTORY/PLANS/PLAN_IMPLEMENTACION_R44.md'),'plan R44 existe');
ok(await exists('docs/06_HISTORY/CHANGELOGS/CHANGELOG_20101_R44.md'),'changelog R44 existe');
ok((pkg.scripts['test:20101:r44']||'').includes('test-kombax-20101-r44-events-flow-stability.mjs'),'package expone test R44');
ok((pkg.scripts.test||'').includes('test-kombax-20101-r44-events-flow-stability.mjs'),'regresión completa incorpora R44');
if(pass!==25)throw new Error(`FAIL R44: se esperaban 25 comprobaciones y hubo ${pass}`);
console.log(`R44 EVENTS FLOW STABILITY: PASS ${pass}/${pass}`);
