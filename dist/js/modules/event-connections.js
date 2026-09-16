import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { esc, humanError } from '../core/utils.js';
import { openDetail, openForm, toast, closeModal } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const POLICY_FIELDS=[
  ['publish_general','general'],['publish_schedule','schedule'],['publish_location','location'],['publish_visuals','visuals'],
  ['publish_organizers','organizers'],['publish_categories','categories'],['publish_participants','participants'],['publish_fight_card','fightCard'],
  ['publish_official_weigh_in','officialWeighIn'],['publish_results','results'],['publish_album','album'],['publish_highlights','highlights']
];
const policyLabel=token=>t(`events.connections.policy.${token}`);
const authStatus=c=>String(c?.authorization_status||'approved');
const connectionStatus=c=>{
  const auth=authStatus(c);
  if(auth!=='approved')return t(`events.connections.status.${auth}`);
  return t(`events.connections.status.${String(c?.status||'none')}`);
};

function privacyNotice(){return `<section class="kx-event-connection-privacy">${icon('shieldCheck',{size:22})}<div><strong>${esc(t('events.connections.privacyTitle'))}</strong><p>${esc(t('events.connections.privacyBody'))}</p></div></section>`;}

async function choosePublicEvent(internalEvent,onDone){
  const rows=await repos.kombaxEvents.list({query:internalEvent.nombre||'',limit:30}).catch(()=>[]);
  const body=`${privacyNotice()}<div class="kx-event-connect-list">${rows.length?rows.map(e=>`<button type="button" class="kx-event-connect-candidate" data-kx-connect-public="${esc(e.id)}"><div><strong>${esc(e.nombre||t('events.page.publicEvent'))}</strong><small>${esc([e.fecha_inicio?new Date(e.fecha_inicio).toLocaleDateString(kxLocaleTag(kxGetLocale())):'',e.municipio,e.organizador_nombre].filter(Boolean).join(' · '))}</small></div><span>${esc(t('events.actions.connect'))}</span></button>`).join(''):`<div class="empty-card compact"><strong>${esc(t('events.connections.noMatches'))}</strong><p>${esc(t('events.connections.noMatchesBody'))}</p></div>`}</div>`;
  const {wrap}=openDetail({title:t('events.connections.chooseTitle'),subtitle:internalEvent.nombre||t('events.connections.chooseSubtitle'),body,width:'820px'});
  wrap.querySelectorAll('[data-kx-connect-public]').forEach(b=>b.addEventListener('click',async()=>{
    b.disabled=true;
    try{
      const out=await repos.eventConnections.mutate('connect',{internal_event_id:internalEvent.id,public_event_id:b.dataset.kxConnectPublic});
      toast(out?.authorization_status==='pending'?t('events.connections.requested'):t('events.connections.connected'));
      closeModal();await onDone?.();
    }catch(error){b.disabled=false;toast(humanError(error)||t('events.connections.requestError'),'error');}
  }));
}

function policyFields(policy={}){return POLICY_FIELDS.map(([name,token])=>({name,label:policyLabel(token),type:'checkbox',value:policy?.[name]===true,full:true}));}

async function editPolicy(connection,onDone){
  openForm({title:t('events.connections.policyTitle'),subtitle:t('events.connections.policySubtitle'),width:'760px',fields:policyFields(connection.policy||{}),submitText:t('events.connections.policySave'),onSubmit:async values=>{
    const policy={};for(const [name] of POLICY_FIELDS)policy[name]=values[name]===true;
    await repos.eventConnections.mutate('policy.set',{connection_id:connection.id,policy});
    toast(t('events.connections.policyUpdated'));
    await repos.eventConnections.mutate('projection.publish',{connection_id:connection.id});
    toast(t('events.connections.publicViewUpdated'));await onDone?.();
  }});
}

function participantRows(data){
  const rows=Array.isArray(data?.participants)?data.participants:[];
  if(!rows.length)return `<div class="empty-card compact"><strong>${esc(t('events.connections.participantsEmpty'))}</strong><p>${esc(t('events.connections.participantsBody'))}</p></div>`;
  return `<div class="kx-event-shared-participants">${rows.map(row=>{
    const license=row.license||null;
    const meta=[row.discipline,row.category,row.event_weight_kg!=null?`${Number(row.event_weight_kg)} kg`:null].filter(Boolean).join(' · ');
    const licenseMeta=license?[license.number,license.verification_status==='verified'?'✓':null,license.expires_at?new Date(license.expires_at).toLocaleDateString(kxLocaleTag(kxGetLocale())):null].filter(Boolean).join(' · '):'—';
    return `<article><div><strong>${esc(row.name||'—')}</strong><small>${esc(row.club_name||'')}</small><small>${esc(meta)}</small></div><span>${esc(licenseMeta)}</span></article>`;
  }).join('')}</div>`;
}

