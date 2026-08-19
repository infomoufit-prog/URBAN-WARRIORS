import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt, isoDate, weekRange, sortSessionsForWeek } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));
const isDirection=()=>((state.session?.roles?.length?state.session.roles:[state.session?.rol]).filter(Boolean)).includes('direccion');
let sessionWeekOffset=0;
const weekTitle=(offset,start,end)=>offset===0?'Esta semana':offset===1?'Semana siguiente':offset===-1?'Semana anterior':`${dateFmt(start)} – ${dateFmt(end)}`;
const forceConfirm=(title,subtitle,onConfirm)=>openForm({title,subtitle:`${subtitle} Escribe ELIMINAR para confirmar.`,fields:[{name:'confirmacion',label:'Confirmación',required:true,placeholder:'ELIMINAR'}],submitText:'Eliminar todo definitivamente',onSubmit:async v=>{if(String(v.confirmacion||'').trim().toUpperCase()!=='ELIMINAR')throw new Error('Escribe ELIMINAR exactamente para confirmar.');return onConfirm();}});

export async function renderSessions(){
  setMainHtml('<div class="loading-card">Cargando sesiones…</div>');
  try{
    const [sessions,groups,reservations,series]=await Promise.all([
      repos.sessions.list(),repos.groups.list(),repos.sessions.reservations(),repos.sessions.series().catch(()=>[])
    ]);
    const can=has(state.session,'session');
    const dayName=n=>({1:'Lun',2:'Mar',3:'Mié',4:'Jue',5:'Vie',6:'Sáb',7:'Dom'})[Number(n)]||String(n);
    const seriesRows=series.map(sr=>{
      const g=groups.find(x=>x.id===sr.grupo_id);
      const actions=can&&sr.activa?`<div class="row-actions"><button class="btn btn-ghost btn-sm edit-series" data-id="${esc(sr.id)}">Editar serie</button><button class="btn btn-ghost btn-sm end-series" data-id="${esc(sr.id)}">Finalizar</button></div>`:'';
      return `<tr><td><strong>${esc(g?.nombre||'—')}</strong></td><td>${(sr.dias_semana||[]).map(dayName).join(' · ')}</td><td>${esc(String(sr.hora_inicio||'').slice(0,5))}${sr.hora_fin?'–'+esc(String(sr.hora_fin).slice(0,5)):''}</td><td>${esc(sr.monitor_nombre||'—')}</td><td>${badge(sr.activa?'Activa':'Finalizada',sr.activa?'ok':'neutral')}</td><td>${actions}</td></tr>`;
    });
    const range=weekRange(sessionWeekOffset);const weekSessions=sortSessionsForWeek(sessions.filter(se=>String(se.fecha)>=range.start&&String(se.fecha)<=range.end),sessionWeekOffset);
    const rows=weekSessions.map(se=>{
      const g=groups.find(x=>x.id===se.grupo_id);const confirmed=reservations.filter(r=>r.sesion_id===se.id&&r.estado==='confirmada').length;
      let actions='';
      if(can){actions='<div class="row-actions">';if(!se.serie_id)actions+=`<button class="btn btn-ghost btn-sm edit-session" data-id="${esc(se.id)}">Editar</button>`;actions+=`<button class="btn btn-ghost btn-sm exception-session" data-id="${esc(se.id)}">Cambios / cancelar</button><button class="btn btn-danger btn-sm delete-session" data-id="${esc(se.id)}">Eliminar</button>`;if(isDirection())actions+=`<button class="btn btn-danger btn-sm force-delete-session" data-id="${esc(se.id)}">Eliminar todo</button>`;actions+='</div>';}
      return `<tr><td>${dateFmt(se.fecha)}<br><small>${esc(String(se.hora_inicio||'').slice(0,5))}${se.hora_fin?'–'+esc(String(se.hora_fin).slice(0,5)):''}</small></td><td><strong>${esc(g?.nombre||'—')}</strong>${se.serie_id?'<br><small>Recurrente</small>':''}</td><td>${esc(se.monitor_nombre||'—')}${se.sala?'<br><small>'+esc(se.sala)+'</small>':''}</td><td>${badge(se.estado,se.estado==='completada'?'ok':se.estado==='cancelada'?'danger':se.estado==='en_curso'?'warn':'neutral')}</td><td><strong>${confirmed}</strong>${g?.plazas?' / '+esc(g.plazas):''}<br><small>confirmados</small></td><td>${actions}</td></tr>`;
    });
    const headerActions=can?'<button class="btn btn-primary" id="new-series">Nueva serie semanal</button> <button class="btn btn-ghost" id="new-session">Sesión puntual</button>':'';
    const weekActions=`<div class="week-nav"><button class="btn btn-ghost btn-sm" id="session-week-prev">← Semana anterior</button><button class="btn btn-ghost btn-sm" id="session-week-current" ${sessionWeekOffset===0?'disabled':''}>Esta semana</button><button class="btn btn-ghost btn-sm" id="session-week-next">Semana siguiente →</button></div>`;
    const weekSummary=`<div class="week-summary"><strong>${esc(weekTitle(sessionWeekOffset,range.start,range.end))}</strong><span>${dateFmt(range.start)} – ${dateFmt(range.end)} · ${weekSessions.length} ${weekSessions.length===1?'sesión':'sesiones'}</span></div>`;
    setMainHtml(`${pageHeader('Sesiones','Organización semanal de sesiones, excepciones y confirmaciones previas',headerActions)}${card('Sesiones recurrentes',seriesRows.length?table(['Grupo','Días','Hora','Monitor','Estado','Acciones'],seriesRows):empty('Sin series recurrentes','Crea una clase semanal y KOMBAX mantendrá 12 semanas futuras generadas automáticamente.'))}${weekSummary}${card('Sesiones de la semana',rows.length?table(['Fecha','Grupo','Monitor / sala','Estado','Reservas','Acciones'],rows):empty('Sin sesiones esta semana','Usa Semana anterior / siguiente para revisar otras semanas.'),weekActions)}`);

    const fields=[{name:'grupo_id',label:'Grupo',type:'select',required:true,options:options(groups.filter(g=>g.activo))},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'hora_inicio',label:'Inicio',type:'time',required:true},{name:'hora_fin',label:'Fin',type:'time'},{name:'monitor_nombre',label:'Monitor/a'},{name:'estado',label:'Estado',type:'select',required:true,options:['programada','en_curso','completada','cancelada'].map(x=>({value:x,label:x}))},{name:'codigo_acceso',label:'Código de acceso'},{name:'observacion_general',label:'Observación',type:'textarea',full:true}];
    const reload=()=>renderSessions();
    const openSession=(se={fecha:isoDate(),estado:'programada'})=>openForm({title:se.id?'Editar sesión':'Nueva sesión puntual',fields,initial:se,onSubmit:async v=>{await repos.sessions.save({...se,...v,id:se.id||null});toast('Sesión guardada');await reload();}});
    const openSeries=(sr={})=>{
      const f=[{name:'grupo_id',label:'Grupo',type:'select',required:true,options:options(groups.filter(g=>g.activo))},{name:'fecha_inicio',label:'Inicio de la serie',type:'date',required:true,value:sr.fecha_inicio||isoDate()},{name:'fecha_fin',label:'Fin opcional',type:'date'},{name:'hora_inicio',label:'Hora de inicio',type:'time',required:true},{name:'hora_fin',label:'Hora de fin',type:'time'},{name:'monitor_nombre',label:'Monitor/a'},{name:'sala',label:'Sala'}];
      ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'].forEach((label,i)=>f.push({name:`d${i+1}`,label,type:'checkbox',value:(sr.dias_semana||[]).includes(i+1)}));
      openForm({title:sr.id?'Editar serie semanal':'Nueva serie semanal',subtitle:'Los cambios de una fecha concreta no alteran el resto de la serie.',width:'780px',fields:f,initial:{...sr,...Object.fromEntries([1,2,3,4,5,6,7].map(d=>[`d${d}`,(sr.dias_semana||[]).includes(d)]))},submitText:'Guardar serie',onSubmit:async v=>{const dias=[1,2,3,4,5,6,7].filter(d=>v[`d${d}`]);if(!dias.length)throw new Error('Selecciona al menos un día de la semana.');await repos.sessions.saveSeries({...sr,...v,dias_semana:dias,id:sr.id||null});toast('Serie semanal guardada y próximas sesiones generadas');await reload();}});
    };
    document.getElementById('new-session')?.addEventListener('click',()=>openSession());document.getElementById('new-series')?.addEventListener('click',()=>openSeries());
    document.getElementById('session-week-prev')?.addEventListener('click',()=>{sessionWeekOffset-=1;renderSessions();});document.getElementById('session-week-current')?.addEventListener('click',()=>{sessionWeekOffset=0;renderSessions();});document.getElementById('session-week-next')?.addEventListener('click',()=>{sessionWeekOffset+=1;renderSessions();});
    bind('.edit-session',id=>openSession(sessions.find(x=>x.id===id)));bind('.edit-series',id=>openSeries(series.find(x=>x.id===id)));
    bind('.end-series',id=>confirmDialog('Finalizar serie','No se crearán nuevas sesiones después de hoy. Las sesiones ya generadas conservan su histórico.',async()=>{await repos.sessions.endSeries(id);toast('Serie finalizada');await reload();},{confirmText:'Finalizar serie'}));
    bind('.exception-session',id=>{const se=sessions.find(x=>x.id===id);openForm({title:'Cambio en esta sesión',subtitle:'Afecta solo a esta fecha y se notificará a alumnos/familias del grupo.',fields:[{name:'estado',label:'Estado',type:'select',required:true,value:se.estado,options:['programada','en_curso','completada','cancelada'].map(x=>({value:x,label:x}))},{name:'monitor_nombre',label:'Monitor/a',value:se.monitor_nombre||''},{name:'hora_inicio',label:'Hora inicio',type:'time',value:String(se.hora_inicio||'').slice(0,5)},{name:'hora_fin',label:'Hora fin',type:'time',value:String(se.hora_fin||'').slice(0,5)},{name:'sala',label:'Sala',value:se.sala||''},{name:'motivo',label:'Motivo / aviso',type:'textarea',full:true,placeholder:'Salud, sustitución, festivo, cambio de sala…'}],submitText:'Guardar y notificar',onSubmit:async v=>{await repos.sessions.exception({sesion_id:id,...v});toast('Cambio guardado y notificado');await reload();}})});
    bind('.delete-session',id=>confirmDialog('Eliminar sesión','Se elimina si no tiene asistencia ni check-ins. Para conservar histórico usa “Cambios / cancelar”.',async()=>{await repos.sessions.delete(id);toast('Sesión eliminada');await reload();},{confirmText:'Eliminar',danger:true}));
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
