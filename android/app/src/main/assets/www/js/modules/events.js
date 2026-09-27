import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, dateFmt, money, humanError } from '../core/utils.js';
import { pageHeader, card, empty, badge, openForm, openDetail, confirmDialog, toast, setError, setMainHtml, closeModal } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { renderCompetitionPreparation, registerOfficialWeighIn } from './competition-preparation.js';
import { openEventConnectionManager } from './event-connections.js';

const manager=()=>has(state.session,'eventManage');
const portal=()=>['familia','alumno'].includes(state.session?.rol);
const eventKind=(s)=>({borrador:'neutral',abierto:'ok',cerrado:'warn',finalizado:'info',cancelado:'danger'})[s]||'neutral';
const registrationKind=(s)=>({solicitado:'warn',confirmado:'ok',rechazado:'danger',baja:'neutral'})[s]||'neutral';
const fightKind=(s)=>({pendiente:'neutral',en_curso:'warn',finalizado:'ok',cancelado:'danger'})[s]||'neutral';
const stateLabel=(s)=>({borrador:'Borrador',abierto:'Inscripción abierta',cerrado:'Inscripción cerrada',finalizado:'Finalizado',cancelado:'Cancelado',solicitado:'Solicitado',confirmado:'Confirmado',rechazado:'Rechazado',baja:'Baja',pendiente:'Pendiente',en_curso:'En curso'})[s]||s||'—';
const personName=(p)=>`${p?.nombre||''} ${p?.apellidos||''}`.trim()||'Participante';
const time=(v)=>String(v||'').slice(0,5);

const eventStateLimits={activo:10,archivado:10,papelera:10};
const eventSchedule=(e)=>[e.fecha?dateFmt(e.fecha):'',e.hora_inicio?time(e.hora_inicio):'',e.hora_fin?`– ${time(e.hora_fin)}`:''].filter(Boolean).join(' ');
const connectionText=(c)=>!c?t('r89.noPublicConnection'):c.authorization_status==='approved'&&c.status==='connected'?'Conectado a KOMBAX Events':c.authorization_status==='pending'?t('r89.pendingConnection'):`Conexión ${c.status||c.authorization_status||'registrada'}`;
const communicationRows=(page)=>{const rows=Array.isArray(page?.items)?page.items:[];return rows.length?`<div class="event-communication-list">${rows.map(x=>`<article><div><strong>${esc(x.titulo||'Aviso')}</strong><small>${esc([x.tipo,x.audiencia,x.created_at?dateFmt(x.created_at):''].filter(Boolean).join(' · '))}</small></div><p>${esc(x.cuerpo||'')}</p></article>`).join('')}</div>`:empty('Sin comunicaciones',t('r89.eventCommsEmpty'));};

async function accessibleMembers(){
  if(portal())return repos.portal.visibleMembers();
  if(manager())return repos.members.list();
  return [];
}

function requirementLines(e){
  const rows=[];
  if(e.edad_min!=null||e.edad_max!=null)rows.push(['Edad',`${e.edad_min??'—'}–${e.edad_max??'—'} años`]);
  if(e.peso_min!=null||e.peso_max!=null)rows.push(['Peso',`${e.peso_min??'—'}–${e.peso_max??'—'} kg`]);
  if(e.categoria_texto)rows.push(['Categoría',e.categoria_texto]);
  if(e.grado_minimo_texto)rows.push(['Grado mínimo',e.grado_minimo_texto]);
  if(e.documentacion_requerida)rows.push(['Documentación',e.documentacion_requerida]);
  if(e.autorizacion_requerida)rows.push(['Autorización','Obligatoria']);
  if(e.cuota_inscripcion!=null)rows.push(['Inscripción',money(e.cuota_inscripcion)]);
  if(e.observaciones_requisitos)rows.push(['Observaciones',e.observaciones_requisitos]);
  return rows;
}

