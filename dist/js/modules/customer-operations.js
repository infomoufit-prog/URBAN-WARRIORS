import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { openDetail, toast, setMainHtml, pageHeader, confirmDialog, closeModal, subviewActions, bindSubviewActions, goBackOrFallback } from '../ui/components.js';
import { conversationChannelTabs, bindConversationChannelTabs } from '../ui/conversation-ui.js';
import { ASSIST_SPECIALISTS, DEFAULT_ASSIST_SPECIALIST, assistSpecialist, specialistFromSubject } from '../core/assist-specialists.js';
import { t, formatDate, formatNumber } from '../i18n/index.js';

const STATUS={OPEN:'Solicitud recibida',AI_REVIEW:'Analizando',WAITING_USER:'Necesita revisión',AI_RESOLVED:'Listo para confirmar',GUIDED_SESSION:'Chat activado',ESCALATED:'Revisión especializada',HUMAN_REVIEW:'Revisión humana',RESOLVED:'Completado',CLOSED:'Cerrado'};
const CATEGORY_LABEL={MANAGEMENT:'Asistencia de gestión',GENERAL:'Soporte KOMBAX',MIGRATION:'Migración de datos',ONBOARDING:'Configuración inicial',INCIDENT:'Incidencia técnica',SECURITY:'Seguridad',DATA_LOSS:'Pérdida de datos',CRITICAL_PERMISSIONS:'Permisos críticos'};
const SUPPORT_EMAIL='soporte@kombax.es';
const PRIVACY_EMAIL='privacidad@kombax.es';
const SECURITY_EMAIL='seguridad@kombax.es';
const CHILD_SAFETY_EMAIL='childsafety@kombax.es';
const migrationAccept='.pdf,.xlsx,.xls,.csv,.jpg,.jpeg,.png,.webp';
const CLUB_ORG_ASSIST_ROLES=new Set(['direccion','coordinacion','secretaria','economia']);
const migrationDrafts=new Map();

