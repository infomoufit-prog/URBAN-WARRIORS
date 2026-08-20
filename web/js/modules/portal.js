import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dateFmt, money, isoDate, weekRange, sortSessionsForWeek } from '../core/utils.js';
import { pageHeader, hero, metric, card, empty, badge, openForm, openDetail, toast, setError, setMainHtml, profileSwitcher, progress, quickRow, table } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { renderOwnKombaxProfilePage } from './public-profile.js';
import { openAuthenticatedPasswordChange } from './account-security.js';

const DAYS=['','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
let portalWeekOffset=0;
const portalWeekTitle=(offset,start,end)=>offset===0?'Esta semana':offset===1?'Semana siguiente':offset===-1?'Semana anterior':`${dateFmt(start)} – ${dateFmt(end)}`;
function socialGeneralCardHtml(status){
  if(!status)return '';
  const stateText=status.status==='activa'?'Activada':status.status==='suspendida'?'Suspendida':'No activada';
  const tone=status.status==='activa'?'ok':status.status==='suspendida'?'warn':'neutral';
  const action=status.eligible&&!['activa','suspendida','cerrada'].includes(status.status)?'<button class="btn btn-primary btn-sm" id="activate-general-community">Activar KOMBAX Social</button>':'';
  const rules='<button class="btn btn-ghost btn-sm" id="view-general-community-rules">Ver normas</button>';
  const message=status.status==='activa'?'Tu identidad pública está activa. Ya puedes acceder al feed profesional desde KOMBAX Social.':status.reason||'Este servicio social es opcional y se activa por separado de las funciones del club.';
  return card('KOMBAX Social',`<div class="social-access-card"><div><span class="page-kicker">RED PROFESIONAL GLOBAL · SERVICIO OPCIONAL</span><div class="row-actions social-access-status">${badge(stateText,tone)}</div><p>${esc(message)}</p><small>La edad se comprueba con la fecha de nacimiento validada por el club. El expediente administrativo no se publica y el contacto personal exige 18 años.</small></div><div class="row-actions">${rules}${action}</div></div>`);
}

function showGeneralCommunityRules(rule){
  openDetail({title:'Normas de KOMBAX Social',subtitle:rule?`Versión ${rule.version}`:'Servicio social opcional',width:'760px',body:`<div class="legal-dialog-body">${esc(rule?.cuerpo||'Las normas específicas se mostrarán antes de activar el servicio.').replace(/\n/g,'<br>')}</div>`});
}

const PORTAL_DOC_TYPES=[
  {value:'inscripcion_asociacion',label:'Inscripción a la asociación'},
  {value:'autorizacion',label:'Autorización'},
  {value:'consentimiento',label:'Consentimiento'},
  {value:'certificado',label:'Certificado'},
  {value:'medico',label:'Documento médico'},
  {value:'identidad',label:'Documento identificativo'},
  {value:'otro',label:'Otro documento'}
];
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));
const activeMember=(members)=>{
  if(!members.length)return null;
  let selected=members.find(x=>String(x.id)===String(state.selectedSocioId));
  if(!selected){selected=members[0];state.selectSocio(selected.id)}
  return selected;
};
const memberBind=(members,rerender)=>document.querySelectorAll('[data-profile-id]').forEach(b=>b.addEventListener('click',()=>{state.selectSocio(b.dataset.profileId);rerender();}));
async function downloadPortalDocument(doc){const blob=await repos.documents.download(doc.storage_path);const href=URL.createObjectURL(blob);const a=document.createElement('a');a.href=href;a.download=doc.nombre||'documento';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(href),1500);}

