import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { setMainHtml, setAppHtml, pageHeader, openForm, openDetail, toast, setError, empty, closeModal } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const FREQ_LABEL={weekly:'Semanal',three_per_week:'3 veces por semana',daily:'Diario',custom:'Personalizado'};
const VERIFY_LABEL={self:'Autoregistrado',team:'Verificado por equipo',official:'Pesaje oficial'};
const CONTEXT_LABEL={normal:'Registro habitual',fasted:'En ayunas',post_training:'Después de entrenar',other:'Otro contexto'};
const ROLE_LABEL={trainer:'Entrenador',preparer:'Preparador',manager:'Manager',representative:'Representante',club_staff:'Equipo del club',guardian:'Tutor'};
const PERM_LABEL={read:'Ver',log:'Añadir pesajes',verify:'Verificar',manage:'Gestionar accesos'};
function setPrepHtml(html){if(document.getElementById('main-view')) setMainHtml(html); else setAppHtml(html);}

function subjectOptions({competitorProfileId=null,socioId=null,clubId=null,eventId=null}={}){return {competitor_profile_id:competitorProfileId||null,socio_id:socioId||null,club_id:clubId||null,event_id:eventId||null};}
function delta(prep){if(prep.last_weight_kg==null||prep.target_weight_kg==null)return null;return Number(prep.last_weight_kg)-Number(prep.target_weight_kg)}
function deltaText(prep){const d=delta(prep);if(d==null)return 'Sin objetivo definido';return `${d>0?'+':''}${d.toFixed(1)} kg respecto al límite`;}
function freshness(prep){if(!prep.last_measured_at)return {key:'empty',label:'Sin registros'};const hours=(Date.now()-new Date(prep.last_measured_at).getTime())/36e5;const limits={daily:[30,48],three_per_week:[60,84],weekly:[168,216],custom:[72,120]};const [okHours,lateHours]=limits[prep.tracking_frequency]||limits.custom;if(hours<=okHours)return {key:'ok',label:'Actualizado'};if(hours<=lateHours)return {key:'warn',label:'Revisar'};return {key:'late',label:'Pendiente'};}
function daysTo(value){if(!value)return null;return Math.ceil((new Date(value).getTime()-Date.now())/86400000)}

function prepCard(p){const fresh=freshness(p),days=daysTo(p.weigh_in_at);return `<button class="kx-prep-card" type="button" data-kx-prep-open="${esc(p.id)}">
  <div class="kx-prep-card-top"><div><span>${esc(p.event_name||p.discipline||'PREPARACIÓN')}</span><strong>${esc(p.subject_name||p.title)}</strong><small>${esc(p.title)}</small></div><b class="kx-prep-status ${fresh.key}">${esc(fresh.label)}</b></div>
  <div class="kx-prep-metrics"><div><small>Último peso</small><strong>${p.last_weight_kg!=null?`${Number(p.last_weight_kg).toFixed(1)} kg`:'—'}</strong></div><div><small>Límite / objetivo</small><strong>${p.target_weight_kg!=null?`${Number(p.target_weight_kg).toFixed(1)} kg`:'—'}</strong></div><div><small>Pesaje</small><strong>${days==null?'—':days<0?'Finalizado':days===0?'Hoy':`${days} d`}</strong></div></div>
  <div class="kx-prep-card-foot"><span>${esc(deltaText(p))}</span><span>${Number(p.measurement_count||0)} registro${Number(p.measurement_count||0)===1?'':'s'} · ${esc(FREQ_LABEL[p.tracking_frequency]||p.tracking_frequency)}</span></div>
</button>`;}

function chartSvg(rows=[]){const data=[...rows].reverse().slice(-30).map(x=>({w:Number(x.weight_kg),t:new Date(x.measured_at).getTime()})).filter(x=>Number.isFinite(x.w));if(data.length<2)return '<div class="kx-weight-chart-empty">Añade al menos dos registros para ver la evolución.</div>';
  const ws=data.map(x=>x.w),min=Math.min(...ws),max=Math.max(...ws),spread=Math.max(1,max-min),w=620,h=180,p=22;const pts=data.map((x,i)=>{const px=p+(i/(data.length-1))*(w-p*2);const py=h-p-((x.w-min)/spread)*(h-p*2);return `${px.toFixed(1)},${py.toFixed(1)}`}).join(' ');
  return `<div class="kx-weight-chart"><svg viewBox="0 0 ${w} ${h}" role="img" aria-label="Evolución del peso"><line x1="${p}" y1="${h-p}" x2="${w-p}" y2="${h-p}"/><polyline points="${pts}"/><text x="${p}" y="15">${max.toFixed(1)} kg</text><text x="${p}" y="${h-4}">${min.toFixed(1)} kg</text></svg></div>`;}

