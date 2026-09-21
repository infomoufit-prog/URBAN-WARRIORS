import { backend } from './backend.js';
import { state } from './state.js';
import { repos } from './repositories.js';

// KOMBAX 20.083 — private workspace isolation.
// Public feed/directory stay global by product design. Private identities, network and chat become club-context scoped.

const original={
  myProfiles:repos.kombaxSocial.myProfiles,
  contacts:repos.kombaxSocial.contacts,
  contactMessages:repos.kombaxSocial.contactMessages,
  markContactRead:repos.kombaxSocial.markContactRead,
  contactStatus:repos.kombaxSocial.contactStatus,
  contact:repos.kombaxSocial.contact,
  showcaseContact:repos.kombaxSocial.showcaseContact,
  sendContactMessage:repos.kombaxSocial.sendContactMessage,
  closeContact:repos.kombaxSocial.closeContact,
  deleteContact:repos.kombaxSocial.deleteContact,
  relations:repos.kombaxSocial.relations,
  requestRelation:repos.kombaxSocial.requestRelation,
  relationState:repos.kombaxSocial.relationState,
  headerSummary:repos.notifications.headerSummary
};

const isClubWorkspace=()=>Boolean(state.session?.club_id)&&state.session?.scope!=='kombax'&&state.session?.scope!=='platform-admin';
const clubId=()=>state.session?.club_id||null;
const storageKey=()=>`kombax_active_identity:${state.session?.id||'guest'}:${clubId()||'global'}`;
let profileCache={token:'',rows:[],at:0};
const token=()=>`${state.session?.id||'guest'}:${clubId()||'global'}:${state.session?.scope||'club'}`;
const selectedSocioKey=()=>`uw2_selected_socio:${state.session?.id||'guest'}:${clubId()||'global'}`;

// 20.083: the previously global selected-student key could survive logout/club changes.
// Keep this UI state tenant-scoped as user + club and discard the legacy global key.
try{localStorage.removeItem('uw2_selected_socio');}catch{}
state.selectedSocioId=null;
state.selectSocio=function(id){
  this.selectedSocioId=id||null;
  try{if(id)localStorage.setItem(selectedSocioKey(),String(id));else localStorage.removeItem(selectedSocioKey());}catch{}
};
function hydrateTenantStudentSelection(){
  if(!state.session?.id||!clubId()){state.selectedSocioId=null;return;}
  try{state.selectedSocioId=localStorage.getItem(selectedSocioKey())||null;}catch{state.selectedSocioId=null;}
}

async function syncPushForWorkspace(){
  if(!isClubWorkspace()||!window.UrbanWarriorsNative?.getPushToken||!state.session?.id)return;
  const pushToken=String(window.UrbanWarriorsNative.getPushToken()||'').trim();if(!pushToken)return;
  const key=`uw_push_synced_token_20083:${state.session.id}:${clubId()}:${pushToken}`;
  try{if(localStorage.getItem(key)==='1')return;}catch{}
  try{
    await backend.mutate('push.registrar',{token:pushToken,plataforma:'android'});
    try{localStorage.setItem(key,'1');}catch{}
  }catch{/* Support-only sessions without a real membership intentionally fail closed here. */}
}

function resetContextCache(){profileCache={token:'',rows:[],at:0};}

async function workspaceProfiles({force=false}={}){
  if(!isClubWorkspace())return original.myProfiles();
  const t=token();
  if(!force&&profileCache.token===t&&Date.now()-profileCache.at<15000)return profileCache.rows;
  const rows=await backend.readRpc('app_kombax_workspace_social_profiles_v147',{p_club_id:clubId()});
  profileCache={token:t,rows:Array.isArray(rows)?rows:[],at:Date.now()};
  return profileCache.rows;
}

async function workspaceActorId(){
  const rows=await workspaceProfiles();
  if(!rows.length)return null;
  let stored='';try{stored=localStorage.getItem(storageKey())||'';}catch{}
  const saved=rows.find(p=>String(p.id)===String(stored));
  if(saved)return saved.id;
  if(stored){try{localStorage.removeItem(storageKey());}catch{}}
  const roles=state.session?.roles?.length?state.session.roles:[state.session?.rol];
  const managerial=state.session?.support_mode===true||roles.some(r=>['direccion','coordinacion'].includes(r));
  const preferred=(managerial?rows.find(p=>p.sujeto_tipo==='club'&&String(p.club_id)===String(clubId())):null)
    ||rows.find(p=>p.sujeto_tipo==='miembro')||rows[0];
  return preferred?.id||null;
}