function eventForm(event=null,disciplines=[],onSaved=renderEvents){
  const initial=event||{estado:'borrador',autorizacion_requerida:false};
  openForm({title:event?'Editar evento':'Nuevo evento / competición',subtitle:'Define el evento y sus requisitos. Los combates se organizan manualmente.',width:'980px',initial,fields:[
    {name:'nombre',label:'Nombre',required:true,full:true,maxLength:180},{name:'disciplina_id',label:'Disciplina',type:'select',options:disciplines.map(x=>({value:x.id,label:x.nombre}))},{name:'estado',label:'Estado',type:'select',required:true,options:['borrador','abierto','cerrado','finalizado','cancelado'].map(value=>({value,label:stateLabel(value)}))},
    {name:'fecha',label:'Fecha',type:'date',required:true},{name:'hora_inicio',label:'Hora inicio',type:'time'},{name:'hora_fin',label:'Hora fin',type:'time'},{name:'fecha_limite_inscripcion',label:'Límite de inscripción',type:'date'},
    {name:'lugar',label:'Lugar',maxLength:240},{name:'organizador',label:'Organizador',maxLength:180},{name:'descripcion',label:'Descripción',type:'textarea',rows:4,full:true,maxLength:4000},
    {name:'edad_min',label:'Edad mínima',type:'number',min:0,max:120},{name:'edad_max',label:'Edad máxima',type:'number',min:0,max:120},{name:'peso_min',label:'Peso mínimo (kg)',type:'number',min:0,step:'0.1'},{name:'peso_max',label:'Peso máximo (kg)',type:'number',min:0,step:'0.1'},
    {name:'categoria_texto',label:'Categoría',maxLength:180},{name:'grado_minimo_texto',label:'Grado mínimo',maxLength:180},{name:'cuota_inscripcion',label:'Cuota de inscripción (€)',type:'number',min:0,step:'0.01'},{name:'autorizacion_requerida',label:'Requiere autorización',type:'checkbox'},
    {name:'documentacion_requerida',label:'Documentación requerida',type:'textarea',rows:3,full:true,maxLength:1500},{name:'observaciones_requisitos',label:'Otros requisitos / indicaciones',type:'textarea',rows:3,full:true,maxLength:2000}
  ],submitText:event?'Guardar cambios':'Crear evento',onSubmit:async v=>{await repos.events.save({...initial,...v,id:event?.id||null});toast(event?'Evento actualizado':'Evento creado');await onSaved();}});
}

function externalForm(event,participant=null,onSaved){
  const initial=participant||{};
  openForm({title:participant?'Editar participante externo':'Añadir participante externo',subtitle:'No necesita cuenta ni instalar KOMBAX. Guarda solo información deportiva necesaria.',width:'820px',initial,fields:[
    {name:'nombre',label:'Nombre',required:true,maxLength:120},{name:'apellidos',label:'Apellidos',maxLength:180},{name:'club_origen',label:'Club de procedencia',maxLength:180},{name:'disciplina_texto',label:'Disciplina',maxLength:160},
    {name:'categoria_texto',label:'Categoría',maxLength:160},{name:'peso',label:'Peso (kg)',type:'number',min:0,step:'0.1'},{name:'grado_texto',label:'Grado / cinturón',maxLength:160},{name:'edad',label:'Edad / categoría de edad',type:'number',min:0,max:120},
    {name:'observaciones',label:'Observaciones deportivas',type:'textarea',rows:3,full:true,maxLength:1000,help:'No introduzcas teléfono, email, dirección, documentos ni otros datos privados.'}
  ],submitText:'Guardar participante',onSubmit:async v=>{await repos.events.saveExternal({...v,id:participant?.id||null,evento_id:event.id});toast('Participante externo guardado');await onSaved();}});
}