async function addMeasurement(prep,onDone){openForm({title:'Registrar peso',subtitle:`${prep.subject_name||'Competidor'} · ${prep.title}`,fields:[
  {name:'weight_kg',label:'Peso (kg)',type:'number',required:true,min:15,max:300,step:'0.1'},
  {name:'measured_at',label:'Fecha y hora',type:'datetime-local',value:new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16)},
  {name:'measurement_context',label:'Contexto',type:'select',value:'normal',options:[{value:'normal',label:'Registro habitual'},{value:'fasted',label:'En ayunas'},{value:'post_training',label:'Después de entrenar'},{value:'other',label:'Otro'}]},
  {name:'note',label:'Nota opcional',type:'textarea',rows:2,full:true,placeholder:'Ej. Registro realizado en el club.'},
  {name:'photo',label:'Foto opcional de la báscula',type:'file',accept:'image/jpeg,image/png,image/webp',help:'JPG, PNG o WEBP · privada · máximo 5 MB.',full:true}
 ],submitText:'Guardar registro',onSubmit:async v=>{const out=await repos.competitionPreparation.mutate('measurement.add',{preparation_id:prep.id,weight_kg:Number(v.weight_kg),measured_at:v.measured_at?new Date(v.measured_at).toISOString():new Date().toISOString(),measurement_context:v.measurement_context,note:v.note||''});if(v.photo&&out?.id)await repos.competitionPreparation.uploadEvidence(prep.id,out.id,v.photo);toast('Peso registrado');await onDone();}});}

async function manageAccess(prep,onDone){let rows=[];try{rows=await repos.competitionPreparation.candidates(prep.id)}catch(e){toast(humanError(e),'error');return;}const body=`<div class="kx-prep-access"><div class="kx-prep-privacy-note">${icon('lock',{size:19})}<div><strong>Privado por defecto</strong><p>El peso no aparece en Social ni en el perfil público. Solo las personas autorizadas pueden verlo.</p></div></div>${rows.length?rows.map(r=>`<article><div><strong>${esc(r.name||'Miembro del equipo')}</strong><small>${esc(r.source==='representation'?'Representación profesional':'Equipo del club')}</small><span>${r.access_role?`${esc(ROLE_LABEL[r.access_role]||r.access_role)} · ${(r.access_permissions||[]).map(x=>esc(PERM_LABEL[x]||x)).join(' · ')}`:'Sin acceso específico'}</span></div><div class="row-actions">${r.access_role?`<button class="btn btn-ghost btn-sm" data-kx-access-revoke="${esc(r.perfil_id)}">Revocar</button>`:`<button class="btn btn-primary btn-sm" data-kx-access-grant="${esc(r.perfil_id)}">Dar acceso</button>`}</div></article>`).join(''):'<div class="empty-card compact"><strong>Sin candidatos disponibles</strong><p>Aparecerán entrenadores/equipo del club o representantes vinculados.</p></div>'}</div>`;const {wrap}=openDetail({title:'Equipo de preparación',subtitle:prep.subject_name||prep.title,width:'760px',body});
  wrap.querySelectorAll('[data-kx-access-grant]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Permisos de preparación',fields:[{name:'role_code',label:'Rol',type:'select',value:'trainer',options:Object.entries(ROLE_LABEL).map(([value,label])=>({value,label}))},{name:'read',label:'Puede ver los registros',type:'checkbox',value:true,full:true},{name:'log',label:'Puede añadir pesajes',type:'checkbox',value:false,full:true},{name:'verify',label:'Puede verificar pesajes',type:'checkbox',value:true,full:true}],submitText:'Conceder acceso',onSubmit:async v=>{const permissions=['read'];if(v.log===true)permissions.push('log');if(v.verify===true)permissions.push('verify');await repos.competitionPreparation.mutate('access.grant',{preparation_id:prep.id,perfil_id:b.dataset.kxAccessGrant,role_code:v.role_code,permissions});toast('Acceso actualizado');closeModal();await manageAccess(prep,onDone);}})));
  wrap.querySelectorAll('[data-kx-access-revoke]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.competitionPreparation.mutate('access.revoke',{preparation_id:prep.id,perfil_id:b.dataset.kxAccessRevoke});toast('Acceso revocado');closeModal();await manageAccess(prep,onDone);}catch(e){b.disabled=false;toast(humanError(e),'error')}}));
}