async function loadPortalBase(){
  const [members,enrollments,disciplines,grades,groups]=await Promise.all([repos.portal.visibleMembers(),repos.portal.enrollments(),repos.catalog.disciplines(),repos.catalog.grades(),repos.groups.list()]);
  const member=activeMember(members);return {members,member,enrollments,disciplines,grades,groups};
}
async function loadPortalDashboard(){
  const base=await loadPortalBase();
  const [sessions,reservations,progressRows,fees,graduations,summaryRows]=await Promise.all([repos.portal.sessions(),repos.portal.reservations(),repos.progress.list(),repos.portal.fees(),repos.portal.graduations(),repos.notifications.headerSummary().catch(()=>[])]);
  const notificationSummary=Array.isArray(summaryRows)?(summaryRows[0]||{}):(summaryRows||{});
  return {...base,sessions,reservations,progressRows,fees,graduations,notificationSummary};
}
async function loadPortalSchedule(){
  const base=await loadPortalBase();
  const [schedules,sessions,reservations]=await Promise.all([repos.portal.schedules(),repos.portal.sessions(),repos.portal.reservations()]);
  return {...base,schedules,sessions,reservations};
}
async function loadPortalProfile(){
  const [members,grades,progressRows,tracking,documents,graduations]=await Promise.all([repos.portal.visibleMembers(),repos.catalog.grades(),repos.progress.list(),repos.portal.tracking(),repos.portal.documents(),repos.portal.graduations()]);
  const member=activeMember(members);return {members,member,grades,progressRows,tracking,documents,graduations};
}
function enrollmentSummary(d,member){
  if(!member)return {links:[],primary:null,discipline:null,group:null,grade:null};
  const links=d.enrollments.filter(x=>x.socio_id===member.id&&x.activa);const primary=links[0];
  return {links,primary,discipline:d.disciplines.find(x=>x.id===primary?.disciplina_id),group:d.groups.find(x=>x.id===primary?.grupo_id),grade:d.grades.find(x=>x.id===primary?.grado_id)};
}
function nextSession(d,groupIds){
  const today=isoDate();return d.sessions.filter(x=>groupIds.includes(x.grupo_id)&&x.estado!=='cancelada'&&String(x.fecha)>=today).sort((a,b)=>`${a.fecha} ${a.hora_inicio}`.localeCompare(`${b.fecha} ${b.hora_inicio}`))[0]||null;
}
function feeState(d,member){const list=d.fees.filter(x=>x.socio_id===member?.id);const open=list.find(x=>['vencida','pendiente','parcialmente_pagada'].includes(x.estado));return open||list[0]||null;}

