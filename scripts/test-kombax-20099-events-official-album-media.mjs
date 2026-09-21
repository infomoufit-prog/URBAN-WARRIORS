import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20099 EVENTS OFFICIAL ALBUM: ${msg}`);console.log(`OK 20099: ${msg}`)};
const [config,sw,index,repo,media,events,css,m175,m176,v175,gradle,main,health]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/core/repositories.js'),read('web/js/core/media.js'),read('web/js/modules/kombax-events.js'),read('web/css/kombax-events.css'),
  read('supabase/migrations/175_kombax_events_official_album_media_20099.sql'),read('supabase/migrations/176_kombax_events_album_idempotency_hardening_20099.sql'),read('supabase/verification/verify_175_events_official_album_media.sql'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20099&&a>=20099&&w>=20099&&h>=20099,'identidad local conserva 20099 o superior en web/PWA/Android/health source');
assert(Number(index.match(/kombax-events\.css\?v=(\d+)/)?.[1]||0)>=20099,'cache-busting Eventos conserva 20099 o superior');
assert(repo.includes("app_kombax_eventos_mutate_v175")&&repo.includes("app_kombax_evento_media_v175")&&repo.includes("app_kombax_evento_media_cuota_v175"),'frontend usa gateway, lector y cuota v175');
assert(repo.includes('maxBytes:100*1024*1024')&&repo.includes('maxDuration:60.2')&&repo.includes('maxLongEdge:1920')&&repo.includes('maxShortEdge:1080'),'subida de vídeo admite 100 MB, 60 s y HD 1080p');
assert(repo.includes('bytes:prepared.sizeBytes')&&repo.includes('duration_seconds:isVideo?prepared.duration:null')&&repo.includes('momento'),'cliente envía metadatos verificables y momento del álbum');
assert(media.includes('maxDuration=15.2')&&media.includes('maxBytes=50*1024*1024'),'prepareVideo conserva por defecto los límites históricos de otros módulos');
assert((events.includes('/30 fotos')||events.includes('/15 fotos'))&&events.includes('/5 vídeos')&&events.includes('60 segundos'),'gestor comunica cuota de fotos vigente (15 histórica o 30 ampliada) y 5 vídeos de 60 segundos');
assert(events.includes('multiple accept="image/jpeg,image/png,image/webp"')&&events.includes('multiple accept="video/mp4,video/webm,video/quicktime"'),'gestor permite selección múltiple de fotos y vídeos');
assert(events.includes("previo:'PREVIO'")&&events.includes("posterior:'POSTEVENTO'")&&events.includes('data-kx-album-filter'),'álbum soporta previo/evento/postevento y filtros');
assert(events.includes('kx-event-photo-grid')&&events.includes('data-kx-photo-id')&&events.includes('openEventPhotoViewer'),'fotos se muestran en cuadrícula seleccionable con visor grande');
assert(events.includes('ArrowLeft')&&events.includes('ArrowRight')&&events.includes('Escape'),'visor permite teclado anterior/siguiente/cerrar');
assert(events.includes('La plaza queda libre de nuevo'),'retirar contenido comunica liberación de cuota');
assert(css.includes('OFFICIAL EVENT ALBUM + HD MEDIA')&&css.includes('grid-template-columns:repeat(5')&&css.includes('@media(max-width:620px)'),'CSS contiene cuadrícula compacta responsive');
assert(css.includes('.kx-event-photo-lightbox')&&css.includes('.kx-album-lightbox-stage'),'CSS contiene lightbox oficial');
assert(m175.includes('file_size_limit=104857600')&&m175.includes("public=false"),'bucket permanece privado y admite hasta 100 MB por archivo');
assert(m175.includes("count(*)")&&m175.includes('>=15')&&m175.includes('>=5'),'backend impone 15 fotos y 5 vídeos');
assert(m175.includes('pg_advisory_xact_lock')&&m175.includes('20099'),'cuotas se serializan para evitar carreras concurrentes');
assert(m176.includes('v_existing.result is not null then return v_existing.result')&&m176.indexOf('v_existing.result is not null')<m176.indexOf('pg_advisory_xact_lock'),'hardening 176 resuelve idempotencia antes de recalcular cuota');
assert(m175.includes('duration_seconds')&&m175.includes('>60.2')&&m175.includes('greatest(v_width,v_height)>1920'),'backend valida metadatos de duración y resolución');
assert(m175.includes("momento in ('previo','evento','posterior')")&&m175.includes('idx_kombax_evento_media_album_momento_20099'),'backend persiste fase previa/evento/postevento e indexa el álbum');
assert(m175.includes('app_kombax_evento_contexto_gestion_v171'),'lector v175 conserva aislamiento por workspace 20.097');
assert(m175.includes('app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id)'),'gateway v175 conserva contratos y aislamiento previos por delegación');
assert(v175.includes('anon_quota_blocked')&&v175.includes('anon_mutate_blocked')&&v175.includes('bucket_limit'),'verificación cubre ACL y bucket');
assert(Number(main.match(/KOMBAXApp\/2\.0\.0-rc\.13\/(\d+)/)?.[1]||0)>=20099,'Android identifica build 20099 o superior');
console.log('PASS 20099 KOMBAX Events Official Album + HD Media');