async function openPreparation(prep,scope,onBack){let rows=[];try{rows=await repos.competitionPreparation.measurements(prep.id,180)}catch(e){setError(e)}const latest=rows[0],d=delta(prep),days=daysTo(prep.weigh_in_at);const target=prep.target_weight_kg!=null?Number(prep.target_weight_kg):null;
  setPrepHtml(`<main class="kx-preparation-detail">${pageHeader('Mi preparación',prep.event_name||prep.title,'','Competición')}
    <section class="kx-prep-hero"><div><span>${esc(prep.event_name||'PREPARACIÓN DE COMPETICIÓN')}</span><h1>${esc(prep.subject_name||prep.title)}</h1><p>${esc(prep.category||prep.discipline||'Seguimiento privado de competición')}</p><div class="kx-prep-hero-tags"><b>${esc(FREQ_LABEL[prep.tracking_frequency]||prep.tracking_frequency)}</b>${prep.weigh_in_at?`<b>Pesaje ${esc(dtFmt(prep.weigh_in_at))}</b>`:''}<b>${esc(prep.status==='active'?'Activa':prep.status)}</b></div></div><button class="btn btn-ghost" id="kx-prep-back">Volver</button></section>
    <section class="kx-prep-summary"><div><small>Peso actual</small><strong>${latest?`${Number(latest.weight_kg).toFixed(1)} kg`:'—'}</strong><span>${latest?esc(dtFmt(latest.measured_at)):'Sin registrar'}</span></div><div><small>Límite / referencia</small><strong>${target!=null?`${target.toFixed(1)} kg`:'—'}</strong><span>${target!=null&&d!=null?`${d>0?'+':''}${d.toFixed(1)} kg`:'Configurable'}</span></div><div><small>Pesaje</small><strong>${days==null?'—':days<0?'Finalizado':days===0?'Hoy':`${days} días`}</strong><span>${prep.event_name?esc(prep.event_name):'Sin evento vinculado'}</span></div></section>
    <section class="kx-prep-actions">${prep.can_log?`<button class="btn btn-primary" id="kx-prep-add">${icon('plus',{size:16})} Registrar peso</button>`:''}${prep.can_manage?`<button class="btn btn-ghost" id="kx-prep-team">${icon('users',{size:16})} Equipo y permisos</button>`:''}${prep.can_manage?`<button class="btn btn-ghost" id="kx-prep-edit">Editar preparación</button>`:''}</section>
    <section class="kx-prep-safety">${icon('shieldCheck',{size:21})}<div><strong>Seguimiento deportivo, no asesoramiento médico</strong><p>KOMBAX registra datos y recordatorios. No recomienda deshidratación, pérdidas rápidas de peso, dietas, medicación ni protocolos clínicos. En menores, el seguimiento debe limitarse a control de categoría y pesaje con supervisión adulta.</p></div></section>
    <section class="kx-prep-chart-card"><div class="section-title"><div><span>EVOLUCIÓN</span><h2>Historial de peso</h2></div></div>${chartSvg(rows)}</section>
    <section class="kx-prep-history"><div class="section-title"><div><span>REGISTROS PRIVADOS</span><h2>${rows.length} pesaje${rows.length===1?'':'s'}</h2></div></div>${rows.length?rows.map(m=>`<article class="kx-weight-row"><div class="kx-weight-main"><strong>${Number(m.weight_kg).toFixed(1)} kg</strong><span>${esc(dtFmt(m.measured_at))}</span><small>${esc(CONTEXT_LABEL[m.measurement_context]||m.measurement_context)}${m.recorded_by_name?` · ${esc(m.recorded_by_name)}`:''}</small>${m.note?`<p>${esc(m.note)}</p>`:''}</div><div class="kx-weight-actions"><b class="kx-verify ${esc(m.verification_kind)}">${esc(VERIFY_LABEL[m.verification_kind]||m.verification_kind)}</b>${m.evidence_path?`<button class="btn btn-ghost btn-sm" data-kx-evidence="${esc(m.evidence_path)}">Ver foto</button>`:''}${prep.can_verify&&m.verification_kind==='self'?`<button class="btn btn-ghost btn-sm" data-kx-verify="${esc(m.id)}">Verificar</button>`:''}</div></article>`).join(''):empty('Sin registros','Añade el primer peso cuando corresponda a tu seguimiento.')}</section>
  </main>`);
  document.getElementById('kx-prep-back')?.addEventListener('click',onBack);
  document.getElementById('kx-prep-add')?.addEventListener('click',()=>addMeasurement(prep,async()=>{const fresh=(await repos.competitionPreparation.list(scope)).find(x=>x.id===prep.id)||prep;await openPreparation(fresh,scope,onBack);}));
  document.getElementById('kx-prep-team')?.addEventListener('click',()=>manageAccess(prep,async()=>openPreparation(prep,scope,onBack)));
  document.getElementById('kx-prep-edit')?.addEventListener('click',()=>openForm({title:'Editar seguimiento',subtitle:'La competición y la inscripción permanecen vinculadas; aquí solo ajustas el seguimiento privado.',fields:[{name:'title',label:'Nombre',required:true},{name:'discipline',label:'Disciplina'},{name:'category',label:'Categoría'},{name:'target_weight_kg',label:'Peso límite / referencia (kg)',type:'number',min:15,max:300,step:'0.1'},{name:'weigh_in_at',label:'Fecha y hora del pesaje',type:'datetime-local'},{name:'tracking_frequency',label:'Frecuencia',type:'select',options:[{value:'weekly',label:'Semanal'},{value:'three_per_week',label:'3 veces por semana'},{value:'daily',label:'Diario'},{value:'custom',label:'Personalizado'}]}],initial:{...prep,weigh_in_at:prep.weigh_in_at?new Date(new Date(prep.weigh_in_at).getTime()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16):''},submitText:'Guardar cambios',onSubmit:async v=>{await repos.competitionPreparation.mutate('preparation.save',{...scope,id:prep.id,event_id:prep.event_id||scope.event_id||null,...v,target_weight_kg:v.target_weight_kg||null,weigh_in_at:v.weigh_in_at?new Date(v.weigh_in_at).toISOString():null});toast('Seguimiento actualizado');const fresh=(await repos.competitionPreparation.list(scope)).find(x=>x.id===prep.id)||prep;await openPreparation(fresh,scope,onBack);}}));
  document.querySelectorAll('[data-kx-verify]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.competitionPreparation.mutate('measurement.verify',{measurement_id:b.dataset.kxVerify,verification_kind:'team'});toast('Pesaje verificado');const fresh=(await repos.competitionPreparation.list(scope)).find(x=>x.id===prep.id)||prep;await openPreparation(fresh,scope,onBack);}catch(e){b.disabled=false;toast(humanError(e),'error')}}));
  document.querySelectorAll('[data-kx-evidence]').forEach(b=>b.addEventListener('click',async()=>{try{const url=await repos.competitionPreparation.evidenceUrl(b.dataset.kxEvidence);const {wrap}=openDetail({title:'Evidencia del pesaje',subtitle:'Imagen privada · acceso temporal',width:'620px',body:`<div class="kx-weight-evidence"><img src="${esc(url)}" alt="Foto privada de la báscula"><small>Esta imagen no forma parte de KOMBAX Social ni del perfil público.</small></div>`});wrap.querySelector('img')?.addEventListener('error',()=>toast('No se pudo abrir la imagen.','error'));}catch(e){toast(humanError(e),'error')}}));
}

async function activateRegistrationPreparation(row,eventSource,eventId,onDone){
  if(!row?.can_manage_private){toast('No tienes permiso para activar el seguimiento privado de esta inscripción.','error');return;}
  if(row.is_external){toast('El seguimiento privado requiere un miembro o perfil Competidor KOMBAX vinculado. El pesaje oficial sí puede registrarse desde el evento.','error');return;}
  openForm({title:'Activar preparación',subtitle:`${row.participant_name||'Competidor'} · seguimiento vinculado a esta inscripción`,width:'720px',fields:[
    {name:'target_weight_kg',label:'Peso límite / referencia (kg)',type:'number',min:15,max:300,step:'0.1',value:row.target_weight_kg||'',help:'Dato deportivo de seguimiento. KOMBAX no prescribe pérdidas de peso ni protocolos de deshidratación.'},
    {name:'weigh_in_at',label:'Fecha y hora del pesaje',type:'datetime-local'},
    {name:'tracking_frequency',label:'Frecuencia de registro',type:'select',required:true,value:'weekly',options:[{value:'weekly',label:'Semanal'},{value:'three_per_week',label:'3 veces por semana'},{value:'daily',label:'Diario'},{value:'custom',label:'Personalizado'}]}
  ],submitText:'Activar seguimiento',onSubmit:async values=>{
    await repos.competitionPreparation.registrationMutate('registration.preparation.activate',{event_source:eventSource,registration_id:row.registration_id,target_weight_kg:values.target_weight_kg||null,weigh_in_at:values.weigh_in_at?new Date(values.weigh_in_at).toISOString():null,tracking_frequency:values.tracking_frequency});
    toast('Preparación activada para esta inscripción.');await onDone?.();
  }});
}

export async function registerOfficialWeighIn({eventSource,eventId,registrationId,onDone=null}={}){
  const roster=await repos.competitionPreparation.eventRoster(eventSource,eventId);const row=(roster||[]).find(x=>String(x.registration_id)===String(registrationId));
  if(!row){toast('Inscripción no disponible.','error');return;}
  if(!row.can_official_weigh_in){toast('El pesaje oficial corresponde a la organización autorizada del evento.','error');return;}
  if(row.official_weight_kg!=null){toast('El pesaje oficial ya está cerrado y permanece bloqueado como histórico.','error');return;}
  openForm({title:'Registrar pesaje oficial',subtitle:`${row.participant_name||'Competidor'} · ${row.category_label||'categoría por confirmar'}`,width:'680px',fields:[
    {name:'weight_kg',label:'Peso oficial (kg)',type:'number',required:true,min:15,max:300,step:'0.1'},
    {name:'weighed_at',label:'Fecha y hora del pesaje',type:'datetime-local',value:new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16)}
  ],submitText:'Confirmar y bloquear',onSubmit:async values=>{
    await repos.competitionPreparation.registrationMutate('official_weigh_in.set',{event_source:eventSource,registration_id:registrationId,weight_kg:Number(values.weight_kg),weighed_at:values.weighed_at?new Date(values.weighed_at).toISOString():new Date().toISOString()});
    toast('Pesaje oficial registrado y bloqueado.');await onDone?.();
  }});
}

