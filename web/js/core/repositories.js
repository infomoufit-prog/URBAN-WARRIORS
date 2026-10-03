import { backend } from './backend.js';
import { getLocale } from '../i18n/index.js';
// Contrato histórico app_kombax_perfil_mutate_v043 · legacy cerrado desde 20.044; repositorio activo usa v072.
// Compatibilidad estática 20.044: app_kombax_mis_perfiles_v072 · app_kombax_perfil_mutate_v072. R28 enruta perfil/mutación por v196.
import { state } from './state.js';
import { isoDate, monthStart } from './utils.js';
import { optimizeImage, prepareBrandLogo, prepareVideo } from './media.js';
import { cached, cacheValue, peekCache, invalidateCache } from './query-cache.js';
import { tenantKey } from './platform.js';

const enc=(v)=>encodeURIComponent(String(v??''));
const session=()=>state.session;
const filterClub=()=>`club_id=eq.${enc(session()?.club_id)}`;
const eventMediaUrlCache=new Map();
function eventMediaUrlCacheKey(mediaId,variant='asset'){return `${String(mediaId||'')}:${String(variant||'asset')}`;}
async function eventMediaAccessUrl(mediaId,variant='asset'){
  const key=eventMediaUrlCacheKey(mediaId,variant),now=Date.now(),hit=eventMediaUrlCache.get(key);
  if(hit?.value&&hit.expires>now)return hit.value;
  if(hit?.promise)return hit.promise;
  const promise=backend.publicInvokeFunction('event-media-url',{media_id:mediaId,variant}).then(value=>{eventMediaUrlCache.set(key,{value,expires:Date.now()+10*60*1000});return value;}).catch(error=>{eventMediaUrlCache.delete(key);throw error;});
  eventMediaUrlCache.set(key,{promise,expires:0});return promise;
}
function invalidateEventMediaUrl(mediaId){const prefix=`${String(mediaId||'')}:`;for(const key of [...eventMediaUrlCache.keys()])if(key.startsWith(prefix))eventMediaUrlCache.delete(key);}

async function read(table,query){return backend.select(table,query)}
async function mutation(op,payload){const out=await backend.mutate(op,payload);invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);return out}
const cachedRead=(suffix,loader,ttl=45000,force=false)=>cached(tenantKey(session(),suffix),loader,{ttl,force});
async function enrichEventTicketing(rows=[]){
  const list=Array.isArray(rows)?rows:[];const ids=[...new Set(list.map(x=>x?.id).filter(Boolean))];if(!ids.length)return list;
  try{
    const ticketRows=await backend.publicRpc('app_kombax_event_ticketing_public_r625',{p_event_ids:ids});
    const map=new Map((Array.isArray(ticketRows)?ticketRows:[]).map(x=>[String(x.event_id),x]));
    return list.map(x=>({...x,...(map.get(String(x.id))||{})}));
  }catch(error){if(!isMissingRpc(error,'app_kombax_event_ticketing_public_r625'))throw error;return list;}
}

