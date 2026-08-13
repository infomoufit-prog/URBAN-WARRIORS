import { backend } from './backend.js';
import { state } from './state.js';
import { isoDate, monthStart } from './utils.js';

const enc=(v)=>encodeURIComponent(String(v??''));
const session=()=>state.session;
const filterClub=()=>`club_id=eq.${enc(session()?.club_id)}`;

async function read(table,query){return backend.select(table,query)}
async function mutation(op,payload){return backend.mutate(op,payload)}

const PUBLIC_IMAGE_TYPES=new Set(['image/jpeg','image/png','image/webp','image/gif']);
async function uploadPublicImage(kind,file){
  if(!file||!file.size)return '';
  if(file.size>5*1024*1024)throw new Error('La imagen supera el límite de 5 MB.');
  if(!PUBLIC_IMAGE_TYPES.has(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP o GIF.');
  const ext=({ 'image/jpeg':'jpg','image/png':'png','image/webp':'webp','image/gif':'gif' })[file.type]||'img';
  const token=crypto.randomUUID?.()||Math.random().toString(36).slice(2);
  const path=`${session().club_id}/${kind}/${Date.now()}-${token}.${ext}`;
  await backend.upload('club-public-media',path,file,false);
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
async function notificationList(limit=500){
  const [items,reads]=await Promise.all([
    read('notificaciones',`select=*&${filterClub()}&order=creado_en.desc&limit=${Number(limit)||500}`),
    session()?.id?read('notificaciones_lecturas',`select=notificacion_id,leida_en&perfil_id=eq.${enc(session().id)}&limit=2000`).catch(()=>[]):Promise.resolve([])
  ]);
  const sharedRead=new Set((reads||[]).map(x=>x.notificacion_id));
  return (items||[]).map(n=>({...n,leida:n.perfil_id===session()?.id?Boolean(n.leida):sharedRead.has(n.id),leida_en:n.perfil_id===session()?.id?n.leida_en:(sharedRead.has(n.id)?reads.find(r=>r.notificacion_id===n.id)?.leida_en:null)}));
}

export const repos={
  dashboard:{
    async load(){
      const c=session()?.club_id; const q=`club_id=eq.${enc(c)}`;
      const safe=async(table,query)=>{try{return await read(table,query)}catch{return[]}};
      const [disc,groups,members,fees,sessions,notifs,pre,payments,enrollments,attendance]=await Promise.all([
        safe('disciplinas',`select=id,nombre,activa&${q}`),safe('grupos',`select=id,nombre,disciplina_id,activo,plazas,monitor_nombre&${q}`),safe('socios',`select=id,nombre,apellidos,estado&${q}`),
        safe('cuotas',`select=id,socio_id,estado,importe,vencimiento&${q}&order=vencimiento.desc&limit=1000`),safe('sesiones_entrenamiento',`select=id,grupo_id,fecha,hora_inicio,hora_fin,estado,monitor_nombre&${q}&order=fecha.desc&limit=120`),notificationList(120).catch(()=>[]),
        safe('preinscripciones',`select=id,nombre,apellidos,estado,creado_en&${q}&order=creado_en.desc&limit=200`),safe('pagos',`select=id,socio_id,importe,fecha,estado_validacion&${q}&order=fecha.desc&limit=400`),safe('socio_disciplinas',`select=id,socio_id,grupo_id,activa&${q}`),safe('asistencias',`select=id,socio_id,sesion_id,estado&${q}&limit=3000`)
      ]);
      return {disc,groups,members,fees,sessions,notifs,pre,payments,enrollments,attendance};
    }
  },
  catalog:{
    disciplines:()=>read('disciplinas',`select=*&${filterClub()}&order=orden,nombre`),
    grades:()=>read('grados',`select=*&${filterClub()}&order=disciplina_id,orden,nombre`),
    saveDiscipline:(p)=>mutation('disciplina.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',color:p.color||'#ffffff',activa:p.activa!==false,orden:Number(p.orden||0)}),
    saveGrade:(p)=>mutation('grado.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,orden:Number(p.orden||1),color:p.color||null,meses_minimos:p.meses_minimos===''||p.meses_minimos==null?null:Number(p.meses_minimos),activo:p.activo!==false}),
    deleteDiscipline:(disciplina_id)=>mutation('disciplina.eliminar',{disciplina_id}),
    async forceDeleteDiscipline(disciplina_id){const out=await mutation('disciplina.eliminar_forzado',{disciplina_id});await removePublicImages(out?.image_urls||[]);return out;},
    deleteGrade:(grado_id)=>mutation('grado.eliminar',{grado_id}), forceDeleteGrade:(grado_id)=>mutation('grado.eliminar_forzado',{grado_id})
  },
  groups:{
    list:()=>read('grupos',`select=*&${filterClub()}&order=nombre`), schedules:()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`),
    save:(p)=>mutation('grupo.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',edad_min:p.edad_min===''?null:Number(p.edad_min),edad_max:p.edad_max===''?null:Number(p.edad_max),plazas:p.plazas===''?null:Number(p.plazas),activo:p.activo!==false,horarios:p.horarios||[]}),
    delete:(grupo_id)=>mutation('grupo.eliminar',{grupo_id}), forceDelete:(grupo_id)=>mutation('grupo.eliminar_forzado',{grupo_id})
  },
  members:{
    list:()=>read('socios',`select=*&${filterClub()}&order=apellidos,nombre`), enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc`), tutors:()=>read('tutores_socios',`select=*&${filterClub()}`),
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
    list:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&order=fecha.desc,hora_inicio.desc&limit=500`),
    series:()=>read('series_sesiones',`select=*&${filterClub()}&order=creado_en.desc`),
    saveSeries:(p)=>mutation('sesion.serie.guardar',{id:p.id||null,grupo_id:p.grupo_id,dias_semana:p.dias_semana||[],hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',codigo_acceso:p.codigo_acceso||'',fecha_inicio:p.fecha_inicio||isoDate(),fecha_fin:p.fecha_fin||null,activa:p.activa!==false}),
    endSeries:(serie_id,fecha_fin=isoDate())=>mutation('sesion.serie.finalizar',{serie_id,fecha_fin}),
    generateRecurring:(horizonte_dias=84)=>mutation('sesiones.recurrentes.generar',{horizonte_dias:Number(horizonte_dias||84)}),
    exception:(p)=>mutation('sesion.excepcion.guardar',{sesion_id:p.sesion_id,estado:p.estado||null,monitor_nombre:p.monitor_nombre||null,hora_inicio:p.hora_inicio||null,hora_fin:p.hora_fin||null,sala:p.sala||null,motivo:p.motivo||'',observacion_general:p.observacion_general||null}),
    save:(p)=>mutation('sesion.guardar',{id:p.id||null,grupo_id:p.grupo_id,fecha:p.fecha,hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',estado:p.estado||'programada',observacion_general:p.observacion_general||'',codigo_acceso:p.codigo_acceso||''}),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&order=registrado_en.desc&limit=2000`),
    reservations:()=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=3000`),
    reserve:(sesion_id,socio_id)=>mutation('sesion.reserva.confirmar',{sesion_id,socio_id}),
    cancelReservation:(sesion_id,socio_id)=>mutation('sesion.reserva.cancelar',{sesion_id,socio_id}),
    saveAttendance:(p)=>mutation('asistencia.guardar',{sesion_id:p.sesion_id,socio_id:p.socio_id,estado:p.estado,observacion:p.observacion||null}),
    checkin:(p)=>mutation('checkin.registrar',{sesion_id:p.sesion_id,socio_id:p.socio_id,codigo:p.codigo||'',metodo:p.metodo||'manual'}),
    delete:(sesion_id)=>mutation('sesion.eliminar',{sesion_id}), forceDelete:(sesion_id)=>mutation('sesion.eliminar_forzado',{sesion_id})
  },
  progress:{
    list:()=>read('v_progreso_socio',`select=*&${filterClub()}&order=apellidos,nombre`)
  },
  tracking:{
    list:()=>read('seguimiento',`select=*&${filterClub()}&order=fecha.desc,creado_en.desc&limit=1000`),
    save:(p)=>mutation('seguimiento.guardar',{socio_id:p.socio_id,tipo:p.tipo,nota:p.nota,visibilidad:p.visibilidad||'equipo',fecha:p.fecha||isoDate()})
  },
  communications:{
    list:()=>read('comunicaciones',`select=*&${filterClub()}&order=creado_en.desc&limit=1000`),
    uploadImage:(file)=>uploadPublicImage('communications',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('publicacion.guardar',{id:p.id||null,tipo:p.tipo||'noticia',titulo:p.titulo,cuerpo:p.cuerpo,audiencia:p.audiencia||'todos',estado:p.estado||'borrador',evento_fecha:p.evento_fecha||null,ubicacion:p.ubicacion||'',imagen_url:p.imagen_url||''}),
    async delete(publicacion_id){const out=await mutation('publicacion.eliminar',{publicacion_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;},
    async cleanupOld(antes_de,incluir_publicadas=false){const out=await mutation('publicacion.limpiar_antiguas',{antes_de,incluir_publicadas:incluir_publicadas===true});await removePublicImages(out?.image_urls||[]);return out;}
  },
  material:{
    list:()=>read('material_catalogo',`select=*&${filterClub()}&order=orden,nombre`), variants:()=>read('material_variantes',`select=*&${filterClub()}&order=material_id,talla,color`), orders:()=>read('material_pedidos',`select=*&${filterClub()}&order=creado_en.desc&limit=1000`),
    uploadImage:(file)=>uploadPublicImage('material',file), removeImage:(url)=>removePublicImage(url),
    save:(p)=>mutation('material.guardar',{id:p.id||null,disciplina_id:p.disciplina_id||null,nombre:p.nombre,categoria:p.categoria||'',descripcion:p.descripcion||'',imagen_url:p.imagen_url||'',precio:Number(p.precio||0),stock:Number(p.stock||0),obligatorio:p.obligatorio===true,referencia:p.referencia||'',activo:p.activo!==false}),
    saveVariant:(p)=>mutation('material.variante.guardar',{id:p.id||null,material_id:p.material_id,talla:p.talla||'',color:p.color||'',referencia:p.referencia||'',stock:Number(p.stock||0),activa:p.activa!==false}),
    request:(p)=>mutation('material.solicitar',{socio_id:p.socio_id,material_id:p.material_id,variante_id:p.variante_id||null,cantidad:Number(p.cantidad||1),observaciones:p.observaciones||''}),
    orderStatus:(pedido_id,estado)=>mutation('material.pedido.estado',{pedido_id,estado}),
    async delete(material_id){const out=await mutation('material.eliminar',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}, async forceDelete(material_id){const out=await mutation('material.eliminar_forzado',{material_id});if(out?.imagen_url)await removePublicImage(out.imagen_url).catch(()=>{});return out;}
  },
  notifications:{
    list:()=>notificationList(500), markRead:(notificacion_id)=>mutation('notificacion.leer',{notificacion_id}),
    markGroup:(tipo)=>mutation('notificacion.leer_grupo',{tipo}), markAll:()=>mutation('notificacion.leer_todas',{}),
    preferences:()=>read('preferencias_notificacion',`select=*&${filterClub()}&perfil_id=eq.${enc(session()?.id)}&limit=1`),
    savePreferences:(p)=>mutation('notificaciones.preferencias',{push_general:p.push_general!==false,push_finanzas:p.push_finanzas!==false,push_sesiones:p.push_sesiones!==false,push_comunidad:p.push_comunidad===true})
  },
  users:{
    members:()=>read('miembros_club',`select=*,perfiles(id,nombre,apellidos,telefono)&${filterClub()}&order=creado_en`), invitations:()=>read('invitaciones_club',`select=*&${filterClub()}&order=creado_en.desc`),
    invite:(email,rol)=>mutation('invitacion.crear',{email,rol})
  },
  portal:{
    visibleMembers:()=>read('socios',`select=*&${filterClub()}&order=apellidos,nombre`),
    enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc`),
    graduations:()=>read('graduaciones',`select=*&${filterClub()}&order=fecha.desc&limit=500`),
    schedules:()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`),
    sessions:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&order=fecha.desc,hora_inicio.desc&limit=500`),
    reservations:()=>read('reservas_sesion',`select=*&${filterClub()}&order=creado_en.desc&limit=3000`),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&order=registrado_en.desc&limit=2000`),
    tracking:()=>read('seguimiento',`select=*&${filterClub()}&order=fecha.desc,creado_en.desc&limit=500`),
    documents:()=>read('documentos_socios',`select=*&${filterClub()}&visible_familia=eq.true&order=creado_en.desc&limit=500`),
    fees:()=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=1000`),
    payments:()=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=1000`),
    receipts:()=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=1000`),
    communications:()=>read('comunicaciones',`select=*&${filterClub()}&estado=in.(publicada,programada)&order=publicada_en.desc,creado_en.desc&limit=200`),
    notifications:()=>notificationList(300),
    requestMinor:(p)=>mutation('preinscripcion.crear',{tipo_solicitud:'menor',nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,tutor_nombre:p.tutor_nombre||'',tutor_email:p.tutor_email||'',telefono:p.telefono||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,tarifa_id:p.tarifa_id||null,parentesco:p.parentesco||null,observaciones:p.observaciones||null}),
    requestEnrollment:(socio_id,disciplina_id,grupo_id,tarifa_id)=>mutation('matricula.solicitar',{socio_id,disciplina_id,grupo_id,tarifa_id:tarifa_id||null}),
    reserveSession:(sesion_id,socio_id)=>mutation('sesion.reserva.confirmar',{sesion_id,socio_id}),
    cancelSessionReservation:(sesion_id,socio_id)=>mutation('sesion.reserva.cancelar',{sesion_id,socio_id}),
    checkin:(sesion_id,socio_id,codigo='')=>mutation('checkin.registrar',{sesion_id,socio_id,codigo,metodo:'codigo'})
  },
  settings:{
    club:()=>read('clubes',`select=*&id=eq.${enc(session()?.club_id)}&limit=1`), config:()=>read('config_club',`select=*&${filterClub()}`),
    uploadBrandImage:(kind,file)=>uploadPublicImage(kind==='cover'?'branding-cover':'branding-logo',file), removeBrandImage:(url)=>removePublicImage(url),
    saveClub:(p)=>mutation('club.configurar',p), profile:(p)=>mutation('perfil.guardar',{nombre:p.nombre||'',apellidos:p.apellidos||'',telefono:p.telefono||''}),
    async uploadAvatar(file){if(!file||!file.size)throw new Error('Selecciona una imagen.');if(file.size>5*1024*1024)throw new Error('La foto supera 5 MB.');if(!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Usa JPG, PNG o WEBP.');const ext=file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg';const path=`${session().club_id}/${session().id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;await backend.upload('profile-media',path,file,false);try{const out=await mutation('perfil.avatar',{avatar_path:path});if(out?.old_avatar_path)await backend.remove('profile-media',out.old_avatar_path).catch(()=>{});return out;}catch(e){await backend.remove('profile-media',path).catch(()=>{});throw e;}},
    async removeAvatar(){const out=await mutation('perfil.avatar',{avatar_path:null});if(out?.old_avatar_path)await backend.remove('profile-media',out.old_avatar_path).catch(()=>{});return out;},
    avatarUrl:(path)=>path?backend.signedUrl('profile-media',path,3600):Promise.resolve('')
  },
  community:{
    list:()=>read('publicaciones_comunidad',`select=*&${filterClub()}&order=creado_en.desc&limit=250`),
    async quota(){const rows=await read('publicaciones_comunidad',`select=id,autor_perfil_id,creado_en&${filterClub()}&autor_perfil_id=eq.${enc(session()?.id)}&creado_en=gte.${enc(new Date(new Date().getFullYear(),new Date().getMonth(),1).toISOString())}&limit=20`);const staff=['direccion','coordinacion','secretaria','comunicacion'].includes(session()?.rol);return {used:rows.length,limit:staff?5:3};},
    async upload(file){if(!file||!file.size)throw new Error('Selecciona una imagen o vídeo.');const isVideo=String(file.type||'').startsWith('video/');const allowedImage=['image/jpeg','image/png','image/webp'];const allowedVideo=['video/mp4','video/webm','video/quicktime'];if(!(isVideo?allowedVideo:allowedImage).includes(file.type))throw new Error('Formato no admitido. Usa JPG, PNG, WEBP, MP4, WEBM o MOV.');if(file.size>(isVideo?20:5)*1024*1024)throw new Error(isVideo?'El vídeo supera 20 MB.':'La imagen supera 5 MB.');const ext=(file.name.split('.').pop()|| (isVideo?'mp4':'jpg')).replace(/[^a-z0-9]/gi,'').toLowerCase();const path=`${session().club_id}/${session().id}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;await backend.upload('community-media',path,file,false);return path;},
    mediaUrl:(path)=>backend.signedUrl('community-media',path,3600),
    publish:(p)=>mutation('comunidad.publicar',{texto:p.texto||'',media_path:p.media_path,media_tipo:p.media_tipo,duracion_segundos:p.duracion_segundos||null}),
    async delete(publicacion_id){const out=await mutation('comunidad.eliminar',{publicacion_id});if(out?.media_path)await backend.remove('community-media',out.media_path).catch(()=>{});return out;},
    moderate:(publicacion_id,oculta=true,motivo='')=>mutation('comunidad.moderar',{publicacion_id,oculta,motivo})
  },
  legal:{
    docs:()=>read('textos_legales',`select=*&${filterClub()}&vigente=eq.true&order=tipo`),
    accept:(tipo,version='2.0.0',aceptado=true,socio_id=null)=>mutation('legal.aceptar',{tipo,version,aceptado,socio_id,user_agent:navigator.userAgent}),
    acceptances:()=>read('aceptaciones_legales',`select=*&${filterClub()}&perfil_id=eq.${enc(session()?.id)}&order=aceptado_en.desc`)
  },
  documents:{
    list:()=>read('documentos_socios',`select=*&${filterClub()}&order=creado_en.desc&limit=2000`),
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