export async function renderPortalDashboard(){
  setMainHtml('<div class="loading-card">Preparando tu espacio…</div>');
  try{
    const d=await loadPortalDashboard();if(!d.member){setMainHtml(`${pageHeader('Mi espacio','Tu actividad en tu club')}${empty('Todavía no hay un alumno vinculado','Cuando el club apruebe tu inscripción aparecerá aquí. Puedes enviar una nueva solicitud desde Solicitudes.')}`);return;}
    const rel=enrollmentSummary(d,d.member);const pr=d.progressRows.find(x=>x.socio_id===d.member.id)||{};const total=Number(pr.asistencias_registradas||0),present=Number(pr.asistencias_presentes||0),pct=total?Math.round(present/total*100):0;const ns=nextSession(d,rel.links.map(x=>x.grupo_id).filter(Boolean));const fee=feeState(d,d.member);const unread=Number(d.notificationSummary?.club_unread_items||0);
    const actions=`<button class="btn btn-primary" data-nav="groups">Ver horarios</button><button class="btn btn-ghost" data-nav="finance">Mensualidades</button>`;
    setMainHtml(`${profileSwitcher(d.members,d.member.id)}
      <div class="profile-hero">${hero({kicker:'Perfil seleccionado',title:`${d.member.nombre} ${d.member.apellidos||''}`,body:`${rel.discipline?.nombre||'Tu club'}${rel.group?` · ${rel.group.nombre}`:''}${pr.grado_actual?` · ${pr.grado_actual}`:''}`,actions,sideValue:`${pct}%`,sideLabel:'asistencia registrada'})}
        <div class="personal-kpis"><div class="personal-kpi"><span>Grado actual</span><strong>${esc(pr.grado_actual||'—')}</strong></div><div class="personal-kpi"><span>Próxima clase</span><strong>${esc(ns?`${dateFmt(ns.fecha)} · ${String(ns.hora_inicio||'').slice(0,5)}`:'—')}</strong></div><div class="personal-kpi"><span>Cuota</span><strong>${esc(fee?.estado||'Al día')}</strong></div><div class="personal-kpi"><span>Avisos</span><strong>${unread}</strong></div></div>
      </div>
      <div style="height:18px"></div>
      ${card('Acciones rápidas',`<div class="action-grid"><button class="action-tile" data-action="portal-checkin"><span>${icon('checkCircle')}</span><strong>Registrar acceso</strong><small>Check-in para una clase de hoy</small></button><button class="action-tile" data-nav="finance"><span>${icon('wallet')}</span><strong>Informar un pago</strong><small>Cuotas y justificantes</small></button><button class="action-tile" data-nav="material"><span>${icon('package')}</span><strong>Solicitar material</strong><small>Catálogo y pedidos</small></button><button class="action-tile" data-nav="requests"><span>${icon('plus')}</span><strong>Nueva solicitud</strong><small>Otro deporte, grupo o menor</small></button><button class="action-tile" data-nav="communications"><span>${icon('megaphone')}</span><strong>Comunicaciones</strong><small>Noticias y eventos del club</small></button><button class="action-tile" data-nav="profile"><span>${icon('chart')}</span><strong>Mi perfil</strong><small>Perfil KOMBAX y progreso privado</small></button></div>`)}
      <div class="grid-2">${card('Progreso',`<div style="display:flex;justify-content:space-between;align-items:end;margin-bottom:10px"><div><small class="muted">ASISTENCIA</small><div style="font-size:30px;font-weight:900;margin-top:5px">${pct}%</div></div><div style="text-align:right"><small class="muted">${present} presentes de ${total}</small></div></div>${progress(pct)}<div class="timeline" style="margin-top:20px">${d.graduations.filter(x=>x.socio_id===d.member.id).slice(0,4).map(g=>`<div class="timeline-item"><strong>Graduación · ${esc(d.grades.find(x=>x.id===g.grado_id)?.nombre||'Nuevo grado')}</strong><small>${dateFmt(g.fecha)}</small></div>`).join('')||'<div class="timeline-item"><strong>Tu evolución empieza aquí</strong><small>Las graduaciones aparecerán en este espacio.</small></div>'}</div>`)}
      ${card('Próxima actividad',ns?quickRow(icon('clock'),rel.group?.nombre||'Clase',`${dateFmt(ns.fecha)} · ${String(ns.hora_inicio||'').slice(0,5)}${ns.hora_fin?`–${String(ns.hora_fin).slice(0,5)}`:''}`,(()=>{const r=d.reservations.find(x=>x.sesion_id===ns.id&&x.socio_id===d.member.id);const reservation=r?.estado==='confirmada'?`${badge('Asistencia confirmada','ok')}<button class="btn btn-ghost btn-sm" data-action="portal-cancel-next" data-id="${esc(ns.id)}">Cancelar asistencia</button>`:`<button class="btn btn-primary btn-sm" data-action="portal-reserve-next" data-id="${esc(ns.id)}">Confirmar asistencia</button>`;const checkin=String(ns.fecha)===isoDate()?'<button class="btn btn-ghost btn-sm" data-action="portal-checkin">Check-in</button>':'';return `<div class="row-actions">${reservation}${checkin}</div>`;})()):empty('Sin clases próximas','Cuando haya una sesión programada para tus grupos aparecerá aquí.'))}</div>`);
    memberBind(d.members,renderPortalDashboard);bindInternalNav();document.querySelectorAll('[data-action="portal-checkin"]').forEach(b=>b.addEventListener('click',()=>openCheckin(d,d.member)));
    document.querySelector('[data-action="portal-reserve-next"]')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;try{await repos.portal.reserveSession(b.dataset.id,d.member.id);toast('Asistencia confirmada');await renderPortalDashboard();}catch(error){setError(error);b.disabled=false;}});
    document.querySelector('[data-action="portal-cancel-next"]')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;try{await repos.portal.cancelSessionReservation(b.dataset.id,d.member.id);toast('Asistencia cancelada');await renderPortalDashboard();}catch(error){setError(error);b.disabled=false;}});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Mi espacio')} ${empty('No se pudo cargar tu espacio',e.message)}`)}
}