async function requireActor(explicit=null){
  if(!isClubWorkspace())return explicit||null;
  const actor=explicit||await workspaceActorId();
  if(!actor)throw new Error('No hay una identidad Social autorizada dentro de este club.');
  const rows=await workspaceProfiles();
  if(!rows.some(p=>String(p.id)===String(actor)))throw new Error('KOMBAX_CONTEXT_IDENTITY_FORBIDDEN');
  return actor;
}

const requestId=()=>crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`;
async function contextNetwork(operation,payload={}){
  const actor=await requireActor(payload.remitente_social_id||payload.autor_social_id||payload.actor_social_id||null);
  const body={...payload};
  if(!body.remitente_social_id&&!body.autor_social_id)body.actor_social_id=actor;
  const response=await backend.writeRpc('app_kombax_context_network_mutate_v147',{
    p_club_id:clubId(),p_operation:operation,p_payload:body,p_request_id:requestId()
  });
  if(!response?.ok||response.operation!==operation)throw new Error(`Respuesta contextual no verificable para ${operation}.`);
  window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));
  return response.data;
}
async function contextRelation(operation,payload={}){
  const body={...payload};
  if(operation==='kombax.relation.request')await requireActor(body.origen_social_id||null);
  const response=await backend.writeRpc('app_kombax_context_relation_mutate_v147',{
    p_club_id:clubId(),p_operation:operation,p_payload:body,p_request_id:requestId()
  });
  if(!response?.ok||response.operation!==operation)throw new Error(`Respuesta contextual no verificable para ${operation}.`);
  window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));
  return response.data;
}

repos.kombaxSocial.myProfiles=()=>isClubWorkspace()?workspaceProfiles({force:true}):original.myProfiles();
repos.kombaxSocial.contacts=async(limit=50)=>{
  if(!isClubWorkspace())return original.contacts(limit);
  const actor=await requireActor();
  return backend.readRpc('app_kombax_contactos_contexto_v147',{p_club_id:clubId(),p_actor_social_id:actor,p_limit:Math.min(200,Math.max(20,Number(limit)||50))});
};
repos.kombaxSocial.contactMessages=async(contacto_id,{before=null,after=null,limit=30}={})=>{
  if(!isClubWorkspace())return original.contactMessages(contacto_id,{before,after,limit});
  const actor=await requireActor();
  return backend.readRpc('app_kombax_contact_mensajes_contexto_v147',{
    p_club_id:clubId(),p_actor_social_id:actor,p_contacto_id:contacto_id,
    p_before_ordinal:before,p_after_ordinal:after,p_limit:Math.min(50,Math.max(1,Number(limit)||30))
  });
};
repos.kombaxSocial.markContactRead=async(contacto_id)=>{
  if(!isClubWorkspace())return original.markContactRead(contacto_id);
  const actor=await requireActor();
  const out=await backend.writeRpc('app_kombax_contact_mark_read_contexto_v147',{p_club_id:clubId(),p_actor_social_id:actor,p_contacto_id:contacto_id});
  window.dispatchEvent(new CustomEvent('uw-kombax-activity-changed'));return out;
};
repos.kombaxSocial.contactStatus=async(contacto_id,estado)=>isClubWorkspace()
  ?contextNetwork('kombax.social.contacto.estado',{contacto_id,estado,actor_social_id:await requireActor()})
  :original.contactStatus(contacto_id,estado);
repos.kombaxSocial.contact=async(remitente_social_id,destinatario_social_id,motivo,mensaje)=>isClubWorkspace()
  ?contextNetwork('kombax.contact.request',{remitente_social_id,destinatario_social_id,motivo,mensaje})
  :original.contact(remitente_social_id,destinatario_social_id,motivo,mensaje);
repos.kombaxSocial.showcaseContact=async(remitente_social_id,elemento_id,mensaje)=>isClubWorkspace()
  ?contextNetwork('kombax.showcase.contact.request',{remitente_social_id,elemento_id,mensaje})
  :original.showcaseContact(remitente_social_id,elemento_id,mensaje);
repos.kombaxSocial.sendContactMessage=async(contacto_id,autor_social_id,texto)=>isClubWorkspace()
  ?contextNetwork('kombax.contact.message.send',{contacto_id,autor_social_id,texto})
  :original.sendContactMessage(contacto_id,autor_social_id,texto);
repos.kombaxSocial.closeContact=async(contacto_id)=>isClubWorkspace()
  ?contextNetwork('kombax.contact.close',{contacto_id,actor_social_id:await requireActor()})
  :original.closeContact(contacto_id);
repos.kombaxSocial.deleteContact=async(contacto_id,actor_social_id)=>isClubWorkspace()
  ?contextNetwork('kombax.contact.delete',{contacto_id,actor_social_id:await requireActor(actor_social_id)})
  :original.deleteContact(contacto_id,actor_social_id);
repos.kombaxSocial.relations=async(social_id,limit=50)=>{
  if(!isClubWorkspace())return original.relations(social_id,limit);
  const actor=await requireActor(social_id||null);
  return backend.readRpc('app_kombax_relaciones_contexto_v147',{p_club_id:clubId(),p_actor_social_id:actor,p_limit:Math.min(150,Math.max(20,Number(limit)||50))});
};
repos.kombaxSocial.requestRelation=async(origen_social_id,destino_social_id,tipo,nota='')=>isClubWorkspace()
  ?contextRelation('kombax.relation.request',{origen_social_id,destino_social_id,tipo,nota})
  :original.requestRelation(origen_social_id,destino_social_id,tipo,nota);
repos.kombaxSocial.relationState=async(relacion_id,estado)=>isClubWorkspace()
  ?contextRelation('kombax.relation.state',{relacion_id,estado})
  :original.relationState(relacion_id,estado);

repos.notifications.headerSummary=async()=>{
  if(!isClubWorkspace())return original.headerSummary();
  const actor=await requireActor();
  return backend.readRpc('app_kombax_header_summary_v147',{p_club_id:clubId(),p_actor_social_id:actor});
};

repos.kombaxSocial.contextIsolationAudit=()=>{
  if(!isClubWorkspace())return Promise.resolve({ok:true,scope:'global',private_context_isolated:true});
  return backend.readRpc('app_kombax_context_isolation_audit_v147',{p_club_id:clubId()});
};

// Fail-safe cleanup: old UI intents may survive a club switch, but never a private dataset.
let lastToken=token();
function checkContext(){
  const next=token();if(next===lastToken)return;
  lastToken=next;resetContextCache();hydrateTenantStudentSelection();syncPushForWorkspace();
  try{sessionStorage.removeItem('kombax_social_open_contact');sessionStorage.removeItem('kombax_social_view');}catch{}
  window.dispatchEvent(new CustomEvent('uw-kombax-private-context-changed',{detail:{token:next}}));
}
window.addEventListener('hashchange',checkContext);
window.addEventListener('popstate',checkContext);
window.addEventListener('uw-kombax-activity-changed',checkContext);
setInterval(checkContext,5000);

// Visible contextual cue + fail-safe UI binding for private actions.
// The backend is authoritative; this only prevents the user from accidentally composing a private action with a different scoped actor.
async function enforcePrivateActorSelectors(){
  if(!isClubWorkspace())return;
  const actor=await workspaceActorId().catch(()=>null);if(!actor)return;
  document.querySelectorAll('.kombax-social-page select[name="remitente"],.kombax-social-page select[name="origen"]').forEach(select=>{
    if(select.dataset.kxContextBound==='1')return;
    select.dataset.kxContextBound='1';
    [...select.options].forEach(option=>{if(option.value&&String(option.value)!==String(actor))option.remove();});
    if([...select.options].some(option=>String(option.value)===String(actor)))select.value=String(actor);
  });
  document.querySelectorAll('#kx-relation-profile').forEach(select=>{
    if(select.dataset.kxContextBound==='1')return;
    select.dataset.kxContextBound='1';
    select.addEventListener('change',event=>{
      event.stopImmediatePropagation();
      try{localStorage.setItem(storageKey(),String(select.value));}catch{}
      resetContextCache();
      document.querySelector('[data-social-view="relations"]')?.click();
    },true);
  });
}

const observer=new MutationObserver(()=>{
  if(!isClubWorkspace())return;
  document.querySelectorAll('.kombax-social-page .kx-identity-context').forEach(el=>{
    if(el.querySelector('.kx-context-isolation-mark'))return;
    const mark=document.createElement('small');mark.className='kx-context-isolation-mark';mark.textContent=`Contexto aislado · ${state.session?.club?.nombre||'club actual'}`;el.appendChild(mark);
  });
  enforcePrivateActorSelectors().catch(()=>{});
});
observer.observe(document.documentElement,{subtree:true,childList:true});

console.info('KOMBAX 20.083 · aislamiento privado de contexto instalado');