function clubOrgTenantRef(){
  const clubId=String(state.session?.club_id||'').trim();
  const role=String(state.session?.rol||'').trim().toLowerCase();
  return clubId&&CLUB_ORG_ASSIST_ROLES.has(role)?`club:${clubId}`:'';
}
function orgTenantRef(context={}){
  const explicit=String(context?.tenantRef||'').trim();if(explicit)return explicit.slice(0,160);
  if(String(context?.profileType||'').toLowerCase()==='club')return clubOrgTenantRef();
  const profileId=String(context?.profileId||'').trim();if(profileId)return `profile:${profileId}`;
  return clubOrgTenantRef();
}
function canUseClubOrgAssist(){return Boolean(clubOrgTenantRef())}
function stripeConnectSubject(context={}){
  const profileId=String(context?.profileId||'').trim(),profileType=String(context?.profileType||'').trim().toLowerCase();
  if(profileId&&profileType==='marca')return {type:'showcase_provider',id:profileId};
  if(profileId&&profileType==='federacion')return {type:'federation',id:profileId};
  const clubId=String(state.session?.club_id||'').trim();return clubId?{type:'club',id:clubId}:null;
}
function asNumber(v,fallback=0){const n=Number(v);return Number.isFinite(n)?n:fallback}
function quotaBar(used,total){const safeTotal=Math.max(1,asNumber(total,1)),pct=Math.min(100,Math.max(0,Math.round(asNumber(used)/safeTotal*100)));return `<div class="kx-assist-quota-bar"><i style="width:${pct}%"></i></div>`}
function assistanceQuota(dashboard){const a=dashboard?.assistance||{};return {used:asNumber(a.used),total:asNumber(a.total),remaining:asNumber(a.remaining),periodEnd:a.period_end,messagesPerConversation:asNumber(a.messages_per_conversation,10)}}
function migrationQuota(dashboard){const m=dashboard?.migration||{};return {used:asNumber(m.used),total:asNumber(m.total),remaining:asNumber(m.remaining),documentsUsed:asNumber(m.documents_used),documentsMax:asNumber(m.documents_max),mbUsed:asNumber(m.mb_used),mbMax:asNumber(m.mb_max),validUntil:m.valid_until,messagesPerConversation:asNumber(m.messages_per_conversation,24)}}
function creditControl(credits){
  if(!credits)return '<span class="kx-ai-credit-unavailable">Créditos IA · saldo no disponible</span>';
  const available=Math.max(0,asNumber(credits.available));
  const total=Math.max(available,asNumber(credits.granted_total||credits.plan_total));
  const used=Math.max(0,asNumber(credits.used_total));
  const renewal=credits.renewal_at?formatDate(credits.renewal_at,{day:'numeric',month:'long'}):'Pendiente';
  const pct=total>0?Math.round((total-available)/total*100):0;
  const warning=pct>=100?'Has utilizado los Créditos IA incluidos en tu plan.':pct>=90?'Te quedan pocos Créditos IA.':pct>=75?'Has utilizado la mayor parte de tus Créditos IA de este periodo.':'';
  return `<details class="kx-ai-credit-control"><summary aria-label="Ver Créditos IA disponibles">🪙 <b>${formatNumber(Math.floor(available))}</b><span>créditos</span></summary><div class="kx-ai-credit-popover"><strong>Créditos IA</strong><p class="kx-ai-credit-amount">${formatNumber(Math.floor(available))} / ${formatNumber(Math.floor(total))} disponibles</p><dl><div><dt>Plan</dt><dd>${esc(String(credits.plan||'KOMBAX'))}</dd></div><div><dt>Próxima renovación</dt><dd>${esc(renewal)}</dd></div><div><dt>Uso de este periodo</dt><dd>${formatNumber(Math.floor(used))} créditos</dd></div></dl><p>Assist y Migrations utilizan el mismo saldo de esta organización. Las tareas sencillas consumen menos que los análisis extensos o las migraciones.</p>${warning?`<p class="kx-ai-credit-warning">${esc(warning)}</p>`:''}<details class="kx-ai-credit-help"><summary>Cómo funcionan los créditos</summary><p>Los Créditos IA permiten utilizar las herramientas inteligentes de KOMBAX. Todos tus asistentes comparten el mismo saldo. Las tareas sencillas consumen menos que los análisis extensos, documentos o migraciones complejas. El consumo se calcula automáticamente según los recursos utilizados.</p></details></div></details>`;
}
function aiCreditsCard(credits){return `<section class="kx-ai-credit-overview" aria-label="Créditos IA"><div><strong>Créditos IA</strong><p>Assist y Migrations comparten el saldo de esta organización.</p></div>${creditControl(credits)}</section>`}
function assistanceQuotaCard(dashboard){const a=assistanceQuota(dashboard);return `<div class="kx-assist-quota-grid single"><article><span>KOMBAX ASSIST · GESTIÓN</span><strong>${a.remaining} / ${a.total}</strong><p>conversaciones disponibles este mes</p>${quotaBar(a.used,a.total)}<small>Hasta <b>${a.messagesPerConversation}</b> mensajes tuyos por conversación. Una conversación empieza a consumir cupo cuando envías el primer mensaje; así protegemos el uso de IA incluido en tu plan.</small></article></div>`}
function migrationQuotaCard(dashboard){const m=migrationQuota(dashboard);return `<div class="kx-assist-quota-grid single"><article><span>KOMBAX MIGRATIONS</span><strong>${m.remaining} / ${m.total}</strong><p>migraciones disponibles</p>${quotaBar(m.used,m.total)}<small>Hasta <b>${m.messagesPerConversation}</b> mensajes tuyos por migración · ${m.documentsUsed} / ${m.documentsMax||'—'} documentos · ${m.mbUsed.toFixed(1)} / ${m.mbMax||'—'} MB.</small></article></div>`}
function isMigrationTicket(ticket){return String(ticket?.category||'')==='MIGRATION'}
function isManagementTicket(ticket){return String(ticket?.category||'')==='MANAGEMENT'}
function isSupportTicket(ticket){return !isMigrationTicket(ticket)&&!isManagementTicket(ticket)}
function isGuidedSupportTicket(ticket){return isSupportTicket(ticket)&&String(ticket?.status||'')==='GUIDED_SESSION'}
function canMigrationContext(context={}){const type=String(context?.profileType||'').toLowerCase();if(type&&!['club','federacion','marca','competidor','profesional'].includes(type))return false;return Boolean(orgTenantRef(context))}
function ticketRows(rows=[],{mode='all'}={}){
  const filtered=(rows||[]).filter(t=>mode==='migration'?isMigrationTicket(t):mode==='assist'?isManagementTicket(t):mode==='support'?isSupportTicket(t):true);
  if(!filtered.length){
    const title=mode==='migration'?'Sin migraciones todavía':mode==='support'?'Sin casos de soporte todavía':'Sin conversaciones de gestión todavía';
    const body=mode==='migration'?'Inicia una migración, conversa y añade documentos dentro del mismo caso.':mode==='support'?`Cuando contactes con ${SUPPORT_EMAIL}, tus casos y chats guiados aparecerán aquí.`:'Abre una conversación cuando necesites analizar o entender la gestión de tu organización.';
    return `<div class="empty-card compact"><strong>${title}</strong><p>${body}</p></div>`;
  }
  return filtered.map(t=>{
    const migration=isMigrationTicket(t),management=isManagementTicket(t),support=isSupportTicket(t),guided=isGuidedSupportTicket(t);
    const primary=migration?`<button class="btn btn-ghost btn-sm" data-kx-migration="${esc(t.ticket_id)}">Continuar migración</button>`:management?`<button class="btn btn-ghost btn-sm" data-kx-assist="${esc(t.ticket_id)}">Continuar conversación</button>`:guided?`<button class="btn btn-primary btn-sm" data-kx-support-chat="${esc(t.ticket_id)}">Abrir chat guiado</button>`:`<a class="btn btn-ghost btn-sm" href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`Soporte KOMBAX · ${t.ticket_id}`)}">Continuar por correo</a>`;
    const human=migration?`<button class="btn btn-ghost btn-sm" data-kx-human="${esc(t.ticket_id)}">Revisión humana</button>`:'';
    const deletion=(migration||management)?`<button class="btn btn-ghost btn-sm" data-kx-delete-ticket="${esc(t.ticket_id)}" data-kx-delete-mode="${migration?'migration':'management'}">Eliminar conversación</button>`:'';
    return `<article class="kx-ticket-row ${support?'support-ticket':''}"><div><span>${esc(t.ticket_id)}</span><strong>${esc(t.subject_redacted)}</strong><small>${esc(CATEGORY_LABEL[t.category]||t.category)} · ${dtFmt(t.updated_at)}</small></div><div><b class="badge">${esc(STATUS[t.status]||t.status)}</b>${primary}${human}${deletion}</div></article>`;
  }).join('');
}
async function createTicket(category='MANAGEMENT',subject='Asistencia de gestión KOMBAX',module='assist',context={}){
  const tenant_ref=orgTenantRef(context);if(!tenant_ref)throw new Error('KOMBAX_MANAGEMENT_ACCESS_REQUIRED');
  return repos.customerOps.createTicket({category,subject,module,tenant_ref});
}
function assistantAvatar(){return `<img class="kx-ai-avatar" src="./assets/assist/assistant-avatar.webp" alt="Asistente virtual KOMBAX" loading="eager" decoding="async">`}
function supportMark(){
  return `<span class="kx-support-mark" aria-hidden="true">✓</span>`;
}
function messageBubbles(rows=[],{migration=false,support=false}={}){
  const brand=support?'Soporte KOMBAX':migration?'KOMBAX Migrations':'KOMBAX Assist';
  if(!rows.length){
    if(support)return `<div class="kx-support-chat-empty"><div class="kx-support-mark large">✓</div><div><strong>Soporte KOMBAX · chat guiado</strong><p>Este canal técnico está vinculado a un caso formal. Primero atendemos el caso por correo. Si aporta valor al diagnóstico, Soporte KOMBAX puede habilitar este chat guiado y, si existe urgencia o hace falta intervención directa, Combots puede asignar asistencia humana.</p></div></div>`;
    return `<div class="kx-assist-welcome kx-assist-welcome-avatar ${migration?'migrations':''}"><span class="kx-assist-welcome-avatar-shell">${assistantAvatar()}</span><div><strong>${brand}${migration?' · Asistente de migración':' · Copiloto de gestión'}</strong><p>${migration?'Cuéntame cómo tienes organizados los datos o añade archivos. Prepararé el análisis y la vista previa, pero no se importará nada sin confirmación.':'Puedo ayudarte a interpretar la gestión autorizada de tu Club, Federación, Marca, Competidor o Profesional. Durante el piloto trabajo en modo de solo lectura: analizo y te indico el siguiente paso, sin modificar datos.'}</p></div></div>`;
  }
  return rows.map(m=>{
    const user=String(m.role).toUpperCase()==='USER';
    const label=user?'TÚ':support?'SOPORTE GUIADO':migration?'KOMBAX MIGRATIONS':'KOMBAX ASSIST';
    const avatar=user?'':`<span class="kx-bubble-avatar">${support?supportMark():assistantAvatar()}</span>`;
    return `<div class="kx-assist-bubble ${user?'user':'assistant'} ${support?'support':''}">${avatar}<div><small>${label}</small><p>${esc(m.content_text).replace(/\n/g,'<br>')}</p><time>${dtFmt(m.created_at)}</time></div></div>`;
  }).join('');
}
function migrationFileRows(preview){
  const analyses=Array.isArray(preview?.files)?preview.files:[],total=asNumber(preview?.files_total),analyzed=asNumber(preview?.files_analyzed),pending=Math.max(0,total-analyzed),review=asNumber(preview?.needs_review),records=asNumber(preview?.detected_records);
  const summary=`<div class="kx-migration-summary"><span><b>${total}</b> archivos</span><span><b>${analyzed}</b> analizados</span><span><b>${pending}</b> pendientes</span><span><b>${review}</b> a revisar</span><span><b>${records}</b> registros detectados</span></div>`;
  const rows=analyses.length?`<div class="kx-migration-analysis-list">${analyses.map(a=>`<article><div><strong>${esc(a.name||a.original_name||a.file_id||'Archivo')}</strong><p>${esc(a.summary||'Pendiente de análisis')}</p></div><span class="badge ${a.needs_review?'warning':''}">${!a.summary?'PENDIENTE':a.needs_review?'REVISAR':'ANALIZADO'}</span></article>`).join('')}</div>`:'<div class="muted">Todavía no hay archivos analizados por KOMBAX Migrations.</div>';
  return `${summary}${rows}<div class="kx-assist-note"><strong>Confirmación obligatoria.</strong> Revisa y completa los campos directamente. Solo se pedirá una confirmación al pulsar incorporar.</div>`;
}
function migrationReviewPanel(data={},catalog={}){
  const files=Array.isArray(data?.files)?data.files:[],rows=files.flatMap(file=>(Array.isArray(file.records)?file.records:[]).map(r=>({...r,file_name:file.file_name||'Archivo'})));
  if(!rows.length)return `<section class="kx-migration-review"><h3>Revisión e importación</h3><p>Cuando el análisis detecte filas, aparecerán aquí para corregirlas y decidir qué importar.</p></section>`;
  const option=(items=[],selected='')=>`<option value="">Seleccionar…</option>${items.filter(x=>x?.activo!==false&&x?.activa!==false).map(x=>`<option value="${esc(x.id)}" ${String(x.id)===String(selected)?'selected':''}>${esc(x.nombre||x.name||'')}</option>`).join('')}`;
  const groupOption=(discipline='',selected='')=>`<select data-field="group_id" data-options="${esc(JSON.stringify(Object.fromEntries(catalog.groups.map(x=>[x.id,x.disciplina_id]))))}"><option value="">Seleccionar…</option>${catalog.groups.filter(x=>x?.activo!==false).map(x=>`<option value="${esc(x.id)}" ${String(x.id)===String(selected)?'selected':''}>${esc(x.nombre||'')}</option>`).join('')}</select>`;
  const catalogKey=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
  const uniqueMatch=(items,label)=>{const key=catalogKey(label);if(!key)return '';const matches=items.filter(x=>catalogKey(x.nombre||x.name)===key);return matches.length===1?String(matches[0].id):'';};
  const cards=rows.slice(0,200).map((r,i)=>{const f=r.fields||{},kind=['student','charge','payment'].includes(r.kind)?r.kind:'student';const disciplineId=String(f.discipline_id||uniqueMatch(catalog.disciplines,f.discipline_name)||'');const eligibleGroups=catalog.groups.filter(x=>x?.activo!==false&&String(x.disciplina_id)===disciplineId);const groupId=String(f.group_id||uniqueMatch(eligibleGroups,f.group_name)||(eligibleGroups.length===1?eligibleGroups[0].id:'')||'');return `<article class="kx-migration-review-row" data-migration-row="${i}" data-source-ref="${esc(r.source_ref||'')}" data-kind="${kind}"><header><label><input type="checkbox" data-import-selected checked> Incluir fila</label><b>${kind==='student'?'Alumno':kind==='charge'?'Cargo':'Pago'}</b><small>${esc(r.file_name)} · Ref. ${esc(r.source_ref||'')}</small></header><div class="kx-migration-fields">${kind==='student'?`<label>Nombre<input data-field="name" value="${esc(f.name||'')}" autocomplete="off"></label><label>Apellidos<input data-field="surname" value="${esc(f.surname||'')}" autocomplete="off"></label><label>Fecha de nacimiento<input data-field="birth_date" type="date" value="${esc(f.birth_date||'')}"></label><label>Correo<input data-field="email" type="email" value="${esc(f.email||'')}"></label><label>Teléfono<input data-field="phone" value="${esc(f.phone||'')}"></label><label>Tutor/a<input data-field="guardian_name" value="${esc(f.guardian_name||'')}"></label><label>Disciplina<select data-field="discipline_id">${option(catalog.disciplines,disciplineId)}</select></label><label>Grupo${groupOption(disciplineId,groupId)}</label><label>Tarifa<select data-field="tariff_id">${option(catalog.tariffs,f.tariff_id)}</select></label>`:kind==='charge'?`<label>Alumno de esta migración<input data-field="student_source_ref" value="${esc(f.student_source_ref||'')}" placeholder="Referencia de la fila del alumno"></label><label>Periodo<input data-field="period" type="date" value="${esc(f.period||'')}"></label><label>Vencimiento<input data-field="due_date" type="date" value="${esc(f.due_date||'')}"></label><label>Importe<input data-field="amount" type="number" min="0" step="0.01" value="${esc(f.amount??'')}"></label><label>Concepto<input data-field="concept" value="${esc(f.concept||'')}"></label>`:`<label>Cargo de esta migración<input data-field="charge_source_ref" value="${esc(f.charge_source_ref||'')}" placeholder="Referencia de la fila del cargo"></label><label>Fecha<input data-field="date" type="date" value="${esc(f.date||'')}"></label><label>Importe<input data-field="amount" type="number" min="0.01" step="0.01" value="${esc(f.amount??'')}"></label><label>Método<select data-field="method">${['','transferencia','bizum','efectivo','tarjeta','sepa','terminal','otro'].map(x=>`<option ${x===String(f.method||'')?'selected':''} value="${x}">${x||'Seleccionar…'}</option>`).join('')}</select></label><label>Referencia<input data-field="reference" value="${esc(f.reference||'')}"></label>`}</div>${(r.issues||[]).length?`<p class="warning">${esc(r.issues.join(' · '))}</p>`:''}</article>`;}).join('');
  return `<section class="kx-migration-review"><div><h3>Datos identificados por KOMBAX Migrations</h3><p>${rows.length} fila(s). Completa solo las preguntas pendientes; el agente preparará la importación cuando los datos esenciales estén listos.</p></div><div id="kx-migration-questions" class="kx-migration-questions" role="status" aria-live="polite"></div><div id="kx-migration-updates"></div><div id="kx-migration-result"></div><div class="kx-migration-review-list">${cards}</div><button class="btn btn-primary" id="kx-migration-import">Sí, incorporar estos datos</button><small>Hasta 200 filas por operación. Los alumnos entran como prealta, las cuotas quedan pendientes y los pagos requieren validación. No se actualizan fichas existentes.</small></section>`;
}
function selectedMigrationRecords(wrap){
  return [...wrap.querySelectorAll('[data-migration-row]')].filter(card=>card.querySelector('[data-import-selected]')?.checked).map(card=>{
    const fields={};card.querySelectorAll('[data-field]').forEach(el=>fields[el.dataset.field]=String(el.value||'').trim());
    return {source_ref:card.dataset.sourceRef,kind:card.dataset.kind,fields,selected:true,needs_review:false};
  });
}
function decorateMigrationRelations(wrap){
  const cards=[...wrap.querySelectorAll('[data-migration-row]')];
  const choices=(kind)=>cards.filter(card=>card.dataset.kind===kind).map(card=>({source:card.dataset.sourceRef,label:kind==='student'?`${card.querySelector('[data-field="name"]')?.value||'Alumno'} ${card.querySelector('[data-field="surname"]')?.value||''}`.trim():`${card.querySelector('[data-field="concept"]')?.value||'Cuota'} · ${card.querySelector('[data-field="amount"]')?.value||''} €`}));
  for(const [kind,field,linkedKind] of [['charge','student_source_ref','student'],['payment','charge_source_ref','charge']]){
    const options=choices(linkedKind);
    cards.filter(card=>card.dataset.kind===kind).forEach(card=>{
      const input=card.querySelector(`[data-field="${field}"]`);if(!input||input.tagName==='SELECT')return;
      const current=String(input.value||''),select=document.createElement('select');select.dataset.field=field;
      select.innerHTML=`<option value="">Seleccionar ${linkedKind==='student'?'alumno':'cuota'}…</option>${options.map(option=>`<option value="${esc(option.source)}" ${option.source===current?'selected':''}>${esc(option.label)}</option>`).join('')}`;
      input.replaceWith(select);
    });
  }
}
function syncMigrationGroupOptions(wrap){
  wrap.querySelectorAll('[data-migration-row][data-kind="student"]').forEach(card=>{
    const discipline=card.querySelector('[data-field="discipline_id"]'),group=card.querySelector('[data-field="group_id"]');if(!discipline||!group)return;
    const map=JSON.parse(group.dataset.options||'{}');[...group.options].forEach((option,index)=>{option.hidden=index>0&&Boolean(discipline.value)&&map[option.value]!==discipline.value;});
  });
}
function captureMigrationDraft(wrap,ticketId){
  const cards=[...wrap.querySelectorAll('[data-migration-row]')];if(!cards.length)return;
  const draft=new Map();for(const card of cards){const fields={};card.querySelectorAll('[data-field]').forEach(input=>fields[input.dataset.field]=input.value);draft.set(card.dataset.sourceRef,{fields,selected:card.querySelector('[data-import-selected]')?.checked!==false});}
  migrationDrafts.set(ticketId,draft);
  try{sessionStorage.setItem(`kx:migration-draft:${ticketId}`,JSON.stringify([...draft]));}catch{}
}
function restoreMigrationDraft(wrap,ticketId){
  let draft=migrationDrafts.get(ticketId);
  if(!draft){try{const saved=JSON.parse(sessionStorage.getItem(`kx:migration-draft:${ticketId}`)||'null');if(Array.isArray(saved))draft=new Map(saved);}catch{}}
  if(!draft)return;
  wrap.querySelectorAll('[data-migration-row]').forEach(card=>{
    const prior=draft.get(card.dataset.sourceRef);if(!prior)return;
    const selected=card.querySelector('[data-import-selected]');if(selected)selected.checked=prior.selected;
    card.querySelectorAll('[data-field]').forEach(input=>{const value=prior.fields[input.dataset.field];if(value!==undefined&&(!input.options||[...input.options].some(option=>option.value===value)))input.value=value;});
  });
}
function applyMigrationFieldUpdates(wrap,updates=[]){
  if(!Array.isArray(updates)||!updates.length)return 0;
  const normalized=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
  let applied=0;
  for(const update of updates){
    const card=[...wrap.querySelectorAll('[data-migration-row]')].find(row=>row.dataset.sourceRef===String(update?.source_ref||''));if(!card)continue;
    for(const [field,value] of Object.entries(update.fields||{}).sort(([a],[b])=>Number(a==='group_name')-Number(b==='group_name'))){
      const targetField=field==='discipline_name'?'discipline_id':field==='group_name'?'group_id':field==='tariff_name'?'tariff_id':field;
      const input=card.querySelector(`[data-field="${targetField}"]`);if(!input||value==null)continue;
      if(input.options){const option=[...input.options].find(option=>field.endsWith('_name')?normalized(option.textContent)===normalized(value):option.value===String(value));if(!option)continue;input.value=option.value;if(field==='discipline_name'){const group=card.querySelector('[data-field="group_id"]');if(group){group.value='';const map=JSON.parse(group.dataset.options||'{}');[...group.options].forEach((item,index)=>{item.hidden=index>0&&map[item.value]!==input.value;});}}}
      else input.value=String(value);
      applied++;
    }
  }
  updateMigrationGuidance(wrap);
  const status=wrap.querySelector('#kx-migration-updates');if(status&&applied)status.innerHTML=`<p class="kx-migration-ai-updates" role="status">El agente ha propuesto ${applied} dato(s) a partir de tu respuesta. Comprueba los campos resaltados antes de autorizar la incorporación.</p>`;
  return applied;
}
function migrationQuestions(records=[],wrap=null){
  const questions=[],studentRefs=new Set(records.filter(r=>r.kind==='student').map(r=>r.source_ref)),charges=new Map(records.filter(r=>r.kind==='charge').map(r=>[r.source_ref,r]));
  for(const record of records){
    const f=record.fields||{},label=record.kind==='student'?`${f.name||'Alumno'} ${f.surname||''}`.trim():record.kind==='charge'?`Cuota ${f.concept||''}`.trim():'Pago';
    const ask=(condition,question)=>{if(condition)questions.push(`${label}: ${question}`);};
    if(record.kind==='student'){
      ask(!f.name||!f.surname,'¿cuál es su nombre y apellido completos?');
      ask(!f.discipline_id,'¿qué disciplina o arte marcial practica?');
      const card=[...(wrap?.querySelectorAll('[data-migration-row]')||[])].find(row=>row.dataset.sourceRef===record.source_ref),group=card?.querySelector('[data-field="group_id"]'),groupMap=JSON.parse(group?.dataset.options||'{}');
      ask(!f.group_id||groupMap[f.group_id]!==f.discipline_id,'¿en qué grupo y horario entrena? El horario se toma del grupo elegido.');
    }else if(record.kind==='charge'){
      ask(!f.student_source_ref||!studentRefs.has(f.student_source_ref),'¿a qué alumno de esta migración corresponde la cuota?');
      ask(!f.period||!f.due_date,'¿cuál es el periodo y la fecha de vencimiento?');
      ask(!Number.isFinite(Number(f.amount))||Number(f.amount)<0||f.amount==='','¿cuál es el importe de la cuota?');
    }else if(record.kind==='payment'){
      ask(!f.charge_source_ref||!charges.has(f.charge_source_ref),'¿a qué cuota de esta migración corresponde el pago?');
      ask(!Number.isFinite(Number(f.amount))||Number(f.amount)<=0,'¿cuál es el importe pagado?');
      const charge=charges.get(f.charge_source_ref);if(charge)ask(Number(f.amount)>Number(charge.fields?.amount||0),'el pago supera el importe de la cuota; ¿qué importe es correcto?');
      ask(!f.method,'¿cuál fue el método de pago?');
    }
  }
  return questions;
}
function migrationFollowups(records=[]){
  return records.filter(row=>row.kind==='student').map(row=>{
    const f=row.fields||{},missing=[];
    if(!f.birth_date)missing.push('fecha de nacimiento');
    if(!f.email&&!f.phone)missing.push('correo o teléfono de contacto');
    if(!f.tariff_id)missing.push('tarifa');
    return missing.length?`${f.name||'Alumno'} ${f.surname||''}: ${missing.join(', ')}`.trim():'';
  }).filter(Boolean);
}
function updateMigrationGuidance(wrap){
  const records=selectedMigrationRecords(wrap),questions=migrationQuestions(records,wrap),box=wrap.querySelector('#kx-migration-questions'),button=wrap.querySelector('#kx-migration-import');
  if(wrap.dataset.kxMigrationCanImport==='false'){
    if(box)box.innerHTML='<strong>El agente ha identificado los datos.</strong><p>La incorporación directa está habilitada actualmente para Club. Federación y Marca pueden continuar con el análisis y solicitar revisión humana.</p>';
    if(button)button.disabled=true;return {records,questions};
  }
  const followups=migrationFollowups(records);
  const optional=followups.length?`<p>Información que podrás completar ahora o verificar después en Alumnos:</p><ul>${followups.slice(0,8).map(item=>`<li>${esc(item)}</li>`).join('')}</ul>${followups.length>8?`<p>Y ${followups.length-8} ficha(s) más.</p>`:''}`:'';
  if(box)box.innerHTML=(questions.length?`<strong>Necesito completar ${questions.length} dato(s) antes de incorporarlos:</strong><ol>${questions.slice(0,12).map(q=>`<li>${esc(q)}</li>`).join('')}</ol>${questions.length>12?`<p>Hay ${questions.length-12} pregunta(s) más. Completa las filas marcadas antes de continuar.</p>`:''}<p>Si falta un grupo u horario, créalo en Mi Club → Grupos y vuelve a esta migración.</p>`:`<strong>${records.length?`He identificado ${records.length} registro(s). ¿Autorizas incorporarlos a tu club?`:'Selecciona los registros que quieras incorporar.'}</strong><p>Revisa las advertencias y los datos de cada ficha antes de confirmar.</p>`)+optional;
  if(button)button.disabled=!records.length||Boolean(questions.length);
  return {records,questions};
}
function assistErrorMessage(error,{support=false}={}){
  const raw=String(error?.message||error||'');
  if(/KOMBAX_MIGRATION_ACCESS_REQUIRED|MIGRATION_ORG_ACCESS_REQUIRED/i.test(raw))return 'KOMBAX Migrations está disponible para Club, Federación, Marca, Competidor y Profesional con permisos de gestión.';
  if(/ORG_ASSIST_ONLY|KOMBAX_MANAGEMENT_ACCESS_REQUIRED|KOMBAX_ORG_HISTORY_ONLY/i.test(raw))return 'KOMBAX Assist de gestión necesita una identidad Club, Federación, Marca, Competidor o Profesional autorizada.';
  if(/ASSIST_CHAT_NOT_ACTIVATED|assist_chat_not_activated/i.test(raw))return support?'El chat guiado de este caso todavía no está activo. Continúa por correo con Soporte KOMBAX; el equipo lo habilitará si es útil para el diagnóstico.':'Este caso pertenece a Soporte KOMBAX y requiere activación del chat guiado por el equipo de soporte.';
  if(/ai_not_configured|OPENAI_API_KEY_MISSING/i.test(raw))return support?'La asistencia guiada no está disponible temporalmente. El caso permanece abierto y puedes continuar por el canal humano de Soporte KOMBAX.':'La asistencia inteligente está instalada, pero la credencial de IA no está habilitada en este entorno. No se ha modificado ningún dato.';
  if(/AI_CREDITS_EXHAUSTED|AI_CREDITS_RESERVATION_REQUIRED/i.test(raw))return 'No hay suficientes Créditos IA disponibles para reservar esta tarea. Puedes esperar la renovación o consultar con soporte.';
  if(/assistant_usage_unavailable|ledger_write_failed|METERING_WRITE_ERROR/i.test(raw))return 'No se pudo confirmar el consumo de esta operación. No se han cobrado créditos; vuelve a intentarlo.';
  if(/TRIAL_DEMO_ONLY|TRIAL_ENDED/i.test(raw))return /TRIAL_ENDED/i.test(raw)?'La prueba de demostración ha terminado. Verifica tu club para continuar.':'Durante la prueba solo se admiten preguntas de demostración sin datos personales.';
  if(/AI_MONTHLY_ECONOMY_GUARD|MONTHLY_ALLOWANCE_EXHAUSTED|assist_limit|allowance/i.test(raw))return support?'Este chat guiado ha alcanzado el límite de asistencia incluido. El caso permanece abierto por correo y Soporte KOMBAX decidirá el siguiente nivel de atención.':'Has utilizado las conversaciones de KOMBAX Assist incluidas en este periodo. El historial permanece disponible y el cupo se renovará en el siguiente periodo.';
  if(/AI_CASE_ECONOMY_GUARD|CASE_TURN_LIMIT/i.test(raw))return support?'Este chat guiado ha alcanzado su límite de mensajes. El caso continúa por correo y Soporte KOMBAX puede escalarlo si la situación lo requiere.':'Esta conversación ha alcanzado el número de mensajes incluido. Inicia una nueva conversación si todavía tienes cupo mensual disponible.';
  return humanError(error);
}
async function refreshChat(wrap,ticketId,{migration=false,support=false,tenantRefValue=''}={}){
  const ref=tenantRefValue||clubOrgTenantRef();
  const [messages,dashboard,preview,supportStatus,migrationJob]=await Promise.all([
    repos.customerOps.messages(ticketId,100).catch(()=>[]),
    !support&&ref?repos.customerOps.dashboard(ref).catch(()=>null):Promise.resolve(null),
    migration?repos.customerOps.migrationPreview(ticketId).catch(()=>null):Promise.resolve(null),
    support?repos.customerOps.supportGuidedStatus(ticketId).catch(()=>null):Promise.resolve(null),
    migration?repos.customerOps.migrationJob(ticketId).catch(()=>null):Promise.resolve(null)
  ]);
  const thread=wrap.querySelector('#kx-assist-thread');if(thread){thread.innerHTML=messageBubbles(messages,{migration,support});thread.scrollTop=thread.scrollHeight;}
  const interactionCount=messages.filter(x=>String(x.role||'').toUpperCase()==='USER').length;
  const creditSnapshot=!support&&ref&&interactionCount>0&&interactionCount%5===0?await repos.customerOps.aiCredits(ref).catch(()=>null):null;
  const creditSlot=wrap.querySelector('#kx-ai-credit-slot');if(creditSlot&&creditSnapshot)creditSlot.innerHTML=creditControl(creditSnapshot);
  const quota=wrap.querySelector('#kx-assist-live-quota');
  if(quota){
    const used=messages.filter(x=>String(x.role||'').toUpperCase()==='USER').length;
    if(support&&supportStatus){
      quota.textContent=`${asNumber(supportStatus.messages_remaining)} mensajes disponibles · ${supportStatus.active?'chat guiado activo':'esperando activación'}`;
    }else{
      quota.textContent=`${used} / 12 mensajes en esta conversación`;
    }
  }
  let migrationData=null,catalog={};
  if(migration){[migrationData,catalog]=await Promise.all([repos.customerOps.migrationRecords(ticketId).catch(()=>null),repos.customerOps.migrationCatalog(tenantRefValue||clubOrgTenantRef()).then(c=>({disciplines:c.disciplines||[],groups:c.groups||[],tariffs:c.tariffs||[]}))]);}
  const migrationBox=wrap.querySelector('#kx-migration-live');if(migrationBox&&preview){captureMigrationDraft(wrap,ticketId);migrationBox.innerHTML=`${migrationFileRows(preview)}${migrationReviewPanel(migrationData,catalog)}`;decorateMigrationRelations(wrap);restoreMigrationDraft(wrap,ticketId);syncMigrationGroupOptions(wrap);updateMigrationGuidance(wrap);}
  const jobBox=wrap.querySelector('#kx-ai-migration-job');if(jobBox&&migrationJob){const used=asNumber(migrationJob.credits_used),pending=asNumber(migrationJob.pending),max=asNumber(migrationJob.next_reservation_max);jobBox.innerHTML=`<strong>${asNumber(migrationJob.files)} fichas o archivos · ${asNumber(migrationJob.ready)} preparados · ${asNumber(migrationJob.needs_review)} necesitan revisión</strong><p>${formatNumber(used,{maximumFractionDigits:2})} Créditos IA utilizados en este trabajo${pending?` · Para el siguiente análisis se reservan hasta ${Math.ceil(max)} créditos; se liberará lo no utilizado.`:''}</p>`;}
  return {messages,dashboard,preview,supportStatus,migrationJob};
}
async function sendChat(wrap,ticketId,{migration=false,support=false,specialty=DEFAULT_ASSIST_SPECIALIST,forcedMessage='',tenantRefValue='',context={}}={}){
  const textarea=wrap.querySelector('#kx-assist-input'),send=wrap.querySelector('#kx-assist-send'),status=wrap.querySelector('#kx-assist-status'),message=String(forcedMessage||textarea?.value||'').trim();if(!message)return;
  if(wrap.dataset.kxChatSending==='1')return null;
  wrap.dataset.kxChatSending='1';
  const thread=wrap.querySelector('#kx-assist-thread');
  if(thread){
    thread.querySelector('.kx-assist-welcome,.kx-support-chat-empty')?.remove();
    thread.insertAdjacentHTML('beforeend',messageBubbles([{role:'USER',content_text:message,created_at:new Date().toISOString()}],{migration,support}));
    thread.insertAdjacentHTML('beforeend',`<div class="kx-assist-bubble assistant kx-assist-pending" role="status" aria-live="polite"><span class="kx-bubble-avatar">${support?supportMark():assistantAvatar()}</span><div><small>${support?'SOPORTE GUIADO':migration?'KOMBAX MIGRATIONS':'KOMBAX ASSIST'}</small><p>${migration?'Analizando la migración…':'Preparando respuesta…'}</p></div></div>`);
    thread.scrollTop=thread.scrollHeight;
  }
  if(textarea&&!forcedMessage)textarea.value='';if(send)send.disabled=true;if(textarea)textarea.disabled=true;
  if(status)status.textContent=support?'Revisando el caso técnico…':migration?'Analizando el siguiente paso de la migración…':'Revisando la gestión autorizada…';
  try{
    const out=await repos.customerOps.chat(ticketId,message,specialty);
    await refreshChat(wrap,ticketId,{migration,support,tenantRefValue});
    if(migration&&Array.isArray(out?.field_updates)){applyMigrationFieldUpdates(wrap,out.field_updates);captureMigrationDraft(wrap,ticketId);}
    if(!support&&!migration&&out?.action?.type==='stripe_connect_onboarding'){
      const subject=stripeConnectSubject(context);
      if(subject)confirmDialog('Configurar cobros y domiciliaciones',t('payments.assistStripeSafety'),async()=>{const onboarding=await repos.payments.connectOnboarding(subject.type,subject.id);if(!onboarding?.url)throw new Error('No se pudo abrir la configuración segura.');location.assign(onboarding.url);},{confirmText:'Abrir Stripe'});
      else toast('Selecciona una organización gestionable para iniciar el alta segura de Stripe.','error');
    }
    if(status)status.textContent=support?`Respuesta de soporte guiado preparada${out?.turns_remaining!=null?` · ${out.turns_remaining} mensaje(s) disponibles`:''}. Si el caso requiere intervención directa, Soporte KOMBAX gestionará internamente la escalada.`:migration?'Análisis actualizado. Completa las preguntas pendientes y autoriza la incorporación cuando todo esté listo.':`Respuesta preparada${out?.turns_remaining!=null?` · ${out.turns_remaining} mensaje(s) disponibles en esta conversación`:''}.`;
    return out;
  }catch(error){
    if(textarea&&!forcedMessage&&!textarea.value.trim())textarea.value=message;
    if(status)status.textContent=assistErrorMessage(error,{support});toast(assistErrorMessage(error,{support}),'error');
    await refreshChat(wrap,ticketId,{migration,support,tenantRefValue}).catch(()=>{});
    return null;
  }finally{delete wrap.dataset.kxChatSending;if(send)send.disabled=false;if(textarea)textarea.disabled=false;textarea?.focus();}
}
function validateMigrationFiles(files=[]){const allowed=new Set(['application/pdf','text/csv','application/csv','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/webp']);return files.find(f=>f.size>10*1024*1024||(!allowed.has(f.type)&&!(/\.(pdf|xlsx?|csv|jpe?g|png|webp)$/i.test(f.name))))||null}
function bindMigrationUpload(wrap,ticketId,tenantRefValue){
  const input=wrap.querySelector('#kx-migration-files'),selection=wrap.querySelector('#kx-migration-selection'),button=wrap.querySelector('#kx-migration-upload');
  input?.addEventListener('change',()=>{const files=[...(input.files||[])],invalid=validateMigrationFiles(files);selection.textContent=invalid?`Archivo no admitido: ${invalid.name}`:files.length?`${files.length} archivo(s) listos para añadir a esta migración.`:'Puedes subir Excel, CSV, PDF, fichas escaneadas o imágenes.';button.disabled=!files.length||Boolean(invalid);});
  button?.addEventListener('click',async()=>{
    button.disabled=true;const files=[...(input.files||[])];
    try{
      selection.textContent=`Subiendo 0 de ${files.length}…`;
      await repos.customerOps.stageMigrationFiles(ticketId,files,({done,total,file})=>{selection.textContent=`${done} de ${total} archivo(s) recibidos${file?` · ${file}`:''}`});
      toast(`${files.length} archivo(s) añadidos a KOMBAX Migrations`);input.value='';
      let state=await refreshChat(wrap,ticketId,{migration:true,tenantRefValue});
      selection.textContent='Archivos guardados. Analizando automáticamente; después podrás revisar y confirmar las filas.';
      for(let batch=0;batch<24;batch++){
        const before=Math.max(0,asNumber(state.preview?.files_total)-asNumber(state.preview?.files_analyzed));if(!before)break;
        const result=await sendChat(wrap,ticketId,{migration:true,tenantRefValue,forcedMessage:'Analiza los archivos pendientes. Extrae los datos sin inventarlos y señala qué debo revisar antes de incorporarlos.'});
        state=await refreshChat(wrap,ticketId,{migration:true,tenantRefValue});
        const after=Math.max(0,asNumber(state.preview?.files_total)-asNumber(state.preview?.files_analyzed));
        if(!result||after>=before)break;
      }
      const pending=Math.max(0,asNumber(state.preview?.files_total)-asNumber(state.preview?.files_analyzed));
      selection.textContent=pending?`${pending} archivo(s) pendientes. Pulsa «Analizar siguiente lote» para reintentar.`:'Análisis terminado. Revisa las filas y confirma la importación cuando estén correctas.';
    }catch(e){button.disabled=false;selection.textContent='La carga no se completó. Los archivos confirmados antes del error permanecen vinculados a esta migración.';toast(humanError(e),'error')}
  });
}