const PUBLIC_IMAGE_TYPES=new Set(['image/jpeg','image/png','image/webp','image/gif']);
async function uploadPublicImage(kind,file){
  if(!file||!file.size)return '';
  if(!PUBLIC_IMAGE_TYPES.has(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP o GIF.');
  const prepared=kind.endsWith('-logo')?await prepareBrandLogo(file):file.type==='image/gif'?{file}:await optimizeImage(file);
  if(prepared.file.size>5*1024*1024)throw new Error('La imagen optimizada supera el límite de 5 MB.');
  const ext=({ 'image/jpeg':'jpg','image/png':'png','image/webp':'webp','image/gif':'gif' })[prepared.file.type]||'img';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().club_id}/${kind}/${Date.now()}-${token}.${ext}`;
  await backend.upload('club-public-media',path,prepared.file,false);
  return backend.publicUrl('club-public-media',path);
}
function publicMediaPath(url){
  if(!url)return '';
  const marker='/storage/v1/object/public/club-public-media/';
  const i=String(url).indexOf(marker);
  if(i<0)return '';
  try{return decodeURIComponent(String(url).slice(i+marker.length).split('?')[0])}catch{return String(url).slice(i+marker.length).split('?')[0]}
}
async function removePublicImage(url){
  const path=publicMediaPath(url);
  if(!path||!path.startsWith(`${session()?.club_id}/`))return false;
  await backend.remove('club-public-media',path);
  return true;
}
async function removePublicImages(urls=[]){
  let removed=0;
  for(const url of [...new Set((urls||[]).filter(Boolean))]){try{if(await removePublicImage(url))removed++;}catch{}}
  return removed;
}
function kombaxPublicMediaPath(url){
  if(!url)return '';
  const marker='/storage/v1/object/public/kombax-public-media/';
  const i=String(url).indexOf(marker);
  if(i<0)return '';
  try{return decodeURIComponent(String(url).slice(i+marker.length).split('?')[0])}catch{return String(url).slice(i+marker.length).split('?')[0]}
}
async function removeOwnedShowcaseImages(urls=[]){
  let removed=0;
  for(const url of [...new Set((urls||[]).filter(Boolean))]){
    const path=kombaxPublicMediaPath(url);
    if(!path||!path.startsWith(`${session()?.id}/showcase/`))continue;
    try{await backend.remove('kombax-public-media',path);removed++;}catch{}
  }
  return removed;
}
const notificationKey=(limit=120)=>tenantKey(session(),`notifications:${Math.min(300,Math.max(20,Number(limit)||120))}`);
// Compatibilidad de regresión: app_kombax_social_mutate_v067 queda solo como marcador histórico; runtime 20.045 usa v083.
async function kombaxSocialMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc('app_kombax_social_mutate_v123',{p_operation:operation,p_payload:{...payload,club_id:session()?.club_id||null},p_request_id:requestId});
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta KOMBAX Social no verificable para ${operation}.`);
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  return response.data;
}
async function kombaxShowcaseMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc('app_kombax_showcase_mutate_v067',{p_operation:operation,p_payload:{...payload,club_id:session()?.club_id||null},p_request_id:requestId});
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta KOMBAX Showcase no verificable para ${operation}.`);
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  return response.data;
}
async function kombaxEventsMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const args={p_operation:operation,p_payload:{...payload,workspace_club_id:session()?.club_id||null},p_request_id:requestId};
  let response;
  try{response=await backend.globalWriteRpc('app_kombax_eventos_mutate_v253',args);}
  catch(error){if(!isMissingRpc(error,'app_kombax_eventos_mutate_v253'))throw error;try{response=await backend.globalWriteRpc('app_kombax_eventos_mutate_v191',args);}catch(r191){if(!isMissingRpc(r191,'app_kombax_eventos_mutate_v191'))throw r191;try{response=await backend.globalWriteRpc('app_kombax_eventos_mutate_v189',args);}catch(inner){if(!isMissingRpc(inner,'app_kombax_eventos_mutate_v189'))throw inner;try{response=await backend.globalWriteRpc('app_kombax_eventos_mutate_v181',args);}catch(legacy){if(!isMissingRpc(legacy,'app_kombax_eventos_mutate_v181'))throw legacy;response=await backend.globalWriteRpc('app_kombax_eventos_mutate_v175',args);}}}}
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta KOMBAX Eventos no verificable para ${operation}.`);
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  return response.data;
}
async function kombaxIdentityMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc('app_kombax_identity_mutate_v124',{p_operation:operation,p_payload:{...payload,club_id:payload.club_id||session()?.club_id||null},p_request_id:requestId});
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta de identidad KOMBAX no verificable para ${operation}.`);
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  return response.data;
}
function isMissingRpc(error,rpcName=''){
  const code=String(error?.code||'').toUpperCase();
  const message=String(error?.message||error||'');
  return code==='PGRST202'||/schema cache|could not find the function|function .* does not exist|404/i.test(message)||(rpcName&&message.toLowerCase().includes(String(rpcName).toLowerCase()));
}
async function rpcWithFallback(primaryCall,fallbackCall,rpcName=''){
  try{return await primaryCall();}
  catch(error){if(!isMissingRpc(error,rpcName))throw error;return fallbackCall();}
}
async function kombaxSocialNetworkMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const args={p_operation:operation,p_payload:{...payload,club_id:session()?.club_id||null},p_request_id:requestId};
  let response;
  try{response=await backend.globalWriteRpc('app_kombax_social_network_mutate_v107',args);}
  catch(error){
    if(!isMissingRpc(error,'app_kombax_social_network_mutate_v107'))throw error;
    if(operation==='kombax.showcase.contact.request')throw new Error('La mensajería de Showcase necesita activar la actualización 107 del backend para completar esta validación.');
    response=await backend.globalWriteRpc('app_kombax_social_network_mutate_v104',args);
  }
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta de red KOMBAX no verificable para ${operation}.`);
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));
  return response.data;
}
async function uploadKombaxSocialMedia(socialId,type,file,{enAlbum=false,audience='publica'}={}){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  if(!socialId)throw new Error('Selecciona la identidad con la que quieres publicar.');
  const isVideo=type==='video'||String(file?.type||'').startsWith('video/');
  const normalizedType=['avatar','banner'].includes(type)?type:(isVideo?'video':'photo');
  const prepared=isVideo?await prepareVideo(file,{maxBytes:100*1024*1024,maxDuration:60.2,maxLongEdge:1920,maxShortEdge:1080}):await optimizeImage(file,{maxEdge:type==='banner'?2560:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>(isVideo?100:25)*1024*1024)throw new Error(isVideo?'El vídeo supera 100 MB.':'El archivo supera 25 MB.');
  const ext=(prepared.file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const restricted=String(audience||'publica')!=='publica'&& !['avatar','banner'].includes(normalizedType);
  const bucket=restricted?'kombax-restricted-media':'kombax-public-media';
  const path=`${session().id}/social/${socialId}/${Date.now()}-${token}.${ext}`;
  await backend.upload(bucket,path,prepared.file,false);
  try{
    const operation=normalizedType==='avatar'?'kombax.social.media.avatar':normalizedType==='banner'?'kombax.social.media.banner':'kombax.social.media.add';
    const data=await kombaxSocialMutation(operation,{social_profile_id:socialId,tipo:normalizedType,storage_path:path,storage_bucket:bucket,mime_type:prepared.mime||prepared.file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:prepared.duration||null,en_album:restricted?false:enAlbum===true});
    if(data?.old_storage_path&&String(data.old_storage_path).startsWith(`${session().id}/social/`))await backend.remove(data.old_storage_bucket||'kombax-public-media',data.old_storage_path).catch(()=>{});
    let mediaPresentation=data?.media_presentation||{};
    if(isVideo&&prepared.cover&&data?.id){
      try{const cover=await storeMediaCover('social_media',data.id,prepared.cover,{bucket,pathPrefix:`${session().id}/social/${socialId}/${data.id}`,presentation:mediaPresentation,mode:'auto',time:prepared.coverTime||0});mediaPresentation=cover.presentation;}catch(error){console.warn('KOMBAX Social video cover:',error);}
    }
    return {...data,media_presentation:mediaPresentation,storage_bucket:bucket,public_url:restricted?'':backend.publicUrl('kombax-public-media',path)};
  }catch(error){await backend.remove(bucket,path).catch(()=>{});throw error;}
}
async function syncPrivateAvatarToKombaxSocial(socialId,sourcePath=session()?.avatar_path){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  if(!socialId)throw new Error('Tu identidad de miembro en KOMBAX Social no está disponible.');
  if(!sourcePath)throw new Error('No hay una foto personal para sincronizar.');
  const blob=await backend.download('profile-media',sourcePath,180);
  const mime=blob.type||'image/jpeg';
  if(!['image/jpeg','image/png','image/webp'].includes(mime))throw new Error('La foto personal no tiene un formato público compatible.');
  const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':'jpg';
  const file=new File([blob],`avatar-publico-kombax.${ext}`,{type:mime,lastModified:Date.now()});
  return uploadKombaxSocialMedia(socialId,'avatar',file,{enAlbum:false});
}
async function uploadKombaxShowcaseImage(brandId,file){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  if(!brandId)throw new Error('Selecciona el espacio de Showcase.');
  if(!file?.size)throw new Error('Selecciona una imagen.');
  const mimeByExtension={jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',webp:'image/webp',heic:'image/heic',heif:'image/heif',avif:'image/avif'};
  const declaredMime=String(file.type||'').toLowerCase();
  const extensionMime=mimeByExtension[String(file.name||'').split('.').pop()?.toLowerCase()]||'';
  const sourceMime=declaredMime==='image/jpg'?'image/jpeg':(!declaredMime||declaredMime==='application/octet-stream'?extensionMime:declaredMime);
  const accepted=['image/jpeg','image/png','image/webp','image/heic','image/heif','image/avif'];
  if(!accepted.includes(sourceMime))throw new Error('Showcase admite fotos JPG, PNG, WEBP, HEIC, HEIF o AVIF.');
  const source=sourceMime===file.type?file:new File([file],file.name||'foto',{type:sourceMime,lastModified:file.lastModified||Date.now()});
  const prepared=await optimizeImage(source,{maxEdge:1920,maxBytes:5*1024*1024,forceReencode:!['image/jpeg','image/png','image/webp'].includes(sourceMime)});
  if(!['image/jpeg','image/png','image/webp'].includes(prepared.file.type))throw new Error('No se pudo convertir la foto a un formato compatible con Showcase.');
  const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/showcase/${brandId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  return {path,url:backend.publicUrl('kombax-public-media',path)};
}

async function uploadReputationMedia(scope,targetId,file,{allowVideo=false}={}){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  if(!targetId)throw new Error('Contenido de reputación no disponible.');
  if(!file?.size)throw new Error('Selecciona un archivo.');
  const isVideo=String(file.type||'').startsWith('video/');
  if(isVideo&&!allowVideo)throw new Error('Las reseñas de producto admiten fotografías.');
  if(!isVideo&&!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');
  if(isVideo&&!['video/mp4','video/webm','video/quicktime'].includes(file.type))throw new Error('Usa MP4, WEBM o MOV.');
  const prepared=isVideo?await prepareVideo(file,{maxBytes:50*1024*1024,maxDuration:60.2,maxLongEdge:1920,maxShortEdge:1080}):await optimizeImage(file,{maxEdge:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>(isVideo?50:5)*1024*1024)throw new Error(isVideo?'El vídeo supera 50 MB.':'La imagen supera 5 MB.');
  const ext=(prepared.file.name?.split('.').pop()||file.name?.split('.').pop()||(isVideo?'mp4':'jpg')).replace(/[^a-z0-9]/gi,'').toLowerCase();
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/reputation/${scope}/${targetId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  return {path,url:backend.publicUrl('kombax-public-media',path),type:isVideo?'video':'image',mime:prepared.mime||prepared.file.type,duration:isVideo?prepared.duration||null:null};
}
async function removeOwnedReputationMedia(items=[]){
  let removed=0;for(const item of items||[]){const url=typeof item==='string'?item:item?.url;const path=kombaxPublicMediaPath(url);if(!path||!path.startsWith(`${session()?.id}/reputation/`))continue;try{await backend.remove('kombax-public-media',path);removed++;}catch{}}return removed;
}

async function readMediaPresentations(scope,ids=[]){
  const safe=[...new Set((ids||[]).filter(Boolean).map(String))].slice(0,200);
  if(!safe.length)return new Map();
  try{
    const rows=await rpcWithFallback(()=>backend.publicRpc('app_kombax_media_presentations_v188',{p_scope:scope,p_ids:safe}),()=>backend.publicRpc('app_kombax_media_presentations_v187',{p_scope:scope,p_ids:safe}),'app_kombax_media_presentations_v188');
    return new Map((rows||[]).map(x=>[String(x.id),x.presentation||{}]));
  }catch(error){
    if(!isMissingRpc(error,'app_kombax_media_presentations_v188')&&!isMissingRpc(error,'app_kombax_media_presentations_v187'))console.warn('Media framing read:',error);
    return new Map();
  }
}
function hasMediaPresentation(value){return Boolean(value&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).length);}
function resolveMediaPresentation(...values){for(const value of values){if(hasMediaPresentation(value))return value;}return {};}
async function enrichMediaPresentations(scope,rows=[],idKey='id',field='media_presentation'){
  const list=Array.isArray(rows)?rows:[];const map=await readMediaPresentations(scope,list.map(x=>x?.[idKey]));
  return list.map(x=>({...x,[field]:resolveMediaPresentation(x?.[field],map.get(String(x?.[idKey]||'')))}));
}
async function enrichShowcaseMedia(rows=[]){
  let out=await enrichMediaPresentations('showcase_item',rows,'id','imagen_presentacion');
  const ids=out.map(x=>x?.id).filter(Boolean);
  if(!ids.length)return out;
  const maps=await Promise.all([0,1,2].map(i=>readMediaPresentations(`showcase_gallery_${i}`,ids)));
  out=out.map(x=>({...x,galeria_presentacion:Object.fromEntries([0,1,2].map(i=>[String(i),maps[i].get(String(x.id))||x?.galeria_presentacion?.[String(i)]||{}]))}));
  try{
    const [commerce,listing]=await Promise.all([
      backend.globalReadRpc('app_showcase_commerce_details_v259',{p_ids:ids}),
      backend.publicRpc('app_showcase_listing_details_r628',{p_ids:ids}).catch(error=>{if(!isMissingRpc(error,'app_showcase_listing_details_r628'))throw error;return [];})
    ]);
    const byId=new Map((Array.isArray(commerce)?commerce:[]).map(x=>[String(x.id),x]));
    const listingById=new Map((Array.isArray(listing)?listing:[]).map(x=>[String(x.id),x]));
    return out.map(x=>({...x,...(byId.get(String(x.id))||{}),...(listingById.get(String(x.id))||{})}));
  }catch(error){if(!isMissingRpc(error,'app_showcase_commerce_details_v259'))console.warn('Showcase Commerce:',error);return out;}
}

async function readSocialProfilePosts(socialId,cursor=null,limit=10){
  const args={p_social_id:socialId,p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(10,Math.max(1,Number(limit)||10))};
  const rows=await rpcWithFallback(()=>backend.globalReadRpc('app_kombax_social_profile_posts_v256',args),()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_social_profile_posts_v255',args),()=>backend.globalReadRpc('app_kombax_social_profile_posts_v099',args),'app_kombax_social_profile_posts_v255'),'app_kombax_social_profile_posts_v256');
  const list=Array.isArray(rows)?rows:[];
  const socialIds=list.filter(x=>x.media_scope==='social_media').map(x=>x.media_id).filter(Boolean);
  const profileIds=list.filter(x=>x.media_scope==='profile_media').map(x=>x.media_id).filter(Boolean);
  const [socialMap,profileMap]=await Promise.all([readMediaPresentations('social_media',socialIds),readMediaPresentations('profile_media',profileIds)]);
  return Promise.all(list.map(async x=>{
    const scope=String(x.media_scope||'');const id=String(x.media_id||'');
    const presentation=resolveMediaPresentation(x.media_presentation,scope==='social_media'?socialMap.get(id):profileMap.get(id));
    const bucket=String(x.media_bucket||'kombax-public-media');const path=String(x.media_path||'');
    let media_url='';let media_cover_url='';
    if(path){try{media_url=bucket==='kombax-restricted-media'?await backend.signedUrl(bucket,path,600):backend.publicUrl('kombax-public-media',path);}catch{media_url='';}}
    const coverPath=String(presentation?.cover_storage_path||'');const coverBucket=String(presentation?.cover_storage_bucket||bucket||'kombax-public-media');
    if(coverPath){try{media_cover_url=coverBucket==='kombax-restricted-media'?await backend.signedUrl(coverBucket,coverPath,600):backend.publicUrl('kombax-public-media',coverPath);}catch{media_cover_url='';}}
    return {...x,media_presentation:presentation,media_url,media_cover_url};
  }));
}

async function setMediaPresentation(scope,targetId,presentation={}){
  if(!targetId)throw new Error('Contenido multimedia no disponible.');
  const current=(await readMediaPresentations(scope,[targetId]).catch(()=>new Map())).get(String(targetId))||{};
  const merged={...current,...(presentation&&typeof presentation==='object'?presentation:{})};
  const out=await rpcWithFallback(()=>backend.globalWriteRpc('app_kombax_media_presentation_set_v188',{p_scope:scope,p_target_id:targetId,p_presentation:merged}),()=>backend.globalWriteRpc('app_kombax_media_presentation_set_v187',{p_scope:scope,p_target_id:targetId,p_presentation:merged}),'app_kombax_media_presentation_set_v188');
  invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
  return out;
}

async function storeMediaCover(scope,targetId,file,{bucket='kombax-public-media',pathPrefix='',presentation={},mode='upload',time=0}={}){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  if(!targetId)throw new Error('Vídeo no disponible.');
  const prepared=await optimizeImage(file,{maxEdge:1600,maxBytes:2*1024*1024});
  const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/jpeg'?'jpg':'webp';
  const prefix=String(pathPrefix||`${session().id}/covers/${scope}/${targetId}`).replace(/^\/+|\/+$/g,'');
  const path=`${prefix}/cover-${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
  await backend.upload(bucket,path,prepared.file,false);
  const previous=presentation&&typeof presentation==='object'?presentation:{};
  const next={...previous,cover_mode:['auto','frame','upload'].includes(mode)?mode:'upload',cover_storage_path:path,cover_storage_bucket:bucket,cover_mime_type:prepared.mime||prepared.file.type,cover_time:Number.isFinite(Number(time))?Math.max(0,Number(time)):0};
  try{
    await setMediaPresentation(scope,targetId,next);
    const oldPath=String(previous.cover_storage_path||''),oldBucket=String(previous.cover_storage_bucket||bucket);
    if(oldPath&&oldPath!==path)await backend.remove(oldBucket,oldPath).catch(()=>{});
    return {presentation:next,path,bucket,url:bucket==='kombax-public-media'?backend.publicUrl(bucket,path):''};
  }catch(error){await backend.remove(bucket,path).catch(()=>{});throw error;}
}

function coverPathFromPresentation(presentation={}){return String(presentation?.cover_storage_path||'').trim();}
function coverBucketFromPresentation(presentation={},fallback='kombax-public-media'){return String(presentation?.cover_storage_bucket||fallback||'kombax-public-media').trim();}
async function removeMediaCover(presentation={},fallbackBucket='kombax-public-media'){const path=coverPathFromPresentation(presentation);if(!path)return false;const bucket=coverBucketFromPresentation(presentation,fallbackBucket);await backend.remove(bucket,path).catch(()=>{});return true;}
function thumbPathFromPresentation(presentation={}){return String(presentation?.thumb_storage_path||'').trim();}
function thumbBucketFromPresentation(presentation={},fallback='kombax-events-media'){return String(presentation?.thumb_storage_bucket||fallback||'kombax-events-media').trim();}
async function removeMediaThumbnail(presentation={},fallbackBucket='kombax-events-media'){const path=thumbPathFromPresentation(presentation);if(!path)return false;await backend.remove(thumbBucketFromPresentation(presentation,fallbackBucket),path).catch(()=>{});return true;}
async function storeEventMediaThumbnail(eventId,targetId,file,presentation={}){
  if(!eventId||!targetId||!file?.size)return {presentation};
  const prepared=await optimizeImage(file,{maxEdge:960,maxBytes:350*1024});
  const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/jpeg'?'jpg':'webp';
  const path=`${eventId}/${targetId}/thumb-${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
  await backend.upload('kombax-events-media',path,prepared.file,false);
  const previous=presentation&&typeof presentation==='object'?presentation:{};
  const next={...previous,thumb_storage_path:path,thumb_storage_bucket:'kombax-events-media',thumb_mime_type:prepared.mime||prepared.file.type,thumb_width:prepared.width||null,thumb_height:prepared.height||null,thumb_status:'ready'};
  try{
    await setMediaPresentation('event_media',targetId,next);
    const old=String(previous.thumb_storage_path||'');if(old&&old!==path)await backend.remove(String(previous.thumb_storage_bucket||'kombax-events-media'),old).catch(()=>{});
    invalidateEventMediaUrl(targetId);return {presentation:next,path};
  }catch(error){await backend.remove('kombax-events-media',path).catch(()=>{});throw error;}
}
async function storeEventVideoCoverWithRetry(eventId,targetId,file,{presentation={},mode='auto',time=0,attempts=3}={}){
  let lastError=null;
  for(let attempt=1;attempt<=Math.max(1,attempts);attempt++){
    try{
      const out=await storeMediaCover('event_media',targetId,file,{bucket:'kombax-events-media',pathPrefix:`${eventId}/${targetId}`,presentation:{...(presentation||{}),cover_status:'ready'},mode,time});
      invalidateEventMediaUrl(targetId);return {...out,status:'ready',attempt};
    }catch(error){lastError=error;if(attempt<attempts)await new Promise(resolve=>setTimeout(resolve,attempt*350));}
  }
  const pending={...(presentation||{}),cover_status:'pending',cover_time:Number.isFinite(Number(time))?Math.max(0,Number(time)):0,cover_last_error_at:new Date().toISOString()};
  await setMediaPresentation('event_media',targetId,pending).catch(()=>{});invalidateEventMediaUrl(targetId);
  return {presentation:pending,status:'pending',error:lastError};
}

async function kombaxGlobalMutation(endpoint,operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc(endpoint,{p_operation:operation,p_payload:payload,p_request_id:requestId});
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta KOMBAX no verificable para ${operation}.`);
  return response.data;
}
async function kombaxProfileMutationR58(operation,payload={}){
  try{return await kombaxGlobalMutation('app_kombax_perfil_mutate_r58',operation,payload);}
  catch(error){
    // Compatibilidad R57 mientras Work aplica la migración 249. El endpoint histórico sigue siendo v196.
    if(String(payload?.tipo||'').toLowerCase()==='media')throw error;
    return kombaxGlobalMutation('app_kombax_perfil_mutate_v196',operation,payload);
  }
}
async function uploadKombaxProfileMedia(profileId,type,file){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  let prepared;
  if(type==='video')prepared=await prepareVideo(file,{maxBytes:100*1024*1024,maxDuration:60.2,maxLongEdge:1920,maxShortEdge:1080});else prepared=await optimizeImage(file,{maxEdge:type==='banner'?2560:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>(type==='video'?100:25)*1024*1024)throw new Error(type==='video'?'El vídeo supera 100 MB.':'El archivo supera 25 MB.');
  const ext=(prepared.file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/${profileId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  try{
    const data=await kombaxGlobalMutation('app_kombax_media_mutate_v072','kombax.media.add',{perfil_directo_id:profileId,tipo,storage_path:path,mime_type:prepared.mime||prepared.file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:prepared.duration||null});
    let mediaPresentation=data?.media_presentation||{};
    if(type==='video'&&prepared.cover&&data?.id){try{const cover=await storeMediaCover('profile_media',data.id,prepared.cover,{bucket:'kombax-public-media',pathPrefix:`${session().id}/${profileId}/${data.id}`,presentation:mediaPresentation,mode:'auto',time:prepared.coverTime||0});mediaPresentation=cover.presentation;}catch(error){console.warn('KOMBAX profile video cover:',error);}}
    return {...data,media_presentation:mediaPresentation,public_url:backend.publicUrl('kombax-public-media',path)};
  }catch(error){await backend.remove('kombax-public-media',path).catch(()=>{});throw error;}
}
async function uploadKombaxClubMedia(clubId,type,file){
  if(!session()?.id)throw new Error('Inicia sesión.');
  if(!clubId)throw new Error('Club no disponible.');
  if(!file?.size)throw new Error('Selecciona un archivo.');
  const requested=String(type||'').trim().toLowerCase();
  const detected=String(file.type||'').startsWith('video/')?'video':String(file.type||'').startsWith('image/')?'photo':'';
  const normalizedType=['photo','video'].includes(requested)?requested:detected;
  if(!normalizedType)throw new Error('Tipo de contenido no válido. Usa una fotografía o un vídeo compatible.');
  if(detected&&requested&&['photo','video'].includes(requested)&&detected!==requested)throw new Error('El tipo seleccionado no coincide con el archivo elegido.');
  let prepared;
  if(normalizedType==='video')prepared=await prepareVideo(file,{maxBytes:100*1024*1024,maxDuration:60.2,maxLongEdge:1920,maxShortEdge:1080});else prepared=await optimizeImage(file,{maxEdge:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>(normalizedType==='video'?100:25)*1024*1024)throw new Error(normalizedType==='video'?'El vídeo supera 100 MB.':'El archivo supera 25 MB.');
  const ext=(prepared.file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/club/${clubId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  try{
    const data=await kombaxGlobalMutation('app_kombax_club_media_mutate_v046','kombax.club.media.add',{club_id:clubId,tipo:normalizedType,storage_path:path,mime_type:prepared.mime||prepared.file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:prepared.duration||null});
    let mediaPresentation=data?.media_presentation||{};
    if(normalizedType==='video'&&prepared.cover&&data?.id){try{const cover=await storeMediaCover('club_media',data.id,prepared.cover,{bucket:'kombax-public-media',pathPrefix:`${session().id}/club/${clubId}/${data.id}`,presentation:mediaPresentation,mode:'auto',time:prepared.coverTime||0});mediaPresentation=cover.presentation;}catch(error){console.warn('KOMBAX club video cover:',error);}}
    return {...data,media_presentation:mediaPresentation,public_url:backend.publicUrl('kombax-public-media',path)};
  }catch(error){await backend.remove('kombax-public-media',path).catch(()=>{});throw error;}
}

async function uploadKombaxVerificationDocument(applicationId,kind,file){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  const allowed=new Set(['application/pdf','image/jpeg','image/png','image/webp']);if(!allowed.has(file?.type))throw new Error('Documento no admitido. Usa PDF, JPG, PNG o WEBP.');
  if(!file?.size||file.size>15*1024*1024)throw new Error('El documento debe pesar menos de 15 MB.');
  const ext=(file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/${applicationId}/${Date.now()}-${token}.${ext}`;await backend.upload('kombax-verification-docs',path,file,false);
  try{return await kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.document.add',{solicitud_id:applicationId,tipo_documento:kind,storage_path:path,mime_type:file.type,bytes:file.size});}
  catch(error){await backend.remove('kombax-verification-docs',path).catch(()=>{});throw error;}
}
async function notificationList(limit=120,{force=false}={}){
  const safeLimit=Math.min(300,Math.max(20,Number(limit)||120));
  return cached(notificationKey(safeLimit),async()=>{
    try{
      const rows=await rpcWithFallback(()=>backend.readRpc('app_notificaciones_centro_v133',{p_club_id:session()?.club_id,p_limit:safeLimit}),()=>backend.readRpc('app_notificaciones_centro_v037',{p_club_id:session()?.club_id,p_limit:safeLimit}),'app_notificaciones_centro_v133');
      if(Array.isArray(rows))return rows;
    }catch(error){
      if(!/app_notificaciones_centro_v133|app_notificaciones_centro_v037|404|schema cache|could not find/i.test(String(error?.message||'')))console.warn('Centro de notificaciones optimizado:',error);
    }
    const [items,reads,actionRows]=await Promise.all([
      read('notificaciones',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=${safeLimit}`),
      session()?.id?read('notificaciones_lecturas',`select=notificacion_id,leida_en&perfil_id=eq.${enc(session().id)}&limit=${Math.min(600,Math.max(100,safeLimit*2))}`).catch(()=>[]):Promise.resolve([]),
      session()?.club_id?backend.readRpc('app_notificaciones_accionables_v034',{p_club_id:session().club_id}).catch(()=>[]):Promise.resolve([])
    ]);
    const sharedRead=new Set((reads||[]).map(x=>x.notificacion_id));
    const readAt=new Map((reads||[]).map(x=>[x.notificacion_id,x.leida_en]));
    const actionMap=new Map((actionRows||[]).map(x=>[x.notificacion_id,x.requiere_accion===true]));
    return (items||[]).map(n=>({...n,requiere_accion:actionMap.get(n.id)===true,leida:Boolean(n.leida)||sharedRead.has(n.id),leida_en:n.leida_en||(sharedRead.has(n.id)?readAt.get(n.id):null)}));
  },{ttl:12000,force});
}

async function optimisticNotificationMutation(operation,payload,predicate){
  const key=notificationKey(300);const current=peekCache(key)||await notificationList(300);
  const previous=current.map(item=>({...item}));const now=new Date().toISOString();
  const optimistic=current.map(item=>predicate(item)?{...item,leida:true,leida_en:item.leida_en||now}:item);
  cacheValue(key,optimistic,12000);window.dispatchEvent(new CustomEvent('uw-notifications-changed',{detail:{optimistic:true}}));
  try{
    const out=await backend.mutate(operation,{...payload,club_id:session()?.club_id});
    await notificationList(300,{force:true});window.dispatchEvent(new CustomEvent('uw-notifications-changed',{detail:{persisted:true}}));return out;
  }catch(error){
    cacheValue(key,previous,12000);window.dispatchEvent(new CustomEvent('uw-notifications-changed',{detail:{rollback:true}}));throw error;
  }
}

export const repos={
  dashboard:{
    async load(){
      return cachedRead('dashboard:load',async()=>{
        const c=session()?.club_id; const q=`club_id=eq.${enc(c)}`;
        const safe=async(table,query)=>{try{return await read(table,query)}catch{return[]}};
        const [groups,members,fees,sessions,notificationSummary,pre,payments,enrollments]=await Promise.all([
          safe('grupos',`select=id,nombre,disciplina_id,activo,plazas,monitor_nombre,monitor_principal_id&${q}`),(session()?.rol==='monitor'?backend.readRpc('app_kombax_mis_alumnos_v057',{p_club_id:c}).catch(()=>[]):safe('socios',`select=id,nombre,apellidos,estado&${q}`)),
          safe('cuotas',`select=id,socio_id,estado,importe,vencimiento&${q}&order=vencimiento.desc&limit=300`),safe('sesiones_entrenamiento',`select=id,grupo_id,fecha,hora_inicio,hora_fin,estado,monitor_nombre&${q}&ciclo_estado=eq.activo&order=fecha.desc&limit=120`),backend.readRpc('app_kombax_header_summary_v105',{p_club_id:c}).then(rows=>Array.isArray(rows)?(rows[0]||{}):(rows||{})).catch(()=>({})),
          safe('preinscripciones',`select=id,nombre,apellidos,estado,creado_en&${q}&order=creado_en.desc&limit=200`),safe('pagos',`select=id,socio_id,importe,fecha,estado_validacion&${q}&order=fecha.desc&limit=400`),safe('socio_disciplinas',`select=id,socio_id,grupo_id,activa&${q}`)
        ]);
        return {groups,members,fees,sessions,notificationSummary,pre,payments,enrollments};
      },30000);
    }
  },
  catalog:{
    disciplines:()=>cachedRead('catalog:disciplines',()=>read('disciplinas',`select=*&${filterClub()}&order=orden,nombre`)),
    grades:()=>cachedRead('catalog:grades',()=>read('grados',`select=*&${filterClub()}&order=disciplina_id,orden,nombre`)),
    saveDiscipline:(p)=>mutation('disciplina.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',color:p.color||'#ffffff',activa:p.activa!==false,orden:Number(p.orden||0)}),
    saveGrade:(p)=>mutation('grado.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,orden:Number(p.orden||1),color:p.color||null,meses_minimos:p.meses_minimos===''||p.meses_minimos==null?null:Number(p.meses_minimos),activo:p.activo!==false}),
    deleteDiscipline:(disciplina_id)=>mutation('disciplina.eliminar',{disciplina_id}),
    async forceDeleteDiscipline(disciplina_id){const out=await mutation('disciplina.eliminar_forzado',{disciplina_id});await removePublicImages(out?.image_urls||[]);return out;},
    deleteGrade:(grado_id)=>mutation('grado.eliminar',{grado_id}), forceDeleteGrade:(grado_id)=>mutation('grado.eliminar_forzado',{grado_id})
  },
  groups:{
    list:()=>cachedRead('groups:list',()=>read('grupos',`select=*&${filterClub()}&order=nombre`)), schedules:()=>cachedRead('groups:schedules',()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`)),
    save:(p)=>mutation('grupo.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',edad_min:p.edad_min===''?null:Number(p.edad_min),edad_max:p.edad_max===''?null:Number(p.edad_max),plazas:p.plazas===''?null:Number(p.plazas),activo:p.activo!==false,horarios:p.horarios||[]}),
    delete:(grupo_id)=>mutation('grupo.eliminar',{grupo_id}), forceDelete:(grupo_id)=>mutation('grupo.eliminar_forzado',{grupo_id})
  },
  members:{
    list:(limit=120)=>session()?.rol==='monitor'?backend.readRpc('app_kombax_mis_alumnos_v057',{p_club_id:session()?.club_id}):read('socios',`select=*&${filterClub()}&order=apellidos,nombre&limit=${Math.min(500,Math.max(20,Number(limit)||120))}`), enrollments:(limit=400)=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc&limit=${Math.min(1000,Math.max(50,Number(limit)||400))}`), tutors:()=>read('tutores_socios',`select=*&${filterClub()}`),
    save:(p)=>mutation('alumno.guardar',{id:p.id||null,nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,telefono:p.telefono||'',email:p.email||'',tutor_nombre:p.tutor_nombre||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,grado_id:p.grado_id||null,grado_texto:p.grado_texto||'',tarifa_id:p.tarifa_id||null,estado:p.estado||'activo',contacto_emergencia:p.contacto_emergencia||'',telefono_emergencia:p.telefono_emergencia||'',notas_internas:p.notas_internas||''}),
    requestEnrollment:(socio_id,disciplina_id,grupo_id,tarifa_id)=>mutation('matricula.solicitar',{socio_id,disciplina_id,grupo_id,tarifa_id:tarifa_id||null}),
    deactivateEnrollment:(matricula_id)=>mutation('matricula.desactivar',{matricula_id}),
    graduation:(p)=>mutation('graduacion.registrar',{socio_id:p.socio_id,disciplina_id:p.disciplina_id,grado_id:p.grado_id,fecha:p.fecha||isoDate(),examinador:p.examinador||'',nota:p.nota||''}),
    archive:(socio_id,motivo='',fecha_baja=isoDate())=>mutation('alumno.archivar',{socio_id,motivo,fecha_baja}),
    inviteAccess:(socio_id,email='')=>backend.writeRpc('app_kombax_alumno_invitar_r58',{p_club_id:session()?.club_id,p_socio_id:socio_id,p_email:String(email||'').trim().toLowerCase()||null}),
    claims:()=>backend.readRpc('app_kombax_membership_claims_club_r59',{p_club_id:session()?.club_id}),
    interests:()=>backend.readRpc('app_kombax_club_interest_list_r98',{p_club_id:session()?.club_id}),
    resolveClaim:(claim_id,approve)=>backend.writeRpc('app_kombax_membership_claim_resolve_r59',{p_claim_id:claim_id,p_aprobar:approve===true}),
    delete:(socio_id)=>mutation('alumno.eliminar',{socio_id}), async forceDelete(socio_id){const out=await mutation('alumno.eliminar_forzado',{socio_id});await Promise.all([(out?.document_paths||[]).map(p=>backend.remove('member-documents',p).catch(()=>{})),(out?.payment_paths||[]).map(p=>backend.remove('justificantes-pago',p).catch(()=>{}))].flat());return out;}
  },
  preenrollments:{
    list:(limit=100)=>read('preinscripciones',`select=*&${filterClub()}&order=creado_en.desc&limit=${Math.min(500,Math.max(20,Number(limit)||100))}`),
    create:(p)=>mutation('preinscripcion.crear',{tipo_solicitud:p.tipo_solicitud||'adulto',nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,tutor_nombre:p.tutor_nombre||'',tutor_email:p.email_acceso||p.tutor_email||'',telefono:p.telefono||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,tarifa_id:p.tarifa_id||null,parentesco:p.parentesco||null,observaciones:p.observaciones||null}),
    approve:(id)=>rpcWithFallback(()=>backend.writeRpc('app_kombax_preinscripcion_aprobar_r59',{p_preinscripcion_id:id}),()=>mutation('preinscripcion.aprobar',{preinscripcion_id:id}),'app_kombax_preinscripcion_aprobar_r59'), wait:(id,motivo)=>mutation('preinscripcion.espera',{preinscripcion_id:id,motivo:motivo||null}), reject:(id,motivo)=>mutation('preinscripcion.rechazar',{preinscripcion_id:id,motivo:motivo||''}),
    cancel:(id,motivo)=>mutation('preinscripcion.cancelar',{preinscripcion_id:id,motivo:motivo||''}),
    delete:(id)=>mutation('preinscripcion.eliminar',{preinscripcion_id:id})
  },
  tariffs:{
    list:()=>read('tarifas',`select=*&${filterClub()}&order=nombre`),
    save:(p)=>mutation('tarifa.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',importe:Number(p.importe||0),matricula:Number(p.matricula||0),periodicidad:p.periodicidad||'mensual',activa:p.activa!==false}),
    delete:(tarifa_id)=>mutation('tarifa.eliminar',{tarifa_id}), forceDelete:(tarifa_id)=>mutation('tarifa.eliminar_forzado',{tarifa_id})
  },
  finance:{
    fees:(limit=120)=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=${Math.min(500,Math.max(20,Number(limit)||120))}`), payments:(limit=120)=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=${Math.min(500,Math.max(20,Number(limit)||120))}`), receipts:(limit=120)=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=${Math.min(500,Math.max(20,Number(limit)||120))}`),
    account:(limit=180)=>read('v_estado_cuenta_socio',`select=*&${filterClub()}&order=periodo.desc&limit=${Math.min(600,Math.max(30,Number(limit)||180))}`),
    async years(){const rows=await read('v_finanzas_metricas_anuales',`select=anio&${filterClub()}&order=anio.desc&limit=50`);return rows.map(r=>({periodo:`${r.anio}-01-01`}));},
    detail:({year,month,socio,origin,status,limit=150}={})=>read('v_finanzas_detalle',`select=*&${filterClub()}${year?`&anio=eq.${enc(year)}`:''}${month?`&mes=eq.${enc(month)}`:''}${socio?`&socio_id=eq.${enc(socio)}`:''}${origin?`&origen=eq.${enc(origin)}`:''}${status?`&estado=eq.${enc(status)}`:''}&order=periodo.desc,vencimiento.desc&limit=${Math.min(600,Math.max(30,Number(limit)||150))}`),
    metricsMonthly:(year)=>read('v_finanzas_metricas_mensuales',`select=*&${filterClub()}${year?`&anio=eq.${enc(year)}`:''}&order=anio.desc,mes.asc&limit=240`),
    metricsAnnual:()=>read('v_finanzas_metricas_anuales',`select=*&${filterClub()}&order=anio.desc&limit=50`),
    generate:(periodo=monthStart())=>mutation('cuotas.generar',{periodo}),
    adminPayment:(p)=>mutation('pago.registrar_admin',{cuota_id:p.cuota_id,importe:Number(p.importe),fecha:p.fecha||isoDate(),metodo:p.metodo,referencia:p.referencia||null,observaciones:p.observaciones||null}),
    communicatePayment:(p)=>mutation('pago.comunicar',{cuota_id:p.cuota_id,importe:Number(p.importe),fecha:p.fecha||isoDate(),metodo:p.metodo,referencia:p.referencia||null,justificante_path:p.justificante_path||null,observaciones:p.observaciones||null}),
    async uploadProof(socioId,file){
      if(!file||!file.size)return '';
      if(file.size>5*1024*1024)throw new Error('El justificante supera 5 MB.');
      const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();
      const path=`${session().club_id}/${socioId}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
      await backend.upload('justificantes-pago',path,file,false);
      return path;
    },
    proofUrl:(path)=>backend.signedUrl('justificantes-pago',path,600),
    validate:(pago_id,decision,motivo)=>mutation('pago.validar',{pago_id,decision,motivo:motivo||null}),
    pause:(cuota_id,motivo,hasta)=>mutation('cuota.pausar_avisos',{cuota_id,motivo,hasta:hasta||null}), resume:(cuota_id)=>mutation('cuota.reactivar_avisos',{cuota_id}),
    annulReceipt:(recibo_id,motivo)=>mutation('recibo.anular',{recibo_id,motivo})
  },
  financeContext:{
    get:(subject_type,subject_id,limit=200)=>backend.globalReadRpc('app_kombax_finance_context_r84',{p_subject_type:subject_type,p_subject_id:subject_id,p_limit:Math.min(500,Math.max(20,Number(limit)||200))}),
    inventory:(subject_type,subject_id,{limit=10,offset=0}={})=>backend.globalReadRpc('app_kombax_inventory_finance_r89',{p_subject_type:subject_type,p_subject_id:subject_id,p_limit:Math.min(50,Math.max(1,Number(limit)||10)),p_offset:Math.max(0,Number(offset)||0)})
  },
  consulting:{
    mine:()=>backend.globalReadRpc('app_kombax_consulting_mine_r85',{}),
    mutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_consulting_mutate_r85',{p_operation:operation,p_payload:payload}),
    create:(payload={})=>backend.globalWriteRpc('app_kombax_consulting_mutate_r85',{p_operation:'request.create',p_payload:payload}),
    acceptQuote:(request_id)=>backend.globalWriteRpc('app_kombax_consulting_mutate_r85',{p_operation:'request.accept_quote',p_payload:{request_id}}),
    async uploadDocument(request_id,file){
      if(!file||!file.size)throw new Error('Selecciona un documento.');
      if(file.size>10*1024*1024)throw new Error('El documento supera 10 MB.');
      const allowed=new Set(['application/pdf','image/jpeg','image/png','image/webp']);if(!allowed.has(file.type))throw new Error('Formato no admitido.');
      const uid=session()?.id;if(!uid)throw new Error('AUTH_REQUIRED');
      const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();const path=`${uid}/${request_id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
      await backend.upload('kombax-consulting-docs',path,file,false);
      try{return await backend.globalWriteRpc('app_kombax_consulting_mutate_r85',{p_operation:'document.add',p_payload:{request_id,storage_path:path,original_name:file.name,mime_type:file.type,size_bytes:file.size}})}
      catch(error){await backend.remove('kombax-consulting-docs',path).catch(()=>{});throw error;}
    }
  },
  privateTraining:{
    status:(subject_type,subject_id)=>backend.globalReadRpc('app_kombax_training_status_r86',{p_subject_type:subject_type,p_subject_id:subject_id})
  },
  payments:{
    connectStatus:(subject_type,subject_id)=>backend.invokeFunction('stripe-connect',{action:'status',subject_type,subject_id},25000),
    connectOnboarding:(subject_type,subject_id)=>backend.invokeFunction('stripe-connect',{action:'onboarding',subject_type,subject_id},35000),
    paymentMethodsStatus:(subject_type,subject_id)=>backend.globalReadRpc('app_stripe_payment_methods_status_r81',{p_subject_type:subject_type,p_subject_id:subject_id}),
    paymentMethodToggle:(subject_type,subject_id,method,enabled)=>backend.globalWriteRpc('app_stripe_payment_method_toggle_r80',{p_subject_type:subject_type,p_subject_id:subject_id,p_method:method,p_enabled:!!enabled}),
    payerOptions:(club_id)=>backend.globalReadRpc('app_stripe_payer_options_r80',{p_club_id:club_id}),
    sepaSetup:(fee_id)=>backend.invokeFunction('stripe-sepa',{action:'setup',fee_id,request_id:crypto.randomUUID()},35000),
    sepaChargeFee:(fee_id)=>backend.invokeFunction('stripe-sepa',{action:'charge_fee',fee_id,request_id:crypto.randomUUID()},35000),
    sepaDueFees:(club_id,limit=50)=>backend.globalReadRpc('app_stripe_sepa_due_fees_r80',{p_club_id:club_id,p_limit:limit}),
    sepaSummary:(club_id)=>backend.globalReadRpc('app_stripe_sepa_summary_r80',{p_club_id:club_id}),
    terminalToggle:(subject_type,subject_id,enabled)=>backend.globalWriteRpc('app_stripe_terminal_toggle_r81',{p_subject_type:subject_type,p_subject_id:subject_id,p_enabled:!!enabled}),
    terminalEnsureLocation:(payload={})=>backend.invokeFunction('stripe-terminal',{action:'ensure_location',...payload},35000),
    terminalConnectionToken:(subject_type,subject_id)=>backend.invokeFunction('stripe-terminal',{action:'connection_token',subject_type,subject_id},25000),
    terminalCreateIntent:(payload={})=>backend.invokeFunction('stripe-terminal',{action:'create_intent',...payload,request_id:payload.request_id||crypto.randomUUID()},35000),
    terminalWebFallback:(payload={})=>backend.invokeFunction('stripe-terminal',{action:'web_fallback',...payload,request_id:payload.request_id||crypto.randomUUID()},35000),
    terminalSales:(subject_type,subject_id,limit=50)=>backend.globalReadRpc('app_stripe_terminal_sales_r81',{p_subject_type:subject_type,p_subject_id:subject_id,p_limit:Math.min(200,Math.max(1,Number(limit)||50))}),
    checkout:(kind,reference_id,quantity=1)=>backend.invokeFunction('stripe-checkout',{kind,reference_id,quantity,user_locale:getLocale(),request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`},35000),
    checkoutCart:(items)=>backend.invokeFunction('stripe-checkout',{kind:'showcase_cart',items:(Array.isArray(items)?items:[]).map(x=>({product_id:x.product_id,quantity:Number(x.quantity||1),variant:x.variant||null})),user_locale:getLocale(),request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`},35000),
    refund:(payload={})=>backend.invokeFunction('stripe-refund',{action:'single',...payload,user_locale:payload.user_locale||getLocale(),request_id:payload.request_id||crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`},45000),
    refundEventBatch:(event_id,reason='')=>backend.invokeFunction('stripe-refund',{action:'event_batch',event_id,reason,user_locale:getLocale(),request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`},90000),
    accountFinance:(scope,subject_id)=>backend.invokeFunction('stripe-account-finance',{scope,subject_id},35000),
    myOrders:(limit=100)=>backend.globalReadRpc('app_showcase_my_orders_v259',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    sellerOrders:(provider_id,limit=100)=>backend.globalReadRpc('app_showcase_seller_orders_v259',{p_provider_id:provider_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    orderMutate:(operation,payload={})=>backend.globalWriteRpc('app_showcase_order_mutate_v259',{p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`})
  },
  commercialCompliance:{
    purchaseEligibility:()=>backend.globalReadRpc('app_kombax_commercial_purchase_eligibility_r63',{}),
    report:(target_type,target_id,reason,detail='')=>backend.globalWriteRpc('app_kombax_commercial_report_r63',{p_target_type:target_type,p_target_id:target_id,p_reason:reason,p_detail:detail,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    cancelEventPlan:(event_id,reason)=>backend.globalWriteRpc('app_kombax_event_cancel_commercial_plan_r63',{p_event_id:event_id,p_reason:reason,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`})
  },
  marketplace:{
    sellerCenter:(provider_id)=>backend.globalReadRpc('app_showcase_seller_center_r627',{p_provider_id:provider_id}),
    sellerApplication:(provider_id,operation,payload={})=>backend.globalWriteRpc('app_showcase_seller_application_mutate_r627',{p_provider_id:provider_id,p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    acceptSellerPolicy:(provider_id,policy_code,policy_version)=>backend.globalWriteRpc('app_showcase_seller_policy_accept_r627',{p_provider_id:provider_id,p_policy_code:policy_code,p_policy_version:policy_version,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    buyerTrust:()=>backend.globalReadRpc('app_kombax_buyer_trust_r627',{}),
    acceptBuyerPolicy:(policy_code,policy_version)=>backend.globalWriteRpc('app_kombax_buyer_policy_accept_r627',{p_policy_code:policy_code,p_policy_version:policy_version,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    buyerIdentitySubmit:(payload={})=>backend.globalWriteRpc('app_kombax_buyer_identity_mutate_r627',{p_operation:'submit',p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    async uploadBuyerIdentityDocument(identity_request_id,document_type,file){
      if(!file||!file.size)throw new Error('Selecciona un documento.');
      if(file.size>15*1024*1024)throw new Error('El documento supera el límite de 15 MB.');
      const allowed=new Set(['application/pdf','image/jpeg','image/png','image/webp']);
      if(!allowed.has(file.type))throw new Error('Formato no admitido. Usa PDF, JPG, PNG o WEBP.');
      const uid=session()?.id;if(!uid)throw new Error('Sesión requerida.');
      const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();
      const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${uid}/buyer/${identity_request_id}/${Date.now()}-${token}.${ext}`;
      await backend.upload('kombax-verification-docs',path,file,false);
      try{return await backend.globalWriteRpc('app_kombax_buyer_identity_document_r627',{p_request_id:identity_request_id,p_document_type:document_type,p_storage_path:path,p_mime_type:file.type,p_bytes:file.size,p_request_token:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`});}
      catch(error){await backend.remove('kombax-verification-docs',path).catch(()=>{});throw error;}
    }
  },
  reminders:{
    load:()=>read('configuracion_avisos_cuota',`select=*&${filterClub()}&limit=1`), history:()=>read('historial_avisos_cuota',`select=*&${filterClub()}&order=fecha_programada.desc&limit=250`),
    save:(p)=>mutation('avisos.configurar',{dias_aviso:p.dias_aviso,hora_envio:p.hora_envio||'10:00',canal_app:p.canal_app!==false,canal_push:p.canal_push!==false,canal_email:p.canal_email===true,agrupar_por_familia:p.agrupar_por_familia!==false,marcar_vencida_dia:Number(p.marcar_vencida_dia||15),zona_horaria:p.zona_horaria||'Europe/Madrid',activo:p.activo!==false}),
    process:(fecha=isoDate())=>mutation('avisos.procesar',{fecha})
  },
  sessions:{
    list:(limit=180)=>read('sesiones_entrenamiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.desc&limit=${Math.min(500,Math.max(60,Number(limit)||180))}`),
    series:(limit=120)=>read('series_sesiones',`select=*&${filterClub()}&order=creado_en.desc&limit=${Math.min(300,Math.max(30,Number(limit)||120))}`),
    saveSeries:(p)=>mutation('sesion.serie.guardar',{id:p.id||null,grupo_id:p.grupo_id,dias_semana:p.dias_semana||[],hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',codigo_acceso:p.codigo_acceso||'',fecha_inicio:p.fecha_inicio||isoDate(),fecha_fin:p.fecha_fin||null,activa:p.activa!==false}),
    endSeries:(serie_id,fecha_fin=isoDate())=>mutation('sesion.serie.finalizar',{serie_id,fecha_fin}),
    generateRecurring:(horizonte_dias=84)=>mutation('sesiones.recurrentes.generar',{horizonte_dias:Number(horizonte_dias||84)}),
    exception:(p)=>mutation('sesion.excepcion.guardar',{sesion_id:p.sesion_id,estado:p.estado||null,monitor_nombre:p.monitor_nombre||null,hora_inicio:p.hora_inicio||null,hora_fin:p.hora_fin||null,sala:p.sala||null,motivo:p.motivo||'',observacion_general:p.observacion_general||null}),
    save:(p)=>mutation('sesion.guardar',{id:p.id||null,grupo_id:p.grupo_id,fecha:p.fecha,hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',estado:p.estado||'programada',observacion_general:p.observacion_general||'',codigo_acceso:p.codigo_acceso||''}),
    attendance:(limit=400)=>read('asistencias',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=registrado_en.desc&limit=${Math.min(800,Math.max(100,Number(limit)||400))}`),
    reservations:(limit=400)=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=${Math.min(800,Math.max(100,Number(limit)||400))}`),
    reserve:(sesion_id,socio_id)=>mutation('sesion.reserva.confirmar',{sesion_id,socio_id}),
    cancelReservation:(sesion_id,socio_id)=>mutation('sesion.reserva.cancelar',{sesion_id,socio_id}),
    saveAttendance:(p)=>mutation('asistencia.guardar',{sesion_id:p.sesion_id,socio_id:p.socio_id,estado:p.estado,observacion:p.observacion||null}),
    checkin:(p)=>mutation('checkin.registrar',{sesion_id:p.sesion_id,socio_id:p.socio_id,codigo:p.codigo||'',metodo:p.metodo||'manual'}),
    delete:(sesion_id)=>mutation('sesion.eliminar',{sesion_id}), forceDelete:(sesion_id)=>mutation('sesion.eliminar_forzado',{sesion_id})
  },
  progress:{
    list:()=>session()?.rol==='monitor'?backend.readRpc('app_kombax_mi_progreso_v057',{p_club_id:session()?.club_id}):read('v_progreso_socio',`select=*&${filterClub()}&order=apellidos,nombre`)
  },
  tracking:{
    list:(limit=200)=>read('seguimiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,creado_en.desc&limit=${Math.min(500,Math.max(50,Number(limit)||200))}`),
    save:(p)=>mutation('seguimiento.guardar',{socio_id:p.socio_id,tipo:p.tipo,nota:p.nota,visibilidad:p.visibilidad||'equipo',fecha:p.fecha||isoDate()})
  },
  communications:{
    list:(limit=80)=>read('comunicaciones',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=${Math.min(300,Math.max(20,Number(limit)||80))}`),
    uploadImage:(file)=>uploadPublicImage('communications',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('publicacion.guardar',{id:p.id||null,tipo:p.tipo||'noticia',titulo:p.titulo,cuerpo:p.cuerpo,audiencia:p.audiencia||'todos',estado:p.estado||'borrador',evento_fecha:p.evento_fecha||null,ubicacion:p.ubicacion||'',imagen_url:p.imagen_url||''}),
    async delete(publicacion_id){const out=await mutation('publicacion.eliminar',{publicacion_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;},
    async cleanupOld(antes_de,incluir_publicadas=false){const out=await mutation('publicacion.limpiar_antiguas',{antes_de,incluir_publicadas:incluir_publicadas===true});await removePublicImages(out?.image_urls||[]);return out;}
  },
  material:{
    list:(limit=150)=>read('material_catalogo',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=orden,nombre&limit=${Math.min(300,Math.max(30,Number(limit)||150))}`), variants:(limit=500)=>read('material_variantes',`select=*&${filterClub()}&order=material_id,talla,color&limit=${Math.min(1000,Math.max(100,Number(limit)||500))}`), orders:(limit=10)=>read('material_pedidos',`select=*&${filterClub()}&order=creado_en.desc&limit=${Math.min(400,Math.max(10,Number(limit)||10))}`),
    inventory:(limit=200)=>backend.readRpc('app_kombax_material_inventory_r89',{p_club_id:session()?.club_id,p_limit:Math.min(300,Math.max(10,Number(limit)||200))}),
    movements:(material_id=null,{limit=10,offset=0}={})=>backend.readRpc('app_kombax_material_stock_movements_r89',{p_club_id:session()?.club_id,p_material_id:material_id||null,p_limit:Math.min(50,Math.max(1,Number(limit)||10)),p_offset:Math.max(0,Number(offset)||0)}),
    inventoryMutate:(operation,payload={})=>backend.writeRpc('app_kombax_material_inventory_mutate_r89',{p_operation:operation,p_payload:{...payload,club_id:session()?.club_id},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    uploadImage:(file)=>uploadPublicImage('material',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('material.guardar',{id:p.id||null,disciplina_id:p.disciplina_id||null,nombre:p.nombre,categoria:p.categoria||'',descripcion:p.descripcion||'',imagen_url:p.imagen_url||'',precio:Number(p.precio||0),stock:Number(p.stock||0),obligatorio:p.obligatorio===true,referencia:p.referencia||'',activo:p.activo!==false}),
    saveVariant:(p)=>mutation('material.variante.guardar',{id:p.id||null,material_id:p.material_id,talla:p.talla||'',color:p.color||'',referencia:p.referencia||'',stock:Number(p.stock||0),activa:p.activa!==false}),
    request:(p)=>mutation('material.solicitar',{socio_id:p.socio_id,material_id:p.material_id,variante_id:p.variante_id||null,cantidad:Number(p.cantidad||1),observaciones:p.observaciones||'',validar_ahora:p.validar_ahora===true}),
    orderStatus:(pedido_id,estado)=>mutation('material.pedido.estado',{pedido_id,estado}),
    async delete(material_id){const out=await mutation('material.eliminar',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}, async forceDelete(material_id){const out=await mutation('material.eliminar_forzado',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}
  },
  notifications:{
    list:(options={})=>notificationList(Math.min(300,Math.max(50,Number(options.limit)||120)),options),
    headerSummary:()=>rpcWithFallback(()=>backend.readRpc('app_kombax_header_summary_v107',{p_club_id:session()?.club_id}),()=>backend.readRpc('app_kombax_header_summary_v106',{p_club_id:session()?.club_id}),'app_kombax_header_summary_v107'),
    markRead:(notificacion_id)=>optimisticNotificationMutation('notificacion.leer',{notificacion_id},n=>n.id===notificacion_id),
    review:(notificacion_id)=>optimisticNotificationMutation('notificacion.revisar',{notificacion_id},n=>n.id===notificacion_id),
    markGroup:(tipo)=>optimisticNotificationMutation('notificacion.leer_grupo',{tipo},n=>n.tipo===tipo&&n.requiere_accion!==true),
    markInformative:()=>optimisticNotificationMutation('notificacion.leer_todas',{},n=>n.requiere_accion!==true),
    invalidate:()=>invalidateCache(tenantKey(session(),'notifications:')),
    // Mi club no ofrece opt-out por categoría. Esta operación existe solo para
    // mantener el contrato RC10 y reestablece siempre las cuatro categorías a true.
    enforceClubPush:()=>mutation('notificaciones.preferencias',{push_general:true,push_finanzas:true,push_sesiones:true,push_comunidad:true}),
  },
  users:{
    members:(limit=150)=>read('miembros_club',`select=*,perfiles(id,nombre,apellidos,telefono)&${filterClub()}&rol=in.(direccion,secretaria,economia,comunicacion,monitor)&order=creado_en&limit=${Math.min(300,Math.max(30,Number(limit)||150))}`),
    teamRequests:async()=>{try{return await backend.readRpc('app_kombax_solicitudes_equipo_v109',{p_club_id:session()?.club_id});}catch{return backend.readRpc('app_kombax_solicitudes_equipo_v060',{p_club_id:session()?.club_id});}},
    resolveTeamRequest:(id,estado,rol=null,nota='')=>backend.writeRpc('app_kombax_solicitud_equipo_resolver_v060',{p_solicitud_id:id,p_estado:estado,p_rol:rol,p_nota:nota||null}),
    createInvitation:(tipo,email,rol=null,nombre='')=>backend.writeRpc('app_kombax_invitacion_crear_v059',{p_club_id:session()?.club_id,p_tipo:String(tipo||'').trim().toLowerCase(),p_email:String(email||'').trim().toLowerCase(),p_rol:rol?String(rol).trim().toLowerCase():null,p_nombre:String(nombre||'').trim()||null,p_expira_horas:168}),
    createTeamInvitation:(email,rol,nombre='')=>backend.writeRpc('app_kombax_invitacion_crear_v059',{p_club_id:session()?.club_id,p_tipo:'equipo',p_email:String(email||'').trim().toLowerCase(),p_rol:String(rol||'').trim().toLowerCase(),p_nombre:String(nombre||'').trim()||null,p_expira_horas:168}),
    createStudentInvitation:(email,nombre='')=>backend.writeRpc('app_kombax_invitacion_crear_v059',{p_club_id:session()?.club_id,p_tipo:'alumno',p_email:String(email||'').trim().toLowerCase(),p_rol:null,p_nombre:String(nombre||'').trim()||null,p_expira_horas:168}),
    sendInvitation:(invitation_id)=>backend.invokeFunction('invite-email',{invitation_id,user_locale:getLocale()}),
    sendTeamInvitation:(invitation_id)=>backend.invokeFunction('invite-email',{invitation_id,user_locale:getLocale()}),
    sendStudentInvitation:(invitation_id)=>backend.invokeFunction('invite-email',{invitation_id,user_locale:getLocale()})
  },
  accessCodes:{
    get:()=>backend.readRpc('app_kombax_codigos_club_v060',{p_club_id:session()?.club_id}),
    rotate:(tipo,codigo='')=>backend.writeRpc('app_kombax_codigo_rotar_v060',{p_club_id:session()?.club_id,p_tipo:tipo,p_codigo:String(codigo||'').trim()||null}),
    requestTeam:(clubSlug,codigo,rol='')=>backend.requestTeamAccess(clubSlug,codigo,session()?.email||'',rol)
  },
  scopes:{
    context:()=>backend.readRpc('app_kombax_mi_ambito_v057',{p_club_id:session()?.club_id}),
    list:()=>backend.readRpc('app_kombax_ambitos_v057',{p_club_id:session()?.club_id}),
    students:()=>backend.readRpc('app_kombax_mis_alumnos_v057',{p_club_id:session()?.club_id}),
    finance:()=>backend.readRpc('app_kombax_mi_cartera_v057',{p_club_id:session()?.club_id}),
    progress:()=>backend.readRpc('app_kombax_mi_progreso_v057',{p_club_id:session()?.club_id}),
    mutate:async(operation,payload={})=>{
      const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const out=await backend.writeRpc('app_kombax_ambito_mutate_v057',{p_operation:operation,p_payload:{...payload,club_id:session()?.club_id},p_request_id:requestId});
      if(!out?.ok||out.request_id!==requestId)throw new Error('Respuesta de ámbitos no verificable.');
      return out.data;
    },
    collect:(p)=>backend.writeRpc('app_kombax_monitor_cobro_v057',{p_cuota_id:p.cuota_id,p_importe:Number(p.importe),p_fecha:p.fecha||isoDate(),p_metodo:p.metodo,p_referencia:p.referencia||null,p_observaciones:p.observaciones||null})
  },
  lifecycle:{
    maintenance:()=>backend.writeRpc('app_ciclo_mantenimiento_v133',{p_club_id:session()?.club_id}),
    async list({tipo='',estado='',desde='',hasta='',limit=150}={}){await this.maintenance().catch(()=>null);return backend.readRpc('app_ciclo_listar_v038',{p_club_id:session()?.club_id,p_tipo:tipo||null,p_estado:estado||null,p_desde:desde||null,p_hasta:hasta||null,p_limit:Math.min(300,Math.max(20,Number(limit)||150))});},
    async listPage({tipo='',estado='',desde='',hasta='',limit=10,offset=0}={}){await this.maintenance().catch(()=>null);return backend.readRpc('app_ciclo_listar_page_r89',{p_club_id:session()?.club_id,p_tipo:tipo||null,p_estado:estado||null,p_desde:desde||null,p_hasta:hasta||null,p_limit:Math.min(50,Math.max(1,Number(limit)||10)),p_offset:Math.max(0,Number(offset)||0)});},
    action:(tipo,ids,accion,motivo='')=>backend.writeRpc('app_ciclo_accion_v038',{p_club_id:session()?.club_id,p_recurso_tipo:tipo,p_ids:ids,p_accion:accion,p_motivo:motivo||null}),
    previewDelete:(tipo,id)=>backend.readRpc('app_ciclo_eliminar_preview_r89',{p_club_id:session()?.club_id,p_recurso_tipo:tipo,p_recurso_id:id}),
    async deleteForever(tipo,id,confirmacion=''){
      const out=await backend.writeRpc('app_ciclo_eliminar_definitivo_r89',{p_club_id:session()?.club_id,p_recurso_tipo:tipo,p_recurso_id:id,p_confirmacion:confirmacion});
      for(const item of Array.isArray(out?.storage_objects)?out.storage_objects:[]){if(item?.bucket&&item?.path)await backend.remove(item.bucket,item.path).catch(()=>{});}
      await removePublicImages(Array.isArray(out?.public_image_urls)?out.public_image_urls:[]);
      invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);
      return out;
    }
  },
  portal:{
    visibleMembers:()=>read('socios',`select=*&${filterClub()}&order=apellidos,nombre&limit=200`),
    enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc&limit=400`),
    graduations:()=>read('graduaciones',`select=*&${filterClub()}&order=fecha.desc&limit=200`),
    schedules:()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`),
    sessions:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.desc&limit=180`),
    reservations:()=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=400`),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=registrado_en.desc&limit=400`),
    tracking:()=>read('seguimiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,creado_en.desc&limit=200`),
    documents:()=>read('documentos_socios',`select=*&${filterClub()}&ciclo_estado=eq.activo&visible_familia=eq.true&order=creado_en.desc&limit=150`),
    fees:()=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=180`),
    payments:()=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=180`),
    receipts:()=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=180`),
    communications:()=>read('comunicaciones',`select=*&${filterClub()}&ciclo_estado=eq.activo&estado=in.(publicada,programada)&order=publicada_en.desc,creado_en.desc&limit=200`),
    notifications:()=>notificationList(300),
    requestMinor:(p)=>mutation('preinscripcion.crear',{tipo_solicitud:'menor',nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,tutor_nombre:p.tutor_nombre||'',tutor_email:p.tutor_email||'',telefono:p.telefono||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,tarifa_id:p.tarifa_id||null,parentesco:p.parentesco||null,observaciones:p.observaciones||null}),
    requestEnrollment:(socio_id,disciplina_id,grupo_id,tarifa_id)=>mutation('matricula.solicitar',{socio_id,disciplina_id,grupo_id,tarifa_id:tarifa_id||null}),
    reserveSession:(sesion_id,socio_id)=>mutation('sesion.reserva.confirmar',{sesion_id,socio_id}),
    cancelSessionReservation:(sesion_id,socio_id)=>mutation('sesion.reserva.cancelar',{sesion_id,socio_id}),
    checkin:(sesion_id,socio_id,codigo='')=>mutation('checkin.registrar',{sesion_id,socio_id,codigo,metodo:'codigo'})
  },
  settings:{
    club:()=>cachedRead('settings:club',()=>read('clubes',`select=*&id=eq.${enc(session()?.club_id)}&limit=1`),60000), config:()=>cachedRead('settings:config',()=>read('config_club',`select=*&${filterClub()}`),60000),
    brandingHistory:()=>read('club_branding_history',`select=*&${filterClub()}&order=version.desc&limit=20`).catch(()=>[]),
    publishBranding:(p)=>backend.writeRpc('app_publicar_branding_v039',{p_club_id:session()?.club_id,p_expected_version:Number(p.expected_version||1),p_theme_id:p.theme_id,p_logo_url:p.logo_url||null,p_portada_url:p.portada_url||null}),
    restoreBranding:(version)=>backend.writeRpc('app_restaurar_branding_v039',{p_club_id:session()?.club_id,p_source_version:Number(version)}),
    uploadBrandImage:(kind,file)=>uploadPublicImage(kind==='cover'?'branding-cover':'branding-logo',file), removeBrandImage:(url)=>removePublicImage(url),
    saveClub:(p)=>mutation('club.configurar',p), profile:(p)=>mutation('perfil.guardar',{nombre:p.nombre||'',apellidos:p.apellidos||'',telefono:p.telefono||''}),
    async uploadAvatar(file){if(!file||!file.size)throw new Error('Selecciona una imagen.');if(file.size>5*1024*1024)throw new Error('La foto supera 5 MB.');if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');const ext=file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg';const path=`${session().club_id}/${session().id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;await backend.upload('profile-media',path,file,false);try{const out=await mutation('perfil.avatar',{avatar_path:path});if(out?.old_avatar_path)await backend.remove('profile-media',out.old_avatar_path).catch(()=>{});return out;}catch(e){await backend.remove('profile-media',path).catch(()=>{});throw e;}},
    async removeAvatar(){const out=await mutation('perfil.avatar',{avatar_path:null});if(out?.old_avatar_path)await backend.remove('profile-media',out.old_avatar_path).catch(()=>{});return out;},
    avatarUrl:(path)=>path?backend.signedUrl('profile-media',path,3600):Promise.resolve('')
  },
  clubPublic:{
    async one(club_id=session()?.club_id){const rows=await rpcWithFallback(()=>backend.readRpc('app_perfil_club_publico_v132',{p_club_id:club_id}),()=>backend.readRpc('app_perfil_club_publico_v061',{p_club_id:club_id}),'app_perfil_club_publico_v132');const out=rows?.[0]||null;if(!out)return null;const [logo,cover]=await Promise.all([readMediaPresentations('club_public_logo',[club_id]),readMediaPresentations('club_public_cover',[club_id])]);return {...out,logo_presentation:out.logo_presentation||logo.get(String(club_id))||{},portada_presentation:out.portada_presentation||cover.get(String(club_id))||{}};},
    save:(p)=>mutation('club_publico.guardar',{slug:p.slug,nombre_publico:p.nombre_publico,alias:p.alias||'',lema:p.lema||'',descripcion:p.descripcion||'',historia:p.historia||'',ciudad:p.ciudad||'',provincia:p.provincia||'',pais:p.pais||'España',logros:p.logros||'',contacto_publico:p.contacto_publico||'',web_publica:p.web_publica||'',instagram:p.instagram||'',tiktok:p.tiktok||'',youtube:p.youtube||'',logo_url:p.logo_url||'',portada_url:p.portada_url||'',visible:true}),
    uploadImage:(kind,file)=>uploadPublicImage(kind==='cover'?'public-club-cover':'public-club-logo',file),
    removeImage:(url)=>removePublicImage(url),
    album:async(club_id=session()?.club_id)=>enrichMediaPresentations('club_media',await backend.globalReadRpc('app_kombax_club_album_v046',{p_club_id:club_id})),
    albumUrl:(path)=>backend.publicUrl('kombax-public-media',path),
    uploadAlbumMedia:(club_id,type,file)=>uploadKombaxClubMedia(club_id,type,file),
    setVideoCover:(club_id,media,file,{presentation={},mode='upload',time=0}={})=>storeMediaCover('club_media',media.id,file,{bucket:'kombax-public-media',pathPrefix:`${session()?.id}/club/${club_id}/${media.id}`,presentation,mode,time}),
    removeAlbumMedia:async(club_id,media)=>{const out=await kombaxGlobalMutation('app_kombax_club_media_mutate_v046','kombax.club.media.remove',{club_id,media_id:media.id});if(out?.storage_path)await backend.remove('kombax-public-media',out.storage_path).catch(()=>{});await removeMediaCover(media?.media_presentation,'kombax-public-media');return out;}
  },
  publicIdentity:{
    search:(query='')=>backend.readRpc('app_buscar_identidades_publicas_v035',{p_club_id:session()?.club_id,p_query:query||'',p_limit:60})
  },
  sportsProfiles:{
    list:async(socio_id=null)=>enrichMediaPresentations('sports_profile',await backend.readRpc('app_perfiles_deportivos_publicos_v032',{p_club_id:session()?.club_id,p_socio_id:socio_id||null}),'socio_id','foto_presentation'),
    async one(socio_id){const rows=await this.list(socio_id);return rows?.[0]||null;},
    save:(p)=>mutation('perfil_deportivo.guardar',{socio_id:p.socio_id,apodo:p.apodo||'',presentacion:p.presentacion||'',experiencia_anos:p.experiencia_anos===''||p.experiencia_anos==null?null:Number(p.experiencia_anos),guardia:p.guardia||'',tecnica_favorita:p.tecnica_favorita||'',especialidad:p.especialidad||'',categoria_competitiva:p.categoria_competitiva||'',competiciones_logros:p.competiciones_logros||'',objetivos:p.objetivos||'',visible:p.visible!==false}),
    moderate:(socio_id,visible,motivo='')=>mutation('perfil_deportivo.moderar',{socio_id,visible:visible===true,motivo:motivo||''}),
    async uploadPhoto(socio_id,file){
      if(!file||!file.size)throw new Error('Selecciona una imagen.');
      if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');
      const prepared=await optimizeImage(file,{maxEdge:1280,maxBytes:2*1024*1024});
      if(prepared.file.size>5*1024*1024)throw new Error('La foto supera 5 MB.');
      const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
      const path=`${session().club_id}/${socio_id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
      await backend.upload('sports-profile-media',path,prepared.file,false);
      try{const out=await mutation('perfil_deportivo.foto',{socio_id,foto_path:path});if(out?.old_foto_path&&out.old_foto_path!==path)await backend.remove('sports-profile-media',out.old_foto_path).catch(()=>{});return out;}
      catch(error){await backend.remove('sports-profile-media',path).catch(()=>{});throw error;}
    },
    async removePhoto(socio_id){const out=await mutation('perfil_deportivo.foto',{socio_id,foto_path:null});if(out?.old_foto_path)await backend.remove('sports-profile-media',out.old_foto_path).catch(()=>{});return out;},
    photoUrl:(path)=>path?backend.signedUrl('sports-profile-media',path,3600):Promise.resolve('')
  },
  mediaFraming:{
    get:(scope,ids=[])=>readMediaPresentations(scope,ids),
    enrich:(scope,rows=[],idKey='id',field='media_presentation')=>enrichMediaPresentations(scope,rows,idKey,field),
    set:(scope,targetId,presentation)=>setMediaPresentation(scope,targetId,presentation),
    setCover:(scope,targetId,file,options={})=>storeMediaCover(scope,targetId,file,options),
    coverPath:(presentation)=>coverPathFromPresentation(presentation),
    coverBucket:(presentation,fallback)=>coverBucketFromPresentation(presentation,fallback)
  },
  kombaxEvents:{
    async list({query='',tipo='',estado='',limit=24}={}){const rows=await rpcWithFallback(()=>backend.globalReadRpc('app_kombax_eventos_publicos_v178',{p_query:query||'',p_tipo:tipo||null,p_estado:estado||null,p_limit:Math.min(100,Math.max(1,Number(limit)||24))}),()=>backend.globalReadRpc('app_kombax_eventos_publicos_v173',{p_query:query||'',p_tipo:tipo||null,p_estado:estado||null,p_limit:Math.min(100,Math.max(1,Number(limit)||24))}),'app_kombax_eventos_publicos_v178');return enrichEventTicketing(rows);},
    promoted:async(limit=6)=>{try{const rows=await backend.publicRpc('app_kombax_promoted_events_r64',{p_limit:Math.min(12,Math.max(1,Number(limit)||6))});return enrichEventTicketing((rows||[]).map(x=>({...x,kombax_promoted:true})));}catch(error){if(!isMissingRpc(error,'app_kombax_promoted_events_r64'))console.warn('Events promoted R64:',error);return [];}},
    async listPage({query='',tipo='',estado='',phase='',cursor=null,limit=24}={}){
      try{
        const out=await backend.globalReadRpc('app_kombax_eventos_visible_page_v236',{p_query:String(query||'').trim(),p_tipo:tipo||null,p_estado:estado||null,p_phase:phase||null,p_cursor_bucket:cursor?.bucket??null,p_cursor_fecha:cursor?.fecha||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(48,Math.max(1,Number(limit)||24))});
        return {items:await enrichEventTicketing(Array.isArray(out?.items)?out.items:[]),has_more:out?.has_more===true,next_cursor:out?.next_cursor||null,keyset:true};
      }catch(error){
        if(!isMissingRpc(error,'app_kombax_eventos_visible_page_v236'))throw error;
        try{
          const out=await backend.globalReadRpc('app_kombax_eventos_publicos_page_v191',{p_query:String(query||'').trim(),p_tipo:tipo||null,p_estado:estado||null,p_phase:phase||null,p_cursor_bucket:cursor?.bucket??null,p_cursor_fecha:cursor?.fecha||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(48,Math.max(1,Number(limit)||24))});
          return {items:await enrichEventTicketing(Array.isArray(out?.items)?out.items:[]),has_more:out?.has_more===true,next_cursor:out?.next_cursor||null,keyset:true};
        }catch(fallbackError){
          if(!isMissingRpc(fallbackError,'app_kombax_eventos_publicos_page_v191'))throw fallbackError;
          const items=await this.list({query,tipo,estado,limit});return {items:Array.isArray(items)?items:[],has_more:false,next_cursor:null,keyset:false};
        }
      }
    },
    live:({limit=24}={})=>backend.publicRpc('app_kombax_eventos_live_v164',{p_limit:Math.min(48,Math.max(1,Number(limit)||24))}),
    async detail(id){
      const bundled=await rpcWithFallback(
        ()=>backend.globalReadRpc('app_kombax_evento_bundle_v253',{p_evento_id:id,p_workspace_club_id:session()?.club_id||null}),
        ()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_evento_bundle_v189',{p_evento_id:id,p_workspace_club_id:session()?.club_id||null}),()=>backend.globalReadRpc('app_kombax_evento_publico_detalle_v178',{p_evento_id:id}),'app_kombax_evento_bundle_v189'),
        'app_kombax_evento_bundle_v253'
      );
      if(!bundled)return bundled;
      if(bundled.event){
        const baseEvent=bundled.event||{};const event=(await enrichEventTicketing([baseEvent]))[0]||baseEvent;const participants=await enrichMediaPresentations('event_participant',bundled.participants||[]);const participantPresentation=new Map(participants.map(x=>[String(x.id),x.media_presentation||{}]));
        const fights=(bundled.fights||[]).map(x=>({...x,a_media_presentation:participantPresentation.get(String(x.participante_a_id||''))||{},b_media_presentation:participantPresentation.get(String(x.participante_b_id||''))||{}}));
        const media=await enrichMediaPresentations('event_media',bundled.media||[]);
        return {...event,main_event:bundled.main_event||null,entities:bundled.entities||[],participants,participants_count:Number(bundled.participants_count??participants.length),participants_accepted_count:Number(bundled.participants_accepted_count??participants.filter(x=>x.estado_inscripcion==='aceptada').length),participants_pending_count:Number(bundled.participants_pending_count??participants.filter(x=>x.estado_inscripcion==='pendiente').length),participants_has_more:bundled.participants_has_more===true,participants_next_cursor:bundled.participants_next_cursor||null,fights,media,engagement:bundled.engagement||null,can_manage:bundled.can_manage===true,can_manage_fights:bundled.can_manage_fights===true};
      }
      return bundled;
    },
    async detailBySlug(slug){
      const normalized=String(slug||'').trim().toLowerCase();
      const out=await rpcWithFallback(
        ()=>backend.publicRpc('app_kombax_evento_slug_v253',{p_slug:normalized}),
        ()=>rpcWithFallback(
          ()=>rpcWithFallback(()=>backend.publicRpc('app_kombax_evento_publico_slug_v178',{p_slug:normalized}),()=>backend.publicRpc('app_kombax_evento_publico_slug_v173',{p_slug:normalized}),'app_kombax_evento_publico_slug_v178'),
          ()=>backend.publicRpc('app_kombax_evento_publico_slug_v166',{p_slug:normalized}),
          'app_kombax_evento_publico_slug_v178'
        ),
        'app_kombax_evento_slug_v253'
      );
      if(!out?.event)return out;
      const publicEvent=(await enrichEventTicketing([out.event]))[0]||out.event;
      const participants=await enrichMediaPresentations('event_participant',out.participants||[]);
      const participantPresentation=new Map(participants.map(x=>[String(x.id),x.media_presentation||{}]));
      const fights=(out.fights||[]).map(x=>({...x,a_media_presentation:participantPresentation.get(String(x.participante_a_id||''))||{},b_media_presentation:participantPresentation.get(String(x.participante_b_id||''))||{}}));
      const media=await enrichMediaPresentations('event_media',out.media||await backend.publicRpc('app_kombax_evento_media_v175',{p_evento_id:out.event.id,p_workspace_club_id:null}).catch(()=>[]));
      return {...publicEvent,main_event:out.main_event||null,fase_temporal:out.fase_temporal||publicEvent?.fase_temporal||null,entities:out.entities||[],participants,participants_count:Number(out.participants_count??participants.length),participants_accepted_count:Number(out.participants_accepted_count??participants.filter(x=>x.estado_inscripcion==='aceptada').length),participants_pending_count:Number(out.participants_pending_count??0),participants_has_more:out.participants_has_more===true,participants_next_cursor:out.participants_next_cursor||null,fights,media,engagement:out.engagement||null,can_manage:out.can_manage===true,can_manage_fights:out.can_manage_fights===true};
    },
    engagement:(id)=>backend.globalReadRpc('app_kombax_evento_engagement_v162',{p_evento_id:id}).then(rows=>Array.isArray(rows)?rows[0]||null:rows),
    participants:async(id)=>enrichMediaPresentations('event_participant',await backend.globalReadRpc('app_kombax_evento_participantes_v161',{p_evento_id:id})),
    async participantsPage(id,{query='',cursor=null,limit=40}={}){
      try{
        const out=await backend.publicRpc('app_kombax_evento_participantes_page_v253',{p_evento_id:id,p_query:String(query||'').trim(),p_cursor_creado_en:cursor?.creado_en||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(100,Math.max(1,Number(limit)||40))});
        const items=await enrichMediaPresentations('event_participant',Array.isArray(out?.items)?out.items:[]);
        return {...out,items,total_count:Number(out?.total_count||0),accepted_count:Number(out?.accepted_count||0),pending_count:Number(out?.pending_count||0),has_more:out?.has_more===true,next_cursor:out?.next_cursor||null};
      }catch(error){
        if(!isMissingRpc(error,'app_kombax_evento_participantes_page_v253'))throw error;
        const items=await this.participants(id);return {items,total_count:items.length,accepted_count:items.filter(x=>x.estado_inscripcion==='aceptada').length,pending_count:items.filter(x=>x.estado_inscripcion==='pendiente').length,has_more:false,next_cursor:null};
      }
    },
    fights:(id)=>backend.globalReadRpc('app_kombax_evento_resultados_v164',{p_evento_id:id}),
    media:async(id)=>enrichMediaPresentations('event_media',await backend.publicRpc('app_kombax_evento_media_v175',{p_evento_id:id,p_workspace_club_id:session()?.club_id||null})),
    async mediaQuota(id){
      try{const rows=await backend.globalReadRpc('app_kombax_evento_media_cuota_v253',{p_evento_id:id,p_workspace_club_id:session()?.club_id||null});return Array.isArray(rows)?rows[0]||null:rows;}
      catch(error){if(!isMissingRpc(error,'app_kombax_evento_media_cuota_v253'))throw error;const rows=await backend.globalReadRpc('app_kombax_evento_media_cuota_v175',{p_evento_id:id,p_workspace_club_id:session()?.club_id||null});return Array.isArray(rows)?rows[0]||null:rows;}
    },
    mediaUrl:(media_id,variant='asset')=>eventMediaAccessUrl(media_id,variant),
    history:(social_profile_id,limit=60)=>backend.publicRpc('app_kombax_evento_historial_competidor_v166',{p_social_profile_id:social_profile_id,p_limit:Math.min(100,Math.max(1,Number(limit)||60))}),
    visibility:(id)=>backend.globalReadRpc('app_kombax_event_visibility_v236',{p_evento_id:id}),
    setVisibility:(id,payload)=>backend.globalWriteRpc('app_kombax_event_visibility_mutate_v236',{p_evento_id:id,p_payload:payload}),
    organizerContexts:()=>session()?.club_id?backend.globalReadRpc('app_kombax_eventos_organizador_contexto_v171',{p_club_id:session().club_id}):backend.globalReadRpc('app_kombax_eventos_mis_organizadores_v160',{}),
    myManagedEvents:(limit=100)=>backend.globalReadRpc('app_kombax_event_center_list_r69',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    community:(event_id,limit=100)=>backend.publicRpc('app_kombax_event_community_r73',{p_event_id:event_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    communityManage:(event_id,limit=150)=>backend.globalReadRpc('app_kombax_event_community_manage_r73',{p_event_id:event_id,p_limit:Math.min(200,Math.max(1,Number(limit)||150))}),
    comment:(event_id,body,parent_id=null,media=[],kind='comment')=>backend.globalWriteRpc('app_kombax_event_comment_upsert_r73',{p_event_id:event_id,p_body:String(body||''),p_parent_id:parent_id||null,p_media:Array.isArray(media)?media:[],p_kind:String(kind||'comment')}),
    reactionSet:(event_id,reaction='like')=>backend.globalWriteRpc('app_kombax_event_reaction_set_r73',{p_event_id:event_id,p_reaction:String(reaction||'like')}),
    commentWithdraw:(comment_id)=>backend.globalWriteRpc('app_kombax_event_comment_withdraw_r72',{p_comment_id:comment_id}),
    reviewUpsert:(event_id,rating,body='',media=[])=>backend.globalWriteRpc('app_kombax_event_review_upsert_r72',{p_event_id:event_id,p_rating:Number(rating),p_body:String(body||''),p_media:Array.isArray(media)?media:[]}),
    reviewWithdraw:(review_id)=>backend.globalWriteRpc('app_kombax_event_review_withdraw_r72',{p_review_id:review_id}),
    reviewRespond:(review_id,response='')=>backend.globalWriteRpc('app_kombax_event_review_respond_r72',{p_review_id:review_id,p_response:String(response||'')}),
    uploadCommunityMedia:(event_id,file)=>uploadReputationMedia('events',event_id,file,{allowVideo:true}),
    removeCommunityMedia:(items)=>removeOwnedReputationMedia(items),
    reputationReport:(target_type,target_id,reason,detail='')=>backend.globalWriteRpc('app_kombax_reputation_report_r72',{p_target_type:target_type,p_target_id:target_id,p_reason:String(reason||''),p_detail:String(detail||'')}),
    invitations:()=>session()?.club_id?backend.globalReadRpc('app_kombax_eventos_invitaciones_contexto_v172',{p_club_id:session().club_id}):backend.globalReadRpc('app_kombax_eventos_invitaciones_v160',{}),
    ticketingPublic:(event_ids=[])=>backend.publicRpc('app_kombax_event_ticketing_public_r625',{p_event_ids:event_ids}),
    ticketingManageStatus:(event_id)=>backend.globalReadRpc('app_kombax_event_ticketing_manage_status_r6253',{p_event_id:event_id}),
    ticketingSave:(event_id,payload={})=>backend.globalWriteRpc('app_kombax_event_ticketing_mutate_r6253',{p_event_id:event_id,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    ticketingServiceRequest:(event_id)=>backend.globalWriteRpc('app_kombax_event_ticketing_service_request_r628',{p_event_id:event_id,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    ticketingContractAccept:(event_id,policy_code,policy_version)=>backend.globalWriteRpc('app_kombax_event_contract_accept_r628',{p_event_id:event_id,p_policy_code:policy_code,p_policy_version:policy_version,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    myTickets:(limit=100)=>backend.globalReadRpc('app_kombax_my_event_tickets_r6253',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    ticketSales:(event_id,limit=200)=>backend.globalReadRpc('app_kombax_event_ticket_sales_r65',{p_event_id:event_id,p_limit:Math.min(500,Math.max(1,Number(limit)||200))}),
    ticketDashboard:(event_id)=>backend.globalReadRpc('app_kombax_event_ticket_dashboard_r6252',{p_event_id:event_id}),
    finance:(event_id)=>backend.globalReadRpc('app_kombax_event_finance_r65',{p_event_id:event_id}),
    communications:(event_id,limit=100)=>backend.globalReadRpc('app_kombax_commerce_communications_r65',{p_scope:'event',p_subject_id:event_id,p_limit:limit}),
    attendeeMessage:(event_id,subject,message)=>backend.globalWriteRpc('app_kombax_event_attendee_message_r65',{p_event_id:event_id,p_subject:subject,p_message:message,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    businessIntelligence:(event_id,days=30)=>backend.globalReadRpc('app_kombax_event_bi_r65',{p_event_id:event_id,p_days:days}),
    analytics:(event_id,days=30)=>backend.globalReadRpc('app_kombax_event_analytics_r77',{p_event_id:event_id,p_days:Math.min(365,Math.max(1,Number(days)||30))}),
    analyticsRange:(event_id,from,to)=>backend.globalReadRpc('app_kombax_event_analytics_range_r77',{p_event_id:event_id,p_from:from,p_to:to}),
    reportPayload:(event_id,report_type='results',days=30)=>backend.globalReadRpc('app_kombax_report_payload_r77',{p_scope:'event',p_subject_id:event_id,p_report_type:report_type,p_days:Math.min(365,Math.max(1,Number(days)||30))}),
    report:(event_id,report_type='general',period=30)=>{const range=period&&typeof period==='object'?period:null;return backend.invokeFunction('kombax-report-r77',{scope:'event',subject_id:event_id,report_type,...(range?.from&&range?.to?{from:range.from,to:range.to,days:range.days||30}:{days:Math.min(365,Math.max(1,Number(period)||30))}),user_locale:getLocale()},60000)},
    checkinHistory:(event_id,limit=200)=>backend.globalReadRpc('app_kombax_event_checkin_history_r65',{p_event_id:event_id,p_limit:limit}),
    track:(event_type,event_id,source=null,metadata={})=>backend.globalWriteRpc('app_kombax_commerce_track_r65',{p_event_type:event_type,p_provider_id:null,p_product_id:null,p_event_id:event_id,p_order_id:null,p_source:source,p_amount_minor:null,p_metadata:metadata}),
    ticketAccessStatus:(event_id)=>backend.globalReadRpc('app_kombax_event_ticket_access_status_r6252',{p_event_id:event_id}),
    ticketCheckin:(event_id,code)=>backend.globalWriteRpc('app_kombax_event_ticket_checkin_r6252',{p_event_id:event_id,p_code:String(code||'').trim()}),
    ticketStaff:(event_id)=>backend.globalReadRpc('app_kombax_event_ticket_staff_r6252',{p_event_id:event_id}),
    ticketStaffMutate:(event_id,email,role_code,active=true)=>backend.globalWriteRpc('app_kombax_event_ticket_staff_mutate_r6252',{p_event_id:event_id,p_email:String(email||'').trim(),p_role_code:role_code,p_active:active===true}),
    ticketUse:(ticket_id)=>backend.globalWriteRpc('app_kombax_event_ticket_mutate_r625',{p_operation:'event.ticket.use',p_payload:{ticket_id},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    async uploadVisual(evento_id,kind,file){
      if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
      if(!evento_id)throw new Error('Guarda primero el evento.');
      if(!['cartel','banner'].includes(kind))throw new Error('Tipo visual no válido.');
      if(!file?.size)throw new Error('Selecciona una imagen.');
      if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');
      const prepared=await optimizeImage(file,{maxEdge:kind==='banner'?2560:2200,maxBytes:6*1024*1024});
      const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
      const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${session().id}/events/${evento_id}/${kind}-${Date.now()}-${token}.${ext}`;
      await backend.upload('kombax-public-media',path,prepared.file,false);
      return {path,url:backend.publicUrl('kombax-public-media',path),width:prepared.width||null,height:prepared.height||null};
    },
    async uploadParticipantPhoto(evento_id,file){
      if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
      if(!evento_id)throw new Error('Evento no disponible.');
      if(!file?.size)throw new Error('Selecciona una imagen.');
      if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');
      const prepared=await optimizeImage(file,{maxEdge:1600,maxBytes:4*1024*1024});
      const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
      const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${session().id}/events/${evento_id}/fighters/${Date.now()}-${token}.${ext}`;
      await backend.upload('kombax-public-media',path,prepared.file,false);
      return {path,url:backend.publicUrl('kombax-public-media',path),width:prepared.width||null,height:prepared.height||null};
    },
    save:(payload)=>kombaxEventsMutation('event.save',payload),
    addEntity:(payload)=>kombaxEventsMutation('event.entity.add',payload),
    removeEntity:(entity_id)=>kombaxEventsMutation('event.entity.remove',{entity_id}),
    respondInvitation:(entity_id,aceptar)=>kombaxEventsMutation('event.entity.respond',{entity_id,aceptar:aceptar===true}),
    submitParticipant:(payload)=>kombaxEventsMutation('event.participant.submit',payload),
    setParticipantStatus:(participant_id,estado)=>kombaxEventsMutation('event.participant.status',{participant_id,estado}),
    updateParticipant:(payload)=>kombaxEventsMutation('event.participant.update',payload),
    withdrawParticipant:(participant_id)=>kombaxEventsMutation('event.participant.withdraw',{participant_id}),
    saveFight:(payload)=>kombaxEventsMutation('event.fight.save',payload),
    removeFight:(fight_id)=>kombaxEventsMutation('event.fight.remove',{fight_id}),
    setFightResult:(payload)=>kombaxEventsMutation('event.fight.result.set',payload),
    setInterest:(evento_id,estado='interesado',notificaciones=true)=>kombaxEventsMutation('event.interest.set',{evento_id,estado,notificaciones:notificaciones===true}),
    linkSocial:(payload)=>kombaxEventsMutation('event.social.link',payload),
    async uploadMedia(evento_id,file,{tipo='',combate_id=null,competidor_social_profile_id=null,titulo='',descripcion='',destacado=false,allow_download=false,orden=0,estado='visible',momento='evento',onProgress=null}={}){
      if(!file?.size)throw new Error('Selecciona una foto o vídeo.');
      const isVideo=String(file.type||'').startsWith('video/');
      const allowed=isVideo?['video/mp4','video/webm','video/quicktime']:['image/jpeg','image/png','image/webp'];
      if(!allowed.includes(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP, MP4, WEBM o MOV.');
      if(file.size>(isVideo?100:10)*1024*1024)throw new Error(isVideo?'El vídeo supera 100 MB.':'La imagen supera 10 MB.');
      onProgress?.({stage:'prepare',uploaded:0,total:Number(file.size||0),percent:0});
      const prepared=isVideo?await prepareVideo(file,{maxBytes:100*1024*1024,maxDuration:60.2,maxLongEdge:1920,maxShortEdge:1080}):await optimizeImage(file,{maxEdge:2560,maxBytes:8*1024*1024});
      const mediaId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const ext=(prepared.file.name?.split('.').pop()||file.name?.split('.').pop()||(isVideo?'mp4':'jpg')).replace(/[^a-z0-9]/gi,'').toLowerCase();
      const path=`${evento_id}/${mediaId}/${Date.now()}-asset.${ext}`;
      const total=Number(prepared.file.size||0);
      const report=(uploaded,totalBytes=total)=>onProgress?.({stage:'upload',uploaded:Number(uploaded||0),total:Number(totalBytes||total),percent:totalBytes?Math.min(100,Math.max(0,Math.round(Number(uploaded||0)/Number(totalBytes)*100))):0});
      if(isVideo||total>6*1024*1024)await backend.uploadResumable('kombax-events-media',path,prepared.file,{upsert:false,onProgress:report});
      else{await backend.upload('kombax-events-media',path,prepared.file,false);report(total,total);}
      try{
        onProgress?.({stage:'register',uploaded:total,total,percent:100});
        const data=await kombaxEventsMutation('event.media.register',{media_id:mediaId,evento_id,tipo:tipo||(isVideo?'clip':'foto'),combate_id,competidor_social_profile_id,storage_path:path,mime_type:prepared.mime||prepared.file.type||file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:isVideo?prepared.duration:null,momento,titulo,descripcion,destacado:destacado===true,allow_download:allow_download===true,orden:Number(orden)||0,estado});
        let mediaPresentation=data?.media_presentation||{};let coverStatus='not_applicable',thumbStatus='not_applicable';
        if(isVideo){
          coverStatus=repos.mediaFraming.coverPath(mediaPresentation)?'ready':'pending';
          if(prepared.cover){
            onProgress?.({stage:'cover',uploaded:total,total,percent:100});
            const cover=await storeEventVideoCoverWithRetry(evento_id,mediaId,prepared.cover,{presentation:mediaPresentation,mode:'auto',time:prepared.coverTime||0,attempts:3});
            mediaPresentation=cover.presentation||mediaPresentation;coverStatus=cover.status||coverStatus;
          }
        }else{
          try{
            onProgress?.({stage:'thumbnail',uploaded:total,total,percent:100});
            const thumb=await storeEventMediaThumbnail(evento_id,mediaId,prepared.file,mediaPresentation);mediaPresentation=thumb.presentation||mediaPresentation;thumbStatus='ready';
          }catch(error){
            thumbStatus='pending';mediaPresentation={...mediaPresentation,thumb_status:'pending',thumb_last_error_at:new Date().toISOString()};await setMediaPresentation('event_media',mediaId,mediaPresentation).catch(()=>{});
          }
        }
        invalidateEventMediaUrl(mediaId);
        onProgress?.({stage:'done',uploaded:total,total,percent:100,cover_status:coverStatus,thumb_status:thumbStatus});
        return {...data,media_presentation:mediaPresentation,cover_status:coverStatus,thumb_status:thumbStatus};
      }catch(error){await backend.remove('kombax-events-media',path).catch(()=>{});invalidateEventMediaUrl(mediaId);throw error;}
    },
    registerExternalVideo:(evento_id,external_url,{combate_id=null,competidor_social_profile_id=null,titulo='',descripcion='',destacado=false,orden=0,estado='visible',momento='evento'}={})=>kombaxEventsMutation('event.media.register',{media_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`,evento_id,tipo:'video_externo',combate_id,competidor_social_profile_id,external_url,momento,titulo,descripcion,destacado:destacado===true,allow_download:false,orden:Number(orden)||0,estado}),
    addMediaReference:(evento_id,{source_kind,source_id=null,titulo='',momento='evento'}={})=>kombaxEventsMutation('event.media.reference.add',{evento_id,source_kind,source_id,titulo,momento}),
    updateMedia:(payload)=>kombaxEventsMutation('event.media.update',payload),
    async setVideoCover(evento_id,media,file,{presentation={},mode='upload',time=0}={}){const out=await storeEventVideoCoverWithRetry(evento_id,media.id,file,{presentation,mode,time,attempts:3});if(out.status!=='ready')throw out.error||new Error('La portada quedó pendiente de regeneración.');return out;},
    async uploadDemoMedia(evento_id,file,{media_id,titulo='',descripcion='',destacado=false,orden=0,momento='evento'}={}){
      if(!state.session?.platform_admin)throw new Error('PLATFORM_OWNER_REQUIRED');
      if(!media_id||!file?.size)throw new Error('DEMO_MEDIA_INVALID');
      const prepared=await optimizeImage(file,{maxEdge:2560,maxBytes:8*1024*1024});
      const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
      const path=`${evento_id}/${media_id}/demo-${String(titulo||'asset').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||'asset'}.${ext}`;
      await backend.remove('kombax-events-media',path).catch(()=>{});
      await backend.upload('kombax-events-media',path,prepared.file,false);
      try{
        return await backend.globalWriteRpc('app_kombax_eventos_mutate_v175',{p_operation:'event.media.register',p_payload:{media_id,evento_id,tipo:'foto',storage_path:path,mime_type:prepared.mime||prepared.file.type||file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,momento,titulo,descripcion,destacado:destacado===true,allow_download:false,orden:Number(orden)||0,estado:'visible'},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`});
      }catch(error){await backend.remove('kombax-events-media',path).catch(()=>{});throw error;}
    },
    demoAssetFile:(path,options={})=>backend.localAssetFile(path,options),
    seedDemoEvent:()=>rpcWithFallback(()=>backend.globalWriteRpc('app_kombax_demo_event_seed_v178',{}),()=>backend.globalWriteRpc('app_kombax_demo_event_seed_v177',{}),'app_kombax_demo_event_seed_v178'),
    seedUrbanWarriorsJiuJitsuDemoEvent:()=>backend.globalWriteRpc('app_kombax_demo_urban_warriors_jiujitsu_seed_v180',{}),
    cleanupDemoEvent:()=>backend.globalWriteRpc('app_kombax_demo_event_cleanup_v177',{}),
    cleanupUrbanWarriorsJiuJitsuDemoEvent:()=>backend.globalWriteRpc('app_kombax_demo_urban_warriors_jiujitsu_cleanup_v180',{}),
    async removeMedia(media){const out=await kombaxEventsMutation('event.media.remove',{media_id:media.id});if(media?.storage_path)await backend.remove('kombax-events-media',media.storage_path).catch(()=>{});await Promise.all([removeMediaCover(media?.media_presentation,'kombax-events-media'),removeMediaThumbnail(media?.media_presentation,'kombax-events-media')]);invalidateEventMediaUrl(media?.id);return out;}
  },
  events:{
    list:(limit=100)=>read('eventos_competicion',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.asc,id.desc&limit=${Math.min(300,Math.max(20,Number(limit)||100))}`),
    listPage:({state='activo',offset=0,limit=10}={})=>read('eventos_competicion',`select=*&${filterClub()}&ciclo_estado=eq.${enc(state)}&order=fecha.desc,hora_inicio.asc,id.desc&offset=${Math.max(0,Number(offset)||0)}&limit=${Math.min(51,Math.max(1,Number(limit)||10)+1)}`),
    listState:(state='activo',limit=10)=>read('eventos_competicion',`select=*&${filterClub()}&ciclo_estado=eq.${enc(state)}&order=fecha.desc,hora_inicio.asc,id.desc&limit=${Math.min(300,Math.max(10,Number(limit)||10))}`),
    communications:(evento_id,{limit=10,offset=0}={})=>backend.readRpc('app_evento_comunicaciones_r89',{p_evento_id:evento_id,p_limit:Math.min(50,Math.max(1,Number(limit)||10)),p_offset:Math.max(0,Number(offset)||0)}),
    linkCommunication:(evento_id,comunicacion_id)=>backend.writeRpc('app_evento_comunicacion_vincular_r89',{p_evento_id:evento_id,p_comunicacion_id:comunicacion_id}),
    participants:(evento_id)=>backend.readRpc('app_evento_participantes_visibles_v033',{p_club_id:session()?.club_id,p_evento_id:evento_id}),
    fights:(evento_id)=>backend.readRpc('app_evento_combates_visibles_v033',{p_club_id:session()?.club_id,p_evento_id:evento_id}),
    save:(p)=>mutation('evento.guardar',{id:p.id||null,disciplina_id:p.disciplina_id||null,nombre:p.nombre,descripcion:p.descripcion||'',fecha:p.fecha,hora_inicio:p.hora_inicio||null,hora_fin:p.hora_fin||null,lugar:p.lugar||'',organizador:p.organizador||'',fecha_limite_inscripcion:p.fecha_limite_inscripcion||null,estado:p.estado||'borrador',edad_min:p.edad_min===''||p.edad_min==null?null:Number(p.edad_min),edad_max:p.edad_max===''||p.edad_max==null?null:Number(p.edad_max),peso_min:p.peso_min===''||p.peso_min==null?null:Number(p.peso_min),peso_max:p.peso_max===''||p.peso_max==null?null:Number(p.peso_max),categoria_texto:p.categoria_texto||'',grado_minimo_texto:p.grado_minimo_texto||'',documentacion_requerida:p.documentacion_requerida||'',autorizacion_requerida:p.autorizacion_requerida===true,cuota_inscripcion:p.cuota_inscripcion===''||p.cuota_inscripcion==null?null:Number(p.cuota_inscripcion),observaciones_requisitos:p.observaciones_requisitos||''}),
    setStatus:(evento_id,estado)=>mutation('evento.estado',{evento_id,estado}),
    saveExternal:(p)=>mutation('evento.participante.externo',{id:p.id||null,evento_id:p.evento_id,nombre:p.nombre,apellidos:p.apellidos||'',club_origen:p.club_origen||'',disciplina_texto:p.disciplina_texto||'',categoria_texto:p.categoria_texto||'',peso:p.peso===''||p.peso==null?null:Number(p.peso),grado_texto:p.grado_texto||'',edad:p.edad===''||p.edad==null?null:Number(p.edad),observaciones:p.observaciones||''}),
    requestRegistration:(p)=>mutation('evento.inscripcion.solicitar',{evento_id:p.evento_id,socio_id:p.socio_id,disciplina_texto:p.disciplina_texto||'',categoria_texto:p.categoria_texto||'',peso:p.peso===''||p.peso==null?null:Number(p.peso),grado_texto:p.grado_texto||'',observaciones:p.observaciones||''}),
    setRegistrationStatus:(participante_id,estado,observaciones='')=>mutation('evento.inscripcion.estado',{participante_id,estado,observaciones}),
    withdraw:(participante_id,observaciones='')=>mutation('evento.inscripcion.baja',{participante_id,observaciones}),
    saveFight:(p)=>mutation('evento.combate.guardar',{id:p.id||null,evento_id:p.evento_id,participante_a_id:p.participante_a_id,participante_b_id:p.participante_b_id,disciplina_texto:p.disciplina_texto||'',categoria_texto:p.categoria_texto||'',tatami_ring:p.tatami_ring||'',orden:p.orden===''||p.orden==null?null:Number(p.orden),hora_aprox:p.hora_aprox||null,estado:p.estado||'pendiente',resultado:p.resultado||'',ganador_participante_id:p.ganador_participante_id||null,observaciones:p.observaciones||''}),
    deleteFight:(combate_id)=>mutation('evento.combate.eliminar',{combate_id})
  },
  community:{
    async listPage(cursor=null,limit=20){
      const posts=await read('publicaciones_comunidad',`select=*&${filterClub()}&ciclo_estado=eq.activo${cursor?.created&&cursor?.id?`&or=(creado_en.lt.${enc(cursor.created)},and(creado_en.eq.${enc(cursor.created)},id.lt.${enc(cursor.id)}))`:''}&order=creado_en.desc,id.desc&limit=${Math.min(20,Math.max(1,Number(limit)||20))}`);
      if(!posts?.length||!session()?.id)return posts||[];
      const ids=posts.map(p=>p.id).filter(Boolean);if(!ids.length)return posts;
      const mine=await read('comunidad_likes',`select=publicacion_id&${filterClub()}&perfil_id=eq.${enc(session().id)}&publicacion_id=in.(${ids.map(enc).join(',')})&limit=${ids.length}`).catch(()=>[]);
      const liked=new Set((mine||[]).map(x=>x.publicacion_id));
      return posts.map(p=>({...p,likedByMe:liked.has(p.id)}));
    },
    async quota(){const rows=await read('publicaciones_comunidad',`select=id,autor_perfil_id,creado_en&${filterClub()}&ciclo_estado=eq.activo&autor_perfil_id=eq.${enc(session()?.id)}&creado_en=gte.${enc(new Date(new Date().getFullYear(),new Date().getMonth(),1).toISOString())}&limit=20`);const staff=['direccion','coordinacion','secretaria','comunicacion'].includes(session()?.rol);return {used:rows.length,limit:staff?5:3};},
    async upload(file){if(!file||!file.size)throw new Error('Selecciona una imagen o vídeo.');const isVideo=String(file.type||'').startsWith('video/');const allowedImage=['image/jpeg','image/png','image/webp'];const allowedVideo=['video/mp4','video/webm','video/quicktime'];if(!(isVideo?allowedVideo:allowedImage).includes(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP, MP4, WEBM o MOV.');if(file.size>(isVideo?50:5)*1024*1024)throw new Error(isVideo?'El vídeo supera 50 MB.':'La imagen supera 5 MB.');const ext=(file.name.split('.').pop()|| (isVideo?'mp4':'jpg')).replace(/[^a-z0-9]/gi,'').toLowerCase();const path=`${session().club_id}/${session().id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;await backend.upload('community-media',path,file,false);return path;},
    mediaUrl:(path)=>String(path||'').startsWith('demo-static:')?Promise.resolve('./'+String(path).slice('demo-static:'.length).replace(/^\.?\//,'')):backend.signedUrl('community-media',path,3600),
    publish:(p)=>mutation('comunidad.publicar',{texto:p.texto||'',media_path:p.media_path,media_tipo:p.media_tipo,duracion_segundos:p.duracion_segundos||null,media_mime:p.media_mime||null,media_width:p.media_width||null,media_height:p.media_height||null,media_size_bytes:p.media_size_bytes||null,portada_automatica_path:p.portada_automatica_path||null,portada_manual_path:p.portada_manual_path||null}),
    async delete(publicacion_id){const out=await mutation('comunidad.eliminar',{publicacion_id});for(const path of [...new Set([out?.media_path,out?.portada_automatica_path,out?.portada_manual_path].filter(Boolean))])await backend.remove('community-media',path).catch(()=>{});return out;},
    moderate:(publicacion_id,oculta=true,motivo='')=>mutation('comunidad.moderar',{publicacion_id,oculta,motivo}),
    changeCover:(publicacion_id,portada_manual_path)=>mutation('comunidad.moderar',{publicacion_id,accion:'portada',portada_manual_path}),
    like:(publicacion_id,activo)=>mutation('comunidad.like',{publicacion_id,activo:activo===true}),
    blocked:()=>backend.readRpc('app_comunidad_bloqueados_v036',{p_club_id:session()?.club_id}),
    block:(perfil_id,bloquear=true)=>mutation('comunidad.bloquear',{perfil_id,bloquear:bloquear===true}),
    report:(objetivo_tipo,objetivo_id,motivo,detalle='',ambito='club')=>mutation('comunidad.denunciar',{objetivo_tipo,objetivo_id,motivo,detalle,ambito}),
    reports:()=>backend.readRpc('app_comunidad_reportes_v036',{p_club_id:session()?.club_id}),
    reportStatus:(reporte_id,estado,{resolucion='',ocultar_publicacion=false}={})=>mutation('comunidad.denuncia.estado',{reporte_id,estado,resolucion,ocultar_publicacion:ocultar_publicacion===true}),
    removePath:(path)=>path?backend.remove('community-media',path):Promise.resolve()
  },
  kombaxProfiles:{
    mine:()=>backend.globalReadRpc('app_kombax_mis_perfiles_v196',{}),
    taxonomy:()=>backend.publicRpc('app_kombax_profile_taxonomy_v196',{}),
    capabilities:(profileId)=>backend.globalReadRpc('app_kombax_profile_capabilities_v196',{p_perfil_directo_id:profileId}),
    workspace:(profileId)=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_managed_profile_hub_v200',{p_perfil_directo_id:profileId}),()=>backend.globalReadRpc('app_kombax_managed_profile_hub_v197',{p_perfil_directo_id:profileId}),'app_kombax_managed_profile_hub_v200'),
    professionalWorkspace:(profileId)=>rpcWithFallback(
      ()=>backend.globalReadRpc('app_kombax_professional_workspace_r118',{p_profile_id:profileId}),
      ()=>backend.globalReadRpc('app_kombax_professional_workspace_v198',{p_profile_id:profileId}),
      'app_kombax_professional_workspace_r118'
    ),
    professionalMutate:(operation,payload={})=>kombaxGlobalMutation('app_kombax_professional_mutate_v198',operation,payload),
    professionalCredentialMutate:(operation,payload={})=>kombaxGlobalMutation('app_kombax_professional_credential_mutate_r118',operation,payload),
    professionalPublicCredentials:(profileId)=>backend.globalReadRpc('app_kombax_professional_public_credentials_r118',{p_profile_id:profileId}),
    async uploadProfessionalCredentialEvidence(profileId,credentialId,file){
      if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
      if(!profileId||!credentialId)throw new Error('Credencial profesional no disponible.');
      if(!file?.size)throw new Error('Selecciona un documento de acreditación.');
      const allowed=new Set(['application/pdf','image/jpeg','image/png','image/webp']);
      if(!allowed.has(file.type))throw new Error('Formato no admitido. Usa PDF, JPG, PNG o WEBP.');
      if(file.size>15*1024*1024)throw new Error('El documento supera 15 MB.');
      const ext=file.type==='application/pdf'?'pdf':file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg';
      const uid=String(session().id),token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${uid}/professional-credential/${credentialId}/${Date.now()}-${token}.${ext}`;
      await backend.upload('kombax-verification-docs',path,file,false);
      try{
        const out=await kombaxGlobalMutation('app_kombax_professional_credential_mutate_r118','professional.credential.evidence.register',{
          professional_profile_id:profileId,credential_id:credentialId,storage_path:path,mime_type:file.type,size_bytes:file.size
        });
        return {...out,storage_path:path};
      }catch(error){
        await backend.remove('kombax-verification-docs',path).catch(()=>{});
        throw error;
      }
    },
    professionalFinance:(profileId)=>backend.globalReadRpc('app_kombax_professional_finance_v199',{p_profile_id:profileId}),
    professionalFinanceNotifications:(profileId)=>backend.globalReadRpc('app_kombax_professional_finance_notifications_v199',{p_profile_id:profileId}),
    professionalFinanceMutate:(operation,payload={})=>kombaxGlobalMutation('app_kombax_professional_finance_mutate_v199',operation,payload),
    clubs:()=>backend.globalReadRpc('app_kombax_mis_clubes_v097',{}),
    applications:()=>backend.globalReadRpc('app_kombax_mis_solicitudes_v072',{}),
    album:async(profileId)=>enrichMediaPresentations('profile_media',await backend.globalReadRpc('app_kombax_album_v072',{p_perfil_directo_id:profileId})),
    saveProfile:(payload)=>kombaxProfileMutationR58('kombax.profile.save',payload),
    saveApplication:(payload)=>kombaxProfileMutationR58('kombax.application.save',payload),
    submitApplication:(solicitud_id)=>kombaxProfileMutationR58('kombax.application.submit',{solicitud_id}),
    withdrawApplication:(solicitud_id)=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.withdraw',{solicitud_id}),
    managers:(profileId)=>backend.globalReadRpc('app_kombax_profile_managers_v070',{p_perfil_directo_id:profileId}),
    setManager:(profileId,perfilId,rol='editor',estado='activo')=>kombaxGlobalMutation('app_kombax_profile_manager_mutate_v070','kombax.profile.manager.set',{perfil_directo_id:profileId,perfil_id:perfilId,rol,estado}),
    uploadMedia:uploadKombaxProfileMedia,
    setVideoCover:(profileId,media,file,{presentation={},mode='upload',time=0}={})=>storeMediaCover('profile_media',media.id,file,{bucket:'kombax-public-media',pathPrefix:`${session()?.id}/${profileId}/${media.id}`,presentation,mode,time}),
    removeMedia:async(media)=>{const out=await kombaxGlobalMutation('app_kombax_media_mutate_v072','kombax.media.remove',{media_id:media.id});if(out?.storage_path)await backend.remove('kombax-public-media',out.storage_path).catch(()=>{});await removeMediaCover(media?.media_presentation,'kombax-public-media');return out;},
    uploadVerificationDocument:uploadKombaxVerificationDocument
  },
  kombaxMemberships:{
    active:()=>backend.globalReadRpc('app_kombax_mis_membresias_r58',{}),
    pending:()=>backend.globalReadRpc('app_kombax_membresias_pendientes_r58',{}),
    requestClaim:(socio_id)=>backend.globalWriteRpc('app_kombax_membresia_solicitar_r58',{p_socio_id:socio_id}),
    contactClub:(club_id,mensaje,request_kind='member',target_socio_id=null)=>backend.globalWriteRpc('app_kombax_club_link_request_r117',{p_club_id:club_id,p_request_kind:request_kind,p_mensaje:String(mensaje||'').trim(),p_target_socio_id:target_socio_id||null}),
    resolveClubLink:(thread_id,approve=true,socio_id=null)=>backend.globalWriteRpc('app_kombax_club_link_resolve_r117',{p_thread_id:thread_id,p_approve:approve===true,p_socio_id:socio_id||null})
  },
  federationLicenses:{
    federationContext:(profileId)=>backend.globalReadRpc('app_kombax_federation_context_v200',{p_federation_profile_id:profileId}),
    clubContext:(clubId)=>backend.globalReadRpc('app_kombax_club_federation_context_v200',{p_club_id:clubId}),
    self:(profileId=null)=>backend.globalReadRpc('app_kombax_self_licenses_v200',{p_direct_profile_id:profileId||null}),
    professional:(profileId)=>backend.globalReadRpc('app_kombax_professional_authorized_licenses_v200',{p_professional_profile_id:profileId}),
    directory:(query='',limit=100)=>backend.globalReadRpc('app_kombax_federation_directory_v200',{p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    pendingInvitations:()=>backend.globalReadRpc('app_kombax_federation_team_pending_invitations_v200',{}),
    documents:(licenseId)=>backend.globalReadRpc('app_kombax_federation_license_documents_v200',{p_license_id:licenseId}),
    saveRelationship:(federationProfileId,clubId,status='active',relationshipLabel='afiliado',privateNote='')=>backend.globalWriteRpc('app_kombax_federation_relationship_save_v200',{p_federation_profile_id:federationProfileId,p_club_id:clubId,p_status:status,p_relationship_label:relationshipLabel,p_private_note:privateNote}),
    mutate:(operation,payload={})=>kombaxGlobalMutation('app_kombax_federation_mutate_v200',operation,payload),
    sendInvitation:(federation_invitation_id)=>backend.invokeFunction('invite-email',{federation_invitation_id,user_locale:getLocale()}),
    async uploadDocument(licenseId,file,{documentType='administrative'}={}){
      if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
      if(!licenseId)throw new Error('Licencia no disponible.');
      if(!file?.size)throw new Error('Selecciona un documento.');
      if(!['application/pdf','image/jpeg','image/png'].includes(file.type))throw new Error('Formato no admitido. Usa PDF, JPG o PNG.');
      if(file.size>10*1024*1024)throw new Error('El documento supera 10 MB.');
      const ext=file.type==='application/pdf'?'pdf':file.type==='image/png'?'png':'jpg';
      const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${session().id}/${licenseId}/${Date.now()}-${token}.${ext}`;
      await backend.upload('federation-license-documents',path,file,false);
      try{return await kombaxGlobalMutation('app_kombax_federation_mutate_v200','federation.document.register',{license_id:licenseId,storage_path:path,file_name:String(file.name||`documento.${ext}`).slice(0,220),mime_type:file.type,size_bytes:file.size,document_type:documentType});}
      catch(error){await backend.remove('federation-license-documents',path).catch(()=>{});throw error;}
    },
    documentUrl:(path)=>backend.signedUrl('federation-license-documents',path,300)
  },
  socialGeneral:{
    status:()=>backend.readRpc('app_kombax_social_estado_v124',{p_club_id:session()?.club_id}),
    activate:({acepta_normas,acepta_privacidad,acepta_seguridad_menor=false})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,acepta_seguridad_menor:acepta_seguridad_menor===true,user_agent:navigator.userAgent}),
    moderateAccess:(perfil_id,estado,motivo)=>mutation('comunidad_general.moderar_acceso',{perfil_id,estado,motivo}),
    async rules(){const rows=await read('textos_legales',`select=id,tipo,version,cuerpo&${filterClub()}&tipo=eq.comunidad_general&vigente=eq.true&order=creado_en.desc&limit=1`);return rows?.[0]||null;}
  },
  kombaxIdentity:{
    status:()=>backend.globalReadRpc('app_kombax_social_estado_v124',{p_club_id:session()?.club_id||null}),
    myProfiles:()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_r117',{p_club_id:session()?.club_id||null}),()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_v051',{p_club_id:session()?.club_id||null}),'app_kombax_social_mis_perfiles_r117'),
    memberPublicProfile:()=>backend.globalReadRpc('app_kombax_member_public_profile_r117',{}),
    team:()=>backend.globalReadRpc('app_kombax_club_team_v051',{p_club_id:session()?.club_id||null}),
    activateMember:({fecha_nacimiento=null,acepta_normas,acepta_privacidad,acepta_seguridad_menor=false})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,fecha_nacimiento:fecha_nacimiento||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,acepta_seguridad_menor:acepta_seguridad_menor===true,user_agent:navigator.userAgent}),
    updateMemberProfile:(payload={})=>kombaxIdentityMutation('kombax.identity.member.profile.update',{club_id:session()?.club_id||null,bio_publica:String(payload.bio_publica||'').trim(),apodo_deportivo:String(payload.apodo_deportivo||'').trim(),disciplinas_publicas:String(payload.disciplinas_publicas||'').trim(),experiencia_anos:payload.experiencia_anos===''||payload.experiencia_anos==null?null:Number(payload.experiencia_anos),guardia:String(payload.guardia||'').trim(),tecnica_favorita:String(payload.tecnica_favorita||'').trim(),especialidad:String(payload.especialidad||'').trim(),trayectoria_declarada:String(payload.trayectoria_declarada||'').trim(),objetivos:String(payload.objetivos||'').trim()}),
    setTeamPermission:(perfil_id,permiso,activo=true)=>kombaxIdentityMutation('kombax.club.permission.set',{club_id:session()?.club_id||null,perfil_id,permiso,activo:activo===true}),
  },
  kombaxSocial:{
    status:()=>backend.globalReadRpc('app_kombax_social_estado_v124',{p_club_id:session()?.club_id||null}),
    myProfiles:()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_r117',{p_club_id:session()?.club_id||null}),()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_v051',{p_club_id:session()?.club_id||null}),'app_kombax_social_mis_perfiles_r117'),
    networkProfiles:()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_social_network_profiles_v255',{p_club_id:session()?.club_id||null}),()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_v051',{p_club_id:session()?.club_id||null}),'app_kombax_social_network_profiles_v255'),
    promotions:async(limit=2)=>{try{return await backend.globalReadRpc('app_kombax_social_promotions_r64',{p_limit:Math.min(2,Math.max(1,Number(limit)||2))});}catch(error){if(!isMissingRpc(error,'app_kombax_social_promotions_r64'))console.warn('Social promotions R64:',error);return [];}},
    promotionImpression:(campaign_id)=>backend.globalWriteRpc('app_kombax_social_promotion_impression_r64',{p_campaign_id:campaign_id,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    feed:async(cursor=null,limit=20)=>{
      const args={p_cursor_score:cursor?.score??null,p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(20,Math.max(1,Number(limit)||20))};
      let rows;
      try{rows=await backend.globalReadRpc('app_kombax_social_feed_v238',args);}catch(error238){if(!isMissingRpc(error238,'app_kombax_social_feed_v238'))throw error238;try{rows=await backend.globalReadRpc('app_kombax_social_feed_v237',args);}catch(error){if(!isMissingRpc(error,'app_kombax_social_feed_v237'))throw error;try{rows=await backend.globalReadRpc('app_kombax_social_feed_v236',args);}catch(error236){if(!isMissingRpc(error236,'app_kombax_social_feed_v236'))throw error236;rows=await backend.globalReadRpc('app_kombax_social_feed_v085',{p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:args.p_limit});}}}
      const ids=(rows||[]).map(x=>x.id).filter(Boolean);if(!ids.length)return rows||[];
      const links=await backend.globalReadRpc('app_kombax_eventos_social_links_v162',{p_publicacion_ids:ids}).catch(()=>[]);
      const map=new Map((links||[]).map(x=>[String(x.publicacion_id),x]));
      // v238 devuelve el multimedia resuelto en `media_id` (social_media o profile_media), no necesariamente en `social_media_id`.
      // Resolver ambas fuentes evita que Android/WebView pierda poster/encuadre aunque el feed venga de una referencia de álbum.
      const resolvedMediaIds=(rows||[]).map(x=>x.social_media_id||x.media_id).filter(Boolean);
      const [socialMediaMap,profileMediaMap]=await Promise.all([
        readMediaPresentations('social_media',resolvedMediaIds),
        readMediaPresentations('profile_media',resolvedMediaIds)
      ]);
      return (rows||[]).map(x=>{
        const resolvedId=String(x.social_media_id||x.media_id||'');
        const isSocialMedia=socialMediaMap.has(resolvedId);
        return {...x,event_link:map.get(String(x.id))||null,social_media_id:x.social_media_id||(isSocialMedia?x.media_id:null),media_presentation:resolveMediaPresentation(x.media_presentation,socialMediaMap.get(resolvedId),profileMediaMap.get(resolvedId))};
      });
    },
    directory:(query='',limit=30)=>backend.globalReadRpc('app_kombax_social_directorio_v072',{p_query:String(query||'').trim(),p_limit:Math.min(50,Math.max(1,Number(limit)||30))}),
    clubDirectory:(query='',limit=100)=>backend.globalReadRpc('app_kombax_club_social_directory_v095',{p_club_id:session()?.club_id||null,p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    // Compatibilidad contractual de regresiones históricas: app_kombax_perfil_publico_v068 · app_kombax_perfil_publico_v072 · app_kombax_social_feed_v065 · app_kombax_social_feed_v072 · app_kombax_social_directorio_v065 · app_kombax_social_comentarios_v053
    publicProfile:async(social_id)=>{
      const profile=await backend.globalReadRpc('app_kombax_perfil_publico_v094',{p_social_id:social_id});
      if(!profile?.id)return profile;
      const type=profile.perfil_tipo||profile.sujeto_tipo;
      const albumScope=type==='club'?'club_media':type==='miembro'?'social_media':'profile_media';
      if(Array.isArray(profile.album))profile.album=await enrichMediaPresentations(albumScope,profile.album);
      if(Array.isArray(profile.showcase))profile.showcase=await enrichMediaPresentations('showcase_item',profile.showcase,'id','imagen_presentacion');
      try{profile.posts=await readSocialProfilePosts(social_id,null,5);}catch{}
      if(type==='miembro'){
        try{
          const media=await enrichMediaPresentations('social_media',await backend.globalReadRpc('app_kombax_social_media_v085',{p_social_id:social_id}));
          const avatar=media.find(x=>x.tipo==='avatar'&&x.estado==='active');
          if(avatar){profile.avatar_media_id=avatar.id;profile.avatar_media_scope='social_media';profile.avatar_media_presentation=avatar.media_presentation||{};}
        }catch{}
      }else if(profile.perfil_directo_id){
        try{
          const media=await enrichMediaPresentations('profile_media',await backend.globalReadRpc('app_kombax_album_v072',{p_perfil_directo_id:profile.perfil_directo_id}));
          const avatar=media.find(x=>x.tipo==='avatar'&&x.estado==='active');
          if(avatar){profile.avatar_media_id=avatar.id;profile.avatar_media_scope='profile_media';profile.avatar_media_presentation=avatar.media_presentation||{};}
        }catch{}
      }
      return profile;
    },
    quota:(social_id)=>backend.globalReadRpc('app_kombax_social_cupo_v099',{p_social_id:social_id}),
    profilePosts:(social_id,cursor=null,limit=10)=>readSocialProfilePosts(social_id,cursor,limit),
    headerActivity:()=>backend.globalReadRpc('app_kombax_header_activity_v106',{}),
    contacts:(limit=50)=>rpcWithFallback(
      ()=>backend.globalReadRpc('app_kombax_contactos_v133',{p_limit:Math.min(200,Math.max(20,Number(limit)||50))}),
      ()=>rpcWithFallback(
        ()=>backend.globalReadRpc('app_kombax_contactos_v107',{}),
        ()=>rpcWithFallback(
          ()=>backend.globalReadRpc('app_kombax_contactos_v106',{}),
          ()=>backend.globalReadRpc('app_kombax_contactos_v104',{}),
          'app_kombax_contactos_v106'
        ),
        'app_kombax_contactos_v107'
      ),
      'app_kombax_contactos_v133'
    ),
    contactMessages:(contacto_id,{before=null,after=null,limit=30}={})=>backend.globalReadRpc('app_kombax_contact_mensajes_v106',{p_contacto_id:contacto_id,p_before_ordinal:before,p_after_ordinal:after,p_limit:Math.min(50,Math.max(1,Number(limit)||30))}),
    markContactRead:async(contacto_id)=>{const out=await backend.globalWriteRpc('app_kombax_contact_mark_read_v106',{p_contacto_id:contacto_id});window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;},
    activate:({acepta_normas,acepta_privacidad,acepta_seguridad_menor=false})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,acepta_seguridad_menor:acepta_seguridad_menor===true,user_agent:navigator.userAgent}),
    activateDirect:(perfil_directo_id,{acepta_normas,acepta_privacidad,acepta_seguridad_menor=false})=>kombaxSocialMutation('kombax.social.direct.activate',{perfil_directo_id,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,acepta_seguridad_menor:acepta_seguridad_menor===true,user_agent:navigator.userAgent}),
    audiences:(autor_perfil_id)=>backend.globalReadRpc('app_kombax_social_audiencias_v083',{p_autor_social_id:autor_perfil_id}),
    publish:(autor_perfil_id,tipo,texto,options={})=>kombaxSocialMutation('kombax.social.publicar',{autor_perfil_id,tipo,texto,comentarios_estado:options.comentarios_estado||'open',social_media_id:options.social_media_id||null,audiencia:options.audiencia||'publica',audiencia_club_id:options.audiencia_club_id||null,audiencia_federacion_social_id:options.audiencia_federacion_social_id||null,audiencia_club_ids:Array.isArray(options.audiencia_club_ids)?options.audiencia_club_ids:[],audiencia_excluded_club_ids:Array.isArray(options.audiencia_excluded_club_ids)?options.audiencia_excluded_club_ids:[],audiencia_profile_ids:Array.isArray(options.audiencia_profile_ids)?options.audiencia_profile_ids:[],audiencia_profile_types:Array.isArray(options.audiencia_profile_types)?options.audiencia_profile_types:[]}),
    media:async(social_id)=>enrichMediaPresentations('social_media',await backend.globalReadRpc('app_kombax_social_media_v085',{p_social_id:social_id})),
    setBannerPosition:(social_id,x=50,y=50)=>backend.globalWriteRpc('app_kombax_social_banner_position_v131',{p_social_id:social_id,p_x:Number(x),p_y:Number(y)}),
    uploadMedia:(social_id,type,file,options={})=>uploadKombaxSocialMedia(social_id,type,file,options),
    syncPrivateAvatar:(social_id,source_path=session()?.avatar_path)=>syncPrivateAvatarToKombaxSocial(social_id,source_path),
    attachAlbumMedia:async(social_profile_id,source_type,source_id,sourcePresentation={})=>{
      const out=await kombaxSocialMutation('kombax.social.media.from_album',{social_profile_id,source_type,source_id});
      const inherited=out?.media_presentation&&typeof out.media_presentation==='object'?out.media_presentation:{};
      const source=sourcePresentation&&typeof sourcePresentation==='object'?sourcePresentation:{};
      if(out?.id&&!Object.keys(inherited).length&&Object.keys(source).length){
        await setMediaPresentation('social_media',out.id,source);
        return {...out,media_presentation:source};
      }
      return out;
    },
    removeMedia:async(media)=>{const out=await kombaxSocialMutation('kombax.social.media.remove',{media_id:media.id});if(out?.storage_path&&String(out.storage_path).startsWith(`${session()?.id}/social/`))await backend.remove(out.storage_bucket||media.storage_bucket||'kombax-public-media',out.storage_path).catch(()=>{});await removeMediaCover(media?.media_presentation,media?.storage_bucket||'kombax-public-media');return out;},
    mediaUrl:(path)=>backend.publicUrl('kombax-public-media',path),
    mediaAccessUrl:(path,bucket='kombax-public-media')=>bucket==='kombax-restricted-media'?backend.signedUrl('kombax-restricted-media',path,600):Promise.resolve(backend.publicUrl('kombax-public-media',path)),
    setVideoCover:(media,file,{presentation={},mode='upload',time=0}={})=>storeMediaCover('social_media',media.id,file,{bucket:media.storage_bucket||'kombax-public-media',pathPrefix:`${session()?.id}/social/${media.social_profile_id||media.autor_id||'media'}/${media.id}`,presentation,mode,time}),
    withdraw:(publicacion_id)=>kombaxSocialMutation('kombax.social.retirar',{publicacion_id}),
    deletePost:async(publicacion_id)=>{const out=await kombaxSocialMutation('kombax.social.eliminar',{publicacion_id});if(out?.storage_path&&String(out.storage_path).startsWith(`${session()?.id}/social/`))await backend.remove(out.storage_bucket||'kombax-public-media',out.storage_path).catch(()=>{});return out;},
    like:(publicacion_id,activo)=>kombaxSocialMutation('kombax.social.like',{publicacion_id,activo:activo===true}),
    // R47 compatibility marker: kombax.social.preferencia is superseded in R49 by a dedicated RPC so it cannot mutate public Likes.
    preference:(publicacion_id,valor=0)=>backend.globalWriteRpc('app_kombax_social_preference_v240',{p_publicacion_id:publicacion_id,p_valor:Number(valor)||0,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    reportOffTopic:(publicacion_id,detalle='')=>backend.globalWriteRpc('app_kombax_social_report_offtopic_v240',{p_publicacion_id:publicacion_id,p_detalle:String(detalle||'').trim()}),
    visibilityConfig:(publicacion_id)=>backend.globalReadRpc('app_kombax_social_visibility_config_v237',{p_post_id:publicacion_id}),
    setVisibility:(publicacion_id,options={})=>kombaxSocialMutation('kombax.social.visibilidad',{publicacion_id,audiencia:options.audiencia||'publica',audiencia_club_id:options.audiencia_club_id||null,audiencia_federacion_social_id:options.audiencia_federacion_social_id||null,audiencia_club_ids:Array.isArray(options.audiencia_club_ids)?options.audiencia_club_ids:[],audiencia_excluded_club_ids:Array.isArray(options.audiencia_excluded_club_ids)?options.audiencia_excluded_club_ids:[],audiencia_profile_ids:Array.isArray(options.audiencia_profile_ids)?options.audiencia_profile_ids:[],audiencia_profile_types:Array.isArray(options.audiencia_profile_types)?options.audiencia_profile_types:[]}),
    block:(perfil_social_id,bloquear=true)=>kombaxSocialMutation('kombax.social.bloquear',{perfil_social_id,bloquear:bloquear===true}),
    contact:(remitente_social_id,destinatario_social_id,motivo,mensaje)=>kombaxSocialNetworkMutation('kombax.contact.request',{remitente_social_id,destinatario_social_id,motivo,mensaje}),
    showcaseContact:(remitente_social_id,elemento_id,mensaje)=>kombaxSocialNetworkMutation('kombax.showcase.contact.request',{remitente_social_id,elemento_id,mensaje}),
    contactStatus:async(contacto_id,estado)=>{const out=await kombaxSocialMutation('kombax.social.contacto.estado',{contacto_id,estado});window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;},
    sendContactMessage:(contacto_id,autor_social_id,texto)=>kombaxSocialNetworkMutation('kombax.contact.message.send',{contacto_id,autor_social_id,texto}),
    closeContact:(contacto_id)=>kombaxSocialNetworkMutation('kombax.contact.close',{contacto_id}),
    deleteContact:(contacto_id,actor_social_id)=>kombaxSocialNetworkMutation('kombax.contact.delete',{contacto_id,actor_social_id}),
    setAffiliationVisibility:(social_profile_id,visible)=>kombaxSocialNetworkMutation('kombax.social.affiliation.visibility',{social_profile_id,visible:visible===true}),
    shareAffiliation:(social_profile_id)=>kombaxSocialNetworkMutation('kombax.social.affiliation.share',{social_profile_id}),
    report:(objetivo_tipo,objetivo_id,motivo,detalle='')=>kombaxSocialMutation('kombax.social.denunciar',{objetivo_tipo,objetivo_id,motivo,detalle}),
    reportMessage:(message_id,motivo,detalle='')=>backend.globalWriteRpc('app_kombax_contact_message_report_v122',{p_message_id:message_id,p_motivo:motivo,p_detalle:detalle}),
    minorConsentStatus:()=>backend.globalReadRpc('app_kombax_social_minor_consent_status_v121',{}),
    requestMinorConsent:()=>{const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;return backend.globalWriteRpc('app_kombax_social_minor_consent_mutate_v121',{p_operation:'kombax.social.minor.consent.request',p_payload:{club_id:session()?.club_id||null},p_request_id:requestId});},
    decideMinorConsent:(consent_id,estado)=>{const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;return backend.globalWriteRpc('app_kombax_social_minor_consent_mutate_v121',{p_operation:'kombax.social.minor.consent.decide',p_payload:{consent_id,estado},p_request_id:requestId});},
    moderationQueue:(limit=100)=>backend.globalReadRpc('app_kombax_moderation_queue_v114',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    moderate:(reporte_id,estado,resolucion='',accion='ninguna')=>kombaxSocialMutation('kombax.social.moderar',{reporte_id,estado,resolucion,accion}),
    moderationDecide:(reporte_id,decision_state,reason_code,reason_text,confidence=null,evidence={})=>backend.globalWriteRpc('app_kombax_moderation_decide_v114',{p_reporte_id:reporte_id,p_decision_state:decision_state,p_reason_code:reason_code,p_reason_text:reason_text,p_confidence:confidence,p_evidence:evidence}),
    save:(publicacion_id,activo=true)=>kombaxSocialMutation('kombax.social.guardar',{publicacion_id,activo:activo===true}),
    comments:(publicacion_id,limit=100)=>backend.globalReadRpc('app_kombax_social_comentarios_v083',{p_publicacion_id:publicacion_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    comment:(publicacion_id,autor_social_id,texto,parent_id=null)=>kombaxSocialMutation('kombax.social.comentar',{publicacion_id,autor_social_id,texto,parent_id}),
    removeComment:(comentario_id,motivo='')=>kombaxSocialMutation('kombax.social.comentario.eliminar',{comentario_id,motivo}),
    saved:(limit=100)=>backend.globalReadRpc('app_kombax_social_guardados_v083',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    relations:(social_id,limit=50)=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_relaciones_v133',{p_social_id:social_id,p_limit:Math.min(150,Math.max(20,Number(limit)||50))}),()=>backend.globalReadRpc('app_kombax_relaciones_v068',{p_social_id:social_id}),'app_kombax_relaciones_v133'),
    requestRelation:async(origen_social_id,destino_social_id,tipo='conexion_kombax',nota='')=>{let out;if(String(tipo||'')==='conexion_kombax'){const args={p_origen_social_id:origen_social_id,p_destino_social_id:destino_social_id,p_nota:nota||null,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`};out=await rpcWithFallback(()=>backend.globalWriteRpc('app_kombax_relation_request_v255',args),()=>backend.globalWriteRpc('app_kombax_relation_request_v247',args),'app_kombax_relation_request_v255');}else{out=await kombaxGlobalMutation('app_kombax_relacion_mutate_v045','kombax.relation.request',{origen_social_id,destino_social_id,tipo,nota,club_id:session()?.club_id||null});}window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;},
    relationState:async(relacion_id,estado)=>{const args={p_relacion_id:relacion_id,p_estado:estado,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`};const out=await rpcWithFallback(()=>backend.globalWriteRpc('app_kombax_relation_state_v255',args),()=>kombaxGlobalMutation('app_kombax_relacion_mutate_v045','kombax.relation.state',{relacion_id,estado,club_id:session()?.club_id||null}),'app_kombax_relation_state_v255');window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;}
  },
  kombaxShowcase:{
    categories:()=>backend.globalReadRpc('app_kombax_showcase_categorias_v042',{}),
    list:async(query='',category='',cursor=null,limit=24)=>enrichShowcaseMedia(await backend.globalReadRpc('app_kombax_showcase_list_v054',{p_query:String(query||'').trim(),p_categoria:category||null,p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(24,Math.max(1,Number(limit)||24))})),
    saved:async(limit=100)=>enrichShowcaseMedia(await backend.globalReadRpc('app_kombax_showcase_guardados_v054',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))})),
    toggleSaved:(elemento_id,activo=true)=>kombaxShowcaseMutation(activo?'kombax.showcase.guardar':'kombax.showcase.desguardar',{elemento_id}),
    myBrands:()=>backend.globalReadRpc('app_kombax_showcase_mis_espacios_v048',{p_club_id:session()?.club_id||null}),
    myItems:async(marca_id,limit=60)=>enrichShowcaseMedia(await rpcWithFallback(()=>backend.globalReadRpc('app_kombax_showcase_mis_elementos_v133',{p_marca_id:marca_id,p_limit:Math.min(200,Math.max(20,Number(limit)||60))}),()=>backend.globalReadRpc('app_kombax_showcase_mis_elementos_v054',{p_marca_id:marca_id}),'app_kombax_showcase_mis_elementos_v133')),
    saveBrand:(payload)=>kombaxShowcaseMutation('kombax.showcase.marca.guardar',payload),
    brandState:(marca_id,estado,verificada=false)=>kombaxShowcaseMutation('kombax.showcase.marca.estado',{marca_id,estado,verificada:verificada===true}),
    saveItem:(payload)=>kombaxShowcaseMutation('kombax.showcase.elemento.guardar',payload),
    uploadImage:(marca_id,file)=>uploadKombaxShowcaseImage(marca_id,file),
    removeUploadedImage:(path)=>path&&String(path).startsWith(`${session()?.id}/showcase/`)?backend.remove('kombax-public-media',path):Promise.resolve(false),
    itemState:(elemento_id,estado,options={})=>kombaxShowcaseMutation('kombax.showcase.elemento.estado',{elemento_id,estado,destacado:options.destacado===true,etiqueta_destacada:options.etiqueta_destacada||''}),
    capacity:(provider_id,reconcile=true)=>backend.globalReadRpc('app_kombax_showcase_capacity_r72',{p_provider_id:provider_id,p_reconcile:reconcile===true}),
    reviews:(product_id,filter='recent',limit=50)=>backend.publicRpc('app_kombax_showcase_reviews_r73',{p_product_id:product_id,p_filter:filter,p_limit:Math.min(100,Math.max(1,Number(limit)||50))}),
    reviewUpsert:(product_id,rating,body='',media=[])=>backend.globalWriteRpc('app_kombax_showcase_review_upsert_r72',{p_product_id:product_id,p_rating:Number(rating),p_body:String(body||''),p_media:Array.isArray(media)?media:[]}),
    reviewWithdraw:(review_id)=>backend.globalWriteRpc('app_kombax_showcase_review_withdraw_r72',{p_review_id:review_id}),
    reviewRespond:(review_id,response='')=>backend.globalWriteRpc('app_kombax_showcase_review_respond_r72',{p_review_id:review_id,p_response:String(response||'')}),
    sellerReviews:(provider_id,limit=100)=>backend.globalReadRpc('app_kombax_showcase_seller_reviews_r73',{p_provider_id:provider_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    uploadReviewMedia:(product_id,file)=>uploadReputationMedia('showcase',product_id,file,{allowVideo:false}),
    removeReviewMedia:(items)=>removeOwnedReputationMedia(items),
    deleteItem:async(elemento_id)=>{const out=await kombaxShowcaseMutation('kombax.showcase.elemento.eliminar',{elemento_id});if(out?.deleted===true)await removeOwnedShowcaseImages([out?.imagen_url,...(Array.isArray(out?.galeria)?out.galeria:[])]);return out;},
    inquiryRequest:(elemento_id,mensaje)=>backend.globalWriteRpc('app_kombax_showcase_inquiry_request_r58',{p_elemento_id:elemento_id,p_mensaje:String(mensaje||'').trim()}),
    myInquiries:(limit=50)=>backend.globalReadRpc('app_kombax_showcase_my_inquiries_r58',{p_limit:Math.min(100,Math.max(1,Number(limit)||50))}),
    providerInquiries:(marca_id,limit=80)=>backend.globalReadRpc('app_kombax_showcase_provider_inquiries_r58',{p_marca_id:marca_id,p_limit:Math.min(150,Math.max(1,Number(limit)||80))}),
    inquiryMessages:(inquiry_id,limit=150)=>backend.globalReadRpc('app_kombax_showcase_inquiry_messages_r58',{p_inquiry_id:inquiry_id,p_limit:Math.min(300,Math.max(1,Number(limit)||150))}),
    inquirySend:(inquiry_id,mensaje)=>backend.globalWriteRpc('app_kombax_showcase_inquiry_send_r58',{p_inquiry_id:inquiry_id,p_mensaje:String(mensaje||'').trim()}),
    saveCommerce:(item_id,payload)=>backend.globalWriteRpc('app_showcase_commerce_mutate_v259',{p_item_id:item_id,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    saveListingMeta:(item_id,payload)=>backend.globalWriteRpc('app_showcase_listing_meta_mutate_r628',{p_item_id:item_id,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    sellerDashboard:(provider_id)=>backend.globalReadRpc('app_showcase_seller_dashboard_r628',{p_provider_id:provider_id}),
    finance:(provider_id)=>backend.globalReadRpc('app_kombax_showcase_finance_r65',{p_provider_id:provider_id}),
    stockMovements:(provider_id,product_id=null,limit=150)=>backend.globalReadRpc('app_kombax_showcase_stock_movements_r65',{p_provider_id:provider_id,p_product_id:product_id,p_limit:limit}),
    stockAdjust:(product_id,new_stock,note='')=>backend.globalWriteRpc('app_kombax_showcase_stock_adjust_r65',{p_product_id:product_id,p_new_stock:Number(new_stock),p_note:note||null,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    inventoryCost:(provider_id,limit=200)=>backend.globalReadRpc('app_kombax_showcase_inventory_cost_r89',{p_provider_id:provider_id,p_limit:Math.min(300,Math.max(10,Number(limit)||200))}),
    inventoryMutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_showcase_inventory_mutate_r89',{p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    communications:(provider_id,limit=100)=>backend.globalReadRpc('app_kombax_commerce_communications_r65',{p_scope:'showcase',p_subject_id:provider_id,p_limit:limit}),
    businessIntelligence:(provider_id,days=30)=>backend.globalReadRpc('app_kombax_showcase_bi_r65',{p_provider_id:provider_id,p_days:days}),
    analytics:(provider_id,days=30)=>backend.globalReadRpc('app_kombax_showcase_analytics_r77',{p_provider_id:provider_id,p_days:Math.min(365,Math.max(1,Number(days)||30))}),
    analyticsRange:(provider_id,from,to)=>backend.globalReadRpc('app_kombax_showcase_analytics_range_r77',{p_provider_id:provider_id,p_from:from,p_to:to}),
    report:(provider_id,report_type='general',period=30)=>{const range=period&&typeof period==='object'?period:null;return backend.invokeFunction('kombax-report-r77',{scope:'showcase',subject_id:provider_id,report_type,...(range?.from&&range?.to?{from:range.from,to:range.to,days:range.days||30}:{days:Math.min(365,Math.max(1,Number(period)||30))}),user_locale:getLocale()},60000)},
    track:(event_type,{provider_id=null,product_id=null,event_id=null,order_id=null,source=null,amount_minor=null,metadata={}}={})=>backend.globalWriteRpc('app_kombax_commerce_track_r65',{p_event_type:event_type,p_provider_id:provider_id,p_product_id:product_id,p_event_id:event_id,p_order_id:order_id,p_source:source,p_amount_minor:amount_minor,p_metadata:metadata}),
    removeOwnedImages:(urls)=>removeOwnedShowcaseImages(urls)
  },
  supportPrivacy:{
    list:(subject_type,subject_id,limit=25)=>backend.globalReadRpc('app_kombax_support_authorizations_v194',{p_subject_type:subject_type,p_subject_id:subject_id,p_limit:Math.min(100,Math.max(1,Number(limit)||25))}),
    create:(payload)=>backend.globalWriteRpc('app_kombax_support_authorization_mutate_v194',{p_operation:'support.authorization.create',p_payload:payload}),
    revoke:(authorization_id)=>backend.globalWriteRpc('app_kombax_support_authorization_mutate_v194',{p_operation:'support.authorization.revoke',p_payload:{authorization_id}})
  },
  brandBusiness:{
    workspace:(brand_profile_id)=>backend.globalReadRpc('app_kombax_brand_workspace_v223',{p_brand_profile_id:brand_profile_id}),
    discovery:(brand_profile_id,{target_type='fighter',query='',discipline=null,territory=null,limit=30}={})=>backend.globalReadRpc('app_kombax_brand_discovery_v224',{p_brand_profile_id:brand_profile_id,p_target_type:target_type,p_query:String(query||'').trim(),p_discipline:discipline||null,p_territory:territory||null,p_limit:Math.min(100,Math.max(1,Number(limit)||30))}),
    openCampaigns:(profile_id=null,limit=50)=>backend.globalReadRpc('app_kombax_brand_open_campaigns_v223',{p_profile_id:profile_id||null,p_limit:Math.min(100,Math.max(1,Number(limit)||50))}),
    preferences:(profile_id)=>backend.globalReadRpc('app_kombax_brand_collaboration_preferences_v223',{p_profile_id:profile_id}),
    inbox:(profile_id,limit=100)=>backend.globalReadRpc('app_kombax_brand_inbox_v223',{p_profile_id:profile_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    publicProfile:(brand_profile_id)=>backend.publicRpc('app_kombax_brand_public_profile_v224',{p_brand_profile_id:brand_profile_id}),
    targetPreferences:(target_type,target_id)=>backend.globalReadRpc('app_kombax_brand_target_preferences_v224',{p_target_type:target_type,p_target_id:target_id}),
    saveTargetPreferences:(operation,payload={})=>backend.globalWriteRpc('app_kombax_brand_target_preferences_mutate_v224',{p_operation:operation,p_payload:payload}),
    mutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_brand_mutate_v223',{p_operation:operation,p_payload:payload})
  },
  eventConnections:{
    get:({internal_event_id=null,public_event_id=null}={})=>backend.globalReadRpc('app_kombax_event_connections_v220',{p_internal_event_id:internal_event_id,p_public_event_id:public_event_id}),
    listForPublic:(public_event_id)=>backend.globalReadRpc('app_kombax_event_connections_for_public_v261',{p_public_event_id:public_event_id}),
    participants:(connection_id)=>backend.globalReadRpc('app_kombax_event_connection_participants_v261',{p_connection_id:connection_id}),
    mutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_event_connection_mutate_v220',{p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    publicProjection:(public_event_id)=>backend.publicRpc('app_kombax_event_public_projection_v220',{p_public_event_id:public_event_id})
  },
  fighterDiscovery:{
    search:({query='',discipline=null,category=null,weight_kg=null,level=null,territory=null,short_notice=false,limit=30}={})=>backend.globalReadRpc('app_kombax_fighter_discovery_search_v221',{p_query:String(query||'').trim(),p_discipline:discipline||null,p_category:category||null,p_weight_kg:weight_kg===''||weight_kg==null?null:Number(weight_kg),p_level:level||null,p_territory:territory||null,p_short_notice:short_notice===true,p_limit:Math.min(100,Math.max(1,Number(limit)||30))}),
    mine:(competitor_profile_id)=>backend.globalReadRpc('app_kombax_fighter_discovery_me_v221',{p_competitor_profile_id:competitor_profile_id}),
    save:(competitor_profile_id,payload={})=>backend.globalWriteRpc('app_kombax_fighter_discovery_mutate_v221',{p_competitor_profile_id:competitor_profile_id,p_payload:payload}),
    invitations:({event_id=null,competitor_profile_id=null,limit=50}={})=>backend.globalReadRpc('app_kombax_fight_invitations_v221',{p_event_id:event_id,p_competitor_profile_id:competitor_profile_id,p_limit:Math.min(200,Math.max(1,Number(limit)||50))}),
    invite:(payload)=>backend.globalWriteRpc('app_kombax_fight_invitation_mutate_v221',{p_operation:'invite',p_payload:payload}),
    respond:(invitation_id,status,response_note='')=>backend.globalWriteRpc('app_kombax_fight_invitation_mutate_v221',{p_operation:'respond',p_payload:{invitation_id,status,response_note}}),
    withdraw:(invitation_id)=>backend.globalWriteRpc('app_kombax_fight_invitation_mutate_v221',{p_operation:'withdraw',p_payload:{invitation_id}}),
    register:(invitation_id,registered_participant_id)=>backend.globalWriteRpc('app_kombax_fight_invitation_mutate_v221',{p_operation:'register',p_payload:{invitation_id,registered_participant_id}})
  },
  discovery:{
    search:(filters={})=>rpcWithFallback(
      ()=>backend.globalReadRpc('app_kombax_discovery_search_r118',{p_filters:filters||{}}),
      ()=>backend.globalReadRpc('app_kombax_discovery_search_r626',{p_filters:filters||{}}),
      'app_kombax_discovery_search_r118'
    ),
    profile:(profile_id)=>backend.globalReadRpc('app_kombax_discovery_profile_r626',{p_profile_id:profile_id}),
    save:(profile_id,payload={})=>backend.globalWriteRpc('app_kombax_discovery_mutate_r626',{p_profile_id:profile_id,p_payload:payload||{},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    publicProfile:(social_profile_id)=>rpcWithFallback(
      ()=>backend.globalReadRpc('app_kombax_discovery_public_profile_r118',{p_social_profile_id:social_profile_id}),
      ()=>backend.globalReadRpc('app_kombax_discovery_public_profile_r626',{p_social_profile_id:social_profile_id}),
      'app_kombax_discovery_public_profile_r118'
    ),
    personFacets:(social_profile_id)=>backend.globalReadRpc('app_kombax_person_facets_r118',{p_social_profile_id:social_profile_id}),
    slots:(profile_id)=>backend.globalReadRpc('app_kombax_discovery_slots_r626',{p_profile_id:profile_id}),
    saveSlot:(profile_id,payload={})=>backend.globalWriteRpc('app_kombax_discovery_slot_mutate_r626',{p_profile_id:profile_id,p_operation:'save',p_payload:payload||{},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    deleteSlot:(profile_id,slot_id)=>backend.globalWriteRpc('app_kombax_discovery_slot_mutate_r626',{p_profile_id:profile_id,p_operation:'delete',p_payload:{id:slot_id},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`})
  },
  competitionPreparation:{
    list:({competitor_profile_id=null,socio_id=null,club_id=null}={},limit=100)=>backend.globalReadRpc('app_kombax_preparations_v216',{p_competitor_profile_id:competitor_profile_id,p_socio_id:socio_id,p_club_id:club_id,p_limit:Math.min(300,Math.max(1,Number(limit)||100))}),
    measurements:(preparation_id,limit=120)=>backend.globalReadRpc('app_kombax_weight_measurements_v216',{p_preparation_id:preparation_id,p_limit:Math.min(500,Math.max(1,Number(limit)||120))}),
    candidates:(preparation_id)=>backend.globalReadRpc('app_kombax_preparation_candidates_v216',{p_preparation_id:preparation_id}),
    eventRoster:(event_source,event_id)=>backend.globalReadRpc('app_kombax_event_preparation_roster_v218',{p_event_source:event_source,p_event_id:event_id}),
    registrationMutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_event_preparation_mutate_v218',{p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    mutate:(operation,payload={})=>backend.globalWriteRpc('app_kombax_preparation_mutate_v216',{p_operation:operation,p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    async uploadEvidence(preparation_id,measurement_id,file){
      if(!file||!file.size)return null;if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');
      const prepared=await optimizeImage(file,{maxEdge:1600,maxBytes:4*1024*1024});if(prepared.file.size>5*1024*1024)throw new Error('La imagen supera 5 MB.');
      const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
      const path=`${preparation_id}/${measurement_id}/${Date.now()}-${token}.${ext}`;await backend.upload('competition-weight-evidence',path,prepared.file,false);
      try{await backend.globalWriteRpc('app_kombax_preparation_mutate_v216',{p_operation:'measurement.attach_photo',p_payload:{measurement_id,evidence_path:path},p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`});return path;}catch(error){await backend.remove('competition-weight-evidence',path).catch(()=>{});throw error;}
    },
    evidenceUrl:(path)=>backend.signedUrl('competition-weight-evidence',path,900)
  },
  customerOps:{
    tickets:(tenant_ref=null,limit=50)=>backend.globalReadRpc('app_kombax_customer_ops_tickets_r60',{p_tenant_ref:tenant_ref,p_limit:Math.min(100,Math.max(1,Number(limit)||50))}),
    supportTickets:(limit=50)=>backend.globalReadRpc('app_kombax_customer_ops_tickets_v211',{p_limit:Math.min(100,Math.max(1,Number(limit)||50))}),
    supportGuidedStatus:(ticket_id)=>backend.globalReadRpc('app_kombax_support_guided_status_r60',{p_ticket_id:ticket_id}),
    allowance:(tenant_ref=null)=>backend.globalReadRpc('app_kombax_assistance_allowance_v213',{p_tenant_ref:tenant_ref}),
    dashboard:(tenant_ref=null)=>backend.globalReadRpc('app_kombax_assist_dashboard_v227',{p_tenant_ref:tenant_ref}),
    aiCredits:(tenant_ref=null)=>backend.globalReadRpc('app_kombax_ai_credits_r97',{p_tenant_ref:tenant_ref}),
    guideAccess:(tenant_ref=null)=>backend.globalReadRpc('app_kombax_org_guide_access_r60',{p_tenant_ref:tenant_ref}),
    downloadGuide:(tenant_ref=null)=>backend.downloadFunction('migration-guide-r60',{tenant_ref,user_locale:getLocale()},30000),
    deleteHistory:({ticket_id=null,mode=null,tenant_ref=null}={})=>backend.invokeFunction('kombax-history-delete-r60',{ticket_id,mode,tenant_ref},45000),
    messages:(ticket_id,limit=100)=>backend.globalReadRpc('app_kombax_assist_messages_v227',{p_ticket_id:ticket_id,p_limit:Math.min(120,Math.max(1,Number(limit)||100))}),
    createTicket:(payload)=>backend.globalWriteRpc('app_kombax_customer_ops_mutate_v233',{p_operation:'ticket.create',p_payload:payload}),
    requestHuman:(ticket_id)=>backend.globalWriteRpc('app_kombax_customer_ops_mutate_v233',{p_operation:'ticket.human_review',p_payload:{ticket_id}}),
    migrationFiles:(ticket_id)=>backend.globalReadRpc('app_kombax_migration_files_v228',{p_ticket_id:ticket_id}),
    migrationPreview:(ticket_id)=>backend.globalReadRpc('app_kombax_migration_preview_v228',{p_ticket_id:ticket_id}),
    migrationJob:(ticket_id)=>backend.globalReadRpc('app_kombax_ai_migration_job_r103',{p_ticket_id:ticket_id}),
    migrationRecords:(ticket_id)=>backend.globalReadRpc('app_kombax_migration_records_v271',{p_ticket_id:ticket_id}),
    migrationImport:(ticket_id,request_id,records)=>backend.globalWriteRpc('app_kombax_migration_import_v271',{p_ticket_id:ticket_id,p_request_id:request_id,p_records:records}),
    chat:(ticket_id,message,specialty='management',client_request_id=(crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`))=>backend.invokeFunction('kombax-assist-r38',{ticket_id,message,specialty,client_request_id,user_locale:getLocale()},70000),
    async stageMigrationFiles(ticket_id,files=[],onProgress=null){
      const uid=session()?.id;if(!uid)throw new Error('AUTH_REQUIRED');
      const mimeByExt={pdf:'application/pdf',csv:'text/csv',xls:'application/vnd.ms-excel',xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',webp:'image/webp'};
      const allowed=new Set(Object.values(mimeByExt));const input=[...(files||[])];if(!input.length)throw new Error('Selecciona al menos un archivo para la migración.');
      const staged=[];
      for(let i=0;i<input.length;i++){
        const file=input[i],ext=String(file?.name||'').split('.').pop().toLowerCase(),mime=allowed.has(file?.type)?file.type:mimeByExt[ext];
        if(!mime)throw new Error(`Formato no admitido: ${file?.name||'archivo'}.`);if(!file?.size||file.size>10*1024*1024)throw new Error(`El archivo ${file?.name||''} supera el límite de 10 MB.`);
        const uploadFile=file.type===mime?file:new File([file],file.name,{type:mime,lastModified:file.lastModified});const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);const path=`${uid}/${ticket_id}/${Date.now()}-${token}.${ext}`;
        await backend.upload('kombax-migration-staging',path,uploadFile,false);
        try{const meta=await backend.globalWriteRpc('app_kombax_migration_file_register_v228',{p_ticket_id:ticket_id,p_storage_path:path,p_original_name:String(file.name||'archivo').slice(0,255),p_mime_type:mime,p_size_bytes:file.size});staged.push({...meta,original_name:file.name,size_bytes:file.size});}
        catch(error){await backend.remove('kombax-migration-staging',path).catch(()=>{});throw error;}
        onProgress?.({done:i+1,total:input.length,file:file.name});
      }
      return staged;
    }
  },
  pilot:{
    window:()=>backend.publicRpc('app_kombax_pilot_registration_window_r110',{}),
    activateClub:(payload)=>backend.globalWriteRpc('app_kombax_pilot_club_activate_r110',{p_payload:payload,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`})
  },

  platformAdmin:{
    context:()=>backend.globalReadRpc('app_kombax_platform_context_v055',{}),
    dashboard:()=>backend.globalReadRpc('app_kombax_platform_dashboard_v072',{}),
    profiles:(query='',limit=100)=>backend.globalReadRpc('app_kombax_platform_profiles_v117',{p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    application:(solicitud_id)=>backend.globalReadRpc('app_kombax_platform_application_v072',{p_solicitud_id:solicitud_id}),
    verificationDocumentUrl:(path)=>backend.signedUrl('kombax-verification-docs',path,600),
    professionalCredentialQueue:()=>backend.globalReadRpc('app_kombax_professional_credential_queue_r118',{}),
    professionalCredentialReview:(professional_profile_id,credential_id,decision,review_note='')=>kombaxGlobalMutation(
      'app_kombax_professional_credential_mutate_r118','professional.credential.review',
      {professional_profile_id,credential_id,decision,review_note:String(review_note||'').trim()}
    ),
    club:(club_id)=>backend.globalReadRpc('app_kombax_platform_club_v055',{p_club_id:club_id}),
    releaseContract:()=>backend.globalReadRpc('app_kombax_release_contract_v056',{}),
    reviewApplication:(solicitud_id,estado,motivo='')=>kombaxGlobalMutation('app_kombax_perfil_mutate_v196','kombax.application.review',{solicitud_id,estado,motivo}),
    createClub:(payload)=>kombaxGlobalMutation('app_kombax_platform_mutate_v097','kombax.platform.club.create',payload),
    setProfileService:(perfil_directo_id,plan_codigo,estado='activa')=>kombaxGlobalMutation('app_kombax_subscription_mutate_v071','kombax.subscription.set',{perfil_directo_id,plan_codigo,estado}),
    setTeamPermission:(club_id,perfil_id,permiso,activo=true)=>kombaxGlobalMutation('app_kombax_platform_mutate_v055','kombax.platform.team.permission.set',{club_id,perfil_id,permiso,activo:activo===true}),
    setModerator:(perfil_id,rol='moderador',activo=true)=>kombaxGlobalMutation('app_kombax_platform_mutate_v055','kombax.platform.moderator.set',{perfil_id,rol,activo:activo===true}),
    setVerifier:(perfil_id,activo=true,motivo='')=>backend.globalWriteRpc('app_kombax_verificador_set_v117',{p_perfil_id:perfil_id,p_activo:activo===true,p_motivo:String(motivo||'').trim()}),
    pilotReadiness:()=>backend.globalReadRpc('app_kombax_pilot_readiness_status_v117',{}),
    pilotMetrics:()=>backend.globalReadRpc('app_kombax_pilot_metrics_r97',{}),
    aiMetrics:()=>backend.globalReadRpc('app_kombax_ai_admin_metrics_r103',{}),
    ownerAgents:()=>backend.globalReadRpc('app_kombax_owner_agents_dashboard_r105',{}),
    ownerAgentConversations:()=>backend.globalReadRpc('app_kombax_owner_agent_conversations_r107',{}),
    ownerAgentConversation:(operation,{agent=null,conversation_id=null,title=null}={})=>backend.globalWriteRpc('app_kombax_owner_agent_conversation_mutate_r107',{p_operation:operation,p_agent:agent,p_conversation_id:conversation_id,p_title:title}),
    ownerAgentChat:(agent,message,{reasoning_effort='low',context_type=null,context_id=null,conversation_id=null,document_ids=[]}={})=>backend.invokeFunction('kombax-owner-agents-r105',{agent,message:String(message||'').trim(),reasoning_effort:reasoning_effort==='medium'?'medium':'low',context_type,context_id,conversation_id,document_ids:[...new Set((Array.isArray(document_ids)?document_ids:[]).map(String).filter(Boolean))].slice(0,3),client_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`},65000),
    async ownerAgentDocumentUpload(file,category='other',title=''){
      if(!file||!file.size)throw new Error('Selecciona un documento.');
      if(file.size>10*1024*1024)throw new Error('El documento supera 10 MB.');
      const allowed={pdf:'application/pdf',txt:'text/plain',csv:'text/csv',tsv:'text/tab-separated-values',xls:'application/vnd.ms-excel',xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',doc:'application/msword',docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',ppt:'application/vnd.ms-powerpoint',pptx:'application/vnd.openxmlformats-officedocument.presentationml.presentation',jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',webp:'image/webp'};
      const ext=String(file.name||'').split('.').pop()?.toLowerCase()||'',mime=allowed[ext];
      if(!mime)throw new Error('Formato no admitido. Usa PDF, Excel, CSV, Word, PowerPoint, TXT, JPG, PNG o WEBP.');
      const uid=String(session()?.id||'');if(!uid)throw new Error('La sesión Owner ha caducado.');
      const safeName=String(file.name||`documento.${ext}`).replace(/[^a-zA-Z0-9._-]+/g,'-').slice(-120);
      const path=`${uid}/owner-inbox/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}-${safeName}`;
      const uploadFile=file.type===mime?file:new File([file],file.name,{type:mime,lastModified:file.lastModified});
      await backend.upload('kombax-owner-inbox',path,uploadFile,false);
      try{return await backend.globalWriteRpc('app_kombax_owner_document_register_r106',{p_storage_path:path,p_original_name:String(file.name||safeName).slice(0,255),p_mime_type:mime,p_size_bytes:file.size,p_category:['request','verification','showcase','pilot','incident','finance','other'].includes(category)?category:'other',p_title:String(title||'').trim().slice(0,180)||null});}
      catch(error){await backend.remove('kombax-owner-inbox',path).catch(()=>{});throw error;}
    },
    pilotRequests:()=>backend.globalReadRpc('app_kombax_pilot_requests_r99',{}),
    pilotAssign:(club_id,plan_code,notes='')=>backend.globalWriteRpc('app_kombax_pilot_assign_r99',{p_club_id:club_id,p_plan_code:plan_code,p_notes:notes}),
    pilotEnroll:(subject_type,subject_id,notes='')=>backend.globalWriteRpc('app_kombax_pilot_enroll_r97',{p_subject_type:subject_type,p_subject_id:subject_id,p_notes:notes}),
    founderBenefit:(subject_type,subject_id,program,start_at)=>backend.globalWriteRpc('app_kombax_founder_benefit_r97',{p_subject_type:subject_type,p_subject_id:subject_id,p_program:program,p_start_at:start_at}),
    aiCreditGrant:(tenant_ref,amount,type,key,expires_at=null)=>backend.globalWriteRpc('app_kombax_ai_grant_r97',{p_tenant_ref:tenant_ref,p_amount:amount,p_type:type,p_key:key,p_expires:expires_at}),
    setPilotReadiness:(control,verified,evidence)=>backend.globalWriteRpc('app_kombax_pilot_readiness_set_v117',{p_control:control,p_verificado:verified===true,p_evidencia:String(evidence||'').trim()}),
    clientIncidents:(limit=100)=>backend.globalReadRpc('app_kombax_client_incidents_v117',{p_limit:Math.min(500,Math.max(1,Number(limit)||100))}),
    entities:(query='',limit=100)=>backend.globalReadRpc('app_kombax_platform_entities_v114',{p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    entitySessionStart:(entidad_tipo,entidad_id,motivo)=>backend.globalWriteRpc('app_kombax_platform_entity_session_start_v114',{p_entidad_tipo:entidad_tipo,p_entidad_id:entidad_id,p_motivo:motivo}),
    entitySessionContext:()=>backend.globalReadRpc('app_kombax_platform_entity_session_context_v114',{}),
    entityDetail:(entity_session_id)=>backend.globalReadRpc('app_kombax_platform_entity_detail_v114',{p_entity_session_id:entity_session_id}),
    entitySessionEnd:()=>backend.globalWriteRpc('app_kombax_platform_entity_session_end_v114',{}),
    supportAudit:(action,entity_session_id,detail={})=>backend.globalWriteRpc('app_kombax_support_audit_v140',{p_action:action,p_entity_session_id:entity_session_id,p_detail:detail}),
    entityStatus:(entity_session_id,payload)=>kombaxGlobalMutation('app_kombax_platform_entity_mutate_v114',payload?.estado?'kombax.admin.entity.moderation.set':'kombax.admin.entity.status.set',{...payload,entity_session_id}),
    deletionQueue:(estado=null,limit=50)=>backend.globalReadRpc('app_kombax_deletion_queue_v119',{p_estado:estado,p_limit:limit}),
    reviewDeletion:(solicitud_id,estado,resolucion='',nota_retencion='')=>kombaxGlobalMutation('app_kombax_eliminacion_mutate_v047','kombax.deletion.review',{solicitud_id,estado,resolucion,nota_retencion}),
    executeDeletion:(solicitud_id)=>backend.invokeFunction('account-deletion-executor',{solicitud_id}),
    metrics:(days=90)=>backend.globalReadRpc('app_kombax_metrics_platform_v133',{p_days:Math.min(365,Math.max(7,Number(days)||90))}),
    ownerAlerts:(limit=80)=>backend.globalReadRpc('app_kombax_owner_alerts_r114',{p_limit:Math.min(200,Math.max(1,Number(limit)||80))}),
    ownerReport:(days=90)=>backend.invokeFunction('kombax-owner-report-r114',{days:Math.min(365,Math.max(7,Number(days)||90))},60000),
    clubMetrics:(club_id,days=90)=>backend.globalReadRpc('app_kombax_metrics_club_v133',{p_club_id:club_id,p_days:Math.min(365,Math.max(7,Number(days)||90))}),
    marketplace:(days=30)=>backend.globalReadRpc('app_kombax_marketplace_owner_dashboard_r627',{p_days:Math.min(365,Math.max(7,Number(days)||30))}),
    marketplaceSellerReview:(application_id,status,note='')=>backend.globalWriteRpc('app_kombax_marketplace_owner_seller_review_r627',{p_application_id:application_id,p_status:status,p_note:String(note||'').trim(),p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    marketplaceBuyerDetail:(identity_request_id)=>backend.globalReadRpc('app_kombax_marketplace_owner_buyer_detail_r627',{p_identity_request_id:identity_request_id}),
    marketplaceBuyerReview:(identity_request_id,status,note='')=>backend.globalWriteRpc('app_kombax_marketplace_owner_buyer_review_r627',{p_identity_request_id:identity_request_id,p_status:status,p_note:String(note||'').trim(),p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    commercialServices:(limit=100)=>backend.globalReadRpc('app_kombax_commercial_owner_dashboard_r628',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    commercialServiceReview:(access_id,status,note='')=>backend.globalWriteRpc('app_kombax_commercial_owner_service_mutate_r628',{p_access_id:access_id,p_status:status,p_note:String(note||'').trim(),p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    commercialRequests:(limit=100)=>backend.globalReadRpc('app_kombax_commercial_owner_requests_r642',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    activateCommercialPlan:(plan_request_id,note='')=>backend.globalWriteRpc('app_kombax_commercial_admin_activate_plan_r642',{p_plan_request_id:plan_request_id,p_note:String(note||'').trim()}),
    rejectCommercialPlan:(plan_request_id,note='')=>backend.globalWriteRpc('app_kombax_commercial_admin_reject_plan_r642',{p_plan_request_id:plan_request_id,p_note:String(note||'').trim()}),
    decideCommercialEntitlement:(entitlement_id,decision,note='')=>backend.globalWriteRpc('app_kombax_commercial_admin_entitlement_decide_r642',{p_entitlement_id:entitlement_id,p_decision:decision,p_note:String(note||'').trim()})
  },
  commercial:{
    catalog:(audience=null)=>backend.globalReadRpc('app_kombax_commercial_catalog_r64',{p_audience:audience||null}),
    offers:(audience=null)=>backend.globalReadRpc('app_kombax_offer_catalog_r98',{p_audience:audience||null,p_country:'ES'}),
    context:(subject_type,subject_id)=>backend.globalReadRpc('app_kombax_commercial_context_r64',{p_subject_type:subject_type,p_subject_id:subject_id}),
    requestPlan:(subject_type,subject_id,plan_code,billing_cycle='monthly')=>backend.globalWriteRpc('app_kombax_commercial_plan_request_r64',{p_subject_type:subject_type,p_subject_id:subject_id,p_plan_code:plan_code,p_billing_cycle:billing_cycle,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    requestActivation:(subject_type,subject_id,entitlement_code,{scope_id=null,days=null}={})=>backend.globalWriteRpc('app_kombax_commercial_activation_request_r64',{p_subject_type:subject_type,p_subject_id:subject_id,p_entitlement_code:entitlement_code,p_scope_id:scope_id,p_days:days,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}),
    requestPromotion:(content_type,content_id,days)=>backend.globalWriteRpc('app_kombax_content_promotion_request_r64',{p_content_type:content_type,p_content_id:content_id,p_days:days,p_request_id:crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`})
  },
  accountDeletion:{
    list:()=>backend.globalReadRpc('app_kombax_solicitudes_eliminacion_v047',{}),
    request:(payload)=>kombaxGlobalMutation('app_kombax_eliminacion_mutate_v047','kombax.deletion.request',payload),
    cancel:(solicitud_id)=>kombaxGlobalMutation('app_kombax_eliminacion_mutate_v047','kombax.deletion.cancel',{solicitud_id})
  },
  legal:{
    docs:()=>cachedRead('legal:docs',()=>read('textos_legales',`select=*&${filterClub()}&vigente=eq.true&order=tipo`),120000),
    accept:(tipo,version='2.0.0',aceptado=true,socio_id=null)=>mutation('legal.aceptar',{tipo,version,aceptado,socio_id,user_agent:navigator.userAgent}),
    acceptances:()=>read('aceptaciones_legales',`select=*&${filterClub()}&perfil_id=eq.${enc(session()?.id)}&order=aceptado_en.desc`)
  },
  documents:{
    list:(limit=120)=>read('documentos_socios',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=${Math.min(500,Math.max(20,Number(limit)||120))}`),
    async upload(socioId,file,meta={}){
      if(!file||!file.size)throw new Error('Selecciona un archivo.');
      if(file.size>10*1024*1024)throw new Error('El archivo supera el límite de 10 MB.');
      const allowed=new Set(['application/pdf','image/jpeg','image/png','image/webp']);
      if(file.type&&!allowed.has(file.type))throw new Error('Formato no admitido. Usa PDF, JPG, PNG o WEBP.');
      const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();
      const path=`${session().club_id}/${socioId}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;
      await backend.upload('member-documents',path,file,false);
      try{
        const created=await mutation('documento.registrar',{socio_id:socioId,nombre:meta.nombre||file.name,tipo:meta.tipo||'otro',storage_path:path,mime_type:file.type||null,tamano_bytes:file.size,visible_familia:meta.visible_familia!==false});
        await mutation('documento.actualizar',{documento_id:created.id,nombre:meta.nombre||file.name,tipo:meta.tipo||'otro',fecha_documento:meta.fecha_documento||null,observaciones:meta.observaciones||null,firmado:meta.firmado===true,visible_familia:meta.visible_familia!==false});
        if(meta.reemplaza_id){await mutation('documento.archivar',{documento_id:meta.reemplaza_id,estado:'sustituido',reemplazado_por:created.id});}
        return created;
      }catch(e){await backend.remove('member-documents',path).catch(()=>{});throw e;}
    },
    update:(documento_id,meta={})=>mutation('documento.actualizar',{documento_id,...meta}),
    archive:(documento_id,estado='archivado',reemplazado_por=null)=>mutation('documento.archivar',{documento_id,estado,reemplazado_por}),
    async delete(documento_id){const out=await mutation('documento.eliminar',{documento_id});if(out?.storage_path)await backend.remove('member-documents',out.storage_path).catch(()=>{});return out;},
    url:(path)=>backend.signedUrl('member-documents',path,600),
    download:(path)=>backend.download('member-documents',path,600)
  }
};