export async function renderCompetitionPreparation({competitorProfileId=null,socioId=null,clubId=null,eventId=null,eventSource=null,registrationId=null,onBack=null,title='Mis competiciones'}={}){
  const scope=subjectOptions({competitorProfileId,socioId,clubId,eventId});setPrepHtml('<div class="loading-card">Cargando competición…</div>');
  try{
    if(eventSource&&eventId&&registrationId){
      const roster=await repos.competitionPreparation.eventRoster(eventSource,eventId);const row=(roster||[]).find(x=>String(x.registration_id)===String(registrationId));
      if(!row){setPrepHtml(`${pageHeader(title)}${empty('Inscripción no disponible','No tienes acceso a esta inscripción o ya no forma parte del evento.')}`);return;}
      if(row.preparation_id&&row.can_view_private){
        const rowScope=subjectOptions({competitorProfileId:row.competitor_profile_id,socioId:row.socio_id,clubId,eventId:eventSource==='kombax_event'?eventId:null});
        const preps=await repos.competitionPreparation.list(rowScope);const prep=(preps||[]).find(x=>String(x.id)===String(row.preparation_id));
        if(prep){await openPreparation(prep,rowScope,onBack||(()=>{}));return;}
      }
      const status=row.official_weight_kg!=null?`Pesaje oficial: ${Number(row.official_weight_kg).toFixed(1)} kg`:(row.preparation_id?'Seguimiento activo':'Seguimiento no activado');
      setPrepHtml(`<main class="kx-preparation-page">${pageHeader(title,'Seguimiento ligado exclusivamente a esta inscripción','','Competición')}
        <section class="kx-prep-intro"><div>${icon('activity',{size:28})}</div><div><span>EVENTO → INSCRIPCIÓN → PREPARACIÓN</span><h2>${esc(row.participant_name||'Competidor')}</h2><p>${esc(row.category_label||'Categoría por confirmar')} · ${esc(status)}</p></div>${row.can_manage_private&&!row.preparation_id&&!row.is_external?'<button class="btn btn-primary" id="kx-prep-activate">Activar seguimiento</button>':''}</section>
        <section class="kx-prep-privacy-note">${icon('lock',{size:20})}<div><strong>Histórico privado</strong><p>La organización o federación no ve los registros diarios por organizar el evento. Solo recibe la información administrativa y el pesaje oficial.</p></div></section>
        ${row.is_external?empty('Seguimiento privado no disponible','Esta ficha es externa y no está enlazada a un perfil Competidor o miembro KOMBAX. Puede registrar el pesaje oficial la organización.'):(row.preparation_id&&!row.can_view_private?empty('Preparación privada','El seguimiento existe, pero tu rol en este evento no te concede acceso al histórico diario.'):empty('Seguimiento pendiente','Actívalo desde esta inscripción para comenzar a registrar la evolución.'))}
      </main>`);
      document.getElementById('kx-prep-activate')?.addEventListener('click',()=>activateRegistrationPreparation(row,eventSource,eventId,()=>renderCompetitionPreparation({competitorProfileId,socioId,clubId,eventId,eventSource,registrationId,onBack,title})));
      if(onBack){const head=document.querySelector('.page-head');if(head){const btn=document.createElement('button');btn.type='button';btn.className='btn btn-ghost btn-sm';btn.textContent='Volver';btn.addEventListener('click',onBack);head.append(btn);}}
      return;
    }

    const rows=await repos.competitionPreparation.list(scope);setPrepHtml(`<main class="kx-preparation-page">${pageHeader(title,'Tus seguimientos aparecen vinculados a las competiciones en las que participas','','Competición')}
      <section class="kx-prep-intro"><div>${icon('activity',{size:28})}</div><div><span>MIS COMPETICIONES</span><h2>Preparación asociada a cada inscripción.</h2><p>El seguimiento se activa desde un evento concreto. Aquí conservas el acceso a tus competiciones y a su histórico privado.</p></div></section>
      <section class="kx-prep-privacy-note">${icon('lock',{size:20})}<div><strong>Privado por defecto</strong><p>Los registros de peso no se publican en Social ni se comparten con otros clubes o con una federación salvo los datos oficiales necesarios del evento.</p></div></section>
      <section class="kx-prep-list">${rows.length?rows.map(prepCard).join(''):empty('Todavía no tienes seguimientos activos','Cuando una inscripción a una competición active preparación, aparecerá aquí automáticamente.')}</section>
    </main>`);
    const refresh=()=>renderCompetitionPreparation({competitorProfileId,socioId,clubId,eventId,eventSource,registrationId,onBack,title});
    document.querySelectorAll('[data-kx-prep-open]').forEach(b=>b.addEventListener('click',()=>{const prep=rows.find(x=>x.id===b.dataset.kxPrepOpen);if(prep)openPreparation(prep,scope,refresh)}));
    if(onBack){const head=document.querySelector('.page-head');if(head){const btn=document.createElement('button');btn.type='button';btn.className='btn btn-ghost btn-sm';btn.textContent='Volver';btn.addEventListener('click',onBack);head.append(btn);}}
  }catch(e){setError(e);setPrepHtml(`${pageHeader(title)}${empty('No se pudo cargar el seguimiento',humanError(e))}`);}
}

export function migrationAssistBanner(){return `<section class="kx-migration-assist-banner"><div class="kx-migration-assist-icon">${icon('upload',{size:24})}</div><div><span>KOMBAX MIGRATIONS · ACCESO DIRECTO</span><h3>¿Ya tienes tus datos en Excel, CSV, PDF, fichas o imágenes?</h3><p>Entra directamente al chat de migración y sube tus documentos en la misma conversación. KOMBAX Migrations analiza por lotes, reutiliza lo ya extraído y prepara una vista previa; nunca importa datos sin confirmación.</p></div><button type="button" class="btn btn-primary" data-kx-migration-assist>Abrir KOMBAX Migrations</button></section>`;}