function bindInternalNav(){document.querySelectorAll('#main-view [data-nav]').forEach(b=>b.addEventListener('click',()=>document.querySelector(`.nav-item[data-nav="${b.dataset.nav}"]`)?.click()||document.querySelector(`.bottom-nav [data-nav="${b.dataset.nav}"]`)?.click()));}
function openCheckin(d,member){
  const rel=enrollmentSummary(d,member);const today=d.sessions.filter(x=>x.fecha===isoDate()&&rel.links.some(l=>l.grupo_id===x.grupo_id)&&x.estado!=='cancelada');
  if(!today.length){toast('No hay una clase disponible hoy para este alumno','error');return;}
  openForm({title:'Registrar acceso',subtitle:`${member.nombre} · check-in del día`,fields:[{name:'sesion_id',label:'Clase',type:'select',required:true,options:today.map(s=>({value:s.id,label:`${d.groups.find(g=>g.id===s.grupo_id)?.nombre||'Clase'} · ${String(s.hora_inicio||'').slice(0,5)}`}))},{name:'codigo',label:'Código de acceso',help:'Déjalo vacío si esta clase no requiere código.'}],submitText:'Registrar acceso',onSubmit:async v=>{await repos.portal.checkin(v.sesion_id,member.id,v.codigo||'');toast('Acceso registrado');await renderPortalDashboard();}});
}