async function downloadMigrationGuide(context={}){
  const ref=orgTenantRef(context);if(!ref)throw new Error('KOMBAX_ORG_GUIDE_ONLY');
  const blob=await repos.customerOps.downloadGuide(ref);if(!blob?.size)throw new Error('No se pudo descargar la guía de migración.');
  const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_MARCA_R64.pdf';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
export async function openMigrationGuide(context={}){
  const ref=orgTenantRef(context);if(!ref){toast('La guía de migración está disponible para los perfiles Club, Federación, Marca, Competidor y Profesional.','error');return;}
  try{
    const access=await repos.customerOps.guideAccess(ref);if(access?.allowed!==true)throw new Error('KOMBAX_ORG_GUIDE_ONLY');
    const {wrap}=openDetail({title:t('migrations.guideCopy.title'),subtitle:t('migrations.guideCopy.subtitle'),width:'980px',body:`<div class="kx-customer-ops kx-migration-guide">
      <section class="kx-guide-brand">
        <div class="kx-guide-brand-logo"><img src="./assets/brand/kombax-symbol-red.png" alt="KOMBAX"><div><span>KOMBAX MIGRATIONS</span><strong>Tus datos entran en KOMBAX. Tu histórico no se pierde.</strong><p>Guía práctica para incorporar alumnos, cuotas y pagos al Club con autorización final. Federaciones y Marcas pueden analizar sus documentos y solicitar revisión humana.</p></div></div>
        <button class="btn btn-primary" id="kx-download-migration-guide">${t('migrations.guideCopy.download')}</button>
      </section>
      <section class="kx-guide-benefits">
        <article><span>IMPORTA POR LOTES</span><strong>Excel, CSV, PDF e imágenes</strong><p>Trabaja con varios archivos en una misma migración y conserva el contexto.</p></article>
        <article><span>REVISA ANTES</span><strong>Vista previa obligatoria</strong><p>Los vacíos, posibles duplicados y conflictos se muestran antes de incorporar datos.</p></article>
        <article><span>ACTIVA SIN DUPLICAR</span><strong>La cuenta se vincula a la ficha</strong><p>Los registros administrativos pueden existir antes de que el alumno o federado tenga cuenta.</p></article>
      </section>
      <section class="kx-guide-section"><div class="section-title"><div><span>FLUJO RECOMENDADO</span><h3>De tus archivos a una estructura operativa</h3></div></div><div class="kx-guide-flow"><div><b>1</b><strong>Explica</strong><small>Origen y significado de los datos.</small></div><div><b>2</b><strong>Sube</strong><small>Excel, CSV, PDF o imágenes.</small></div><div><b>3</b><strong>Analiza</strong><small>KOMBAX pregunta y normaliza.</small></div><div><b>4</b><strong>Revisa</strong><small>Vista previa y dudas.</small></div><div><b>5</b><strong>Confirma</strong><small>Solo cuando todo encaja.</small></div></div></section>
      <section class="kx-guide-section"><div class="section-title"><div><span>EJEMPLOS</span><h3>Cómo se traduce a tu día a día</h3></div></div><div class="kx-guide-examples">
        <article><span>CLUB · EXCEL DE ALUMNOS</span><h3>Alumnos, grupos y acceso</h3><p>Ejemplo: Ana (16+ con email) puede quedar preparada para invitación; Marc (menor de 16) conserva su ficha y se vincula mediante tutor; Luis (histórico sin email) sigue siendo gestionable y queda pendiente de activación.</p><small>No se crea una segunda ficha al activar la cuenta.</small></article>
        <article><span>FINANZAS</span><h3>Cuotas, matrículas y pagos</h3><p>Separa tarifa, cuota concreta, periodo, estado, pago y recibo. Una reimportación no debe volver a crear movimientos históricos que ya existen.</p><small>KOMBAX registra y valida; no procesa dinero.</small></article>
        <article><span>FEDERACIÓN · PDF / LISTADOS</span><h3>Federados y licencias</h3><p>Extrae titular, número de licencia, disciplina, fechas y entidad. Los campos dudosos se dejan para revisión antes de crear relaciones.</p><small>La relación federativa no concede acceso automático a las zonas privadas del Club.</small></article>
        <article><span>DOCUMENTACIÓN</span><h3>Archivo + metadatos</h3><p>Cuando corresponde, el archivo se mantiene asociado a su titular, tipo, referencia, entidad, fecha y vencimiento para que siga siendo localizable.</p><small>Las imágenes y PDFs se analizan de forma controlada.</small></article>
      </div></section>
      <section class="kx-guide-section"><div class="section-title"><div><span>CUENTAS</span><h3>Reglas que evitan duplicados</h3></div></div><div class="kx-guide-rule-grid">
        <div><strong>Alta nueva 16+</strong><p>Email desde preinscripción -> ficha -> invitación -> verificación -> misma ficha activa.</p></div>
        <div><strong>Histórico sin email</strong><p>Puede migrarse y administrarse. Queda Falta email / Sin activar hasta completar el dato.</p></div>
        <div><strong>Menor de 16</strong><p>El menor conserva su ficha; el padre, madre o tutor obtiene una relación autorizada de acceso.</p></div>
        <div><strong>Multiclub</strong><p>Una cuenta global puede tener varias membresías sin mezclar cuotas, asistencia, documentos ni permisos.</p></div>
      </div></section>
      <section class="kx-guide-section"><div class="section-title"><div><span>ASISTENCIA</span><h3>Tres líneas distintas dentro de KOMBAX</h3></div></div><div class="kx-guide-split"><article><strong>KOMBAX Migrations</strong><p>Canal de Club, Federación, Marca, Competidor y Profesional para analizar archivos. La incorporación directa está disponible en Club para alumnos, cuotas y pagos tras autorización final; los demás perfiles usan revisión humana.</p></article><article><strong>KOMBAX Assist</strong><p>Copiloto de gestión para Club, Federación, Marca, Competidor y Profesional. Analiza el contexto autorizado en modo de solo lectura y ayuda a decidir el siguiente paso.</p></article><article><strong>Soporte KOMBAX</strong><p>Canal técnico y formal de la plataforma. Mantiene el sistema de casos: primero correo, después chat guiado si ayuda al diagnóstico y, cuando KOMBAX lo considera necesario, escalada a asistencia humana directa.</p></article></div></section>
      <section class="kx-guide-section"><div class="section-title"><div><span>PRIVACIDAD Y CONTROL</span><h3>Puedes borrar conversaciones e historial</h3></div></div><div class="kx-assist-note"><strong>Eliminar conversación:</strong> borra mensajes, análisis, metadatos y archivos de Storage asociados al caso. <strong>Borrar historial:</strong> limpia todos los casos visibles del módulo y contexto actual. La contabilidad mínima de uso permanece: borrar contenido no restaura cupos.</div></section>
      <section class="kx-guide-section"><div class="section-title"><div><span>DUDAS FRECUENTES</span><h3>Antes de empezar</h3></div></div><div class="kx-guide-faq">
        <details><summary>¿Tengo que limpiar el Excel antes de subirlo?</summary><p>No necesariamente. Explica de dónde procede y qué significa cada hoja; KOMBAX Migrations puede ayudarte a detectar formatos distintos, vacíos y relaciones.</p></details>
        <details><summary>¿Qué pasa si faltan emails?</summary><p>Los históricos pueden migrarse sin email y quedar pendientes. Las altas nuevas 16+ deben recoger email desde la preinscripción. Los menores de 16 acceden mediante tutor.</p></details>
        <details><summary>¿Puedo subir Excel y PDF en la misma migración?</summary><p>Sí. Puedes añadir varias cargas al mismo caso y reutilizar lo ya analizado dentro de sus límites.</p></details>
        <details><summary>¿El asistente importa automáticamente?</summary><p>No. El flujo es analizar -> preguntar -> normalizar -> vista previa -> confirmar.</p></details>
        <details><summary>¿La Federación ve las finanzas privadas de los clubes?</summary><p>No por el hecho de estar federados. El ámbito federativo y las zonas privadas del Club permanecen separados.</p></details>
        <details><summary>¿Cómo pido ayuda?</summary><p>Para transferencias, abre KOMBAX Migrations. Para ayuda de gestión, abre KOMBAX Assist. Para soporte técnico, cuenta, privacidad, seguridad o asuntos legales, utiliza Soporte KOMBAX. La primera vía es el correo; KOMBAX puede activar un chat guiado y, si el caso lo requiere, Combots puede asignar asistencia humana directa.</p></details>
      </div></section>
      <div class="kx-guide-cta"><div><span>MENOS FRICCIÓN · MÁS CONTROL</span><strong>Tu organización revisa antes de confirmar.</strong><p>La guía PDF incluye ejemplos completos, checklist y plantillas mínimas recomendadas para Club, Federación, Marca, Competidor y Profesional.</p></div><button class="btn btn-primary" id="kx-download-migration-guide-bottom">Descargar PDF</button></div>
    </div>`});
    const bindDownload=button=>button?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;try{await downloadMigrationGuide(context);toast('Guía de migración preparada');}catch(error){toast(humanError(error),'error')}finally{b.disabled=false}});
    bindDownload(wrap.querySelector('#kx-download-migration-guide'));bindDownload(wrap.querySelector('#kx-download-migration-guide-bottom'));
  }catch(error){toast('La guía de migración está disponible para los perfiles Club, Federación, Marca, Competidor y Profesional.','error');}
}

