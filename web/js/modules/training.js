import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt, isoDate } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));
const isDirection=()=>((state.session?.roles?.length?state.session.roles:[state.session?.rol]).filter(Boolean)).includes('direccion');
const forceConfirm=(title,subtitle,onConfirm)=>openForm({title,subtitle:`${subtitle} Escribe ELIMINAR para confirmar.`,fields:[{name:'confirmacion',label:'Confirmación',required:true,placeholder:'ELIMINAR'}],submitText:'Eliminar todo definitivamente',onSubmit:async v=>{if(String(v.confirmacion||'').trim().toUpperCase()!=='ELIMINAR')throw new Error('Escribe ELIMINAR exactamente para confirmar.');return onConfirm();}});

export async function renderSessions(){
  setMainHtml('<div class="loading-card">Cargando sesiones…</div>');
  try{
    const [sessions,groups,reservations]=await Promise.all([repos.sessions.list(),repos.groups.list(),repos.sessions.reservations()]);const can=has(state.session,'session');
    const rows=sessions.map(s=>{const g=groups.find(x=>x.id===s.grupo_id);const confirmed=reservations.filter(r=>r.sesion_id===s.id&&r.estado==='confirmada').length;return `<tr><td>${dateFmt(s.fecha)}<br><small>${esc(String(s.hora_inicio||'').slice(0,5))}${s.hora_fin?`–${esc(String(s.hora_fin).slice(0,5))}`:''}</small></td><td><strong>${esc(g?.nombre||'—')}</strong></td><td>${esc(s.monitor_nombre||'—')}</td><td>${badge(s.estado,s.estado==='completada'?'ok':s.estado==='cancelada'?'danger':s.estado==='en_curso'?'warn':'neutral')}</td><td><strong>${confirmed}</strong>${g?.plazas?` / ${esc(g.plazas)}`:''}<br><small>confirmados</small></td><td>${can?`<div class="row-actions"><button class="btn btn-ghost btn-sm edit-session" data-id="${esc(s.id)}">Editar</button>${s.estado!=='cancelada'?`<button class="btn btn-ghost btn-sm cancel-session" data-id="${esc(s.id)}">Cancelar</button>`:''}<button class="btn btn-danger btn-sm delete-session" data-id="${esc(s.id)}">Eliminar</button>${isDirection()?`<button class="btn btn-danger btn-sm force-delete-session" data-id="${esc(s.id)}">Eliminar todo</button>`:''}</div>`:''}</td></tr>`});
    setMainHtml(`${pageHeader('Sesiones','Programación de entrenamientos y confirmaciones previas',can?'<button class="btn btn-primary" id="new-session">Nueva sesión</button>':'')}${card('Sesiones',rows.length?table(['Fecha','Grupo','Monitor','Estado','Reservas','Acciones'],rows):empty('Sin sesiones'))}`);
    const fields=[{name:'grupo_id',label:'Grupo',type:'select',required:true,options:options(groups.filter(g=>g.activo))},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'hora_inicio',label:'Inicio',type:'time',required:true},{name:'hora_fin',label:'Fin',type:'time'},{name:'monitor_nombre',label:'Monitor/a'},{name:'estado',label:'Estado',type:'select',required:true,options:['programada','en_curso','completada','cancelada'].map(x=>({value:x,label:x}))},{name:'codigo_acceso',label:'Código de acceso'},{name:'observacion_general',label:'Observación',type:'textarea',full:true}];
    const reload=()=>renderSessions();const open=(s={fecha:isoDate(),estado:'programada'})=>openForm({title:s.id?'Editar sesión':'Nueva sesión',fields,initial:s,onSubmit:async v=>{await repos.sessions.save({...s,...v,id:s.id||null});toast('Sesión guardada');await reload();}});
    document.getElementById('new-session')?.addEventListener('click',()=>open());bind('.edit-session',id=>open(sessions.find(x=>x.id===id)));
    bind('.cancel-session',id=>{const s=sessions.find(x=>x.id===id);confirmDialog('Cancelar sesión','Se conserva la sesión y su histórico, pero deja de estar activa.',async()=>{await repos.sessions.save({...s,estado:'cancelada'});toast('Sesión cancelada');await reload();},{confirmText:'Cancelar sesión'});});
    bind('.delete-session',id=>confirmDialog('Eliminar sesión','Se elimina si no tiene asistencia ni check-ins. El Gestor de la app puede borrar también el histórico con “Eliminar todo”.',async()=>{await repos.sessions.delete(id);toast('Sesión eliminada');await reload();},{confirmText:'Eliminar',danger:true}));
    bind('.force-delete-session',id=>forceConfirm('Eliminar sesión e histórico','Se borrarán también asistencias, reservas y check-ins registrados en esta sesión.',async()=>{await repos.sessions.forceDelete(id);toast('Sesión e histórico eliminados');await reload();}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Sesiones')} ${empty('No se pudieron cargar las sesiones',e.message)}`)}
}

export async function renderAttendance(){
  setMainHtml('<div class="loading-card">Cargando asistencia…</div>');
  try{
    const [sessions,groups,members,enrollments,attendance,reservations]=await Promise.all([repos.sessions.list(),repos.groups.list(),repos.members.list(),repos.members.enrollments(),repos.sessions.attendance(),repos.sessions.reservations()]);
    const activeSessions=sessions.slice(0,60);const canAttendance=has(state.session,'attendance'),canCheckin=has(state.session,'checkin');
    const sessionOptions=activeSessions.map(s=>({value:s.id,label:`${String(s.fecha).slice(0,10)} · ${groups.find(g=>g.id===s.grupo_id)?.nombre||'Grupo'} · ${String(s.hora_inicio||'').slice(0,5)}`}));
    const selected=activeSessions[0]?.id||'';
    setMainHtml(`${pageHeader('Asistencia','Confirmación previa + presencia real mediante check-in')}${card('Selecciona sesión',`<div class="field"><label>Sesión</label><select id="attendance-session"><option value="">Selecciona</option>${sessionOptions.map(o=>`<option value="${esc(o.value)}" ${o.value===selected?'selected':''}>${esc(o.label)}</option>`).join('')}</select></div><div id="attendance-board" style="margin-top:16px"></div>`)}`);
    const board=document.getElementById('attendance-board');
    const draw=(sid)=>{
      const ses=sessions.find(s=>s.id===sid);if(!ses){board.innerHTML=empty('Selecciona una sesión');return;}
      const ids=new Set(enrollments.filter(e=>e.grupo_id===ses.grupo_id&&e.activa).map(e=>e.socio_id));const list=members.filter(m=>ids.has(m.id));const confirmedCount=reservations.filter(r=>r.sesion_id===sid&&r.estado==='confirmada').length;const g=groups.find(x=>x.id===ses.grupo_id);
      const rows=list.map(m=>{const a=attendance.find(x=>x.sesion_id===sid&&x.socio_id===m.id);const r=reservations.find(x=>x.sesion_id===sid&&x.socio_id===m.id);return `<tr><td><strong>${esc(m.apellidos)}, ${esc(m.nombre)}</strong></td><td>${badge(r?.estado==='confirmada'?'Confirmada':r?.estado==='cancelada'?'Cancelada':'Sin confirmar',r?.estado==='confirmada'?'ok':r?.estado==='cancelada'?'danger':'neutral')}</td><td>${badge(a?.estado||'pendiente',a?.estado==='presente'?'ok':a?.estado==='ausente'?'danger':a?.estado==='retraso'?'warn':'neutral')}</td><td><div class="row-actions">${canAttendance?['presente','ausente','ausencia_justificada','retraso'].map(st=>`<button class="btn btn-ghost btn-sm set-att" data-id="${esc(m.id)}" data-status="${st}">${esc(st)}</button>`).join(''):''}${canCheckin?`<button class="btn btn-primary btn-sm do-checkin" data-id="${esc(m.id)}">Check-in</button>`:''}</div></td></tr>`});
      board.innerHTML=`<div class="metrics" style="margin-bottom:14px"><div class="metric"><span>Confirmados</span><strong>${confirmedCount}${g?.plazas?`/${g.plazas}`:''}</strong><small>han indicado que asistirán</small></div><div class="metric"><span>Matriculados</span><strong>${list.length}</strong><small>en el grupo</small></div></div>${rows.length?table(['Alumno','Reserva','Asistencia','Acciones'],rows):empty('Sin alumnos matriculados en este grupo')}`;
      board.querySelectorAll('.set-att').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.sessions.saveAttendance({sesion_id:sid,socio_id:b.dataset.id,estado:b.dataset.status});toast('Asistencia guardada');await renderAttendance();}catch(e){setError(e);b.disabled=false;}}));
      board.querySelectorAll('.do-checkin').forEach(b=>b.addEventListener('click',()=>openForm({title:'Registrar check-in',fields:[{name:'codigo',label:'Código (si aplica)'},{name:'metodo',label:'Método',type:'select',value:'manual',options:['manual','codigo','qr','nfc'].map(x=>({value:x,label:x}))}],onSubmit:async v=>{await repos.sessions.checkin({sesion_id:sid,socio_id:b.dataset.id,...v});toast('Check-in registrado');await renderAttendance();}})));
    };
    document.getElementById('attendance-session')?.addEventListener('change',e=>draw(e.target.value));draw(selected);
  }catch(e){setError(e);setMainHtml(`${pageHeader('Asistencia')} ${empty('No se pudo cargar la asistencia',e.message)}`)}
}

