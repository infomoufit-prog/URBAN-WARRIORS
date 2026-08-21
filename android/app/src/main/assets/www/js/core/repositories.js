import { backend } from './backend.js';
// Contrato histórico app_kombax_perfil_mutate_v043 · legacy cerrado desde 20.044; repositorio activo usa v072.
import { state } from './state.js';
import { isoDate, monthStart } from './utils.js';
import { optimizeImage, prepareVideo } from './media.js';
import { cached, cacheValue, peekCache, invalidateCache } from './query-cache.js';
import { tenantKey } from './platform.js';

const enc=(v)=>encodeURIComponent(String(v??''));
const session=()=>state.session;
const filterClub=()=>`club_id=eq.${enc(session()?.club_id)}`;

async function read(table,query){return backend.select(table,query)}
async function mutation(op,payload){const out=await backend.mutate(op,payload);invalidateCache(`${session()?.club_id||'public'}:${session()?.id||'anonymous'}:`);return out}
const cachedRead=(suffix,loader,ttl=45000,force=false)=>cached(tenantKey(session(),suffix),loader,{ttl,force});

const PUBLIC_IMAGE_TYPES=new Set(['image/jpeg','image/png','image/webp','image/gif']);
async function uploadPublicImage(kind,file){
  if(!file||!file.size)return '';
  if(!PUBLIC_IMAGE_TYPES.has(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP o GIF.');
  const prepared=file.type==='image/gif'?{file}:await optimizeImage(file);
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
const notificationKey=()=>tenantKey(session(),'notifications');
// Compatibilidad de regresión: app_kombax_social_mutate_v067 queda solo como marcador histórico; runtime 20.045 usa v083.
async function kombaxSocialMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc('app_kombax_social_mutate_v099',{p_operation:operation,p_payload:{...payload,club_id:session()?.club_id||null},p_request_id:requestId});
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
async function kombaxIdentityMutation(operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc('app_kombax_identity_mutate_v094',{p_operation:operation,p_payload:{...payload,club_id:payload.club_id||session()?.club_id||null},p_request_id:requestId});
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
  const prepared=isVideo?await prepareVideo(file):await optimizeImage(file,{maxEdge:type==='banner'?2560:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>25*1024*1024)throw new Error('El archivo supera 25 MB.');
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
    return {...data,storage_bucket:bucket,public_url:restricted?'':backend.publicUrl('kombax-public-media',path)};
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
  if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Showcase admite JPG, PNG o WEBP.');
  const prepared=await optimizeImage(file,{maxEdge:1920,maxBytes:5*1024*1024});
  const ext=prepared.file.type==='image/png'?'png':prepared.file.type==='image/webp'?'webp':'jpg';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/showcase/${brandId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  return {path,url:backend.publicUrl('kombax-public-media',path)};
}

async function kombaxGlobalMutation(endpoint,operation,payload={}){
  const requestId=crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const response=await backend.globalWriteRpc(endpoint,{p_operation:operation,p_payload:payload,p_request_id:requestId});
  if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta KOMBAX no verificable para ${operation}.`);
  return response.data;
}
async function uploadKombaxProfileMedia(profileId,type,file){
  if(!session()?.id)throw new Error('Inicia sesión en KOMBAX.');
  let prepared;
  if(type==='video')prepared=await prepareVideo(file);else prepared=await optimizeImage(file,{maxEdge:type==='banner'?2560:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>25*1024*1024)throw new Error('El archivo supera 25 MB.');
  const ext=(prepared.file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/${profileId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  try{
    const data=await kombaxGlobalMutation('app_kombax_media_mutate_v072','kombax.media.add',{perfil_directo_id:profileId,tipo,storage_path:path,mime_type:prepared.mime||prepared.file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:prepared.duration||null});
    return {...data,public_url:backend.publicUrl('kombax-public-media',path)};
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
  if(normalizedType==='video')prepared=await prepareVideo(file);else prepared=await optimizeImage(file,{maxEdge:1920,maxBytes:5*1024*1024});
  if(prepared.file.size>25*1024*1024)throw new Error('El archivo supera 25 MB.');
  const ext=(prepared.file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'')||'bin';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().id}/club/${clubId}/${Date.now()}-${token}.${ext}`;
  await backend.upload('kombax-public-media',path,prepared.file,false);
  try{
    const data=await kombaxGlobalMutation('app_kombax_club_media_mutate_v046','kombax.club.media.add',{club_id:clubId,tipo:normalizedType,storage_path:path,mime_type:prepared.mime||prepared.file.type,bytes:prepared.sizeBytes||prepared.file.size,width:prepared.width||null,height:prepared.height||null,duration_seconds:prepared.duration||null});
    return {...data,public_url:backend.publicUrl('kombax-public-media',path)};
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
async function notificationList(limit=500,{force=false}={}){
  return cached(notificationKey(),async()=>{
    try{
      const rows=await backend.readRpc('app_notificaciones_centro_v037',{p_club_id:session()?.club_id,p_limit:Math.min(1000,Math.max(1,Number(limit)||500))});
      if(Array.isArray(rows))return rows;
    }catch(error){
      if(!/app_notificaciones_centro_v037|404|schema cache|could not find/i.test(String(error?.message||'')))console.warn('Centro de notificaciones optimizado:',error);
    }
    const [items,reads,actionRows]=await Promise.all([
      read('notificaciones',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=${Number(limit)||500}`),
      session()?.id?read('notificaciones_lecturas',`select=notificacion_id,leida_en&perfil_id=eq.${enc(session().id)}&limit=3000`).catch(()=>[]):Promise.resolve([]),
      session()?.club_id?backend.readRpc('app_notificaciones_accionables_v034',{p_club_id:session().club_id}).catch(()=>[]):Promise.resolve([])
    ]);
    const sharedRead=new Set((reads||[]).map(x=>x.notificacion_id));
    const readAt=new Map((reads||[]).map(x=>[x.notificacion_id,x.leida_en]));
    const actionMap=new Map((actionRows||[]).map(x=>[x.notificacion_id,x.requiere_accion===true]));
    return (items||[]).map(n=>({...n,requiere_accion:actionMap.get(n.id)===true,leida:Boolean(n.leida)||sharedRead.has(n.id),leida_en:n.leida_en||(sharedRead.has(n.id)?readAt.get(n.id):null)}));
  },{ttl:12000,force});
}

async function optimisticNotificationMutation(operation,payload,predicate){
  const key=notificationKey();const current=peekCache(key)||await notificationList(1000);
  const previous=current.map(item=>({...item}));const now=new Date().toISOString();
  const optimistic=current.map(item=>predicate(item)?{...item,leida:true,leida_en:item.leida_en||now}:item);
  cacheValue(key,optimistic,12000);window.dispatchEvent(new CustomEvent('uw-notifications-changed',{detail:{optimistic:true}}));
  try{
    const out=await backend.mutate(operation,{...payload,club_id:session()?.club_id});
    await notificationList(1000,{force:true});window.dispatchEvent(new CustomEvent('uw-notifications-changed',{detail:{persisted:true}}));return out;
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
          safe('cuotas',`select=id,socio_id,estado,importe,vencimiento&${q}&order=vencimiento.desc&limit=1000`),safe('sesiones_entrenamiento',`select=id,grupo_id,fecha,hora_inicio,hora_fin,estado,monitor_nombre&${q}&ciclo_estado=eq.activo&order=fecha.desc&limit=120`),backend.readRpc('app_kombax_header_summary_v105',{p_club_id:c}).then(rows=>Array.isArray(rows)?(rows[0]||{}):(rows||{})).catch(()=>({})),
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
    list:()=>session()?.rol==='monitor'?backend.readRpc('app_kombax_mis_alumnos_v057',{p_club_id:session()?.club_id}):read('socios',`select=*&${filterClub()}&order=apellidos,nombre`), enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc&limit=1000`), tutors:()=>read('tutores_socios',`select=*&${filterClub()}`),
    save:(p)=>mutation('alumno.guardar',{id:p.id||null,nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,telefono:p.telefono||'',email:p.email||'',tutor_nombre:p.tutor_nombre||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,grado_id:p.grado_id||null,grado_texto:p.grado_texto||'',tarifa_id:p.tarifa_id||null,estado:p.estado||'activo',contacto_emergencia:p.contacto_emergencia||'',telefono_emergencia:p.telefono_emergencia||'',notas_internas:p.notas_internas||''}),
    requestEnrollment:(socio_id,disciplina_id,grupo_id,tarifa_id)=>mutation('matricula.solicitar',{socio_id,disciplina_id,grupo_id,tarifa_id:tarifa_id||null}),
    deactivateEnrollment:(matricula_id)=>mutation('matricula.desactivar',{matricula_id}),
    graduation:(p)=>mutation('graduacion.registrar',{socio_id:p.socio_id,disciplina_id:p.disciplina_id,grado_id:p.grado_id,fecha:p.fecha||isoDate(),examinador:p.examinador||'',nota:p.nota||''}),
    archive:(socio_id,motivo='',fecha_baja=isoDate())=>mutation('alumno.archivar',{socio_id,motivo,fecha_baja}),
    delete:(socio_id)=>mutation('alumno.eliminar',{socio_id}), async forceDelete(socio_id){const out=await mutation('alumno.eliminar_forzado',{socio_id});await Promise.all([(out?.document_paths||[]).map(p=>backend.remove('member-documents',p).catch(()=>{})),(out?.payment_paths||[]).map(p=>backend.remove('justificantes-pago',p).catch(()=>{}))].flat());return out;}
  },
  preenrollments:{
    list:()=>read('preinscripciones',`select=*&${filterClub()}&order=creado_en.desc`),
    create:(p)=>mutation('preinscripcion.crear',{tipo_solicitud:p.tipo_solicitud||'adulto',nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,tutor_nombre:p.tutor_nombre||'',tutor_email:p.tutor_email||'',telefono:p.telefono||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,tarifa_id:p.tarifa_id||null,parentesco:p.parentesco||null,observaciones:p.observaciones||null}),
    approve:(id)=>mutation('preinscripcion.aprobar',{preinscripcion_id:id}), wait:(id,motivo)=>mutation('preinscripcion.espera',{preinscripcion_id:id,motivo:motivo||null}), reject:(id,motivo)=>mutation('preinscripcion.rechazar',{preinscripcion_id:id,motivo:motivo||''}),
    cancel:(id,motivo)=>mutation('preinscripcion.cancelar',{preinscripcion_id:id,motivo:motivo||''}),
    delete:(id)=>mutation('preinscripcion.eliminar',{preinscripcion_id:id})
  },
  tariffs:{
    list:()=>read('tarifas',`select=*&${filterClub()}&order=nombre`),
    save:(p)=>mutation('tarifa.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',importe:Number(p.importe||0),matricula:Number(p.matricula||0),periodicidad:p.periodicidad||'mensual',activa:p.activa!==false}),
    delete:(tarifa_id)=>mutation('tarifa.eliminar',{tarifa_id}), forceDelete:(tarifa_id)=>mutation('tarifa.eliminar_forzado',{tarifa_id})
  },
  finance:{
    fees:()=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=1000`), payments:()=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=1000`), receipts:()=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=1000`),
    account:()=>read('v_estado_cuenta_socio',`select=*&${filterClub()}&order=periodo.desc&limit=2000`),
    years:()=>read('cuotas',`select=periodo&${filterClub()}&order=periodo.desc&limit=5000`),
    detail:({year,month,socio,origin,status}={})=>read('v_finanzas_detalle',`select=*&${filterClub()}${year?`&anio=eq.${enc(year)}`:''}${month?`&mes=eq.${enc(month)}`:''}${socio?`&socio_id=eq.${enc(socio)}`:''}${origin?`&origen=eq.${enc(origin)}`:''}${status?`&estado=eq.${enc(status)}`:''}&order=periodo.desc,vencimiento.desc&limit=2000`),
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
  reminders:{
    load:()=>read('configuracion_avisos_cuota',`select=*&${filterClub()}&limit=1`), history:()=>read('historial_avisos_cuota',`select=*&${filterClub()}&order=fecha_programada.desc&limit=250`),
    save:(p)=>mutation('avisos.configurar',{dias_aviso:p.dias_aviso,hora_envio:p.hora_envio||'10:00',canal_app:p.canal_app!==false,canal_push:p.canal_push!==false,canal_email:p.canal_email===true,agrupar_por_familia:p.agrupar_por_familia!==false,marcar_vencida_dia:Number(p.marcar_vencida_dia||15),zona_horaria:p.zona_horaria||'Europe/Madrid',activo:p.activo!==false}),
    process:(fecha=isoDate())=>mutation('avisos.procesar',{fecha})
  },
  sessions:{
    list:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.desc&limit=500`),
    series:()=>read('series_sesiones',`select=*&${filterClub()}&order=creado_en.desc&limit=500`),
    saveSeries:(p)=>mutation('sesion.serie.guardar',{id:p.id||null,grupo_id:p.grupo_id,dias_semana:p.dias_semana||[],hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',codigo_acceso:p.codigo_acceso||'',fecha_inicio:p.fecha_inicio||isoDate(),fecha_fin:p.fecha_fin||null,activa:p.activa!==false}),
    endSeries:(serie_id,fecha_fin=isoDate())=>mutation('sesion.serie.finalizar',{serie_id,fecha_fin}),
    generateRecurring:(horizonte_dias=84)=>mutation('sesiones.recurrentes.generar',{horizonte_dias:Number(horizonte_dias||84)}),
    exception:(p)=>mutation('sesion.excepcion.guardar',{sesion_id:p.sesion_id,estado:p.estado||null,monitor_nombre:p.monitor_nombre||null,hora_inicio:p.hora_inicio||null,hora_fin:p.hora_fin||null,sala:p.sala||null,motivo:p.motivo||'',observacion_general:p.observacion_general||null}),
    save:(p)=>mutation('sesion.guardar',{id:p.id||null,grupo_id:p.grupo_id,fecha:p.fecha,hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',estado:p.estado||'programada',observacion_general:p.observacion_general||'',codigo_acceso:p.codigo_acceso||''}),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=registrado_en.desc&limit=2000`),
    reservations:()=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=3000`),
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
    list:()=>read('seguimiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,creado_en.desc&limit=1000`),
    save:(p)=>mutation('seguimiento.guardar',{socio_id:p.socio_id,tipo:p.tipo,nota:p.nota,visibilidad:p.visibilidad||'equipo',fecha:p.fecha||isoDate()})
  },
  communications:{
    list:()=>read('comunicaciones',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=1000`),
    uploadImage:(file)=>uploadPublicImage('communications',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('publicacion.guardar',{id:p.id||null,tipo:p.tipo||'noticia',titulo:p.titulo,cuerpo:p.cuerpo,audiencia:p.audiencia||'todos',estado:p.estado||'borrador',evento_fecha:p.evento_fecha||null,ubicacion:p.ubicacion||'',imagen_url:p.imagen_url||''}),
    async delete(publicacion_id){const out=await mutation('publicacion.eliminar',{publicacion_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;},
    async cleanupOld(antes_de,incluir_publicadas=false){const out=await mutation('publicacion.limpiar_antiguas',{antes_de,incluir_publicadas:incluir_publicadas===true});await removePublicImages(out?.image_urls||[]);return out;}
  },
  material:{
    list:()=>read('material_catalogo',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=orden,nombre&limit=500`), variants:()=>read('material_variantes',`select=*&${filterClub()}&order=material_id,talla,color&limit=2000`), orders:()=>read('material_pedidos',`select=*&${filterClub()}&order=creado_en.desc&limit=1000`),
    uploadImage:(file)=>uploadPublicImage('material',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('material.guardar',{id:p.id||null,disciplina_id:p.disciplina_id||null,nombre:p.nombre,categoria:p.categoria||'',descripcion:p.descripcion||'',imagen_url:p.imagen_url||'',precio:Number(p.precio||0),stock:Number(p.stock||0),obligatorio:p.obligatorio===true,referencia:p.referencia||'',activo:p.activo!==false}),
    saveVariant:(p)=>mutation('material.variante.guardar',{id:p.id||null,material_id:p.material_id,talla:p.talla||'',color:p.color||'',referencia:p.referencia||'',stock:Number(p.stock||0),activa:p.activa!==false}),
    request:(p)=>mutation('material.solicitar',{socio_id:p.socio_id,material_id:p.material_id,variante_id:p.variante_id||null,cantidad:Number(p.cantidad||1),observaciones:p.observaciones||'',validar_ahora:p.validar_ahora===true}),
    orderStatus:(pedido_id,estado)=>mutation('material.pedido.estado',{pedido_id,estado}),
    async delete(material_id){const out=await mutation('material.eliminar',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}, async forceDelete(material_id){const out=await mutation('material.eliminar_forzado',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}
  },
  notifications:{
    list:(options={})=>notificationList(1000,options),
    headerSummary:()=>rpcWithFallback(()=>backend.readRpc('app_kombax_header_summary_v107',{p_club_id:session()?.club_id}),()=>backend.readRpc('app_kombax_header_summary_v106',{p_club_id:session()?.club_id}),'app_kombax_header_summary_v107'),
    markRead:(notificacion_id)=>optimisticNotificationMutation('notificacion.leer',{notificacion_id},n=>n.id===notificacion_id),
    review:(notificacion_id)=>optimisticNotificationMutation('notificacion.revisar',{notificacion_id},n=>n.id===notificacion_id),
    markGroup:(tipo)=>optimisticNotificationMutation('notificacion.leer_grupo',{tipo},n=>n.tipo===tipo&&n.requiere_accion!==true),
    markInformative:()=>optimisticNotificationMutation('notificacion.leer_todas',{},n=>n.requiere_accion!==true),
    invalidate:()=>invalidateCache(notificationKey()),
    preferences:()=>read('preferencias_notificacion',`select=*&${filterClub()}&perfil_id=eq.${enc(session()?.id)}&limit=1`),
    savePreferences:(p)=>mutation('notificaciones.preferencias',{push_general:p.push_general!==false,push_finanzas:p.push_finanzas!==false,push_sesiones:p.push_sesiones!==false,push_comunidad:p.push_comunidad===true})
  },
  users:{
    members:()=>read('miembros_club',`select=*,perfiles(id,nombre,apellidos,telefono)&${filterClub()}&rol=in.(direccion,secretaria,economia,comunicacion,monitor)&order=creado_en&limit=500`),
    teamRequests:async()=>{try{return await backend.readRpc('app_kombax_solicitudes_equipo_v109',{p_club_id:session()?.club_id});}catch{return backend.readRpc('app_kombax_solicitudes_equipo_v060',{p_club_id:session()?.club_id});}},
    resolveTeamRequest:(id,estado,rol=null,nota='')=>backend.writeRpc('app_kombax_solicitud_equipo_resolver_v060',{p_solicitud_id:id,p_estado:estado,p_rol:rol,p_nota:nota||null})
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
    list:({tipo='',estado='',desde='',hasta='',limit=300}={})=>backend.readRpc('app_ciclo_listar_v038',{p_club_id:session()?.club_id,p_tipo:tipo||null,p_estado:estado||null,p_desde:desde||null,p_hasta:hasta||null,p_limit:Number(limit||300)}),
    action:(tipo,ids,accion,motivo='')=>backend.writeRpc('app_ciclo_accion_v038',{p_club_id:session()?.club_id,p_recurso_tipo:tipo,p_ids:ids,p_accion:accion,p_motivo:motivo||null})
  },
  portal:{
    visibleMembers:()=>read('socios',`select=*&${filterClub()}&order=apellidos,nombre&limit=500`),
    enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc&limit=1000`),
    graduations:()=>read('graduaciones',`select=*&${filterClub()}&order=fecha.desc&limit=500`),
    schedules:()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`),
    sessions:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.desc&limit=500`),
    reservations:()=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=3000`),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=registrado_en.desc&limit=2000`),
    tracking:()=>read('seguimiento',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,creado_en.desc&limit=500`),
    documents:()=>read('documentos_socios',`select=*&${filterClub()}&ciclo_estado=eq.activo&visible_familia=eq.true&order=creado_en.desc&limit=500`),
    fees:()=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=1000`),
    payments:()=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=1000`),
    receipts:()=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=1000`),
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
    async one(club_id=session()?.club_id){const rows=await backend.readRpc('app_perfil_club_publico_v061',{p_club_id:club_id});return rows?.[0]||null;},
    save:(p)=>mutation('club_publico.guardar',{slug:p.slug,nombre_publico:p.nombre_publico,alias:p.alias||'',lema:p.lema||'',descripcion:p.descripcion||'',historia:p.historia||'',ciudad:p.ciudad||'',provincia:p.provincia||'',pais:p.pais||'España',logros:p.logros||'',contacto_publico:p.contacto_publico||'',web_publica:p.web_publica||'',instagram:p.instagram||'',tiktok:p.tiktok||'',youtube:p.youtube||'',logo_url:p.logo_url||'',portada_url:p.portada_url||'',visible:true}),
    uploadImage:(kind,file)=>uploadPublicImage(kind==='cover'?'public-club-cover':'public-club-logo',file),
    removeImage:(url)=>removePublicImage(url),
    album:(club_id=session()?.club_id)=>backend.globalReadRpc('app_kombax_club_album_v046',{p_club_id:club_id}),
    albumUrl:(path)=>backend.publicUrl('kombax-public-media',path),
    uploadAlbumMedia:(club_id,type,file)=>uploadKombaxClubMedia(club_id,type,file),
    removeAlbumMedia:async(club_id,media)=>{const out=await kombaxGlobalMutation('app_kombax_club_media_mutate_v046','kombax.club.media.remove',{club_id,media_id:media.id});if(out?.storage_path)await backend.remove('kombax-public-media',out.storage_path).catch(()=>{});return out;}
  },
  publicIdentity:{
    search:(query='')=>backend.readRpc('app_buscar_identidades_publicas_v035',{p_club_id:session()?.club_id,p_query:query||'',p_limit:60})
  },
  sportsProfiles:{
    list:(socio_id=null)=>backend.readRpc('app_perfiles_deportivos_publicos_v032',{p_club_id:session()?.club_id,p_socio_id:socio_id||null}),
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
  events:{
    list:()=>read('eventos_competicion',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=fecha.desc,hora_inicio.asc,id.desc&limit=500`),
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
    mediaUrl:(path)=>backend.signedUrl('community-media',path,3600),
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
    mine:()=>backend.globalReadRpc('app_kombax_mis_perfiles_v072',{}),
    clubs:()=>backend.globalReadRpc('app_kombax_mis_clubes_v097',{}),
    applications:()=>backend.globalReadRpc('app_kombax_mis_solicitudes_v072',{}),
    album:(profileId)=>backend.globalReadRpc('app_kombax_album_v072',{p_perfil_directo_id:profileId}),
    saveProfile:(payload)=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.profile.save',payload),
    saveApplication:(payload)=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.save',payload),
    submitApplication:(solicitud_id)=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.submit',{solicitud_id}),
    withdrawApplication:(solicitud_id)=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.withdraw',{solicitud_id}),
    managers:(profileId)=>backend.globalReadRpc('app_kombax_profile_managers_v070',{p_perfil_directo_id:profileId}),
    setManager:(profileId,perfilId,rol='editor',estado='activo')=>kombaxGlobalMutation('app_kombax_profile_manager_mutate_v070','kombax.profile.manager.set',{perfil_directo_id:profileId,perfil_id:perfilId,rol,estado}),
    uploadMedia:uploadKombaxProfileMedia,
    removeMedia:async(media)=>{const out=await kombaxGlobalMutation('app_kombax_media_mutate_v072','kombax.media.remove',{media_id:media.id});if(out?.storage_path)await backend.remove('kombax-public-media',out.storage_path).catch(()=>{});return out;},
    uploadVerificationDocument:uploadKombaxVerificationDocument
  },
  socialGeneral:{
    status:()=>backend.readRpc('app_kombax_social_estado_v065',{p_club_id:session()?.club_id}),
    activate:({acepta_normas,acepta_privacidad})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,user_agent:navigator.userAgent}),
    moderateAccess:(perfil_id,estado,motivo)=>mutation('comunidad_general.moderar_acceso',{perfil_id,estado,motivo}),
    async rules(){const rows=await read('textos_legales',`select=id,tipo,version,cuerpo&${filterClub()}&tipo=eq.comunidad_general&vigente=eq.true&order=creado_en.desc&limit=1`);return rows?.[0]||null;}
  },
  kombaxIdentity:{
    status:()=>backend.globalReadRpc('app_kombax_social_estado_v065',{p_club_id:session()?.club_id||null}),
    myProfiles:()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_v051',{p_club_id:session()?.club_id||null}),
    team:()=>backend.globalReadRpc('app_kombax_club_team_v051',{p_club_id:session()?.club_id||null}),
    activateMember:({acepta_normas,acepta_privacidad})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,user_agent:navigator.userAgent}),
    updateMemberProfile:(payload={})=>kombaxIdentityMutation('kombax.identity.member.profile.update',{club_id:session()?.club_id||null,bio_publica:String(payload.bio_publica||'').trim(),apodo_deportivo:String(payload.apodo_deportivo||'').trim(),disciplinas_publicas:String(payload.disciplinas_publicas||'').trim(),experiencia_anos:payload.experiencia_anos===''||payload.experiencia_anos==null?null:Number(payload.experiencia_anos),guardia:String(payload.guardia||'').trim(),tecnica_favorita:String(payload.tecnica_favorita||'').trim(),especialidad:String(payload.especialidad||'').trim(),trayectoria_declarada:String(payload.trayectoria_declarada||'').trim(),objetivos:String(payload.objetivos||'').trim()}),
    setTeamPermission:(perfil_id,permiso,activo=true)=>kombaxIdentityMutation('kombax.club.permission.set',{club_id:session()?.club_id||null,perfil_id,permiso,activo:activo===true})
  },
  kombaxSocial:{
    status:()=>backend.globalReadRpc('app_kombax_social_estado_v065',{p_club_id:session()?.club_id||null}),
    myProfiles:()=>backend.globalReadRpc('app_kombax_social_mis_perfiles_v051',{p_club_id:session()?.club_id||null}),
    feed:(cursor=null,limit=20)=>backend.globalReadRpc('app_kombax_social_feed_v085',{p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(20,Math.max(1,Number(limit)||20))}),
    directory:(query='',limit=30)=>backend.globalReadRpc('app_kombax_social_directorio_v072',{p_query:String(query||'').trim(),p_limit:Math.min(50,Math.max(1,Number(limit)||30))}),
    clubDirectory:(query='',limit=100)=>backend.globalReadRpc('app_kombax_club_social_directory_v095',{p_club_id:session()?.club_id||null,p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    // Compatibilidad contractual de regresiones históricas: app_kombax_perfil_publico_v068 · app_kombax_perfil_publico_v072 · app_kombax_social_feed_v065 · app_kombax_social_feed_v072 · app_kombax_social_directorio_v065 · app_kombax_social_comentarios_v053
    publicProfile:(social_id)=>backend.globalReadRpc('app_kombax_perfil_publico_v094',{p_social_id:social_id}),
    quota:(social_id)=>backend.globalReadRpc('app_kombax_social_cupo_v099',{p_social_id:social_id}),
    profilePosts:(social_id,cursor=null,limit=10)=>backend.globalReadRpc('app_kombax_social_profile_posts_v099',{p_social_id:social_id,p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(10,Math.max(1,Number(limit)||10))}),
    headerActivity:()=>backend.globalReadRpc('app_kombax_header_activity_v106',{}),
    contacts:()=>rpcWithFallback(()=>backend.globalReadRpc('app_kombax_contactos_v107',{}),()=>backend.globalReadRpc('app_kombax_contactos_v106',{}),'app_kombax_contactos_v107'),
    contactMessages:(contacto_id,{before=null,after=null,limit=30}={})=>backend.globalReadRpc('app_kombax_contact_mensajes_v106',{p_contacto_id:contacto_id,p_before_ordinal:before,p_after_ordinal:after,p_limit:Math.min(50,Math.max(1,Number(limit)||30))}),
    markContactRead:async(contacto_id)=>{const out=await backend.globalWriteRpc('app_kombax_contact_mark_read_v106',{p_contacto_id:contacto_id});window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;},
    activate:({acepta_normas,acepta_privacidad})=>kombaxIdentityMutation('kombax.identity.member.activate',{club_id:session()?.club_id||null,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,user_agent:navigator.userAgent}),
    activateDirect:(perfil_directo_id,{acepta_normas,acepta_privacidad})=>kombaxSocialMutation('kombax.social.direct.activate',{perfil_directo_id,acepta_normas:acepta_normas===true,acepta_privacidad:acepta_privacidad===true,user_agent:navigator.userAgent}),
    audiences:(autor_perfil_id)=>backend.globalReadRpc('app_kombax_social_audiencias_v083',{p_autor_social_id:autor_perfil_id}),
    publish:(autor_perfil_id,tipo,texto,options={})=>kombaxSocialMutation('kombax.social.publicar',{autor_perfil_id,tipo,texto,comentarios_estado:options.comentarios_estado||'open',social_media_id:options.social_media_id||null,audiencia:options.audiencia||'publica',audiencia_club_id:options.audiencia_club_id||null,audiencia_federacion_social_id:options.audiencia_federacion_social_id||null}),
    media:(social_id)=>backend.globalReadRpc('app_kombax_social_media_v085',{p_social_id:social_id}),
    uploadMedia:(social_id,type,file,options={})=>uploadKombaxSocialMedia(social_id,type,file,options),
    syncPrivateAvatar:(social_id,source_path=session()?.avatar_path)=>syncPrivateAvatarToKombaxSocial(social_id,source_path),
    attachAlbumMedia:(social_profile_id,source_type,source_id)=>kombaxSocialMutation('kombax.social.media.from_album',{social_profile_id,source_type,source_id}),
    removeMedia:async(media)=>{const out=await kombaxSocialMutation('kombax.social.media.remove',{media_id:media.id});if(out?.storage_path&&String(out.storage_path).startsWith(`${session()?.id}/social/`))await backend.remove(out.storage_bucket||media.storage_bucket||'kombax-public-media',out.storage_path).catch(()=>{});return out;},
    mediaUrl:(path)=>backend.publicUrl('kombax-public-media',path),
    mediaAccessUrl:(path,bucket='kombax-public-media')=>bucket==='kombax-restricted-media'?backend.signedUrl('kombax-restricted-media',path,600):Promise.resolve(backend.publicUrl('kombax-public-media',path)),
    withdraw:(publicacion_id)=>kombaxSocialMutation('kombax.social.retirar',{publicacion_id}),
    deletePost:async(publicacion_id)=>{const out=await kombaxSocialMutation('kombax.social.eliminar',{publicacion_id});if(out?.storage_path&&String(out.storage_path).startsWith(`${session()?.id}/social/`))await backend.remove(out.storage_bucket||'kombax-public-media',out.storage_path).catch(()=>{});return out;},
    like:(publicacion_id,activo)=>kombaxSocialMutation('kombax.social.like',{publicacion_id,activo:activo===true}),
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
    moderationQueue:(limit=100)=>backend.globalReadRpc('app_kombax_moderation_queue_v050',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    moderate:(reporte_id,estado,resolucion='',accion='ninguna')=>kombaxSocialMutation('kombax.social.moderar',{reporte_id,estado,resolucion,accion}),
    save:(publicacion_id,activo=true)=>kombaxSocialMutation('kombax.social.guardar',{publicacion_id,activo:activo===true}),
    comments:(publicacion_id,limit=100)=>backend.globalReadRpc('app_kombax_social_comentarios_v083',{p_publicacion_id:publicacion_id,p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    comment:(publicacion_id,autor_social_id,texto,parent_id=null)=>kombaxSocialMutation('kombax.social.comentar',{publicacion_id,autor_social_id,texto,parent_id}),
    removeComment:(comentario_id,motivo='')=>kombaxSocialMutation('kombax.social.comentario.eliminar',{comentario_id,motivo}),
    saved:(limit=100)=>backend.globalReadRpc('app_kombax_social_guardados_v083',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    relations:(social_id)=>backend.globalReadRpc('app_kombax_relaciones_v068',{p_social_id:social_id}),
    requestRelation:async(origen_social_id,destino_social_id,tipo,nota='')=>{const out=await kombaxGlobalMutation('app_kombax_relacion_mutate_v045','kombax.relation.request',{origen_social_id,destino_social_id,tipo,nota,club_id:session()?.club_id||null});window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;},
    relationState:async(relacion_id,estado)=>{const out=await kombaxGlobalMutation('app_kombax_relacion_mutate_v045','kombax.relation.state',{relacion_id,estado,club_id:session()?.club_id||null});window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;}
  },
  kombaxShowcase:{
    categories:()=>backend.globalReadRpc('app_kombax_showcase_categorias_v042',{}),
    list:(query='',category='',cursor=null,limit=24)=>backend.globalReadRpc('app_kombax_showcase_list_v054',{p_query:String(query||'').trim(),p_categoria:category||null,p_cursor:cursor?.created||null,p_cursor_id:cursor?.id||null,p_limit:Math.min(24,Math.max(1,Number(limit)||24))}),
    saved:(limit=100)=>backend.globalReadRpc('app_kombax_showcase_guardados_v054',{p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    toggleSaved:(elemento_id,activo=true)=>kombaxShowcaseMutation(activo?'kombax.showcase.guardar':'kombax.showcase.desguardar',{elemento_id}),
    myBrands:()=>backend.globalReadRpc('app_kombax_showcase_mis_espacios_v048',{p_club_id:session()?.club_id||null}),
    myItems:(marca_id)=>backend.globalReadRpc('app_kombax_showcase_mis_elementos_v054',{p_marca_id:marca_id}),
    saveBrand:(payload)=>kombaxShowcaseMutation('kombax.showcase.marca.guardar',payload),
    brandState:(marca_id,estado,verificada=false)=>kombaxShowcaseMutation('kombax.showcase.marca.estado',{marca_id,estado,verificada:verificada===true}),
    saveItem:(payload)=>kombaxShowcaseMutation('kombax.showcase.elemento.guardar',payload),
    uploadImage:(marca_id,file)=>uploadKombaxShowcaseImage(marca_id,file),
    removeUploadedImage:(path)=>path&&String(path).startsWith(`${session()?.id}/showcase/`)?backend.remove('kombax-public-media',path):Promise.resolve(false),
    itemState:(elemento_id,estado,options={})=>kombaxShowcaseMutation('kombax.showcase.elemento.estado',{elemento_id,estado,destacado:options.destacado===true,etiqueta_destacada:options.etiqueta_destacada||''}),
    deleteItem:async(elemento_id)=>{const out=await kombaxShowcaseMutation('kombax.showcase.elemento.eliminar',{elemento_id});await removeOwnedShowcaseImages([out?.imagen_url,...(Array.isArray(out?.galeria)?out.galeria:[])]);return out;},
    removeOwnedImages:(urls)=>removeOwnedShowcaseImages(urls)
  },
  platformAdmin:{
    context:()=>backend.globalReadRpc('app_kombax_platform_context_v055',{}),
    dashboard:()=>backend.globalReadRpc('app_kombax_platform_dashboard_v072',{}),
    profiles:(query='',limit=100)=>backend.globalReadRpc('app_kombax_platform_profiles_v072',{p_query:String(query||'').trim(),p_limit:Math.min(200,Math.max(1,Number(limit)||100))}),
    application:(solicitud_id)=>backend.globalReadRpc('app_kombax_platform_application_v072',{p_solicitud_id:solicitud_id}),
    verificationDocumentUrl:(path)=>backend.signedUrl('kombax-verification-docs',path,600),
    club:(club_id)=>backend.globalReadRpc('app_kombax_platform_club_v055',{p_club_id:club_id}),
    releaseContract:()=>backend.globalReadRpc('app_kombax_release_contract_v056',{}),
    reviewApplication:(solicitud_id,estado,motivo='')=>kombaxGlobalMutation('app_kombax_perfil_mutate_v072','kombax.application.review',{solicitud_id,estado,motivo}),
    createClub:(payload)=>kombaxGlobalMutation('app_kombax_platform_mutate_v097','kombax.platform.club.create',payload),
    setProfileService:(perfil_directo_id,plan_codigo,estado='activa')=>kombaxGlobalMutation('app_kombax_subscription_mutate_v071','kombax.subscription.set',{perfil_directo_id,plan_codigo,estado}),
    setTeamPermission:(club_id,perfil_id,permiso,activo=true)=>kombaxGlobalMutation('app_kombax_platform_mutate_v055','kombax.platform.team.permission.set',{club_id,perfil_id,permiso,activo:activo===true}),
    setModerator:(perfil_id,rol='moderador',activo=true)=>kombaxGlobalMutation('app_kombax_platform_mutate_v055','kombax.platform.moderator.set',{perfil_id,rol,activo:activo===true})
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
    list:()=>read('documentos_socios',`select=*&${filterClub()}&ciclo_estado=eq.activo&order=creado_en.desc&limit=2000`),
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