async function deleteHistory({ticketId=null,mode=null,context={},afterDelete=null}={}){
  const ref=orgTenantRef(context);if(!ref)throw new Error('KOMBAX_ORG_HISTORY_ONLY');
  const result=await repos.customerOps.deleteHistory({ticket_id:ticketId,mode,tenant_ref:ref});
  toast(ticketId?'Conversación eliminada':'Historial eliminado');
  await afterDelete?.(result);return result;
}
function requestDeleteTicket(ticketId,mode,context={},afterDelete=null){
  confirmDialog('Eliminar conversación','Se eliminarán los mensajes, análisis y archivos asociados a esta conversación. Esta acción no restaura migraciones ni conversaciones consumidas en tu plan.',()=>deleteHistory({ticketId,mode,context,afterDelete}),{confirmText:'Eliminar conversación',danger:true});
}
function requestClearHistory(mode,context={},afterDelete=null){
  const label=mode==='migration'?'migraciones':'conversaciones de gestión';
  confirmDialog('Borrar historial',`Se eliminarán todos tus ${label} del contexto actual, incluidos mensajes, análisis y archivos vinculados. Los contadores de uso y la auditoría mínima se conservarán y no se recuperará ningún cupo.`,()=>deleteHistory({mode,context,afterDelete}),{confirmText:'Borrar historial',danger:true});
}

