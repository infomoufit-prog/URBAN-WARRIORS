import { backend } from './backend.js';
import { state } from './state.js';
import { isoDate, monthStart } from './utils.js';

const enc=(v)=>encodeURIComponent(String(v??''));
const session=()=>state.session;
const filterClub=()=>`club_id=eq.${enc(session()?.club_id)}`;

async function read(table,query){return backend.select(table,query)}
async function mutation(op,payload){return backend.mutate(op,payload)}

export const repos={
  dashboard:{
    async load(){
      const c=session()?.club_id; const q=`club_id=eq.${enc(c)}`;
      const safe=async(table,query)=>{try{return await read(table,query)}catch{return[]}};
      const [disc,groups,members,fees,sessions,notifs]=await Promise.all([
        safe('disciplinas',`select=id,activa&${q}`),safe('grupos',`select=id,activo&${q}`),safe('socios',`select=id,estado&${q}`),
        safe('cuotas',`select=id,estado,importe&${q}&order=vencimiento.desc&limit=1000`),safe('sesiones_entrenamiento',`select=id,fecha,estado&${q}&order=fecha.desc&limit=100`),safe('notificaciones',`select=id,leida&${q}&order=creado_en.desc&limit=100`)
      ]);
      return {disc,groups,members,fees,sessions,notifs};
    }
  },
  catalog:{
    disciplines:()=>read('disciplinas',`select=*&${filterClub()}&order=orden,nombre`),
    grades:()=>read('grados',`select=*&${filterClub()}&order=disciplina_id,orden,nombre`),
    saveDiscipline:(p)=>mutation('disciplina.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',color:p.color||'#ffffff',activa:p.activa!==false,orden:Number(p.orden||0)}),
    saveGrade:(p)=>mutation('grado.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,orden:Number(p.orden||1),color:p.color||null,meses_minimos:p.meses_minimos===''||p.meses_minimos==null?null:Number(p.meses_minimos),activo:p.activo!==false})
  },
  groups:{
    list:()=>read('grupos',`select=*&${filterClub()}&order=nombre`), schedules:()=>read('horarios_grupo',`select=*&${filterClub()}&order=dia_semana,hora_inicio`),
    save:(p)=>mutation('grupo.guardar',{id:p.id||null,disciplina_id:p.disciplina_id,nombre:p.nombre,monitor_nombre:p.monitor_nombre||'',sala:p.sala||'',edad_min:p.edad_min===''?null:Number(p.edad_min),edad_max:p.edad_max===''?null:Number(p.edad_max),plazas:p.plazas===''?null:Number(p.plazas),activo:p.activo!==false,horarios:p.horarios||[]})
  },
  members:{
    list:()=>read('socios',`select=*&${filterClub()}&order=apellidos,nombre`), enrollments:()=>read('socio_disciplinas',`select=*&${filterClub()}&order=fecha_inicio.desc`), tutors:()=>read('tutores_socios',`select=*&${filterClub()}`),
    save:(p)=>mutation('alumno.guardar',{id:p.id||null,nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,telefono:p.telefono||'',email:p.email||'',tutor_nombre:p.tutor_nombre||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,grado_id:p.grado_id||null,grado_texto:p.grado_texto||'',tarifa_id:p.tarifa_id||null,estado:p.estado||'activo',contacto_emergencia:p.contacto_emergencia||'',telefono_emergencia:p.telefono_emergencia||'',notas_internas:p.notas_internas||''}),
    requestEnrollment:(socio_id,disciplina_id,grupo_id,tarifa_id)=>mutation('matricula.solicitar',{socio_id,disciplina_id,grupo_id,tarifa_id:tarifa_id||null}),
    deactivateEnrollment:(matricula_id)=>mutation('matricula.desactivar',{matricula_id}),
    graduation:(p)=>mutation('graduacion.registrar',{socio_id:p.socio_id,disciplina_id:p.disciplina_id,grado_id:p.grado_id,fecha:p.fecha||isoDate(),examinador:p.examinador||'',nota:p.nota||''})
  },
  preenrollments:{
    list:()=>read('preinscripciones',`select=*&${filterClub()}&order=creado_en.desc`),
    create:(p)=>mutation('preinscripcion.crear',{tipo_solicitud:p.tipo_solicitud||'adulto',nombre:p.nombre,apellidos:p.apellidos,fecha_nacimiento:p.fecha_nacimiento||null,tutor_nombre:p.tutor_nombre||'',tutor_email:p.tutor_email||'',telefono:p.telefono||'',disciplina_id:p.disciplina_id||null,grupo_id:p.grupo_id||null,tarifa_id:p.tarifa_id||null,parentesco:p.parentesco||null,observaciones:p.observaciones||null}),
    approve:(id)=>mutation('preinscripcion.aprobar',{preinscripcion_id:id}), wait:(id,motivo)=>mutation('preinscripcion.espera',{preinscripcion_id:id,motivo:motivo||null}), reject:(id,motivo)=>mutation('preinscripcion.rechazar',{preinscripcion_id:id,motivo:motivo||''})
  },
  tariffs:{
    list:()=>read('tarifas',`select=*&${filterClub()}&order=nombre`),
    save:(p)=>mutation('tarifa.guardar',{id:p.id||null,nombre:p.nombre,descripcion:p.descripcion||'',importe:Number(p.importe||0),matricula:Number(p.matricula||0),periodicidad:p.periodicidad||'mensual',activa:p.activa!==false})
  },
  finance:{
    fees:()=>read('cuotas',`select=*&${filterClub()}&order=vencimiento.desc&limit=1000`), payments:()=>read('pagos',`select=*&${filterClub()}&order=fecha.desc&limit=1000`), receipts:()=>read('recibos_cuota',`select=*&${filterClub()}&order=periodo.desc,numero.desc&limit=1000`),
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
    pause:(cuota_id,motivo,hasta)=>mutation('cuota.pausar_avisos',{cuota_id,motivo,hasta:hasta||null}), resume:(cuota_id)=>mutation('cuota.reactivar_avisos',{cuota_id})
  },
  reminders:{
    load:()=>read('configuracion_avisos_cuota',`select=*&${filterClub()}&limit=1`), history:()=>read('historial_avisos_cuota',`select=*&${filterClub()}&order=fecha_programada.desc&limit=250`),
    save:(p)=>mutation('avisos.configurar',{dias_aviso:p.dias_aviso,hora_envio:p.hora_envio||'10:00',canal_app:p.canal_app!==false,canal_push:p.canal_push!==false,canal_email:p.canal_email===true,agrupar_por_familia:p.agrupar_por_familia!==false,marcar_vencida_dia:Number(p.marcar_vencida_dia||15),zona_horaria:p.zona_horaria||'Europe/Madrid',activo:p.activo!==false}),
    process:(fecha=isoDate())=>mutation('avisos.procesar',{fecha})
  },
  sessions:{
    list:()=>read('sesiones_entrenamiento',`select=*&${filterClub()}&order=fecha.desc,hora_inicio.desc&limit=500`),
    save:(p)=>mutation('sesion.guardar',{id:p.id||null,grupo_id:p.grupo_id,fecha:p.fecha,hora_inicio:p.hora_inicio,hora_fin:p.hora_fin||null,monitor_nombre:p.monitor_nombre||'',estado:p.estado||'programada',observacion_general:p.observacion_general||'',codigo_acceso:p.codigo_acceso||''}),
    attendance:()=>read('asistencias',`select=*&${filterClub()}&order=registrado_en.desc&limit=2000`),
    saveAttendance:(p)=>mutation('asistencia.guardar',{sesion_id:p.sesion_id,socio_id:p.socio_id,estado:p.estado,observacion:p.observacion||null}),
    checkin:(p)=>mutation('checkin.registrar',{sesion_id:p.sesion_id,socio_id:p.socio_id,codigo:p.codigo||'',metodo:p.metodo||'manual'})
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
    save:(p)=>mutation('publicacion.guardar',{id:p.id||null,tipo:p.tipo||'noticia',titulo:p.titulo,cuerpo:p.cuerpo,audiencia:p.audiencia||'todos',estado:p.estado||'borrador',evento_fecha:p.evento_fecha||null,ubicacion:p.ubicacion||'',imagen_url:p.imagen_url||''})
  },
  material:{
    list:()=>read('material_catalogo',`select=*&${filterClub()}&order=orden,nombre`), variants:()=>read('material_variantes',`select=*&${filterClub()}&order=material_id,talla,color`), orders:()=>read('material_pedidos',`select=*&${filterClub()}&order=creado_en.desc&limit=1000`),
    save:(p)=>mutation('material.guardar',{id:p.id||null,disciplina_id:p.disciplina_id||null,nombre:p.nombre,categoria:p.categoria||'',descripcion:p.descripcion||'',imagen_url:p.imagen_url||'',precio:Number(p.precio||0),stock:Number(p.stock||0),obligatorio:p.obligatorio===true,referencia:p.referencia||'',activo:p.activo!==false}),
    saveVariant:(p)=>mutation('material.variante.guardar',{id:p.id||null,material_id:p.material_id,talla:p.talla||'',color:p.color||'',referencia:p.referencia||'',stock:Number(p.stock||0),activa:p.activa!==false}),
    request:(p)=>mutation('material.solicitar',{socio_id:p.socio_id,material_id:p.material_id,variante_id:p.variante_id||null,cantidad:Number(p.cantidad||1),observaciones:p.observaciones||''}),
    orderStatus:(pedido_id,estado)=>mutation('material.pedido.estado',{pedido_id,estado})
  },
  notifications:{
    list:()=>read('notificaciones',`select=*&${filterClub()}&order=creado_en.desc&limit=500`), markRead:(notificacion_id)=>mutation('notificacion.leer',{notificacion_id})
  },
  users:{
    members:()=>read('miembros_club',`select=*,perfiles(id,nombre,apellidos,telefono)&${filterClub()}&order=creado_en`), invitations:()=>read('invitaciones_club',`select=*&${filterClub()}&order=creado_en.desc`),
    invite:(email,rol)=>mutation('invitacion.crear',{email,rol})
  },
  settings:{
    club:()=>read('clubes',`select=*&id=eq.${enc(session()?.club_id)}&limit=1`), config:()=>read('config_club',`select=*&${filterClub()}`),
    saveClub:(p)=>mutation('club.configurar',p), profile:(p)=>mutation('perfil.guardar',{nombre:p.nombre||'',apellidos:p.apellidos||'',telefono:p.telefono||''})
  },
  documents:{
    list:()=>read('documentos_socios',`select=*&${filterClub()}&order=creado_en.desc&limit=1000`),
    async upload(socioId,file,meta={}){const ext=(file.name.split('.').pop()||'bin').replace(/[^a-z0-9]/gi,'').toLowerCase();const path=`${session().club_id}/${socioId}/${Date.now()}-${crypto.randomUUID?.()||Math.random().toString(36).slice(2)}.${ext}`;await backend.upload('member-documents',path,file,false);try{return await mutation('documento.registrar',{socio_id:socioId,nombre:meta.nombre||file.name,tipo:meta.tipo||'otro',storage_path:path,mime_type:file.type||null,tamano_bytes:file.size,visible_familia:meta.visible_familia!==false})}catch(e){throw e}},
    url:(path)=>backend.signedUrl('member-documents',path,600)
  }
};