async function openSharedParticipants(connection){
  try{
    const data=await repos.eventConnections.participants(connection.id);
    openDetail({title:t('events.connections.participantsTitle'),subtitle:t('events.connections.referenceOnly'),body:participantRows(data),width:'900px'});
  }catch(error){toast(humanError(error)||t('events.connections.queryError'),'error');}
}

export async function openEventConnectionManager(internalEvent,{onDone=null}={}){
  let connection=null;
  try{connection=await repos.eventConnections.get({internal_event_id:internalEvent.id});}catch(error){toast(humanError(error)||t('events.connections.queryError'),'error');return;}
  if(!connection){await choosePublicEvent(internalEvent,async()=>openEventConnectionManager(internalEvent,{onDone}));return;}
  const authorization=authStatus(connection),approved=authorization==='approved';
  const enabled=POLICY_FIELDS.filter(([name])=>connection.policy?.[name]===true).map(([,token])=>policyLabel(token));
  const status=connectionStatus(connection);
  const actions=approved
    ?`<button class="btn btn-primary" id="kx-policy-edit">${esc(t('events.actions.configure'))}</button><button class="btn btn-ghost" id="kx-participants-sync">${esc(t('events.actions.syncParticipants'))}</button><button class="btn btn-ghost" id="kx-participants-view">${esc(t('events.actions.viewParticipants'))}</button>${connection.status==='connected'?`<button class="btn btn-ghost" id="kx-connection-pause">${esc(t('events.actions.pause'))}</button>`:`<button class="btn btn-ghost" id="kx-connection-resume">${esc(t('events.actions.resume'))}</button>`}<button class="btn btn-ghost" id="kx-connection-disconnect">${esc(t('events.actions.disconnect'))}</button>`
    :authorization==='pending'?'' : `<button class="btn btn-primary" id="kx-connection-request-again">${esc(t('events.actions.connect'))}</button>`;
  const body=`<div class="kx-event-connection-manager">${privacyNotice()}<section class="kx-event-connection-card"><header><div><span>KOMBAX EVENTS</span><h3>${esc(connection.public_event?.nombre||t('events.page.publicEvent'))}</h3><small>${esc(status)}</small></div><b class="kx-connection-state ${esc(authorization)}">${esc(status)}</b></header><div class="kx-connection-link"><span>${esc(t('events.labels.myClub'))}</span><b>${esc(connection.internal_event?.nombre||internalEvent.nombre)}</b><i>↔</i><span>KOMBAX Events</span><b>${esc(connection.public_event?.nombre||t('events.page.publicEvent'))}</b></div></section>${authorization==='pending'?`<div class="alert"><strong>${esc(t('events.connections.approvalPending'))}</strong><span>${esc(t('events.connections.publicOrganizerRule'))}</span></div>`:''}<section class="kx-event-publication-summary"><h4>${esc(t('events.labels.publicInformation'))}</h4>${approved&&enabled.length?`<div class="kx-policy-pills">${enabled.map(x=>`<span>${esc(x)}</span>`).join('')}</div>`:`<p>${esc(t('events.connections.noneAuthorized'))}</p>`}</section>${actions?`<div class="row-actions">${actions}</div>`:''}</div>`;
  const {wrap}=openDetail({title:t('events.connections.managerTitle'),subtitle:t('events.connections.managerSubtitle'),body,width:'900px'});
  const refresh=async()=>{closeModal();await openEventConnectionManager(internalEvent,{onDone});};
  wrap.querySelector('#kx-policy-edit')?.addEventListener('click',()=>editPolicy(connection,refresh));
  wrap.querySelector('#kx-participants-sync')?.addEventListener('click',async()=>{try{await repos.eventConnections.mutate('participants.sync',{connection_id:connection.id});toast(t('events.connections.participantsSynced'));await refresh();}catch(error){toast(humanError(error)||t('events.connections.queryError'),'error');}});
  wrap.querySelector('#kx-participants-view')?.addEventListener('click',()=>openSharedParticipants(connection));
  wrap.querySelector('#kx-connection-pause')?.addEventListener('click',async()=>{await repos.eventConnections.mutate('status.set',{connection_id:connection.id,status:'paused'});toast(t('events.connections.paused'));await refresh();});
  wrap.querySelector('#kx-connection-resume')?.addEventListener('click',async()=>{await repos.eventConnections.mutate('status.set',{connection_id:connection.id,status:'connected'});toast(t('events.connections.resumed'));await refresh();});
  wrap.querySelector('#kx-connection-disconnect')?.addEventListener('click',async()=>{await repos.eventConnections.mutate('status.set',{connection_id:connection.id,status:'disconnected'});toast(t('events.connections.disconnected'));await refresh();});
  wrap.querySelector('#kx-connection-request-again')?.addEventListener('click',async()=>{try{await repos.eventConnections.mutate('connect',{internal_event_id:internalEvent.id,public_event_id:connection.public_event_id});toast(t('events.connections.requested'));await refresh();}catch(error){toast(humanError(error)||t('events.connections.requestError'),'error');}});
}