export async function openKombaxAssist(ticketId=null,context={},specialty=DEFAULT_ASSIST_SPECIALIST){
  const ref=orgTenantRef(context);if(!ref){toast('KOMBAX Assist de gestión está disponible para Club, Federación, Marca, Competidor y Profesional con permisos autorizados.','error');return;}
  const credits=await repos.customerOps.aiCredits(ref).catch(()=>null);
  let tickets=[];try{tickets=await repos.customerOps.tickets(ref,100)}catch{}
  let specialist=assistSpecialist(specialty);
  if(!ticketId){const subject=`KOMBAX Assist · ${specialist.label}`;const out=await createTicket('MANAGEMENT',subject,'assist',context);ticketId=out.ticket_id;tickets=[...tickets,{ticket_id:ticketId,category:'MANAGEMENT',subject_redacted:subject}];}
  const current=tickets.find(t=>String(t.ticket_id)===String(ticketId));
  if(!current){toast('No se pudo validar la conversación dentro de esta organización.','error');return;}
  if(isMigrationTicket(current)){await openKombaxMigrations(ticketId,context);return;}
  if(isSupportTicket(current)){await openKombaxSupportChat(ticketId,context);return;}
  if(!isManagementTicket(current)){toast('No se pudo reconocer el tipo de conversación.','error');return;}
  specialist=specialistFromSubject(current.subject_redacted||`· ${specialist.label}`);
  const showMigrations=canMigrationContext(context);
  setMainHtml(`<div class="kx-ai-chat-layer kx-assist-management-chat">${pageHeader('KOMBAX Assist','Asistencia inteligente de gestión · modo de solo lectura durante el piloto.',subviewActions({backId:'kx-assist-back',closeId:'kx-assist-close',backLabel:'Volver'}),'Conversaciones')}${conversationChannelTabs('assist',{showMigrations})}<section class="kx-ai-chat-head"><div class="kx-ai-chat-identity">${assistantAvatar()}<div><span>KOMBAX ASSIST</span><h2>Copiloto de gestión</h2><p>Club · Federación · Marca · Competidor · Profesional</p></div></div><div id="kx-ai-credit-slot" class="kx-ai-credit-slot">${creditControl(credits)}</div><div class="kx-assist-context"><span>CONVERSACIÓN ${esc(ticketId)}</span><b id="kx-assist-live-quota">0 / 12 mensajes en esta conversación</b></div></section><div class="kx-assist-chat" data-ticket="${esc(ticketId)}"><div id="kx-assist-thread" class="kx-assist-thread kx-assist-thread-page"><div class="loading-card">Cargando conversación…</div></div><div class="kx-assist-quick-prompts" aria-label="Consultas rápidas"><button type="button" data-kx-assist-prompt="Resume lo más importante de la gestión que debería revisar ahora.">Resumen de gestión</button><button type="button" data-kx-assist-prompt="¿Qué pendientes detectas y qué debería revisar primero?">Detectar pendientes</button><button type="button" data-kx-assist-prompt="Explícame las cifras disponibles de forma sencilla y accionable.">Entender cifras</button></div><div id="kx-assist-status" class="kx-assist-status">KOMBAX Assist puede analizar el contexto autorizado. No modifica datos durante el piloto.</div><div class="kx-assist-composer kx-assist-composer-sticky"><textarea id="kx-assist-input" rows="2" maxlength="4000" placeholder="Pregunta sobre la gestión de tu organización…"></textarea><button class="btn btn-primary" id="kx-assist-send">${t('assist.thread.send')}</button></div><div class="kx-ai-support-separation"><div><strong>¿Es un tema técnico, de cuenta, privacidad, seguridad o legal?</strong><p>Eso no lo resuelve el agente de gestión. Utiliza Ayuda y soporte para atención técnica y trazabilidad. KOMBAX decide si activa chat guiado o asistencia humana directa.</p></div><button class="btn btn-ghost btn-sm" id="kx-open-support-from-assist">Ayuda y soporte</button><button class="btn btn-ghost btn-sm" id="kx-delete-current-ticket">${t('migrations.thread.delete')}</button></div></div></div>`);
  const root=document.querySelector('main')||document;
  const specialistHeading=root.querySelector('.kx-assist-management-chat .kx-ai-chat-identity');
  if(specialistHeading){
    const label=specialistHeading.querySelector('span'),title=specialistHeading.querySelector('h2'),description=specialistHeading.querySelector('p');
    if(label)label.textContent=`KOMBAX ASSIST · ${specialist.label.toUpperCase()}`;
    if(title)title.textContent=specialist.title;
    if(description)description.textContent=specialist.description;
  }
  const specialtyBadge=root.querySelector('.kx-assist-management-chat .kx-assist-context');
  if(specialtyBadge){const badge=document.createElement('small');badge.textContent=`Especialidad activa: ${specialist.label}`;specialtyBadge.append(badge);}
  const recommended=root.querySelector('.kx-assist-management-chat [data-kx-assist-prompt]');
  if(credits?.trial){const quick=root.querySelector('.kx-assist-quick-prompts');if(quick)quick.innerHTML=['Resume las funciones principales de KOMBAX para un club de demostración.','¿Cómo puedo organizar grupos y horarios en KOMBAX?','Explícame cómo funcionan las cuotas de demostración.'].map(x=>`<button type="button" data-kx-assist-prompt="${esc(x)}">${esc(x)}</button>`).join('');const input=root.querySelector('#kx-assist-input'),send=root.querySelector('#kx-assist-send');if(input){input.readOnly=true;input.placeholder='Durante la prueba usa las consultas de demostración de arriba.';}if(send)send.disabled=true;}
  else if(recommended){recommended.dataset.kxAssistPrompt=specialist.prompt;recommended.textContent=`Consulta recomendada · ${specialist.label}`;}
  bindConversationChannelTabs(root,{context,onSocial:context.onSocial,onShowcase:context.onShowcase,onAssist:()=>{},onMigrations:showMigrations?(context.onMigrations||(()=>openKombaxMigrations(null,context))):null});
  await refreshChat(root,ticketId,{migration:false,support:false,tenantRefValue:ref});
  root.querySelector('#kx-assist-send')?.addEventListener('click',()=>sendChat(root,ticketId,{migration:false,support:false,specialty:specialist.id,tenantRefValue:ref,context}));
  root.querySelector('#kx-assist-input')?.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendChat(root,ticketId,{migration:false,support:false,specialty:specialist.id,tenantRefValue:ref,context});}});
  root.querySelectorAll('[data-kx-assist-prompt]').forEach(b=>b.addEventListener('click',()=>sendChat(root,ticketId,{migration:false,support:false,specialty:specialist.id,tenantRefValue:ref,context,forcedMessage:b.dataset.kxAssistPrompt||''})));
  bindSubviewActions(root,{backId:'kx-assist-back',closeId:'kx-assist-close',onBack:()=>context.onBack?context.onBack():renderKombaxAssistHome(context),onClose:context.onBack||(()=>{location.hash='#dashboard';})});
  root.querySelector('#kx-open-support-from-assist')?.addEventListener('click',()=>{location.hash='#support';renderKombaxSupportHome(context);});
  root.querySelector('#kx-delete-current-ticket')?.addEventListener('click',()=>requestDeleteTicket(ticketId,'management',context,()=>renderKombaxAssistHome(context)));
}