export async function renderPortalSchedule(){
  setMainHtml('<div class="loading-card">Cargando horarios…</div>');
  try{
    const d=await loadPortalSchedule();if(!d.member){setMainHtml(`${pageHeader('Horarios')} ${empty('Sin alumno vinculado')}`);return;}
    const rel=enrollmentSummary(d,d.member);const gids=new Set(rel.links.map(x=>x.grupo_id));const sched=d.schedules.filter(x=>gids.has(x.grupo_id));const range=weekRange(portalWeekOffset);const sessions=sortSessionsForWeek(d.sessions.filter(x=>gids.has(x.grupo_id)&&String(x.fecha)>=range.start&&String(x.fecha)<=range.end&&x.estado!=='cancelada'),portalWeekOffset);
    const scheduleRows=sched.map(h=>`<tr><td><strong>${esc(d.groups.find(g=>g.id===h.grupo_id)?.nombre||'Grupo')}</strong></td><td>${esc(DAYS[h.dia_semana]||'—')}</td><td>${esc(String(h.hora_inicio||'').slice(0,5))}–${esc(String(h.hora_fin||'').slice(0,5))}</td></tr>`);
    const now=new Date();const nowKey=`${String(now.getFullYear()).padStart(4,'0')}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')} ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
    const sessionAttendanceAction=(s)=>{const r=d.reservations.find(x=>x.sesion_id===s.id&&x.socio_id===d.member.id);const confirmed=r?.estado==='confirmada';const sessionKey=`${String(s.fecha||'')} ${String(s.hora_inicio||'').slice(0,5)}`;const future=sessionKey>=nowKey;if(!future)return badge('Sesión pasada','neutral');return confirmed?`${badge('Asistencia confirmada','ok')}<button class="btn btn-ghost btn-sm cancel-reservation" data-id="${esc(s.id)}">Cancelar asistencia</button>`:`<button class="btn btn-primary btn-sm reserve-session" data-id="${esc(s.id)}">Confirmar asistencia</button>`;};
    const upcoming=d.sessions.filter(s=>gids.has(s.grupo_id)&&s.estado!=='cancelada'&&`${String(s.fecha||'')} ${String(s.hora_inicio||'').slice(0,5)}`>=nowKey).sort((a,b)=>`${a.fecha} ${a.hora_inicio}`.localeCompare(`${b.fecha} ${b.hora_inicio}`));
    const next=upcoming[0]||null;
    const nextCard=next?card('Próxima sesión',quickRow(String(next.fecha).slice(8,10),d.groups.find(g=>g.id===next.grupo_id)?.nombre||'Clase',`${dateFmt(next.fecha)} · ${String(next.hora_inicio||'').slice(0,5)}${next.hora_fin?`–${String(next.hora_fin).slice(0,5)}`:''} · ${next.estado}`,`<div class="row-actions">${sessionAttendanceAction(next)}${next.fecha===isoDate()?`<button class="btn btn-ghost btn-sm check-session" data-id="${esc(next.id)}">Check-in</button>`:''}</div>`)):empty('Sin próximas sesiones','Cuando el club programe una sesión para tus grupos aparecerá aquí.');
    const sessionRows=sessions.map(s=>{const sessionKey=`${String(s.fecha||'')} ${String(s.hora_inicio||'').slice(0,5)}`;const future=sessionKey>=nowKey;const actions=`<div class="row-actions">${sessionAttendanceAction(s)}${future&&s.fecha===isoDate()?`<button class="btn btn-ghost btn-sm check-session" data-id="${esc(s.id)}">Check-in</button>`:''}</div>`;return quickRow(String(s.fecha).slice(8,10),d.groups.find(g=>g.id===s.grupo_id)?.nombre||'Clase',`${dateFmt(s.fecha)} · ${String(s.hora_inicio||'').slice(0,5)}${s.hora_fin?`–${String(s.hora_fin).slice(0,5)}`:''} · ${s.estado}`,actions)}).join('');
    const weekActions=`<div class="week-nav"><button class="btn btn-ghost btn-sm" id="portal-week-prev">← Semana anterior</button><button class="btn btn-ghost btn-sm" id="portal-week-current" ${portalWeekOffset===0?'disabled':''}>Esta semana</button><button class="btn btn-ghost btn-sm" id="portal-week-next">Semana siguiente →</button></div>`;
    const weekSummary=`<div class="week-summary"><strong>${esc(portalWeekTitle(portalWeekOffset,range.start,range.end))}</strong><span>${dateFmt(range.start)} – ${dateFmt(range.end)} · ${sessions.length} ${sessions.length===1?'sesión':'sesiones'}</span></div>`;
    setMainHtml(`${profileSwitcher(d.members,d.member.id)}${pageHeader('Horarios y asistencia','Consulta tus clases por semana, confirma a cuál asistirás y realiza el check-in al llegar','<button class="btn btn-primary" id="checkin-now">Registrar acceso</button>','Mi actividad')}${card('Horario habitual',scheduleRows.length?table(['Grupo','Día','Hora'],scheduleRows):empty('Sin horario asignado'))}${nextCard}${weekSummary}${card('Sesiones de la semana',sessionRows||empty('Sin sesiones esta semana','Tu próxima sesión seguirá visible arriba. Usa Semana anterior / siguiente para consultar otras semanas.'),weekActions)}`);
    memberBind(d.members,renderPortalSchedule);document.getElementById('checkin-now')?.addEventListener('click',()=>openCheckin(d,d.member));
    document.getElementById('portal-week-prev')?.addEventListener('click',()=>{portalWeekOffset-=1;renderPortalSchedule();});document.getElementById('portal-week-current')?.addEventListener('click',()=>{portalWeekOffset=0;renderPortalSchedule();});document.getElementById('portal-week-next')?.addEventListener('click',()=>{portalWeekOffset+=1;renderPortalSchedule();});
    document.querySelectorAll('.reserve-session').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{const out=await repos.portal.reserveSession(b.dataset.id,d.member.id);toast(`Asistencia confirmada${out?.confirmados!=null?` · ${out.confirmados} confirmados`:''}`);await renderPortalSchedule();}catch(e){setError(e);b.disabled=false;}}));
    document.querySelectorAll('.cancel-reservation').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.portal.cancelSessionReservation(b.dataset.id,d.member.id);toast('Asistencia cancelada');await renderPortalSchedule();}catch(e){setError(e);b.disabled=false;}}));
    document.querySelectorAll('.check-session').forEach(b=>b.addEventListener('click',()=>openForm({title:'Check-in',subtitle:d.groups.find(g=>g.id===d.sessions.find(s=>s.id===b.dataset.id)?.grupo_id)?.nombre||'',fields:[{name:'codigo',label:'Código de acceso'}],submitText:'Registrar',onSubmit:async v=>{await repos.portal.checkin(b.dataset.id,d.member.id,v.codigo||'');toast('Acceso registrado');await renderPortalSchedule();}})));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Horarios')} ${empty('No se pudieron cargar los horarios',e.message)}`)}
}