function registrationForm(event,member,onSaved,{staff=false}={}){
  openForm({title:staff?'Añadir alumno del club':'Solicitar inscripción',subtitle:`${personName(member)} · ${event.nombre}`,width:'700px',fields:[
    {name:'categoria_texto',label:'Categoría competitiva',maxLength:160},{name:'peso',label:'Peso actual (kg)',type:'number',min:0,step:'0.1'},{name:'observaciones',label:'Observaciones deportivas',type:'textarea',rows:3,full:true,maxLength:1000}
  ],submitText:staff?'Añadir a inscritos':'Enviar solicitud',onSubmit:async v=>{const out=await repos.events.requestRegistration({evento_id:event.id,socio_id:member.id,...v});if(staff&&out?.id)await repos.events.setRegistrationStatus(out.id,'confirmado','Añadido por el equipo del club');toast(staff?'Alumno añadido y confirmado':'Solicitud enviada');await onSaved();}});
}

function fightForm(event,participants,fight=null,onSaved){
  const confirmed=participants.filter(p=>p.estado==='confirmado');
  if(confirmed.length<2){toast('Necesitas al menos dos participantes confirmados.','error');return;}
  const personOptions=confirmed.map(p=>({value:p.id,label:`${personName(p)}${p.club_origen?` · ${p.club_origen}`:''}`}));
  const initial=fight||{estado:'pendiente'};
  openForm({title:fight?'Editar combate':'Nuevo combate',subtitle:'Emparejamiento manual. No se generan cuadros automáticamente.',width:'860px',initial,fields:[
    {name:'participante_a_id',label:'Participante A',type:'select',required:true,options:personOptions},{name:'participante_b_id',label:'Participante B',type:'select',required:true,options:personOptions},
    {name:'disciplina_texto',label:'Disciplina',maxLength:160},{name:'categoria_texto',label:'Categoría',maxLength:160},{name:'tatami_ring',label:'Tatami / ring',maxLength:120},{name:'orden',label:'Orden',type:'number',min:1},{name:'hora_aprox',label:'Hora aproximada',type:'time'},
    {name:'estado',label:'Estado',type:'select',required:true,options:['pendiente','en_curso','finalizado','cancelado'].map(value=>({value,label:stateLabel(value)}))},
    {name:'ganador_participante_id',label:'Ganador',type:'select',options:personOptions},{name:'resultado',label:'Resultado',maxLength:500},{name:'observaciones',label:'Observaciones',type:'textarea',rows:3,full:true,maxLength:1000}
  ],submitText:'Guardar combate',onSubmit:async v=>{if(v.participante_a_id===v.participante_b_id)throw new Error('Selecciona dos participantes distintos.');if(v.ganador_participante_id&&![v.participante_a_id,v.participante_b_id].includes(v.ganador_participante_id))throw new Error('El ganador debe ser uno de los dos participantes.');await repos.events.saveFight({...v,id:fight?.id||null,evento_id:event.id});toast('Combate guardado');await onSaved();}});
}

function participantHtml(p,{canManage=false,canWithdraw=false,preparation=null}={}){
  const prep=preparation||null;
  const prepAction=prep?(prep.can_view_private?`<button class="btn btn-primary btn-sm event-preparation-open" data-id="${esc(p.id)}">Abrir preparación</button>`:prep.can_manage_private&&!prep.is_external&&!prep.preparation_id?`<button class="btn btn-primary btn-sm event-preparation-open" data-id="${esc(p.id)}">Activar preparación</button>`:''):'';
  const officialAction=prep?.can_official_weigh_in?(prep.official_weight_kg!=null?`<span class="event-official-weight">Oficial ${Number(prep.official_weight_kg).toFixed(1)} kg</span>`:`<button class="btn btn-ghost btn-sm event-official-weigh-in" data-id="${esc(p.id)}">Pesaje oficial</button>`):'';
  return `<div class="event-participant" data-participant-id="${esc(p.id)}"><div class="event-participant-mark">${p.externo?'EXT':'UW'}</div><div><strong>${esc(personName(p))}</strong><small>${esc([p.club_origen,p.disciplina_texto,p.categoria_texto,p.peso!=null?`${p.peso} kg`:'',p.grado_texto].filter(Boolean).join(' · ')||'Sin datos deportivos adicionales')}</small></div><div class="event-participant-status">${badge(stateLabel(p.estado),registrationKind(p.estado))}</div>${(prepAction||officialAction)?`<div class="event-participant-actions event-preparation-actions">${prepAction}${officialAction}</div>`:''}${canManage?`<div class="event-participant-actions"><button class="btn btn-ghost btn-sm event-participant-state" data-state="confirmado" data-id="${esc(p.id)}">Confirmar</button><button class="btn btn-ghost btn-sm event-participant-state" data-state="rechazado" data-id="${esc(p.id)}">Rechazar</button>${p.externo?`<button class="btn btn-ghost btn-sm event-external-edit" data-id="${esc(p.id)}">Editar</button>`:''}</div>`:canWithdraw?`<button class="btn btn-ghost btn-sm event-withdraw" data-id="${esc(p.id)}">Dar de baja</button>`:''}</div>`;
}