export async function openKombaxMigrations(ticketId=null,context={}){
  const ref=orgTenantRef(context);if(!ref||!canMigrationContext(context)){toast('KOMBAX Migrations está disponible para Club, Federación, Marca, Competidor y Profesional.','error');return;}
  const credits=await repos.customerOps.aiCredits(ref).catch(()=>null);
  try{const access=await repos.customerOps.guideAccess(ref);if(access?.allowed!==true){toast('KOMBAX Migrations requiere una organización autorizada.','error');return;}}catch{toast('No se pudo validar el acceso a Migrations.','error');return;}
  if(!ticketId){const out=await createTicket('MIGRATION','Migración de datos','migration',context);ticketId=out.ticket_id;}
  else{const tickets=await repos.customerOps.tickets(ref,100);if(!tickets.some(t=>String(t.ticket_id)===String(ticketId)&&isMigrationTicket(t))){toast('No se pudo validar esta migración dentro de la organización actual.','error');return;}}
  setMainHtml(`<div class="kx-ai-chat-layer kx-migrations-chat-page">${pageHeader('KOMBAX Migrations','Migración asistida · documentos, análisis, revisión y confirmación.',subviewActions({backId:'kx-migration-back',closeId:'kx-migration-close',backLabel:'Volver'}),'Conversaciones')}${conversationChannelTabs('migrations',{showMigrations:true})}<section class="kx-ai-chat-head migrations"><div class="kx-ai-chat-identity">${assistantAvatar()}<div><span>KOMBAX MIGRATIONS</span><h2>Asistente de migración</h2><p>Tus datos entran en KOMBAX. Tu histórico no se pierde.</p></div></div><div id="kx-ai-credit-slot" class="kx-ai-credit-slot">${creditControl(credits)}</div><div class="kx-assist-context"><span>MIGRACIÓN ${esc(ticketId)}</span><b id="kx-assist-live-quota">0 / 12 mensajes en esta conversación</b></div></section><div class="kx-assist-chat kx-migrations-chat" data-ticket="${esc(ticketId)}"><section class="kx-migration-direct-upload"><div><strong>Añadir documentos</strong><p>Excel, CSV, PDF, fichas escaneadas o imágenes. Puedes añadirlos ahora o durante la conversación.</p></div><label class="kx-upload-zone"><strong>Seleccionar archivos</strong><small>PDF, XLSX, XLS, CSV, JPG, JPEG, PNG o WEBP · máximo 10 MB por archivo</small><input id="kx-migration-files" type="file" multiple accept="${migrationAccept}"></label><div id="kx-migration-selection" class="muted">Puedes empezar escribiendo o subir documentos directamente.</div><div class="row-actions"><button class="btn btn-primary" id="kx-migration-upload" disabled>Subir a esta migración</button></div></section><section id="kx-ai-migration-job" class="kx-ai-migration-job" aria-live="polite"></section><div id="kx-migration-live"><div class="loading-card">Cargando estado de la migración…</div></div><div id="kx-assist-thread" class="kx-assist-thread kx-assist-thread-page"><div class="loading-card">Cargando conversación…</div></div><div id="kx-assist-status" class="kx-assist-status">Sube tus archivos y revisa los datos directamente. Una sola confirmación antes de incorporarlos.</div><div class="kx-assist-composer kx-assist-composer-sticky"><textarea id="kx-assist-input" rows="2" maxlength="4000" placeholder="Ej.: Tengo un Excel de alumnos y varias fichas PDF. ¿Cómo empezamos?"></textarea><button class="btn btn-primary" id="kx-assist-send">${t('assist.thread.send')}</button></div><div class="row-actions kx-migration-chat-actions"><button class="btn btn-ghost" id="kx-assist-analyze">${t('migrations.thread.analyzeNext')}</button><button class="btn btn-ghost" id="kx-assist-human">${t('migrations.thread.humanReview')}</button><button class="btn btn-ghost" id="kx-open-guide">${t('migrations.home.guide')}</button><button class="btn btn-ghost" id="kx-delete-current-ticket">${t('migrations.thread.delete')}</button></div><div class="kx-migration-steps"><span>${t('migrations.steps.received')}</span><span>${t('migrations.steps.analysis')}</span><span>${t('migrations.steps.review')}</span><span>${t('migrations.steps.preview')}</span><span>${t('migrations.steps.confirmation')}</span></div></div></div>`);
  const root=document.querySelector('main')||document;
  if(credits?.trial){const upload=root.querySelector('.kx-migration-direct-upload');if(upload)upload.innerHTML='<div><strong>Prueba con datos de demostración</strong><p>La carga de fichas y documentos reales se habilita al verificar el club. No incluyas datos personales de alumnos ni menores en esta prueba.</p></div>';const input=root.querySelector('#kx-assist-input'),send=root.querySelector('#kx-assist-send');if(input){input.readOnly=true;input.placeholder='Utiliza la consulta de demostración.';}if(send)send.disabled=true;root.querySelector('#kx-assist-analyze')?.remove();root.querySelector('#kx-migration-live')?.insertAdjacentHTML('beforebegin','<button type="button" class="btn btn-ghost" id="kx-trial-migration-prompt">¿Cómo reviso una migración de ejemplo antes de confirmar?</button>');}
  bindConversationChannelTabs(root,{context,onSocial:context.onSocial,onShowcase:context.onShowcase,onAssist:context.onAssist||(()=>renderKombaxAssistHome(context)),onMigrations:()=>{}});
  const migrationWrap=root.querySelector('.kx-assist-chat');
  root.dataset.kxMigrationCanImport=ref.startsWith('club:')?'true':'false';
  migrationWrap.dataset.kxMigrationCanImport=ref.startsWith('club:')?'true':'false';
  bindMigrationUpload(root,ticketId,ref);await refreshChat(root,ticketId,{migration:true,tenantRefValue:ref});
  migrationWrap?.addEventListener('click',e=>{
    const destination=e.target.closest('[data-kx-import-check]');
    if(destination){location.hash=destination.dataset.kxImportCheck==='students'?'#members':'#finance';return;}
    const button=e.target.closest('#kx-migration-import');if(!button)return;
    const {records,questions}=updateMigrationGuidance(migrationWrap);
    if(!records.length){toast('Selecciona al menos un registro.','error');return;}
    if(questions.length){toast('Completa primero los datos que pregunta KOMBAX Migrations.','error');migrationWrap.querySelector('#kx-migration-questions')?.scrollIntoView({behavior:'smooth',block:'center'});return;}
    const counts=records.reduce((sum,row)=>(sum[row.kind]=(sum[row.kind]||0)+1,sum),{});
    const detail=`¿Autorizas a KOMBAX Migrations a incorporar ${counts.student||0} alumnos como prealta, ${counts.charge||0} cuotas pendientes y ${counts.payment||0} pagos pendientes de validación en este club? Los duplicados se omitirán. Revisa después las fichas y los cobros.`;
    confirmDialog('Autorizar incorporación de datos',detail,async()=>{
      button.disabled=true;
      try{
        const result=await repos.customerOps.migrationImport(ticketId,crypto.randomUUID(),records);
        if(result?.ok!==true)throw new Error('No se confirmó la importación.');
        await refreshChat(root,ticketId,{migration:true,tenantRefValue:ref});
        const summary=`Incorporación terminada: ${result.students||0} alumnos, ${result.charges||0} cuotas y ${result.payments_pending_review||0} pagos pendientes de validación. ${result.skipped_duplicates||0} duplicado(s) omitido(s). Ve a Alumnos y Finanzas para comprobarlos.`;
        const resultBox=migrationWrap.querySelector('#kx-migration-result');
        if(resultBox)resultBox.innerHTML=`<div class="kx-migration-import-result" role="status"><strong>${esc(summary)}</strong><div class="row-actions"><button type="button" class="btn btn-ghost btn-sm" data-kx-import-check="students">Ver alumnos</button><button type="button" class="btn btn-ghost btn-sm" data-kx-import-check="finance">Ver cuotas y pagos</button></div></div>`;
        const thread=migrationWrap.querySelector('#kx-assist-thread');
        if(thread){thread.insertAdjacentHTML('beforeend',messageBubbles([{role:'ASSISTANT',content_text:summary,created_at:new Date().toISOString()}],{migration:true}));thread.scrollTop=thread.scrollHeight;}
        const refreshedButton=migrationWrap.querySelector('#kx-migration-import');if(refreshedButton)refreshedButton.disabled=true;
        migrationDrafts.delete(ticketId);try{sessionStorage.removeItem(`kx:migration-draft:${ticketId}`);}catch{}
        toast('Datos incorporados. Revisa las fichas y los cobros.');
      }catch(error){toast(humanError(error),'error');updateMigrationGuidance(migrationWrap);}
    },{confirmText:'Sí, incorporar'});
  });
  migrationWrap?.addEventListener('change',e=>{
    const discipline=e.target.closest('[data-field="discipline_id"]');
    if(discipline){const card=discipline.closest('[data-migration-row]'),group=card?.querySelector('[data-field="group_id"]');if(group){group.value='';const map=JSON.parse(group.dataset.options||'{}');[...group.options].forEach((option,index)=>{option.hidden=index>0&&map[option.value]!==discipline.value;});}}
    updateMigrationGuidance(migrationWrap);captureMigrationDraft(migrationWrap,ticketId);
  });
  migrationWrap?.addEventListener('input',e=>{if(e.target.closest('[data-field]')){updateMigrationGuidance(migrationWrap);captureMigrationDraft(migrationWrap,ticketId);}});
  root.querySelector('#kx-assist-send')?.addEventListener('click',()=>sendChat(root,ticketId,{migration:true,tenantRefValue:ref}));
  root.querySelector('#kx-assist-input')?.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendChat(root,ticketId,{migration:true,tenantRefValue:ref});}});
  root.querySelector('#kx-assist-analyze')?.addEventListener('click',()=>sendChat(root,ticketId,{migration:true,tenantRefValue:ref,forcedMessage:'Analiza el siguiente lote de archivos pendientes. Identifica registros, campos, posibles duplicados, incompletos y cualquier dato que necesite mi revisión antes de migrar.'}));
  root.querySelector('#kx-trial-migration-prompt')?.addEventListener('click',()=>sendChat(root,ticketId,{migration:true,tenantRefValue:ref,forcedMessage:'¿Cómo reviso una migración de ejemplo antes de confirmar?'}));
  root.querySelector('#kx-assist-human')?.addEventListener('click',async()=>{try{await repos.customerOps.requestHuman(ticketId);toast('Migración enviada a revisión humana');}catch(e){toast(humanError(e),'error')}});
  root.querySelector('#kx-open-guide')?.addEventListener('click',()=>openMigrationGuide(context));
  bindSubviewActions(root,{backId:'kx-migration-back',closeId:'kx-migration-close',onBack:()=>context.onBack?context.onBack():renderKombaxMigrationsHome(context),onClose:context.onBack||(()=>{location.hash='#dashboard';})});
  root.querySelector('#kx-delete-current-ticket')?.addEventListener('click',()=>requestDeleteTicket(ticketId,'migration',context,()=>renderKombaxMigrationsHome(context)));
}
export function openMigrationPreparation(context={}){openKombaxMigrations(null,context).catch(e=>toast(assistErrorMessage(e),'error'))}

