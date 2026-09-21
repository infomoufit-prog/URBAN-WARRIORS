import {readFile,access} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20094 LIVE RESULTS HIGHLIGHTS HISTORY: ${msg}`);console.log(`OK 20094: ${msg}`)};
const [m164,m165,m166,m168,m169,m170,repo,backend,events,profile,css,gateway,config,gradle,sw,edge]=await Promise.all([
  read('supabase/migrations/164_kombax_events_live_results_20094.sql'),
  read('supabase/migrations/165_kombax_events_media_highlights_20094.sql'),
  read('supabase/migrations/166_kombax_events_history_hardening_20094.sql'),
  read('supabase/migrations/168_kombax_events_result_write_path_hardening_20094.sql'),
  read('supabase/migrations/169_kombax_events_fk_indexes_20094.sql'),
  read('supabase/migrations/170_kombax_events_media_asset_acl_20094.sql'),
  read('web/js/core/repositories.js'),read('web/js/core/backend.js'),read('web/js/modules/kombax-events.js'),read('web/js/modules/public-profile.js'),read('web/css/kombax-events.css'),read('web/js/modules/gateway.js'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('supabase/functions/event-media-url/index.ts')
]);
const sql=[m164,m165,m166,m168,m169,m170].join('\n');
assert(m164.includes('resultado_estado')&&m164.includes("'provisional','oficial','anulado'")&&m164.includes('app_kombax_eventos_live_v164'),'lifecycle live/resultados explícito');
assert(m164.includes("p_operation<>'event.fight.result.set'")&&m164.includes('app_kombax_eventos_mutate_v164'),'resultado oficial usa mutación dedicada e idempotente');
assert(m165.includes("values('kombax-events-media','kombax-events-media',false")&&m165.includes('kombax_evento_media'),'bucket y catálogo de media privados presentes');
assert(m165.includes('enable row level security')&&m165.includes('revoke all on public.kombax_evento_media'),'media permanece RPC-only');
assert(m166.includes('app_kombax_evento_publico_slug_v166')&&m166.includes('app_kombax_evento_historial_competidor_v166'),'detalle público e histórico oficial presentes');
assert(m168.includes("v_payload:=v_payload - array['resultado','metodo_resultado','ganador_participante_id','asalto','tiempo_resultado','resultado_estado','notas_publicas']"),'Fight Card genérica no puede saltarse lifecycle de resultados');
assert(m169.includes('resultado_actualizado_por_v169')&&m169.includes('media_creado_por_v169'),'índices FK de rendimiento incluidos');
assert(m170.includes("to service_role")&&m170.includes('from public,anon,authenticated'),'asset resolver interno queda service_role-only');
assert(!/from\s+public\.(eventos_competicion|evento_participantes|evento_combates)\b/i.test(sql),'20.094 no lee históricos/eventos privados de Mi Club');
const eventGatewayVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_mutate_v(\d+)/g)].map(m=>Number(m[1])));const publicSlugVersion=Math.max(0,...[...repo.matchAll(/app_kombax_evento_publico_slug_v(\d+)/g)].map(m=>Number(m[1])));assert(eventGatewayVersion>=166&&publicSlugVersion>=166&&repo.includes("app_kombax_evento_historial_competidor_v166"),'repositorio conserva contratos públicos v166+ y gateway 20.094 o superior');
assert(repo.includes("backend.publicRpc('app_kombax_evento_publico_slug_v166'")&&backend.includes('publicInvokeFunction'),'deep-link y media pública no exigen sesión');
assert(repo.includes("publicInvokeFunction('event-media-url'")&&edge.includes('createSignedUrl(asset.storage_path,900)'),'media visible usa URL firmada de 15 minutos');
assert(edge.includes("app_kombax_evento_media_asset_v165")&&!/SUPABASE_SERVICE_ROLE_KEY\s*=/.test(edge),'Edge Function resuelve asset server-side sin clave hardcodeada');
assert(!/\bfetch\s*\(/.test(events),'módulo UI Eventos no introduce fetch directo');
for(const marker of ['AHORA','Publicar resultado','openResultEditor','openMediaManager','fase_temporal'])assert(events.includes(marker),`UI Eventos incluye ${marker}`);assert(events.includes('Álbum y highlights')||events.includes('ÁLBUM OFICIAL'),'UI Eventos conserva Álbum/Highlights como evolución oficial');
assert(profile.includes('Historial KOMBAX Eventos')&&profile.includes('event_history'),'perfil Competidor muestra historial oficial público');
assert(css.includes('kx-event-live-ribbon')&&css.includes('kx-event-media-grid')&&css.includes('kx-fight-result-ribbon'),'estilos live/resultados/media presentes');
assert(gateway.includes("id:'espectador'")&&gateway.includes('disabled:true'),'Espectador sigue cerrado hasta gate edad/privacidad');
await access(new URL('../supabase/verification/verify_169_kombax_events_fk_indexes_20094.sql',import.meta.url));
await access(new URL('../supabase/verification/verify_170_kombax_events_media_asset_acl_20094.sql',import.meta.url));
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0);assert(b>=20094&&a>=20094&&w>=20094,'versionado conserva Fase 5 desde 20.094');
console.log('PASS 20094 KOMBAX Live + Results + Highlights + History');