export async function renderPortalRequests(){
  setMainHtml('<div class="loading-card">Cargando solicitudes…</div>');
  try{
    const [members,disciplines,groups,tariffs,enrollments,notifs]=await Promise.all([repos.portal.visibleMembers(),repos.catalog.disciplines(),repos.groups.list(),repos.tariffs.list(),repos.portal.enrollments(),repos.portal.notifications()]);const member=activeMember(members);const family=state.session?.roles?.includes('familia')||state.session?.rol==='familia';
    const active=enrollments.filter(x=>x.activa).map(x=>{const m=members.find(s=>s.id===x.socio_id);return quickRow(icon('checkCircle'),`${m?.nombre||'Alumno'} · ${disciplines.find(d=>d.id===x.disciplina_id)?.nombre||'Disciplina'}`,groups.find(g=>g.id===x.grupo_id)?.nombre||'Sin grupo',badge('Activa','ok'))}).join('');
    const requestNotifs=notifs.filter(n=>n.tipo==='inscripcion').slice(0,12).map(n=>quickRow(icon('userPlus'),n.titulo,n.cuerpo||'',badge(n.leida?'Revisada':'Nueva',n.leida?'neutral':'warn'))).join('');
    setMainHtml(`${members.length?profileSwitcher(members,member?.id):''}${pageHeader('Solicitudes','Amplía tu actividad o añade un menor',`${member?'<button class="btn btn-primary" id="request-sport">Solicitar disciplina o grupo</button>':''}${family?'<button class="btn btn-ghost" id="request-minor">Añadir menor</button>':''}`,'Mi cuenta')}${card('Matrículas activas',active||empty('Sin matrículas activas'))}${card('Estado y avisos de solicitudes',requestNotifs||empty('Sin novedades','Las resoluciones y cambios de estado de las solicitudes se muestran mediante notificaciones del club.'))}`);
    memberBind(members,renderPortalRequests);
    const relationFields=[{name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:options(disciplines.filter(d=>d.activa))},{name:'grupo_id',label:'Grupo',type:'select',required:true,options:options(groups.filter(g=>g.activo),g=>`${disciplines.find(d=>d.id===g.disciplina_id)?.nombre||''} · ${g.nombre}`)},{name:'tarifa_id',label:'Tarifa',type:'select',options:options(tariffs.filter(t=>t.activa),t=>`${t.nombre} · ${money(t.importe)}`)}];
    document.getElementById('request-sport')?.addEventListener('click',()=>openForm({title:'Nueva solicitud deportiva',subtitle:member?`${member.nombre} ${member.apellidos||''}`:'',fields:relationFields,submitText:'Enviar solicitud',onSubmit:async v=>{await repos.portal.requestEnrollment(member.id,v.disciplina_id,v.grupo_id,v.tarifa_id);toast('Solicitud enviada al club');await renderPortalRequests();}}));
    document.getElementById('request-minor')?.addEventListener('click',()=>openForm({title:'Añadir menor',subtitle:'La solicitud quedará pendiente de aprobación por el club.',fields:[{name:'nombre',label:'Nombre del menor',required:true},{name:'apellidos',label:'Apellidos',required:true},{name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date'},{name:'parentesco',label:'Parentesco',required:true},{name:'telefono',label:'Teléfono de contacto',required:true,value:state.session?.telefono||''},...relationFields,{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.portal.requestMinor({...v,tutor_nombre:`${state.session?.nombre||''} ${state.session?.apellidos||''}`.trim(),tutor_email:state.session?.email||''});toast('Solicitud del menor enviada');await renderPortalRequests();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Solicitudes')} ${empty('No se pudieron cargar las solicitudes',e.message)}`)}
}

export async function renderPortalProfile(){
  setMainHtml('<div class="loading-card">Cargando Mi perfil…</div>');
  try{
    const d=await loadPortalProfile();if(!d.member){setMainHtml(`${pageHeader('Mi perfil')} ${empty('Sin alumno vinculado')}`);return;}
    const member=d.member,pr=d.progressRows.find(x=>x.socio_id===member.id)||{},total=Number(pr.asistencias_registradas||0),present=Number(pr.asistencias_presentes||0),pct=total?Math.round(present/total*100):0;
    const docs=d.documents.filter(x=>x.socio_id===member.id&&x.estado!=='archivado'&&x.estado!=='sustituido'),tracks=d.tracking.filter(x=>x.socio_id===member.id&&x.visibilidad==='familia'),grads=d.graduations.filter(x=>x.socio_id===member.id);
    const isStudent=state.session?.rol==='alumno';
    const [avatarUrl,socialStatus,socialRules]=await Promise.all([state.session?.avatar_path?repos.settings.avatarUrl(state.session.avatar_path).catch(()=> ''):Promise.resolve(''),isStudent?repos.socialGeneral.status().catch(()=>null):Promise.resolve(null),isStudent?repos.socialGeneral.rules().catch(()=>null):Promise.resolve(null)]);
    const ai=String(`${state.session?.nombre||''} ${state.session?.apellidos||''}`).split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('')||'UW';
    const privateHtml=`<section class="kx-private-club-context"><div class="kx-private-club-head"><div>${icon('lock',{size:18})}</div><div><strong>Información privada del club</strong><span>No forma parte de tu perfil público KOMBAX.</span></div></div>
      <div class="metrics">${metric('Asistencia',`${pct}%`,`${present}/${total} registros`)}${metric('Grado actual',pr.grado_actual||'—')}${metric('Graduaciones',grads.length)}${metric('Documentos',docs.length)}</div>
      <div class="grid-2">${card('Evolución privada',`${progress(pct)}<div class="timeline" style="margin-top:20px">${grads.slice(0,12).map(g=>`<div class="timeline-item"><strong>${esc(d.grades.find(x=>x.id===g.grado_id)?.nombre||'Graduación')}</strong><small>${dateFmt(g.fecha)}${g.examinador?` · ${esc(g.examinador)}`:''}</small></div>`).join('')||'<div class="timeline-item"><strong>Sin graduaciones registradas</strong></div>'}</div>`)}${card('Seguimiento compartido',tracks.length?`<div class="timeline">${tracks.slice(0,20).map(x=>`<div class="timeline-item"><strong>${esc(x.tipo)}</strong><small>${dateFmt(x.fecha)} · ${esc(x.nota)}</small></div>`).join('')}</div>`:empty('Sin notas compartidas'))}</div>
      ${card('Seguridad y acceso',quickRow(icon('lock'),'Cambiar contraseña','Confirma tu contraseña actual y crea una nueva. La sesión se cerrará por seguridad al terminar.','<button type="button" class="btn btn-primary btn-sm" id="portal-change-password">Cambiar contraseña</button>'))}
      ${card('Expediente privado',`<div class="profile-photo-card"><div class="profile-photo-large">${avatarUrl?`<img src="${esc(avatarUrl)}" alt="Foto privada de acceso">`:esc(ai)}</div><div><strong>Cuenta de acceso</strong><small style="display:block;margin-top:4px" class="muted">Esta foto pertenece a tu cuenta privada del club y no crea un segundo perfil público.</small><div class="profile-photo-actions"><button class="btn btn-ghost btn-sm" id="portal-avatar">${state.session?.avatar_path?'Cambiar foto privada':'Subir foto privada'}</button>${state.session?.avatar_path?'<button class="btn btn-ghost btn-sm" id="portal-avatar-remove">Quitar</button>':''}<button class="btn btn-ghost btn-sm" id="upload-portal-doc">${icon('upload',{size:14})} Adjuntar documento</button></div></div></div>${docs.length?docs.map(x=>`<div class="document-row"><div><strong>${esc(x.nombre)}</strong><small>${esc(x.tipo)} · ${dateFmt(x.creado_en)}</small></div><div class="row-actions"><button class="btn btn-ghost btn-sm open-doc" data-id="${esc(x.id)}">Abrir</button><button class="btn btn-ghost btn-sm download-portal-doc" data-id="${esc(x.id)}">${icon('download',{size:14})} Descargar</button></div></div>`).join(''):empty('Sin documentos disponibles')}`)}
    </section>`;
    const bindPrivate=async root=>{
      root.querySelectorAll('.open-doc').forEach(b=>b.addEventListener('click',async()=>{try{const doc=docs.find(x=>x.id===b.dataset.id);const u=await repos.documents.url(doc.storage_path);window.open(u,'_blank','noopener,noreferrer')}catch(e){setError(e)}}));
      root.querySelectorAll('.download-portal-doc').forEach(b=>b.addEventListener('click',async()=>{try{const doc=docs.find(x=>x.id===b.dataset.id);await downloadPortalDocument(doc);toast('Descarga iniciada')}catch(e){setError(e)}}));
      root.querySelector('#portal-change-password')?.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>location.reload()}));
      root.querySelector('#portal-avatar')?.addEventListener('click',()=>openForm({title:'Foto privada de acceso',fields:[{name:'avatar',label:'Imagen',type:'file',accept:'image/jpeg,image/png,image/webp',required:true,help:'JPG, PNG o WEBP · máximo 5 MB. No sustituye automáticamente tu avatar público KOMBAX.'}],submitText:'Guardar foto',onSubmit:async v=>{const out=await repos.settings.uploadAvatar(v.avatar);state.session.avatar_path=out?.avatar_path||'';localStorage.setItem('uw2_app_session',JSON.stringify(state.session));window.dispatchEvent(new CustomEvent('uw-profile-avatar-changed'));toast('Foto privada actualizada');await renderPortalProfile();}}));
      root.querySelector('#portal-avatar-remove')?.addEventListener('click',async()=>{try{await repos.settings.removeAvatar();state.session.avatar_path='';localStorage.setItem('uw2_app_session',JSON.stringify(state.session));window.dispatchEvent(new CustomEvent('uw-profile-avatar-changed'));toast('Foto privada eliminada');await renderPortalProfile();}catch(e){setError(e)}});
      root.querySelector('#upload-portal-doc')?.addEventListener('click',()=>openForm({title:'Adjuntar documento',subtitle:`${member.nombre} ${member.apellidos||''} · se guardará en su expediente privado`,fields:[{name:'archivo',label:'Archivo',type:'file',required:true,accept:'application/pdf,image/jpeg,image/png,image/webp',help:'PDF, JPG, PNG o WEBP · máximo 10 MB.'},{name:'tipo',label:'Tipo de documento',type:'select',required:true,options:PORTAL_DOC_TYPES},{name:'nombre',label:'Nombre del documento',placeholder:'Ej. Inscripción firmada 2026'},{name:'fecha_documento',label:'Fecha del documento',type:'date'},{name:'firmado',label:'Documento firmado',type:'checkbox',value:false},{name:'observaciones',label:'Observaciones',type:'textarea',full:true,rows:3}],submitText:'Subir al expediente',onSubmit:async v=>{await repos.documents.upload(member.id,v.archivo,{tipo:v.tipo,nombre:v.nombre||v.archivo?.name||'Documento',fecha_documento:v.fecha_documento||null,firmado:v.firmado===true,observaciones:v.observaciones||'',visible_familia:true});toast('Documento subido al expediente');await renderPortalProfile();}}));
    };

    if(isStudent&&socialStatus?.status==='activa'&&socialStatus?.social_profile_id){
      await renderOwnKombaxProfilePage(socialStatus.social_profile_id,{extraHtml:privateHtml,bindExtra:bindPrivate});return;
    }

    const activation=isStudent?`${socialGeneralCardHtml(socialStatus)}<div class="alert"><strong>Tu perfil KOMBAX será tu única ficha pública</strong><span>Al activarlo, banner, avatar, información deportiva, álbum y publicaciones vivirán en la misma identidad Social. Tu expediente del club seguirá privado.</span></div>`:'';
    setMainHtml(`${isStudent?'':profileSwitcher(d.members,member.id)}${pageHeader(isStudent?'Mi perfil':'Mi cuenta y familiares',`${member.nombre} ${member.apellidos||''}`,'','Cuenta')}${activation}${privateHtml}`);
    if(!isStudent)memberBind(d.members,renderPortalProfile);
    document.getElementById('view-general-community-rules')?.addEventListener('click',()=>showGeneralCommunityRules(socialRules));
    document.getElementById('activate-general-community')?.addEventListener('click',()=>openForm({title:'Activar KOMBAX Social',subtitle:'Tu perfil KOMBAX será tu única ficha pública. El expediente administrativo del club permanece privado.',width:'650px',fields:[{name:'acepta_normas',label:'He leído y acepto las Normas de KOMBAX Social.',type:'checkbox',value:false,required:true,full:true},{name:'acepta_privacidad',label:'Entiendo qué información será pública y qué datos del club seguirán siendo privados.',type:'checkbox',value:false,required:true,full:true}],submitText:'Activar mi perfil KOMBAX',onSubmit:async v=>{if(!v.acepta_normas||!v.acepta_privacidad)throw new Error('Debes aceptar las normas y la privacidad antes de activar el servicio.');await repos.socialGeneral.activate(v);toast('Perfil KOMBAX activado');await renderPortalProfile();}}));
    await bindPrivate(document.getElementById('main-view'));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Mi perfil')} ${empty('No se pudo cargar Mi perfil',e.message)}`)}
}