async function organizationData(context={}){
  const ref=orgTenantRef(context);if(!ref)return {ref:'',allowed:false,migrationAllowed:false,rows:[],dashboard:null};
  try{const [rows,dashboard]=await Promise.all([repos.customerOps.tickets(ref,50),repos.customerOps.dashboard(ref)]);const access=canMigrationContext(context)?await repos.customerOps.guideAccess(ref).catch(()=>({allowed:false})):{allowed:false};return {ref,allowed:true,migrationAllowed:access?.allowed===true,rows,dashboard};}
  catch{return {ref,allowed:false,migrationAllowed:false,rows:[],dashboard:null};}
}
export async function openCustomerOperationsCenter(context={}){
  const {wrap}=openDetail({title:'Soporte KOMBAX',subtitle:'Atención técnica y formal · correo, chat guiado y escalada gestionada por KOMBAX',width:'820px',body:`<div class="kx-customer-ops kx-formal-support"><section class="kx-support-separation-hero"><span>SOPORTE KOMBAX</span><h3>Atención técnica y formal de la plataforma</h3><p>KOMBAX Assist es el copiloto de gestión. Soporte KOMBAX tramita incidencias técnicas, cuenta, facturación KOMBAX, seguridad y privacidad. La atención empieza por correo; si conviene, KOMBAX habilita chat guiado y Combots puede asignar asistencia humana directa en casos urgentes o complejos.</p></section><div class="kx-support-email-grid"><a href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Soporte KOMBAX')}"><strong>Soporte general</strong><span>${SUPPORT_EMAIL}</span><small>Uso, incidencias técnicas, cuenta y seguimiento administrativo.</small></a><a href="mailto:${PRIVACY_EMAIL}"><strong>Privacidad</strong><span>${PRIVACY_EMAIL}</span><small>Derechos de datos y cuestiones de privacidad.</small></a><a href="mailto:${SECURITY_EMAIL}"><strong>Seguridad</strong><span>${SECURITY_EMAIL}</span><small>Incidentes o comunicaciones de seguridad.</small></a><a href="mailto:${CHILD_SAFETY_EMAIL}"><strong>Protección de menores</strong><span>${CHILD_SAFETY_EMAIL}</span><small>Canal específico de seguridad infantil.</small></a></div><div class="row-actions"><button class="btn btn-primary" id="kx-support-open-center">Abrir centro de soporte</button><button class="btn btn-ghost" id="kx-support-open-assist">Ir a KOMBAX Assist</button></div></div>`});
  wrap.querySelector('#kx-support-open-center')?.addEventListener('click',()=>{closeModal();renderKombaxSupportHome(context);});
  wrap.querySelector('#kx-support-open-assist')?.addEventListener('click',()=>{closeModal();renderKombaxAssistHome(context);});
}

export async function renderKombaxSupportHome(context={}){
  setMainHtml('<div class="loading-card">Cargando Ayuda y soporte…</div>');
  try{
    const all=await repos.customerOps.supportTickets(80).catch(()=>[]);
    const rows=(all||[]).filter(isSupportTicket);
    const ref=orgTenantRef(context),showAssist=Boolean(ref);
    setMainHtml(`<div class="kx-support-page">${pageHeader('Ayuda y soporte','Atención técnica y formal de KOMBAX, separada de la mensajería y de KOMBAX Assist.',subviewActions({backId:'kx-support-home-back',closeId:'kx-support-home-close',backLabel:'Volver'}),'Soporte KOMBAX')}<section class="kx-support-main-hero"><div class="kx-support-main-copy"><span>ATENCIÓN TÉCNICA Y FORMAL</span><h2>Primero por correo. Escalamos solo cuando aporta valor.</h2><p>Soporte KOMBAX atiende incidencias de la plataforma, acceso, cuenta, facturación KOMBAX, privacidad y seguridad. La primera respuesta se realiza por correo electrónico para mantener trazabilidad.</p><div class="row-actions"><a class="btn btn-primary" href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Soporte KOMBAX')}">Contactar por correo</a></div></div><div class="kx-support-trust"><div class="kx-support-mark large">✓</div><strong>Escalado gestionado por KOMBAX</strong><p><b>1.</b> Respondemos por correo. <b>2.</b> Si la duda es técnica y ayuda al diagnóstico, Soporte KOMBAX puede habilitar un chat guiado. <b>3.</b> Si el caso es urgente o requiere intervención directa, Combots puede asignar asistencia humana.</p></div></section><section class="kx-support-email-grid kx-support-page-channels"><a href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Soporte KOMBAX')}"><strong>Soporte general</strong><span>${SUPPORT_EMAIL}</span><small>Incidencias técnicas, acceso, cuenta y uso de la plataforma.</small></a><a href="mailto:${PRIVACY_EMAIL}"><strong>Privacidad</strong><span>${PRIVACY_EMAIL}</span><small>Derechos, privacidad y tratamiento de datos.</small></a><a href="mailto:${SECURITY_EMAIL}"><strong>Seguridad</strong><span>${SECURITY_EMAIL}</span><small>Incidentes, vulnerabilidades o accesos sospechosos.</small></a><a href="mailto:${CHILD_SAFETY_EMAIL}"><strong>Protección de menores</strong><span>${CHILD_SAFETY_EMAIL}</span><small>Canal especializado de seguridad infantil.</small></a></section><section class="card kx-support-cases"><div class="section-title"><div><span>MIS CASOS</span><h3>Seguimiento y chat guiado</h3></div></div><div class="kx-support-guided-explainer"><strong>Chat guiado técnico</strong><p>No lo activa el cliente. Cuando Soporte KOMBAX considera que una conversación técnica puede acelerar el diagnóstico, el acceso aparece en el caso. Si se detecta urgencia, Combots puede derivarlo internamente a asistencia humana directa.</p></div><div class="kx-ticket-list">${ticketRows(rows,{mode:'support'})}</div></section><section class="kx-ai-support-separation"><div><strong>¿Buscas ayuda para gestionar tu Club, Federación, Marca, Competidor o Profesional?</strong><p>Eso corresponde a KOMBAX Assist, la línea de gestión con IA y límites propios de uso.</p></div>${showAssist?'<button class="btn btn-ghost" id="kx-support-to-assist">Abrir KOMBAX Assist</button>':''}</section></div>`);
    const root=document.querySelector('main')||document;
    root.querySelectorAll('[data-kx-support-chat]').forEach(b=>b.addEventListener('click',()=>openKombaxSupportChat(b.dataset.kxSupportChat,context).catch(e=>toast(assistErrorMessage(e,{support:true}),'error'))));
    root.querySelector('#kx-support-to-assist')?.addEventListener('click',()=>renderKombaxAssistHome(context));
    bindSubviewActions(root,{backId:'kx-support-home-back',closeId:'kx-support-home-close',onBack:()=>{location.hash='#help';},onClose:context.onBack||(()=>{location.hash='#dashboard';})});
  }catch(error){
    setMainHtml(`${pageHeader('Ayuda y soporte')}<div class="empty-card"><strong>No se pudo cargar el centro de soporte</strong><p>${esc(humanError(error))}</p><a class="btn btn-primary" href="mailto:${SUPPORT_EMAIL}">Contactar por correo</a></div>`);
  }
}

export async function openKombaxSupportChat(ticketId,context={}){
  if(!ticketId)return renderKombaxSupportHome(context);
  const all=await repos.customerOps.supportTickets(100).catch(()=>[]);
  const ticket=(all||[]).find(t=>String(t.ticket_id)===String(ticketId)&&isSupportTicket(t));
  if(!ticket){toast('No se pudo validar este caso de Soporte KOMBAX.','error');return;}
  let guided=null;try{guided=await repos.customerOps.supportGuidedStatus(ticketId)}catch{}
  const actions=subviewActions({backId:'kx-support-back',closeId:'kx-support-close',backLabel:'Volver'});
  if(!guided?.active){
    setMainHtml(`<div class="kx-ai-chat-layer kx-support-guided-layer">${pageHeader('Soporte KOMBAX','Caso técnico/formal · el chat guiado solo se activa desde Soporte KOMBAX.',actions,'Ayuda y soporte')}<section class="kx-support-chat-locked"><div class="kx-support-mark large">✓</div><div><span>CASO ${esc(ticketId)}</span><h2>Seguimiento por correo</h2><p>Tu caso sigue abierto y la vía principal es el correo electrónico. Si el equipo detecta que una conversación técnica ayudará al diagnóstico, habilitará aquí el chat guiado. Si existe urgencia o hace falta intervención directa, Combots puede asignar asistencia humana sin que tengas que solicitarla.</p><div class="row-actions"><a class="btn btn-primary" href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`Soporte KOMBAX · ${ticketId}`)}">Continuar por correo</a></div></div></section></div>`);
    const root=document.querySelector('main')||document;
    bindSubviewActions(root,{backId:'kx-support-back',closeId:'kx-support-close',onBack:()=>renderKombaxSupportHome(context),onClose:()=>{location.hash='#help';}});
    return;
  }

  setMainHtml(`<div class="kx-ai-chat-layer kx-support-guided-layer">${pageHeader('Soporte KOMBAX','Chat técnico guiado · activado por el equipo de soporte para este caso.',actions,'Ayuda y soporte')}<section class="kx-ai-chat-head support"><div class="kx-ai-chat-identity"><div class="kx-support-mark large">✓</div><div><span>SOPORTE KOMBAX</span><h2>Chat técnico guiado</h2><p>Asistencia técnica vinculada al caso y a su trazabilidad por correo</p></div></div><div class="kx-assist-context"><span>CASO ${esc(ticketId)}</span><b id="kx-assist-live-quota">${asNumber(guided.messages_remaining)} mensajes disponibles</b><small>${guided.expires_at?`Activo hasta ${dtFmt(guided.expires_at)}`:'Activo'}</small></div></section><div class="kx-assist-chat kx-support-guided-chat" data-ticket="${esc(ticketId)}"><div id="kx-assist-thread" class="kx-assist-thread kx-assist-thread-page support"><div class="loading-card">Cargando caso…</div></div><div id="kx-assist-status" class="kx-assist-status">Describe el problema técnico con el mayor detalle posible. Soporte KOMBAX decidirá internamente si el caso necesita una escalada adicional.</div><div class="kx-assist-composer kx-assist-composer-sticky"><textarea id="kx-assist-input" rows="2" maxlength="4000" placeholder="Describe la incidencia o responde a la pregunta de soporte…"></textarea><button class="btn btn-primary" id="kx-assist-send">${t('assist.thread.send')}</button></div><div class="kx-support-chat-actions"><a class="btn btn-ghost" href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`Soporte KOMBAX · ${ticketId}`)}">Continuar por correo</a><span class="muted">Si hay urgencia o hace falta intervención directa, Combots puede asignar asistencia humana.</span></div></div></div>`);
  const root=document.querySelector('main')||document;
  await refreshChat(root,ticketId,{support:true});
  root.querySelector('#kx-assist-send')?.addEventListener('click',()=>sendChat(root,ticketId,{support:true}));
  root.querySelector('#kx-assist-input')?.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendChat(root,ticketId,{support:true});}});
  bindSubviewActions(root,{backId:'kx-support-back',closeId:'kx-support-close',onBack:()=>renderKombaxSupportHome(context),onClose:()=>{location.hash='#help';}});
}