function fightHtml(f,participants,canManage){
  const a=participants.find(p=>p.id===f.participante_a_id),b=participants.find(p=>p.id===f.participante_b_id),winner=participants.find(p=>p.id===f.ganador_participante_id);
  return `<div class="event-fight"><div class="event-fight-order"><strong>${f.orden||'—'}</strong><small>${esc(f.tatami_ring||'Orden')}</small></div><div class="event-fight-versus"><strong>${esc(personName(a))}</strong><span>VS</span><strong>${esc(personName(b))}</strong><small>${esc([f.categoria_texto,f.disciplina_texto,time(f.hora_aprox)].filter(Boolean).join(' · '))}</small></div><div class="event-fight-result">${badge(stateLabel(f.estado),fightKind(f.estado))}${f.resultado?`<strong>${esc(f.resultado)}</strong>`:''}${winner?`<small>Ganador: ${esc(personName(winner))}</small>`:''}</div>${canManage?`<div class="row-actions"><button class="btn btn-ghost btn-sm event-fight-edit" data-id="${esc(f.id)}">Editar</button><button class="btn btn-ghost btn-sm event-fight-delete" data-id="${esc(f.id)}">Eliminar</button></div>`:''}</div>`;
}

async function openEvent(event,disciplines,allMembers){
  try{
    const canManage=manager();
    const [participants,fights,preparationRows,communicationPage,connection]=await Promise.all([repos.events.participants(event.id),repos.events.fights(event.id),repos.competitionPreparation.eventRoster('club_event',event.id).catch(()=>[]),canManage?repos.events.communications(event.id,{limit:10,offset:0}).catch(()=>({items:[],has_more:false,next_offset:0})):Promise.resolve({items:[],has_more:false,next_offset:0}),canManage?repos.eventConnections.get({internal_event_id:event.id}).catch(()=>null):Promise.resolve(null)]);
    const ownIds=new Set((allMembers||[]).map(m=>m.id));
    const myRegistrations=participants.filter(p=>!p.externo&&ownIds.has(p.socio_id));
    const requirements=requirementLines(event);
    const actions=[];
    if(canManage){actions.push(`<button class="btn btn-ghost" id="event-edit">${icon('edit',{size:15})} Editar</button>`,`<button class="btn btn-ghost" id="event-kombax-connect">${icon('link',{size:15})} KOMBAX Events</button>`,`<button class="btn btn-primary" id="event-external-add">${icon('plus',{size:15})} Externo</button>`);if(event.ciclo_estado==='activo')actions.push(`<button class="btn btn-ghost" id="event-archive">${icon('archive',{size:15})} Archivar</button>`);if(event.ciclo_estado==='archivado')actions.push(`<button class="btn btn-danger" id="event-trash">${icon('trash',{size:15})} Papelera</button>`,`<button class="btn btn-ghost" id="event-restore">Restaurar</button>`);if(event.ciclo_estado==='papelera')actions.push(`<button class="btn btn-ghost" id="event-restore">Restaurar</button>`,`<button class="btn btn-danger" id="event-delete-forever">Eliminar definitivamente</button>`);}
    const body=`<div class="event-detail">
      <section class="event-detail-hero"><div><span class="page-kicker">${esc(event.organizador||'EVENTO / COMPETICIÓN')}</span><h2>${esc(event.nombre)}</h2><p>${esc(event.descripcion||'')}</p><div class="event-meta"><span>${icon('calendar',{size:15})} ${dateFmt(event.fecha)}${event.hora_inicio?` · ${time(event.hora_inicio)}${event.hora_fin?`–${time(event.hora_fin)}`:''}`:''}</span>${event.lugar?`<span>${icon('mapPin',{size:15})} ${esc(event.lugar)}</span>`:''}</div></div>${badge(stateLabel(event.estado),eventKind(event.estado))}</section>
      <div class="grid-2"><section class="event-panel"><h3>Requisitos</h3>${requirements.length?`<dl class="event-requirements">${requirements.map(([k,v])=>`<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`).join('')}</dl>`:'<p class="muted">Sin requisitos especiales registrados.</p>'}${event.fecha_limite_inscripcion?`<p class="event-deadline">Inscripción hasta ${dateFmt(event.fecha_limite_inscripcion)}</p>`:''}</section>
      <section class="event-panel"><h3>Tu participación</h3>${portal()?(myRegistrations.length?myRegistrations.map(p=>`<div class="event-my-registration"><strong>${esc(allMembers.find(m=>m.id===p.socio_id)?.nombre||p.nombre)}</strong>${badge(stateLabel(p.estado),registrationKind(p.estado))}</div>`).join(''):`<p class="muted">Todavía no hay una inscripción vinculada a tu cuenta.</p>`):`<p class="muted">El equipo del club gestiona las inscripciones y participantes.</p>`}<div class="row-actions event-registration-buttons">${portal()&&event.estado==='abierto'?(allMembers||[]).filter(m=>!participants.some(p=>p.socio_id===m.id&&p.estado!=='baja'&&p.estado!=='rechazado')).map(m=>`<button class="btn btn-ghost btn-sm event-register" data-socio="${esc(m.id)}">Apuntar a ${esc(m.nombre)}</button>`).join(''):''}</div></section></div>
      ${canManage?`<section class="event-panel"><div class="event-section-head"><div><h3>${esc(t('r89.connectionComms'))}</h3><small>${esc(connectionText(connection))}</small></div><button class="btn btn-ghost btn-sm" id="event-message-add">${esc(t('r89.newNotice'))}</button></div><div class="event-connection-summary"><strong>${esc(eventSchedule(event))}</strong>${event.lugar?`<span>${icon('mapPin',{size:14})} ${esc(event.lugar)}</span>`:''}<span>${esc(connectionText(connection))}</span></div><details class="event-communications" open><summary>Comunicaciones del evento</summary><div id="event-communications-list">${communicationRows(communicationPage)}</div>${communicationPage?.has_more?`<button class="btn btn-ghost btn-sm" id="event-communications-more" data-offset="${Number(communicationPage.next_offset||10)}">${esc(t('r89.load10'))}</button>`:''}</details></section>`:''}
      <section class="event-panel"><div class="event-section-head"><div><h3>Inscritos</h3><small>${participants.filter(p=>p.estado==='confirmado').length} confirmados · ${participants.length} registros</small></div>${canManage?`<button class="btn btn-ghost btn-sm" id="event-club-add">Añadir alumno</button>`:''}</div><div class="event-participant-list">${participants.length?participants.map(p=>participantHtml(p,{canManage,canWithdraw:ownIds.has(p.socio_id)&&!['baja','rechazado'].includes(p.estado),preparation:preparationRows.find(r=>String(r.registration_id)===String(p.id))||null})).join(''):empty('Sin inscritos','Aún no se ha registrado ningún participante.')}</div></section>
      <section class="event-panel"><div class="event-section-head"><div><h3>Combates</h3><small>Emparejamientos manuales</small></div>${canManage?`<button class="btn btn-primary btn-sm" id="event-fight-add">${icon('plus',{size:14})} Combate</button>`:''}</div><div class="event-fight-list">${fights.length?fights.map(f=>fightHtml(f,participants,canManage)).join(''):empty('Sin combates','Los combates aparecerán cuando el equipo cree los enfrentamientos.')}</div></section>
    </div>`;
    const modal=openDetail({title:event.nombre,subtitle:`${dateFmt(event.fecha)}${event.lugar?` · ${event.lugar}`:''}`,body,actions:actions.join(''),width:'1080px',className:'event-detail-modal'});
    const refresh=async()=>openEvent(event,disciplines,await accessibleMembers());
    modal.wrap.querySelector('#event-edit')?.addEventListener('click',()=>eventForm(event,disciplines,renderEvents));
    modal.wrap.querySelector('#event-kombax-connect')?.addEventListener('click',()=>openEventConnectionManager(event,{onDone:refresh}));
    modal.wrap.querySelector('#event-archive')?.addEventListener('click',()=>confirmDialog(t('r89.archiveEvent'),t('r89.archiveEventHelp'),async()=>{await repos.lifecycle.action('evento',[event.id],'archivar',t('r89.archiveEventNote'));toast(t('r89.eventArchived'));closeModal();await renderEvents();},{confirmText:'Archivar'}));
    modal.wrap.querySelector('#event-trash')?.addEventListener('click',()=>confirmDialog(t('r89.trashEvent'),t('r89.trashEventHelp'),async()=>{await repos.lifecycle.action('evento',[event.id],'papelera',t('r89.trashEventNote'));toast(t('r89.eventTrashed'));closeModal();await renderEvents();},{confirmText:'Mover a papelera',danger:true}));
    modal.wrap.querySelector('#event-restore')?.addEventListener('click',async()=>{try{await repos.lifecycle.action('evento',[event.id],'restaurar','');toast(t('r89.eventRestored'));closeModal();await renderEvents();}catch(error){setError(error);}});
    modal.wrap.querySelector('#event-delete-forever')?.addEventListener('click',async()=>{try{const plan=await repos.lifecycle.previewDelete('evento',event.id);if(plan?.allowed!==true){toast(plan?.reason||t('r89.eventHistorical'),'warn');return;}confirmDialog(t('r89.deleteEvent'),t('r89.deleteEventHelp'),async()=>{await repos.lifecycle.deleteForever('evento',event.id,'ELIMINAR');toast(t('r89.eventDeleted'));closeModal();await renderEvents();},{confirmText:'Eliminar definitivamente',danger:true});}catch(error){setError(error);}});
    modal.wrap.querySelector('#event-message-add')?.addEventListener('click',()=>openForm({title:t('r89.newEventNotice'),subtitle:t('r89.eventNoticeHelp'),fields:[{name:'titulo',label:'Título',required:true},{name:'cuerpo',label:'Mensaje',type:'textarea',rows:4,full:true,required:true},{name:'audiencia',label:'Audiencia',type:'select',value:'todos',options:[{value:'todos',label:'Todo el club'},{value:'familias',label:'Familias y alumnado'},{value:'monitores',label:'Monitores'}]}],submitText:t('r89.publishNotice'),onSubmit:async v=>{const when=event.fecha?`${event.fecha}T${time(event.hora_inicio)||'12:00'}`:null;const out=await repos.communications.save({tipo:'evento',titulo:v.titulo,cuerpo:v.cuerpo,audiencia:v.audiencia,estado:'publicada',evento_fecha:when,ubicacion:event.lugar||''});const id=out?.id||out?.comunicacion_id;if(!id)throw new Error(t('r89.linkCommError'));await repos.events.linkCommunication(event.id,id);toast(t('r89.noticeLinked'));await refresh();}}));
    modal.wrap.querySelector('#event-communications-more')?.addEventListener('click',async e=>{const b=e.currentTarget;try{const page=await repos.events.communications(event.id,{limit:10,offset:Number(b.dataset.offset||10)});const box=modal.wrap.querySelector('#event-communications-list');if(box&&Array.isArray(page?.items))box.insertAdjacentHTML('beforeend',communicationRows({items:page.items}).replace(/^<div class="event-communication-list">|<\/div>$/g,''));if(page?.has_more){b.dataset.offset=String(page.next_offset||Number(b.dataset.offset||10)+10);}else b.remove();}catch(error){setError(error);}});
    modal.wrap.querySelector('#event-external-add')?.addEventListener('click',()=>externalForm(event,null,refresh));
    modal.wrap.querySelector('#event-club-add')?.addEventListener('click',()=>{
      const choices=(allMembers||[]).filter(m=>!participants.some(p=>p.socio_id===m.id&&p.estado!=='baja'&&p.estado!=='rechazado'));
      if(!choices.length){toast('No quedan alumnos accesibles sin inscripción activa.','error');return;}
      openForm({title:'Añadir alumno del club',subtitle:'El equipo puede completar la lista aunque la inscripción pública ya esté cerrada.',width:'720px',fields:[
        {name:'socio_id',label:'Alumno',type:'select',required:true,options:choices.map(m=>({value:m.id,label:personName(m)}))},
        {name:'categoria_texto',label:'Categoría competitiva',maxLength:160},{name:'peso',label:'Peso actual (kg)',type:'number',min:0,step:'0.1'},
        {name:'observaciones',label:'Observaciones deportivas',type:'textarea',rows:3,full:true,maxLength:1000}
      ],submitText:'Añadir y confirmar',onSubmit:async v=>{const out=await repos.events.requestRegistration({evento_id:event.id,...v});if(!out?.id)throw new Error('No se pudo crear la inscripción.');await repos.events.setRegistrationStatus(out.id,'confirmado','Añadido por el equipo del club');toast('Alumno añadido y confirmado');await refresh();}});
    });
    modal.wrap.querySelectorAll('.event-register').forEach(b=>b.addEventListener('click',()=>{const member=(allMembers||[]).find(m=>m.id===b.dataset.socio);if(member)registrationForm(event,member,refresh,{staff:canManage});}));
    modal.wrap.querySelectorAll('.event-participant-state').forEach(b=>b.addEventListener('click',async()=>{try{await repos.events.setRegistrationStatus(b.dataset.id,b.dataset.state);toast(`Inscripción: ${stateLabel(b.dataset.state)}`);await refresh();}catch(error){setError(error)}}));
    modal.wrap.querySelectorAll('.event-external-edit').forEach(b=>b.addEventListener('click',()=>externalForm(event,participants.find(p=>p.id===b.dataset.id),refresh)));
    modal.wrap.querySelectorAll('.event-withdraw').forEach(b=>b.addEventListener('click',()=>confirmDialog('Dar de baja','La inscripción quedará como baja y no podrá usarse en combates nuevos.',async()=>{await repos.events.withdraw(b.dataset.id);toast('Inscripción dada de baja');await refresh();},{confirmText:'Dar de baja'})));
    modal.wrap.querySelectorAll('.event-preparation-open').forEach(b=>b.addEventListener('click',()=>{closeModal();renderCompetitionPreparation({eventSource:'club_event',eventId:event.id,registrationId:b.dataset.id,title:`${event.nombre} · preparación`,onBack:()=>openEvent(event,disciplines,allMembers)});}));
    modal.wrap.querySelectorAll('.event-official-weigh-in').forEach(b=>b.addEventListener('click',()=>registerOfficialWeighIn({eventSource:'club_event',eventId:event.id,registrationId:b.dataset.id,onDone:refresh})));
    modal.wrap.querySelector('#event-fight-add')?.addEventListener('click',()=>fightForm(event,participants,null,refresh));
    modal.wrap.querySelectorAll('.event-fight-edit').forEach(b=>b.addEventListener('click',()=>fightForm(event,participants,fights.find(f=>f.id===b.dataset.id),refresh)));
    modal.wrap.querySelectorAll('.event-fight-delete').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar combate','Se eliminará este emparejamiento, no los participantes.',async()=>{await repos.events.deleteFight(b.dataset.id);toast('Combate eliminado');await refresh();},{confirmText:'Eliminar',danger:true})));
  }catch(error){setError(error);}
}