export async function openPublicEventConnectionManager(publicEvent){
  try{
    const rows=await repos.eventConnections.listForPublic(publicEvent.id);const connections=Array.isArray(rows)?rows:[];
    const cards=connections.length?connections.map(c=>`<article class="kx-event-connection-card" data-kx-public-connection="${esc(c.id)}"><header><div><strong>${esc(c.club?.nombre||'—')}</strong><small>${esc(c.internal_event?.nombre||'—')}</small></div><b class="kx-connection-state ${esc(c.authorization_status||'pending')}">${esc(connectionStatus(c))}</b></header><small>${esc(t('events.connections.referenceOnly'))}</small><div class="row-actions">${c.authorization_status!=='approved'?`<button type="button" class="btn btn-primary btn-sm" data-kx-connection-approve="${esc(c.id)}">${esc(t('events.actions.approve'))}</button>`:''}${c.authorization_status==='pending'?`<button type="button" class="btn btn-ghost btn-sm" data-kx-connection-reject="${esc(c.id)}">${esc(t('events.actions.reject'))}</button>`:''}${c.authorization_status==='approved'?`<button type="button" class="btn btn-ghost btn-sm" data-kx-connection-revoke="${esc(c.id)}">${esc(t('events.actions.revoke'))}</button>`:''}<button type="button" class="btn btn-ghost btn-sm" data-kx-connection-participants="${esc(c.id)}">${esc(t('events.actions.viewParticipants'))} · ${Number(c.shared_participants||0)}</button></div></article>`).join(''):`<div class="empty-card"><strong>${esc(t('events.connections.organizerEmpty'))}</strong><p>${esc(t('events.connections.publicOrganizerRule'))}</p></div>`;
    const modal=openDetail({title:t('events.connections.organizerTitle'),subtitle:t('events.connections.organizerSubtitle'),body:`${privacyNotice()}<div class="alert"><strong>${esc(t('events.connections.publicOrganizerRule'))}</strong><span>${esc(t('events.connections.referenceOnly'))}</span></div><div class="kx-event-public-connections">${cards}</div>`,width:'1000px'});
    const refresh=async()=>{modal.close();await openPublicEventConnectionManager(publicEvent);};
    const decide=async(id,decision)=>{try{await repos.eventConnections.mutate('authorization.set',{connection_id:id,decision});toast(t('events.connections.authorizationUpdated'));await refresh();}catch(error){toast(humanError(error)||t('events.connections.queryError'),'error');}};
    modal.wrap.querySelectorAll('[data-kx-connection-approve]').forEach(b=>b.addEventListener('click',()=>decide(b.dataset.kxConnectionApprove,'approved')));
    modal.wrap.querySelectorAll('[data-kx-connection-reject]').forEach(b=>b.addEventListener('click',()=>decide(b.dataset.kxConnectionReject,'rejected')));
    modal.wrap.querySelectorAll('[data-kx-connection-revoke]').forEach(b=>b.addEventListener('click',()=>decide(b.dataset.kxConnectionRevoke,'revoked')));
    modal.wrap.querySelectorAll('[data-kx-connection-participants]').forEach(b=>b.addEventListener('click',()=>openSharedParticipants({id:b.dataset.kxConnectionParticipants})));
  }catch(error){toast(humanError(error)||t('events.connections.queryError'),'error');}
}

export async function eventConnectionBadge(internalEventId){
  try{const c=await repos.eventConnections.get({internal_event_id:internalEventId});return c?{connected:authStatus(c)==='approved'&&c.status==='connected',status:c.status,authorization_status:authStatus(c),label:connectionStatus(c),public_event:c.public_event}:null;}catch{return null;}
}