function bindCenter(root,context={}){
  root.querySelector('#kx-open-assist')?.addEventListener('click',()=>openKombaxAssist(null,context).catch(e=>toast(assistErrorMessage(e),'error')));
  root.querySelector('#kx-open-migration')?.addEventListener('click',()=>openKombaxMigrations(null,context).catch(e=>toast(assistErrorMessage(e),'error')));
  root.querySelector('#kx-open-guide')?.addEventListener('click',()=>openMigrationGuide(context));
  root.querySelectorAll('[data-kx-assist]').forEach(b=>b.addEventListener('click',()=>openKombaxAssist(b.dataset.kxAssist,context).catch(e=>toast(assistErrorMessage(e),'error'))));
  root.querySelectorAll('[data-kx-assist-specialist]').forEach(b=>b.addEventListener('click',()=>openKombaxAssist(null,context,b.dataset.kxAssistSpecialist).catch(e=>toast(assistErrorMessage(e),'error'))));
  root.querySelectorAll('[data-kx-migration]').forEach(b=>b.addEventListener('click',()=>openKombaxMigrations(b.dataset.kxMigration,context).catch(e=>toast(assistErrorMessage(e),'error'))));
  root.querySelectorAll('[data-kx-support-chat]').forEach(b=>b.addEventListener('click',()=>openKombaxSupportChat(b.dataset.kxSupportChat,context).catch(e=>toast(assistErrorMessage(e,{support:true}),'error'))));
  root.querySelectorAll('[data-kx-human]').forEach(b=>b.addEventListener('click',async()=>{try{await repos.customerOps.requestHuman(b.dataset.kxHuman);toast('Caso enviado a revisión humana');}catch(e){toast(humanError(e),'error')}}));
  root.querySelectorAll('[data-kx-delete-ticket]').forEach(b=>b.addEventListener('click',()=>requestDeleteTicket(b.dataset.kxDeleteTicket,b.dataset.kxDeleteMode,context,()=>b.dataset.kxDeleteMode==='migration'?renderKombaxMigrationsHome(context):renderKombaxAssistHome(context))));
  root.querySelector('#kx-clear-assist')?.addEventListener('click',()=>requestClearHistory('management',context,()=>renderKombaxAssistHome(context)));
  root.querySelector('#kx-clear-migrations')?.addEventListener('click',()=>requestClearHistory('migration',context,()=>renderKombaxMigrationsHome(context)));
}
export async function renderKombaxAssistHome(context={}){
  setMainHtml(`<div class="loading-card">${t('common.states.loading')} KOMBAX Assist…</div>`);
  const ref=orgTenantRef(context);if(!ref){setMainHtml(`${pageHeader('KOMBAX Assist','Asistencia inteligente de gestión para Club, Federación, Marca, Competidor y Profesional.','','KOMBAX Assist')}<div class="empty-card"><strong>Selecciona una organización gestionable</strong><p>Assist necesita el contexto y permisos de un Club, Federación, Marca, Competidor o Profesional. Para problemas de la plataforma utiliza <a href="mailto:${SUPPORT_EMAIL}">Soporte KOMBAX</a>.</p></div>`);return;}
  try{
    const data=await organizationData(context);if(!data.allowed)throw new Error('KOMBAX_MANAGEMENT_ACCESS_REQUIRED');const rows=data.rows.filter(isManagementTicket),dashboard=data.dashboard,showMigrations=data.migrationAllowed;
    const credits=await repos.customerOps.aiCredits(ref).catch(()=>null);
    setMainHtml(`<div class="kx-assist-page kx-assist-management-home">${pageHeader(t('assist.title'),t('assist.home.subtitle'),subviewActions({backId:'kx-assist-home-back',closeId:'kx-assist-home-close',backLabel:'Volver'}),'KOMBAX Assist')}${conversationChannelTabs('assist',{showMigrations})}<section class="kx-ai-product-hero"><img src="./assets/assist/hero-assist.webp" alt="KOMBAX Assist, asistente virtual de gestión" decoding="async"><div class="kx-ai-product-hero-copy"><span>${t('assist.home.heroKicker')}</span><h2>${t('assist.home.heroTitle')}</h2><p>${t('assist.home.heroBody')}</p><button class="btn btn-primary" id="kx-open-assist" ${(credits?asNumber(credits.available)<=0:assistanceQuota(dashboard).remaining<=0)?'disabled':''}>${t('assist.home.newConversation')}</button></div></section><section class="kx-assist-capabilities"><article><span>CLUB</span><strong>Alumnos, grupos, cuotas y eventos</strong><p>Resume situación, detecta pendientes y explica la información disponible.</p></article><article><span>FEDERACIÓN</span><strong>Clubes, federados y licencias</strong><p>Ayuda a priorizar revisiones y entender el estado administrativo.</p></article><article><span>MARCA</span><strong>Showcase y consultas</strong><p>Resume catálogo, actividad y oportunidades visibles para la identidad gestionada.</p></article></section><section class="card"><div class="section-title"><div><span>${t('assist.home.conversations')}</span><h3>${t('assist.home.continue')}</h3></div>${rows.length?`<button class="btn btn-ghost btn-sm" id="kx-clear-assist">${t('assist.home.clearHistory')}</button>`:''}</div><div class="kx-ticket-list">${ticketRows(rows,{mode:'assist'})}</div></section><section class="kx-ai-support-separation"><div><strong>${t('assist.home.notSupport')}</strong><p>Problemas técnicos, cuenta, facturación de KOMBAX, privacidad, seguridad, protección de menores y cuestiones legales pasan a Ayuda y soporte. La atención comienza por correo y KOMBAX gestiona cualquier escalada posterior.</p></div><button class="btn btn-ghost" id="kx-open-formal-support">${t('assist.home.openSupport')}</button></section></div>`);
    const root=document.querySelector('main')||document;root.querySelector('.kx-ai-product-hero')?.insertAdjacentHTML('beforebegin',aiCreditsCard(credits));bindConversationChannelTabs(root,{context,onSocial:context.onSocial,onShowcase:context.onShowcase,onAssist:()=>{},onMigrations:showMigrations?(context.onMigrations||(()=>renderKombaxMigrationsHome(context))):null});bindCenter(root,context);root.querySelector('#kx-open-formal-support')?.addEventListener('click',()=>renderKombaxSupportHome(context));bindSubviewActions(root,{backId:'kx-assist-home-back',closeId:'kx-assist-home-close',onBack:()=>context.onBack?context.onBack():goBackOrFallback('#dashboard'),onClose:context.onBack||(()=>{location.hash='#dashboard';})});
    const specialistsHtml=ASSIST_SPECIALISTS.map(item=>`<article class="kx-assist-specialist"><span>${esc(item.label).toUpperCase()}</span><strong>${esc(item.title)}</strong><p>${esc(item.description)}</p><button type="button" class="btn btn-ghost btn-sm" data-kx-assist-specialist="${esc(item.id)}" ${(credits?asNumber(credits.available)<=0:assistanceQuota(dashboard).remaining<=0)?'disabled':''}>${t('assist.specialties.open')}</button></article>`).join('');
    const capabilitySection=root.querySelector('.kx-assist-capabilities');
    capabilitySection?.insertAdjacentHTML('beforebegin',`<section class="kx-assist-specialists-wrap"><div class="section-title"><div><span>${t('assist.specialties.count')}</span><h3>${t('assist.specialties.title')}</h3></div></div><div class="kx-assist-specialists">${specialistsHtml}</div></section>`);
    root.querySelectorAll('[data-kx-assist-specialist]').forEach(button=>button.addEventListener('click',()=>openKombaxAssist(null,context,button.dataset.kxAssistSpecialist).catch(error=>toast(assistErrorMessage(error),'error'))));
  }catch(e){setMainHtml(`${pageHeader('KOMBAX Assist')}<div class="empty-card"><strong>No se pudo cargar KOMBAX Assist</strong><p>${esc(assistErrorMessage(e))}</p></div>`)}
}
export async function renderKombaxMigrationsHome(context={}){
  setMainHtml(`<div class="loading-card">${t('common.states.loading')} KOMBAX Migrations…</div>`);
  const ref=orgTenantRef(context);if(!ref||!canMigrationContext(context)){setMainHtml(`${pageHeader('KOMBAX Migrations')}<div class="empty-card"><strong>Disponible para Club, Federación, Marca, Competidor y Profesional</strong><p>KOMBAX Migrations adapta la importación al contexto autorizado de Club, Federación, Marca, Competidor o Profesional.</p></div>`);return;}
  try{
    const [rows,dashboard,access,credits]=await Promise.all([repos.customerOps.tickets(ref,50),repos.customerOps.dashboard(ref),repos.customerOps.guideAccess(ref),repos.customerOps.aiCredits(ref).catch(()=>null)]);if(access?.allowed!==true)throw new Error('KOMBAX_MIGRATION_ACCESS_REQUIRED');
    setMainHtml(`<div class="kx-assist-page kx-migrations-page">${pageHeader(t('migrations.title'),t('migrations.home.subtitle'),subviewActions({backId:'kx-migrations-home-back',closeId:'kx-migrations-home-close',backLabel:'Volver'}),'KOMBAX Migrations')}${conversationChannelTabs('migrations',{showMigrations:true})}<section class="kx-ai-product-hero migrations"><img src="./assets/assist/hero-migrations.webp" alt="KOMBAX Migrations, migración asistida" decoding="async"><div class="kx-ai-product-hero-copy"><span>${t('migrations.home.heroKicker')}</span><h2>${t('migrations.home.heroTitle')}</h2><p>${t('migrations.home.heroBody')}</p><div class="row-actions"><button class="btn btn-primary" id="kx-page-migration-start" ${(credits?asNumber(credits.available)<=0:migrationQuota(dashboard).remaining<=0)?'disabled':''}>${t('migrations.home.start')}</button><button class="btn btn-ghost" id="kx-page-migration-guide">${t('migrations.home.guide')}</button></div></div></section><section class="card"><div class="section-title"><div><span>${t('migrations.home.my')}</span><h3>${t('migrations.home.continue')}</h3></div>${rows.some(isMigrationTicket)?`<button class="btn btn-ghost btn-sm" id="kx-clear-migrations">${t('migrations.home.clearHistory')}</button>`:''}</div><div class="kx-ticket-list">${ticketRows(rows,{mode:'migration'})}</div></section><div class="kx-assist-economy-copy"><strong>Mismo caso, varias cargas.</strong><p>Puedes añadir más documentos a la misma migración y reutilizar el análisis ya realizado dentro de los límites del plan.</p><strong>Sin importación automática.</strong><p>Los posibles duplicados, datos incompletos y conflictos se revisan antes de la <b>Confirmación obligatoria</b> final.</p></div></div>`);
    const root=document.querySelector('main')||document;if(['profesional','competidor'].includes(context.profileType))root.querySelector('.kx-ai-product-hero')?.insertAdjacentHTML('afterend','<section class="card"><strong>Prepara tu documentación</strong><p>Revisa diplomas, acreditaciones y trayectoria con el asistente. Este espacio no importa alumnos ni cobros, ni concede verificaciones automáticamente.</p></section>');root.querySelector('.kx-ai-product-hero')?.insertAdjacentHTML('beforebegin',aiCreditsCard(credits));bindConversationChannelTabs(root,{context,onSocial:context.onSocial,onShowcase:context.onShowcase,onAssist:context.onAssist||(()=>renderKombaxAssistHome(context)),onMigrations:()=>{}});root.querySelector('#kx-page-migration-start')?.addEventListener('click',()=>openKombaxMigrations(null,context).catch(e=>toast(assistErrorMessage(e),'error')));root.querySelector('#kx-page-migration-guide')?.addEventListener('click',()=>openMigrationGuide(context));bindCenter(root,context);bindSubviewActions(root,{backId:'kx-migrations-home-back',closeId:'kx-migrations-home-close',onBack:()=>context.onBack?context.onBack():goBackOrFallback('#dashboard'),onClose:context.onBack||(()=>{location.hash='#dashboard';})});
  }catch(e){setMainHtml(`${pageHeader('KOMBAX Migrations')}<div class="empty-card"><strong>No se pudo cargar KOMBAX Migrations</strong><p>${esc(assistErrorMessage(e))}</p></div>`)}
}
export function migrationAssistBanner({title='¿Ya tienes tus datos en otro sistema?',body='KOMBAX Migrations te permite conversar y subir Excel, CSV, PDF e imágenes, con análisis por lotes, vista previa y confirmación antes de importar.',context={}}={}){const ref=orgTenantRef(context);if(!ref||!canMigrationContext(context))return '';return `<section class="kx-migration-banner"><div><span>KOMBAX MIGRATIONS</span><strong>${esc(title)}</strong><p>${esc(body)}</p></div><button type="button" class="btn btn-primary" data-kx-migration-assist>Abrir migración</button></section>`}
export function managementAssistBanner({title='KOMBAX Assist',body='Tu copiloto de gestión: analiza el contexto autorizado y te ayuda a priorizar sin modificar datos durante el piloto.',context={}}={}){if(!orgTenantRef(context))return '';return `<section class="kx-management-assist-banner"><img src="./assets/assist/assistant-avatar.webp" alt="" loading="lazy"><div><span>KOMBAX ASSIST</span><strong>${esc(title)}</strong><p>${esc(body)}</p></div><button type="button" class="btn btn-primary" data-kx-management-assist>Abrir Assist</button></section>`}
export function bindMigrationAssist(root=document,context={}){root.querySelectorAll('[data-kx-migration-assist]').forEach(button=>button.addEventListener('click',()=>openKombaxMigrations(null,context).catch(e=>toast(assistErrorMessage(e),'error'))));root.querySelectorAll('[data-kx-management-assist]').forEach(button=>button.addEventListener('click',()=>renderKombaxAssistHome(context)));}