export async function renderEvents(){
  setMainHtml('<div class="loading-card">Cargando eventos…</div>');
  try{
    const canManage=manager();
    const [active,archived,trash,disciplines,members]=await Promise.all([
      repos.events.listState('activo',eventStateLimits.activo),
      canManage?repos.events.listState('archivado',eventStateLimits.archivado):Promise.resolve([]),
      canManage?repos.events.listState('papelera',eventStateLimits.papelera):Promise.resolve([]),
      repos.catalog.disciplines().catch(()=>[]),accessibleMembers().catch(()=>[])
    ]);
    const cardHtml=(e)=>`<article class="event-card" data-event-id="${esc(e.id)}"><div class="event-card-date"><strong>${esc(String(e.fecha||'').slice(8,10)||'—')}</strong><span>${esc(e.fecha?new Intl.DateTimeFormat(kxLocaleTag(kxGetLocale()),{month:'short'}).format(new Date(`${e.fecha}T12:00:00`)):'—')}</span></div><div class="event-card-copy"><div class="event-card-top"><span class="page-kicker">${esc(e.organizador||'COMPETICIÓN')}</span>${badge(stateLabel(e.estado),eventKind(e.estado))}${e.ciclo_estado!=='activo'?badge(e.ciclo_estado,e.ciclo_estado==='papelera'?'danger':'neutral'):''}</div><h2>${esc(e.nombre)}</h2><p>${esc([e.lugar,e.categoria_texto,e.grado_minimo_texto].filter(Boolean).join(' · ')||e.descripcion||'Evento del club')}</p><div class="event-card-meta"><span>${icon('calendar',{size:14})} ${esc(eventSchedule(e))}</span>${e.lugar?`<span>${icon('mapPin',{size:14})} ${esc(e.lugar)}</span>`:''}${e.fecha_limite_inscripcion?`<span>Inscripción hasta ${dateFmt(e.fecha_limite_inscripcion)}</span>`:''}</div></div><button class="btn btn-ghost event-open" data-id="${esc(e.id)}">${t('events.actions.view')}</button></article>`;
    const section=(title,rows,state,open=true)=>`<details class="event-history-group" ${open?'open':''}><summary>${esc(title)} <b>${rows.length}${rows.length>=eventStateLimits[state]?' +':''}</b></summary><div class="event-list">${rows.map(cardHtml).join('')||empty(t('r89.noEvents'))}</div>${rows.length>=eventStateLimits[state]&&eventStateLimits[state]<300?`<div class="load-more-wrap"><button class="btn btn-ghost event-load-more" data-state="${state}">${esc(t('r89.load10'))}</button></div>`:''}</details>`;
    const all=[...active,...archived,...trash];
    setMainHtml(`${pageHeader(t('events.title'),t('r89.eventsLead'),canManage?`<button class="btn btn-primary" id="event-new">${icon('plus',{size:16})} Nuevo evento</button>`:'','Club')}${card('Calendario de competición',`${section(t('r89.activeUpcoming'),active,'activo',true)}${canManage?section('Archivados / pasados',archived,'archivado',false):''}${canManage?section('Papelera recuperable',trash,'papelera',false):''}`)}`);
    document.getElementById('event-new')?.addEventListener('click',()=>eventForm(null,disciplines,renderEvents));
    document.querySelectorAll('.event-open').forEach(b=>b.addEventListener('click',()=>{const event=all.find(e=>e.id===b.dataset.id);if(event)openEvent(event,disciplines,members);}));
    document.querySelectorAll('.event-load-more').forEach(b=>b.addEventListener('click',()=>{const key=b.dataset.state;if(!eventStateLimits[key])return;eventStateLimits[key]=Math.min(300,eventStateLimits[key]+10);renderEvents();}));
  }catch(error){setError(error);setMainHtml(`${pageHeader(t('events.title'))}${empty('No se pudieron cargar los eventos',humanError(error))}`);}
}