export async function renderTracking(){
  setMainHtml('<div class="loading-card">Cargando seguimiento…</div>');
  try{
    const [items,members]=await Promise.all([repos.tracking.list(),repos.members.list()]);const can=has(state.session,'tracking');
    const rows=items.map(x=>`<tr><td>${dateFmt(x.fecha)}</td><td><strong>${esc(members.find(m=>m.id===x.socio_id)?.nombre||'—')}</strong></td><td>${esc(x.tipo)}</td><td>${esc(x.nota)}</td><td>${badge(x.visibilidad,'neutral')}</td></tr>`);
    setMainHtml(`${pageHeader('Seguimiento','Notas educativas y evolución',can?'<button class="btn btn-primary" id="new-tracking">Nueva nota</button>':'')}${card('Registros',rows.length?table(['Fecha','Alumno','Tipo','Nota','Visibilidad'],rows):empty('Sin registros de seguimiento'))}`);
    document.getElementById('new-tracking')?.addEventListener('click',()=>openForm({title:'Nueva nota de seguimiento',fields:[{name:'socio_id',label:'Alumno',type:'select',required:true,options:options(members,m=>`${m.apellidos}, ${m.nombre}`)},{name:'fecha',label:'Fecha',type:'date',value:isoDate(),required:true},{name:'tipo',label:'Tipo',required:true,placeholder:'progreso, conducta, objetivo…'},{name:'visibilidad',label:'Visibilidad',type:'select',value:'equipo',options:['equipo','direccion_monitor','familia'].map(x=>({value:x,label:x}))},{name:'nota',label:'Nota',type:'textarea',full:true,required:true}],onSubmit:async v=>{await repos.tracking.save(v);toast('Seguimiento guardado');await renderTracking();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Seguimiento')} ${empty('No se pudo cargar el seguimiento',e.message)}`)}
}


export async function renderProgress(){
  setMainHtml('<div class="loading-card">Cargando progreso…</div>');
  try{
    const rowsData=await repos.progress.list();
    const rows=rowsData.map(x=>{
      const total=Number(x.asistencias_registradas||0),present=Number(x.asistencias_presentes||0);
      const pct=total?Math.round((present/total)*100):0;
      return `<tr><td><strong>${esc(x.apellidos||'')}, ${esc(x.nombre||'')}</strong></td><td>${esc(x.grado_actual||'—')}</td><td>${present}/${total}${total?` · ${pct}%`:''}</td><td>${dateFmt(x.ultima_graduacion)}</td><td>${esc(x.observaciones_seguimiento||0)}</td></tr>`;
    });
    setMainHtml(`${pageHeader('Progreso','Vista calculada desde asistencia, graduaciones y seguimiento')}${card('Evolución',rows.length?table(['Alumno','Grado actual','Asistencia','Última graduación','Observaciones'],rows):empty('Sin datos de progreso'))}`);
  }catch(e){setError(e);setMainHtml(`${pageHeader('Progreso')} ${empty('No se pudo cargar el progreso',e.message)}`)}
}
