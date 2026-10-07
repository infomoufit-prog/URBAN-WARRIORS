import { backend, client } from './core/backend.js';
import { state } from './core/state.js';
import { repos } from './core/repositories.js';
import { humanError, esc } from './core/utils.js';
import { validateBirthDate } from './core/account-birth-date.js';
import { has } from './core/permissions.js';
import { createAdaptivePoller } from './core/adaptive-poller.js';
import { bindAccountModeFields } from './ui/account-mode-fields.js';
import { shell, setAppHtml, bindDismissAlerts, setError, openForm, openDetail, closeModal, toast, setNotificationBadge, setKombaxNotificationBadge, setMessageBadge } from './ui/components.js';
import { navIcon, icon } from './ui/icons.js';
import { renderDashboard, renderCatalog } from './modules/dashboard-catalog.js';
import { renderGroups, renderMembers, renderEnrollments } from './modules/groups-members.js';
import { renderSessions, renderAttendance, renderTracking, renderProgress } from './modules/training.js';
import { renderFinance, renderReminders } from './modules/finance.js';
import { renderCommunications, renderMaterial, renderNotifications } from './modules/comms-material.js';
import { renderUsers, renderSettings, renderProfile, renderInstall } from './modules/admin.js';
import { renderPortalDashboard, renderPortalSchedule, renderPortalRequests, renderPortalProfile } from './modules/portal.js';
import { renderDocuments } from './modules/documents.js';
import { renderCommunity } from './modules/community.js';
import { renderEvents } from './modules/events.js';
import { renderHelpLegal } from './modules/help-legal.js';
import { KOMBAX_BRAND, platformFeatures, hasExplicitClubSelection, selectedClubSlug, selectedClubPreview, selectClubSlug, clearSelectedClub, themeDefinition } from './core/platform.js';
import { renderLifecycle } from './modules/lifecycle.js';
import { renderKombaxGateway, renderClubDirectory, renderDirectProfiles, renderDirectProfileHub, renderGlobalHome, renderIdentityPresentation, openMyAccount } from './modules/gateway.js';
import { renderClubKombaxHub } from './modules/club-kombax-hub.js';
import { renderPlatformAdminAccess, renderPlatformAdminConsole } from './modules/platform-admin-access.js';
import { renderWorkScopes } from './modules/work-scopes.js';
import { openPasswordRecovery } from './modules/auth-recovery.js';
import { TEAM_INVITE_ROLES, teamInviteRoleLabel } from './core/invitations.js';
import { mediaFrameStyle } from './ui/media-framing.js';
import { installClientTelemetry } from './core/telemetry.js';
import { showPlatformLegalGate } from './modules/platform-legal.js';
import { promptMissingAccountBirthDate } from './modules/account-birth-date.js';
import { renderClubFederationAdmin, renderSelfLicenses } from './modules/federation-licenses.js';
import { renderPlanServices } from './modules/plan-services.js';
import { renderKombaxHome } from './modules/kombax-home.js';
import { renderGuides } from './modules/guides.js';
import { renderConsulting } from './modules/consulting.js';
import { renderResourceCenter } from './modules/resource-center.js';
import { renderPrivateTraining } from './modules/private-training.js';
import { t, getLocale, setLocale } from './i18n/index.js';
import { languageSelectorHtml, bindLanguageSelectors } from './i18n/ui.js';
import { installLegacyRuntimeLocalization } from './i18n/legacy-runtime.js';
import { installUniversalContentTranslation } from './i18n/user-content-translation.js';
installLegacyRuntimeLocalization();
installUniversalContentTranslation();

installClientTelemetry();

// R114 · Route-level lazy loading. Keep heavy product modules out of the initial
// authenticated startup graph while preserving the existing router contract.
const lazyModules=new Map();
function lazyModule(path){
  if(!lazyModules.has(path))lazyModules.set(path,import(path).catch(error=>{lazyModules.delete(path);throw error;}));
  return lazyModules.get(path);
}
const renderKombaxSocial=(...args)=>lazyModule('./modules/kombax-social.js').then(m=>m.renderKombaxSocial(...args));
const renderKombaxConversations=(...args)=>lazyModule('./modules/kombax-social.js').then(m=>m.renderKombaxConversations(...args));
const renderShowcase=(...args)=>lazyModule('./modules/showcase.js').then(m=>m.renderShowcase(...args));
const renderMyShowcase=(...args)=>lazyModule('./modules/showcase.js').then(m=>m.renderMyShowcase(...args));
const renderKombaxEvents=(...args)=>lazyModule('./modules/kombax-events.js').then(m=>m.renderKombaxEvents(...args));
const renderMyEventsCenter=(...args)=>lazyModule('./modules/kombax-events.js').then(m=>m.renderMyEventsCenter(...args));
const renderPublicKombaxEventLanding=(...args)=>lazyModule('./modules/kombax-events.js').then(m=>m.renderPublicKombaxEventLanding(...args));
const renderPlatformAdmin=(...args)=>lazyModule('./modules/platform-admin.js').then(m=>m.renderPlatformAdmin(...args));
const renderKombaxAssistHome=(...args)=>lazyModule('./modules/customer-operations.js').then(m=>m.renderKombaxAssistHome(...args));
const renderKombaxMigrationsHome=(...args)=>lazyModule('./modules/customer-operations.js').then(m=>m.renderKombaxMigrationsHome(...args));
const renderKombaxSupportHome=(...args)=>lazyModule('./modules/customer-operations.js').then(m=>m.renderKombaxSupportHome(...args));

const isPortal=()=>['familia','alumno'].includes(state.session?.rol);
const ORG_ASSIST_ROLES=new Set(['direccion','coordinacion','secretaria','economia']);
const PRIVATE_SHOWCASE_ROLES=new Set(['direccion','coordinacion']);
const canUseOrgAssist=(session=state.session)=>Boolean(session?.club_id&&ORG_ASSIST_ROLES.has(String(session?.rol||'')));
const canManagePrivateShowcase=(session=state.session)=>Boolean(session?.club_id&&PRIVATE_SHOWCASE_ROLES.has(String(session?.rol||'')));
const canManagePrivateEvents=(session=state.session)=>Boolean(session?.club_id&&has(session,'eventManage'));
const routes={
  dashboard:()=>renderKombaxHome({onNavigate:id=>navigate(id)}),workspace:()=>isPortal()?renderPortalDashboard():renderDashboard(),resources:()=>renderResourceCenter({section:sessionStorage.getItem('kx_resource_section')||'usage'}),guides:renderGuides,consulting:renderConsulting,training:renderPrivateTraining,catalog:renderCatalog,groups:()=>isPortal()?renderPortalSchedule():renderGroups(),members:renderMembers,enrollments:renderEnrollments,
  sessions:renderSessions,attendance:renderAttendance,progress:renderProgress,finance:renderFinance,reminders:renderReminders,communications:renderCommunications,
  tracking:renderTracking,material:renderMaterial,documents:renderDocuments,notifications:renderNotifications,users:renderUsers,settings:renderSettings,requests:renderPortalRequests,install:renderInstall,profile:()=>isPortal()?renderPortalProfile():(['direccion','coordinacion'].includes(state.session?.rol)?renderClubKombaxHub():renderProfile), 'personal-profile':renderProfile,'platform-admin':renderPlatformAdmin,scopes:renderWorkScopes,community:renderCommunity,social:renderKombaxSocial,conversations:renderKombaxConversations,showcase:renderShowcase,'my-showcase':renderMyShowcase,'kombax-events':renderKombaxEvents,'my-events':renderMyEventsCenter,events:renderEvents,archive:renderLifecycle,assist:renderKombaxAssistHome,migrations:renderKombaxMigrationsHome,'plans-services':()=>renderPlanServices({audience:'club',subjectType:'club',subjectId:state.session?.club_id}),support:renderKombaxSupportHome,help:renderHelpLegal,
  'federation-admin':()=>renderClubFederationAdmin(state.session?.club_id,{onBack:()=>navigate('dashboard')}),
  'my-licenses':()=>renderSelfLicenses(null,{embedded:true,contextLabel:'MI CUENTA',onBack:()=>navigate('dashboard')})
};
const NAV_KEY={dashboard:'dashboard',catalog:'catalog',groups:'groups',members:'members',enrollments:'enrollments',sessions:'sessions',attendance:'attendance',progress:'progress',finance:'finance',reminders:'reminders',communications:'communications',tracking:'tracking',material:'material',documents:'documents',notifications:'notifications',users:'users',settings:'settings',profile:'profile',requests:'requests',install:'install',community:'community',social:'social',showcase:'showcase','my-showcase':'myShowcase','kombax-events':'kombaxEvents','my-events':'myEvents','platform-admin':'platformAdmin','personal-profile':'personalProfile',scopes:'scopes',events:'events',archive:'archive',conversations:'conversations',assist:'assist',migrations:'migrations','plans-services':'plansServices',support:'support',help:'help','federation-admin':'federationAdmin','my-licenses':'myLicenses'};
const navLabel=id=>t(`navigation.routes.${NAV_KEY[id]||id}`);

function navFor(session){
  const role=session?.rol;let ids;
  if(role==='direccion'||role==='coordinacion') ids=['dashboard','members','enrollments','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','events','material','documents','archive','notifications','users','scopes','settings','help','install','profile'];
  else if(role==='secretaria') ids=['dashboard','enrollments','members','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','events','material','documents','archive','notifications','users','settings','help','install','profile'];
  else if(role==='economia') ids=['dashboard','finance','reminders','community','events','material','notifications','settings','help','install','profile'];
  else if(role==='comunicacion') ids=['dashboard','communications','community','events','notifications','settings','help','install','profile'];
  else if(role==='monitor') ids=['dashboard','members','groups','sessions','attendance','tracking','progress','finance','community','events','notifications','help','install','profile'];
  else ids=['dashboard','groups','finance','communications','community','events','material','notifications','requests','help','install','profile'];
  if(platformFeatures().social){const communityIndex=ids.indexOf('community');ids.splice(communityIndex>=0?communityIndex+1:ids.length,0,'social');}
  if(platformFeatures().events){
    const socialIndex=ids.indexOf('social');ids.splice(socialIndex>=0?socialIndex+1:ids.length,0,'kombax-events');
    if(canManagePrivateEvents(session)){const eventsIndex=ids.indexOf('kombax-events');ids.splice(eventsIndex+1,0,'my-events');}
  }
  if(platformFeatures().showcase){
    const privateEventsIndex=ids.indexOf('my-events'),eventsIndex=ids.indexOf('kombax-events'),socialIndex=ids.indexOf('social');
    const anchor=privateEventsIndex>=0?privateEventsIndex:(eventsIndex>=0?eventsIndex:socialIndex);
    ids.splice(anchor>=0?anchor+1:ids.length,0,'showcase');
    if(canManagePrivateShowcase(session)){const showcaseIndex=ids.indexOf('showcase');ids.splice(showcaseIndex+1,0,'my-showcase');}
  }
  if(['direccion','coordinacion','secretaria'].includes(role)){const anchor=ids.indexOf('documents');ids.splice(anchor>=0?anchor:ids.length,0,'federation-admin');}
  if(canUseOrgAssist(session)){const accountAnchor=ids.indexOf('help');const commercial=role==='direccion'||role==='coordinacion'?['plans-services']:[];ids.splice(accountAnchor>=0?accountAnchor:ids.length,0,...commercial,'assist','migrations');}
  if(role==='direccion'||role==='coordinacion')ids.unshift('personal-profile');
  return [...new Set(ids)].map(id=>({id,label:role==='monitor'&&id==='dashboard'?t('navigation.contextual.today'):role==='monitor'&&id==='members'?t('navigation.contextual.myStudents'):role==='monitor'&&id==='groups'?t('navigation.contextual.myGroups'):role==='monitor'&&id==='finance'?t('navigation.contextual.myWallet'):role==='alumno'&&id==='help'?t('navigation.contextual.myManual'):isPortal()&&id==='groups'?t('navigation.contextual.schedules'):isPortal()&&id==='finance'?t('navigation.contextual.fees'):(role==='direccion'||role==='coordinacion')&&id==='profile'?t('navigation.contextual.clubProfile'):navLabel(id),icon:navIcon(id)}));
}
function mobileNavFor(session){
  const profileId=['direccion','coordinacion'].includes(session?.rol)?'personal-profile':'profile';
  const ids=[profileId];
  if(platformFeatures().social)ids.push('social');
  if(platformFeatures().events)ids.push('kombax-events');
  if(platformFeatures().showcase)ids.push('showcase');
  ids.push('more');
  const map={more:{id:'more',label:'Mi Club',icon:navIcon('community')}};
  return ids.map(id=>map[id]||{id,label:navLabel(id),icon:navIcon(id)});
}

let notificationPoller=null;
let notificationPrimed=false;
let knownLatestNotificationId='';
let knownLatestNotificationAt='';
let kombaxHeaderActivity={kombax_pending:0,relation_requests:0,contact_requests:0,message_unread:0};

async function refreshHeaderSummary({announce=true}={}){
  if(!state.session)return 'idle';
  const wasPrimed=notificationPrimed;
  const beforeSignature=`${state.unreadNotificationCount||0}:${state.unreadKombaxCount||0}:${state.unreadMessageCount||0}:${knownLatestNotificationId}:${knownLatestNotificationAt}`;
  try{
    const rows=await repos.notifications.headerSummary();const data=Array.isArray(rows)?(rows[0]||{}):(rows||{});
    const unreadGroups=Number(data.club_unread_groups||0),unreadItems=Number(data.club_unread_items||0);
    kombaxHeaderActivity={kombax_pending:Number(data.kombax_pending||0),relation_requests:Number(data.relation_requests||0),contact_requests:Number(data.contact_requests||0),message_unread:Number(data.message_unread||0)};
    state.unreadNotificationCount=unreadGroups;state.unreadKombaxCount=kombaxHeaderActivity.kombax_pending;state.unreadMessageCount=kombaxHeaderActivity.message_unread;
    setNotificationBadge(unreadGroups);setKombaxNotificationBadge(state.unreadKombaxCount);setMessageBadge(state.unreadMessageCount);
    const latestId=String(data.club_latest_id||''),latestAt=String(data.club_latest_created_at||'');
    if(!notificationPrimed){
      if(announce&&unreadItems)toast(unreadGroups===1?`Tienes ${unreadItems} aviso${unreadItems===1?'':'s'} en 1 grupo pendiente`:`Tienes ${unreadItems} avisos en ${unreadGroups} grupos pendientes`);
    }else if(announce&&latestId&&latestId!==knownLatestNotificationId&&(!knownLatestNotificationAt||latestAt>knownLatestNotificationAt)){
      const title=String(data.club_latest_title||'Nueva notificación');toast(`Nueva notificación: ${title}`);
      if('Notification' in window&&Notification.permission==='granted'&&document.hidden){try{new Notification(title,{body:String(data.club_latest_body||'Tienes una nueva notificación.'),icon:'./assets/icons/icon-192.png'})}catch{}}
    }
    knownLatestNotificationId=latestId;knownLatestNotificationAt=latestAt;notificationPrimed=true;
    const afterSignature=`${state.unreadNotificationCount||0}:${state.unreadKombaxCount||0}:${state.unreadMessageCount||0}:${knownLatestNotificationId}:${knownLatestNotificationAt}`;
    return wasPrimed&&beforeSignature===afterSignature?'idle':true;
  }catch(error){
    if(error?.code==='AUTH_EXPIRED'){state.unreadNotificationCount=0;state.unreadKombaxCount=0;state.unreadMessageCount=0;setNotificationBadge(0);setKombaxNotificationBadge(0);setMessageBadge(0);return true;}
    console.warn('Resumen de actividad:',humanError(error));return false;
  }
}
function openSocialView(view){if(view==='contacts'){try{sessionStorage.setItem('kombax_conversation_channel','social')}catch{};navigate('conversations');return;}try{sessionStorage.setItem('kombax_social_view',view)}catch{};navigate('social');}
function openKombaxActivity(){
  const k=kombaxHeaderActivity;const actionable=Number(k.kombax_pending||0);
  const body=`<div class="kx-header-activity"><section><div class="kx-header-activity-icon">${icon('network',{size:22})}</div><div><small>MI RED KOMBAX</small><strong>${Number(k.relation_requests||0)} solicitud${Number(k.relation_requests||0)===1?'':'es'} pendiente${Number(k.relation_requests||0)===1?'':'s'}</strong><p>Solicitudes privadas que requieren tu decisión.</p></div><button type="button" class="btn btn-ghost btn-sm" data-kx-activity-open="relations">Revisar</button></section><section><div class="kx-header-activity-icon">${icon('message',{size:22})}</div><div><small>SOLICITUDES DE MENSAJERÍA</small><strong>${Number(k.contact_requests||0)} solicitud${Number(k.contact_requests||0)===1?'':'es'} pendiente${Number(k.contact_requests||0)===1?'':'s'}</strong><p>Solicitudes de conversación que todavía esperan aceptación o rechazo. Los mensajes no leídos se consultan desde el icono de Mensajes.</p></div><button type="button" class="btn btn-ghost btn-sm" data-kx-activity-open="contacts">Revisar</button></section>${actionable===0?'<div class="kx-header-activity-empty"><strong>Todo al día</strong><span>No tienes solicitudes KOMBAX pendientes.</span></div>':''}</div>`;
  const {wrap}=openDetail({title:'Notificaciones KOMBAX',subtitle:'Actividad global separada de los avisos de tu Club.',body,width:'640px',className:'kx-header-activity-modal'});
  wrap.querySelectorAll('[data-kx-activity-open]').forEach(button=>button.addEventListener('click',()=>{closeModal();openSocialView(button.dataset.kxActivityOpen)}));
}

async function hydrateSessionAvatar(){
  const path=state.session?.avatar_path;if(!path)return;
  try{
    const url=await repos.settings.avatarUrl(path);
    if(!url)return;
    document.querySelectorAll('[data-session-avatar]').forEach(el=>{const img=el.querySelector('img');if(!img)return;img.src=url;img.hidden=false;img.classList.add('kx-media-frame-img');img.setAttribute('style',mediaFrameStyle(state.session?.avatar_presentation||{},'avatar'));el.classList.add('has-photo');});
  }catch(error){console.warn('Avatar:',humanError(error));}
}

function stopNotificationMonitor(){if(notificationPoller){notificationPoller.stop();notificationPoller=null;}notificationPrimed=false;knownLatestNotificationId='';knownLatestNotificationAt='';}
function startNotificationMonitor(){
  stopNotificationMonitor();
  notificationPoller=createAdaptivePoller(()=>refreshHeaderSummary({announce:true}),{activeMs:15000,hiddenMs:0,maxMs:120000,idleMaxMs:30000,idleAfter:2,jitterRatio:.1});
  notificationPoller.start({immediate:true});
}

async function syncNativePushToken(){
  try{
    if(!state.session||!window.UrbanWarriorsNative?.getPushToken)return;
    const token=String(window.UrbanWarriorsNative.getPushToken()||'').trim();if(!token)return;
    const key=`${state.session.id}:${token}`;if(localStorage.getItem('uw_push_synced_token')===key)return;
    await backend.mutate('push.registrar',{token,plataforma:'android'});localStorage.setItem('uw_push_synced_token',key);
  }catch(error){console.warn('Sincronización push:',error)}
}
window.addEventListener('uw-notifications-changed',()=>refreshHeaderSummary({announce:false}));
window.addEventListener('uw-kombax-activity-changed',()=>refreshHeaderSummary({announce:false}));
window.addEventListener('uw-profile-avatar-changed',()=>hydrateSessionAvatar());
window.addEventListener('uw-native-notification-state',()=>{if(state.route==='profile')navigate('profile',{replace:true});});
let ownerSupportReturnSession=null;
async function exitOwnerSupportMode(){
  const current=state.session;const entitySessionId=current?.support_entity_session_id;
  try{if(entitySessionId)await repos.platformAdmin.supportAudit('support.exit',entitySessionId,{source:'support-workspace'}).catch(()=>null);await repos.platformAdmin.entitySessionEnd().catch(()=>null);}finally{
    state.clearTenantState();state.setCapabilities([]);
    if(ownerSupportReturnSession){state.session=ownerSupportReturnSession;ownerSupportReturnSession=null;}
    await renderPlatformAdminConsole();
  }
}
async function enterOwnerSupportMode({context,data,name}={}){
  if(!context?.entity_session_id||!data?.entity)return;
  ownerSupportReturnSession={...state.session};
  const type=String(context.entidad_tipo||'').toLowerCase();
  if(type==='club'){
    const club=data.entity;
    state.session={...ownerSupportReturnSession,scope:'owner-support',support_mode:true,support_entity_type:'club',support_entity_id:club.id,support_entity_session_id:context.entity_session_id,support_name:name||club.nombre,support_reason:context.motivo||'',club_id:club.id,club,rol:'direccion',roles:['direccion'],coordinacion:false,memberships:[]};
    state.clearTenantState();
    try{await backend.contract(state.session,{force:true});}catch(error){ownerSupportReturnSession=null;state.session=null;throw error;}
    renderShell();toast(`Modo soporte · ${name||club.nombre}`);return;
  }
  state.session={...ownerSupportReturnSession,scope:'owner-support',support_mode:true,support_entity_type:type,support_entity_id:data.entity.id,support_entity_session_id:context.entity_session_id,support_name:name||data.entity.nombre_publico||data.entity.nombre||type,support_reason:context.motivo||''};
  renderDirectProfileHub({onBack:exitOwnerSupportMode});toast(`Modo soporte · ${state.session.support_name}`);
}
window.addEventListener('uw-owner-support-enter',event=>enterOwnerSupportMode(event.detail).catch(setError));

async function navigate(id,{replace=false}={}){
  if(id==='guides'||id==='consulting'){try{sessionStorage.setItem('kx_resource_section',id==='guides'?'knowledge':'consulting')}catch{}id='resources';}
  if(!routes[id])id='dashboard';const allowed=new Set(navFor(state.session).map(x=>x.id));['conversations','support','workspace','resources','guides','consulting','training'].forEach(x=>allowed.add(x));if(['direccion','coordinacion'].includes(state.session?.rol))allowed.add('personal-profile');if(!allowed.has(id))id='dashboard';if(state.route&&state.route!==id)closeModal();state.route=id;
  if(replace)history.replaceState({route:id},'',`#${id}`);else if(location.hash!==`#${id}`)history.pushState({route:id},'',`#${id}`);
  const resourceSection=(()=>{try{return sessionStorage.getItem('kx_resource_section')||'usage'}catch{return 'usage'}})();
  document.querySelectorAll('[data-nav]').forEach(b=>b.classList.toggle('active',b.dataset.nav===id&&(!b.dataset.resourceTarget||b.dataset.resourceTarget===resourceSection)));state.clearError();const alerts=document.getElementById('global-alerts');if(alerts)alerts.innerHTML='';await routes[id]();
}
function openClubSwitcher(){
  const memberships=state.session?.memberships||[],clubs=[...new Map(memberships.filter(x=>x.club?.slug).map(x=>[x.club_id,x.club])).values()];
  if(clubs.length<2)return;
  const {wrap}=openDetail({title:'Cambiar de club',subtitle:'La identidad es la misma; datos, permisos, tema y caché cambian con el contexto.',body:`<div class="club-context-list">${clubs.map(club=>`<button type="button" data-club-context="${esc(club.slug)}" class="club-context-row ${club.id===state.session.club_id?'active':''}"><span>${esc(String(club.nombre||'K').slice(0,2).toUpperCase())}</span><div><strong>${esc(club.nombre)}</strong><small>${esc(club.lema||club.slug)}</small></div>${club.id===state.session.club_id?'<b>ACTUAL</b>':'<b>CAMBIAR</b>'}</button>`).join('')}</div>`});
  wrap.querySelectorAll('[data-club-context]').forEach(button=>button.addEventListener('click',async()=>{if(button.dataset.clubContext===state.session?.club?.slug){closeModal();return;}button.disabled=true;try{stopNotificationMonitor();await backend.switchClub(button.dataset.clubContext);closeModal();renderShell();toast(`Contexto cambiado a ${state.session.club.nombre}`);}catch(error){button.disabled=false;startNotificationMonitor();setError(error);}}));
}
function bindShellNavigation(){
  const shell=document.querySelector('.app-shell'),sidebar=document.getElementById('sidebar'),menuButton=document.getElementById('menu-btn'),scrim=document.getElementById('sidebar-scrim'),clubNav=document.getElementById('club-nav-accordion');
  const productNavs=[...document.querySelectorAll('[data-product-nav]')];
  const setSidebarOpen=open=>{const next=Boolean(open);sidebar?.classList.toggle('open',next);shell?.classList.toggle('sidebar-open',next);menuButton?.setAttribute('aria-expanded',String(next));menuButton?.setAttribute('aria-label',next?'Cerrar menú':'Abrir menú');scrim?.classList.toggle('open',next);};
  document.querySelectorAll('[data-nav]').forEach(b=>b.addEventListener('click',()=>{if(b.dataset.resourceTarget){try{sessionStorage.setItem('kx_resource_section',b.dataset.resourceTarget)}catch{}}navigate(b.dataset.nav);setSidebarOpen(false)}));
  menuButton?.addEventListener('click',()=>setSidebarOpen(!sidebar?.classList.contains('open')));
  document.getElementById('mobile-more')?.addEventListener('click',()=>{if(clubNav)clubNav.open=true;setSidebarOpen(true)});
  clubNav?.addEventListener('toggle',()=>{try{localStorage.setItem('uw2_club_nav_open',clubNav.open?'1':'0')}catch{}});
  productNavs.forEach(nav=>nav.addEventListener('toggle',()=>{try{localStorage.setItem(`uw2_${nav.dataset.productNav}_nav_open`,nav.open?'1':'0')}catch{}}));
  scrim?.addEventListener('click',()=>setSidebarOpen(false));
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&sidebar?.classList.contains('open'))setSidebarOpen(false)},{once:false});
  document.getElementById('logout-btn')?.addEventListener('click',async()=>{stopNotificationMonitor();await backend.signOut();renderLogin();});
  document.getElementById('support-mode-exit')?.addEventListener('click',exitOwnerSupportMode);
  document.getElementById('club-context-button')?.addEventListener('click',openClubSwitcher);
  document.getElementById('kombax-notification-button')?.addEventListener('click',openKombaxActivity);
  document.getElementById('message-button')?.addEventListener('click',()=>openSocialView('contacts'));
}
function renderShell(){
  if(state.session?.preferred_locale)setLocale(state.session.preferred_locale,{persist:true});
  const nav=navFor(state.session),mobile=mobileNavFor(state.session),initial=(location.hash||'#dashboard').slice(1);const allowed=new Set(nav.map(n=>n.id));['workspace','resources','guides','consulting','training'].forEach(x=>allowed.add(x));const route=allowed.has(initial)?initial:'dashboard';setAppHtml(shell(nav,route,mobile));bindDismissAlerts();bindShellNavigation();bindLanguageSelectors(document,{persistAccount:locale=>backend.setPreferredLocale(locale)});hydrateSessionAvatar();startNotificationMonitor();syncNativePushToken();navigate(route,{replace:true});
}

async function openAccountSpace(){
  if(state.session?.support_mode)return;
  stopNotificationMonitor();closeModal();
  try{await openMyAccount({onBack:renderGatewayRoot});if(state.session?.club_id)startNotificationMonitor();}catch(error){setError(error);if(state.session?.club_id)startNotificationMonitor();}
}
window.addEventListener('kx-account-open',openAccountSpace);
window.addEventListener('kx-personal-navigate',()=>stopNotificationMonitor());
async function openClubEntry(club){
  selectClubSlug(club.slug,club);
  if(!state.session?.id){renderClubLogin();return;}
  try{await backend.switchClub(club.slug);renderClubSessionOrLegal();}
  catch(error){
    if(/no pertenece|no está vinculada|no perteneces/i.test(String(error?.message||''))){selectClubSlug(club.slug,club);openInvitationChoice();}else setError(error);
  }
}
window.addEventListener('kx-club-entry',event=>openClubEntry(event.detail).catch(setError));

function renderGatewayRoot(){
  renderKombaxGateway({onAccountAccess:openAccountSpace,onClubDirectory:()=>renderClubDirectory({onBack:renderGatewayRoot,onSelect:club=>openClubEntry(club).catch(setError),onAdminAccess:()=>renderPlatformAdminAccess({onCancel:renderGatewayRoot,onSuccess:renderPlatformAdminConsole})}),onDirectProfiles:()=>renderDirectProfiles({onBack:renderGatewayRoot})});
}

function renderClubSessionOrLegal({startAtHome=false}={}){
  if(startAtHome)history.replaceState(null,'',`${location.pathname}${location.search}#dashboard`);
  if(state.session?.platform_legal_required===true){
    showPlatformLegalGate({onAccepted:renderShell,onExit:()=>renderLogin()});
    return;
  }
  renderShell();
  if(state.session?.birth_date_required===true)setTimeout(()=>promptMissingAccountBirthDate(),240);
}

function renderLogin(prefillEmail=''){
  state.session=null;
  if(platformFeatures().gateway&&!hasExplicitClubSelection()){renderGatewayRoot();return;}
  renderClubLogin(prefillEmail);
}

function renderClubLogin(prefillEmail=''){
  state.session=null;
  const preview=selectedClubPreview()||{};const clubName=preview.nombre||'Tu club',clubSlogan=preview.lema||'Tu comunidad deportiva';const logo=/^(https:\/\/|\.\/|\/)/i.test(String(preview.logo_url||''))?preview.logo_url:KOMBAX_BRAND.symbol;const theme=themeDefinition(preview.theme_id);
  const kombaxMark=`<div class="kombax-cobrand" aria-label="Tecnología ${esc(KOMBAX_BRAND.name)}"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><span><strong>${esc(KOMBAX_BRAND.name)}</strong><small>${esc(KOMBAX_BRAND.tagline)}</small></span></div>`;
  setAppHtml(`<div class="login-shell ${esc(theme.className)}"><section class="login-visual">${kombaxMark}<div class="login-brand"><img src="${esc(logo)}" alt="${esc(clubName)}"><div class="slogan">${esc(clubSlogan)}</div><h1>${esc(clubName.toUpperCase())}</h1><p>${esc(t('auth.login.clubPromise'))}</p></div><div class="login-foot">${esc(clubName)} · ${esc(t('common.app.technology'))}</div></section><section class="login-card-wrap"><form class="login-card" id="login-form">${languageSelectorHtml({id:'kombax-language-login',compact:true})}${kombaxMark}<div class="login-mini-brand"><img src="${esc(logo)}" alt=""><div><strong>${esc(clubName.toUpperCase())}</strong><small>${esc(clubSlogan)}</small></div></div><div class="login-kicker">${esc(t('auth.login.privateAccess'))}</div><h2>${esc(t('auth.login.welcome'))}</h2><p>${esc(t('auth.login.accessAccount',{club:clubName}))}</p><div id="login-error" class="login-error" hidden></div><div class="field login-field"><label for="login-email">${esc(t('auth.login.email'))}</label><div class="login-input-shell">${icon('mail',{size:18})}<input id="login-email" name="email" type="email" autocomplete="username" value="${esc(prefillEmail)}" required></div></div><div class="field login-field login-password-wrap"><label for="login-password">${esc(t('auth.login.password'))}</label><div class="login-input-shell">${icon('key',{size:18})}<input id="login-password" name="password" type="password" autocomplete="current-password" required><button class="login-password-toggle" id="password-toggle" type="button" aria-label="${esc(t('auth.login.showPassword'))}">${icon('eye',{size:18})}</button></div></div><button class="btn btn-primary" id="login-submit" type="submit">${esc(t('auth.login.enter'))} ${icon('chevronRight',{size:17})}</button><button class="login-recovery-link" type="button" id="forgot-password-btn">${esc(t('auth.login.forgotPassword'))}</button><div class="login-link-row"><button class="btn btn-ghost btn-sm" type="button" id="register-btn">${esc(t('auth.login.createAccount'))}</button><button class="btn btn-ghost btn-sm" type="button" id="invite-btn">${esc(t('auth.login.clubCode'))}</button></div>${platformFeatures().gateway?`<button class="club-login-back" type="button" id="back-to-kombax">${icon('chevronLeft',{size:15})} ${esc(t('auth.login.chooseOtherClub'))}</button>`:''}<div class="login-install"><button type="button" id="public-install">${esc(t('auth.login.install',{brand:KOMBAX_BRAND.name}))}</button></div></form></section></div>`);
  const form=document.getElementById('login-form'),btn=document.getElementById('login-submit'),box=document.getElementById('login-error'),password=document.getElementById('login-password'),toggle=document.getElementById('password-toggle');
  bindLanguageSelectors(document);
  toggle?.addEventListener('click',()=>{const visible=password.type==='text';password.type=visible?'password':'text';toggle.setAttribute('aria-label',visible?'Mostrar contraseña':'Ocultar contraseña');toggle.innerHTML=icon(visible?'eye':'eyeOff',{size:18});password.focus();});
  form.addEventListener('submit',async e=>{e.preventDefault();e.stopPropagation();if(!form.reportValidity())return;btn.disabled=true;btn.textContent=t('auth.login.validating');box.hidden=true;try{const fd=new FormData(form);await backend.signIn(fd.get('email'),fd.get('password'));renderClubSessionOrLegal({startAtHome:true});}catch(error){box.hidden=false;box.textContent=humanError(error);btn.disabled=false;btn.innerHTML=`${esc(t('auth.login.enter'))} ${icon('chevronRight',{size:17})}`;}});
  document.getElementById('register-btn')?.addEventListener('click',openRegistrationChoice);document.getElementById('invite-btn')?.addEventListener('click',()=>openInvitationChoice());document.getElementById('public-install')?.addEventListener('click',openPublicInstall);
  document.getElementById('forgot-password-btn')?.addEventListener('click',()=>openPasswordRecovery({prefillEmail:document.getElementById('login-email')?.value||prefillEmail,onComplete:email=>renderClubLogin(email)}));
  document.getElementById('back-to-kombax')?.addEventListener('click',()=>{clearSelectedClub();renderGatewayRoot();});
  const params=new URLSearchParams(location.search);const accessCode=params.get('access_code')||params.get('invite');if(accessCode)setTimeout(()=>openInvitationChoice(accessCode,params.get('access_type')||params.get('invite_type')||'',params.get('team_role')||''),50);
}

function ageYears(value){const d=new Date(`${value}T12:00:00`);if(Number.isNaN(d.getTime()))return null;const now=new Date();let years=now.getFullYear()-d.getFullYear();const before=now.getMonth()<d.getMonth()||(now.getMonth()===d.getMonth()&&now.getDate()<d.getDate());if(before)years--;return years;}
async function publicCatalog(){
  const out=await client.rpc('app_kombax_registro_catalogo_publico_v087',{p_club_slug:selectedClubSlug()});
  if(!out?.available||!out.club?.id)throw new Error('Club no disponible.');
  return {club:out.club,d:Array.isArray(out.d)?out.d:[],g:Array.isArray(out.g)?out.g:[],t:Array.isArray(out.t)?out.t:[],legal:Array.isArray(out.legal)?out.legal:[]};
}
function openRegistrationChoice(){
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:760px"><div class="modal-head"><div><div class="registration-platform-mark"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><span>Tecnología KOMBAX</span></div><h2>Crear cuenta</h2><p>Selecciona cómo vas a utilizar el entorno de tu club.</p></div><button class="icon-btn" id="registration-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:22px"><div class="registration-choice"><button class="choice-card" data-registration="adulto"><strong>Tengo 16 años o más y quiero inscribirme como alumno</strong><small>Crearé mi propia cuenta y solicitaré vincularme al club. La disciplina y el grupo se pueden completar después.</small></button><button class="choice-card" data-registration="tutor"><strong>Soy padre, madre o tutor</strong><small>Crearé mi cuenta y añadiré a un menor.</small></button></div><button class="choice-card" style="width:100%" data-registration="invite"><strong>Formo parte del equipo</strong><small>Usa el código de equipo del club. Tu solicitud quedará pendiente hasta que Gestor o Coordinación valide tu acceso y rol.</small></button><p class="muted" style="font-size:11px;line-height:1.5;margin:18px 0 0">Si eres menor de 16 años no crees una cuenta de alumno independiente: tu alta se gestiona mediante el club o la cuenta de tu padre, madre o tutor.</p></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#registration-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelectorAll('[data-registration]').forEach(b=>b.addEventListener('click',()=>{const type=b.dataset.registration;closeModal();if(type==='invite')openInvitationChoice();else openRegistration(type)}));
}
function showPublicLegal(doc){
  const d=document.createElement('dialog');d.className='legal-dialog';d.innerHTML=`<div class="legal-dialog-head"><div><strong>${esc(({condiciones_uso:'Condiciones de uso',privacidad:'Política de privacidad',comunidad:'Normas de Comunidad del Club',derechos_imagen:'Autorización de imagen'})[doc.tipo]||doc.tipo)}</strong><small>Versión ${esc(doc.version||'')}</small></div><button class="icon-btn" aria-label="Cerrar">${icon('close')}</button></div><div class="legal-dialog-body">${esc(doc.cuerpo||'').replace(/\n/g,'<br>')}</div>`;document.body.appendChild(d);d.querySelector('button').addEventListener('click',()=>{d.close();d.remove()});d.addEventListener('close',()=>d.remove());d.showModal();}
async function openRegistration(type,invite=null){
  try{
    const c=await publicCatalog();const tutor=type==='tutor';const byType=Object.fromEntries((c.legal||[]).map(x=>[x.tipo,x]));
    const modal=openForm({title:tutor?'Cuenta familiar':'Cuenta de alumno',subtitle:'Cuenta → datos básicos → solicitud de vinculación → consentimientos',width:'900px',fields:[
      {name:'email',label:'Email de acceso',type:'email',required:true,value:invite?.email||''},{name:'password',label:'Contraseña',type:'password',required:true},{name:'adulto_nombre',label:tutor?'Nombre del adulto':'Nombre',required:true},{name:'adulto_apellidos',label:tutor?'Apellidos del adulto':'Apellidos',required:true},{name:'adulto_fecha_nacimiento',label:tutor?'Fecha de nacimiento del adulto':'Fecha de nacimiento',type:'date',required:true,help:'Dato privado utilizado para aplicar las reglas de edad de KOMBAX.'},{name:'telefono',label:'Teléfono',help:'Opcional. Puedes completarlo más adelante en tu ficha.'},
      ...(tutor?[{name:'menor_nombre',label:'Nombre del menor',required:true},{name:'menor_apellidos',label:'Apellidos del menor',required:true},{name:'menor_fecha_nacimiento',label:'Nacimiento menor',type:'date',required:true}]:[]),
      {name:'disciplina_id',label:'Disciplina · opcional',type:'select',options:c.d.map(x=>({value:x.id,label:x.nombre})),help:'Puedes crear la cuenta y solicitar la vinculación sin asignar todavía una disciplina.'},{name:'grupo_id',label:'Grupo preferido · opcional',type:'select',options:c.g.map(x=>({value:x.id,label:x.nombre})),help:'Puede asignarse después desde el Club.'},{name:'tarifa_id',label:'Tarifa · opcional',type:'select',options:c.t.map(x=>({value:x.id,label:`${x.nombre} · ${Number(x.importe||0).toFixed(2)} €`}))},
      {name:'terms',label:'He leído y acepto las Condiciones de uso.',type:'checkbox',value:false,required:true,full:true},{name:'privacy',label:'He leído la Política de privacidad.',type:'checkbox',value:false,required:true,full:true},{name:'image_rights',label:tutor?'Autorizo, de forma opcional, el uso de la imagen del menor dentro del club.':'Autorizo, de forma opcional, el uso de mi imagen dentro del club.',type:'checkbox',value:false,full:true}
    ],submitText:'Crear cuenta y enviar solicitud',onSubmit:async v=>{
      if(!v.terms||!v.privacy)throw new Error('Debes aceptar las Condiciones de uso y confirmar que has leído la Política de privacidad.');
      validateBirthDate(v.adulto_fecha_nacimiento,{minAge:tutor?18:16,minimumMessage:tutor?'La cuenta de padre, madre o tutor requiere una persona adulta de 18 años o más.':'El autorregistro como alumno está disponible a partir de los 16 años. Si eres menor de 16, utiliza el alta mediante tutor o contacta con el club.'});
      const legal_acceptances=[{tipo:'condiciones_uso',version:byType.condiciones_uso?.version||'2.0.0',aceptado:true},{tipo:'privacidad',version:byType.privacidad?.version||'2.0.0',aceptado:true},{tipo:'derechos_imagen',version:byType.derechos_imagen?.version||'2.0.0',aceptado:v.image_rights===true}];
      const r=await backend.registerAccount({...v,tipo_cuenta:type,legal_acceptances,invite_code:invite?.code||null,club_slug:invite?.club_slug||selectedClubSlug()});if(r.confirmationRequired){toast('Revisa tu email para confirmar la cuenta');renderLogin(v.email);}else{toast('Cuenta creada');renderClubSessionOrLegal({startAtHome:true});}
    }});
    modal.wrap.querySelector('.modal-head>div')?.insertAdjacentHTML('afterbegin',`<div class="registration-platform-mark"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><span>Tecnología KOMBAX</span></div>`);
    const grid=modal.form.querySelector('.form-grid');const legalBox=document.createElement('div');legalBox.className='registration-legal-links field full';legalBox.innerHTML=`<strong>Lee antes de aceptar</strong><div class="row-actions">${['condiciones_uso','privacidad','comunidad','derechos_imagen'].filter(k=>byType[k]).map(k=>`<button type="button" class="btn btn-ghost btn-sm legal-preview" data-type="${esc(k)}">${esc(({condiciones_uso:'Condiciones de uso',privacidad:'Privacidad',comunidad:'Comunidad del Club',derechos_imagen:'Derechos de imagen'})[k])}</button>`).join('')}</div><small>La autorización de imagen es opcional y puede retirarse posteriormente.</small>`;grid.appendChild(legalBox);legalBox.querySelectorAll('.legal-preview').forEach(b=>b.addEventListener('click',()=>showPublicLegal(byType[b.dataset.type])));
  }catch(e){setError(e)}
}
function openInvitationChoice(prefill='',prefillType='',prefillRole=''){
  const type=String(prefillType||'').toLowerCase();
  if(type==='alumno'||type==='alumnos'||type==='familia')return openStudentAccessCode(prefill);
  if(type==='equipo')return openTeamAccessCode(prefill,prefillRole);
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:720px"><div class="modal-head"><div><h2>Tengo un código del club</h2><p>Introduce el código corto que te ha facilitado el club o que aparece junto a su QR.</p></div><button class="icon-btn" id="invitation-choice-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:22px"><div class="registration-choice"><button class="choice-card" data-access-kind="alumnos"><strong>Alumnos y familias</strong><small>Para solicitar el alta como alumno/a o crear una cuenta de padre, madre o tutor.</small></button><button class="choice-card" data-access-kind="equipo"><strong>Miembros del equipo</strong><small>Para crear tu cuenta y solicitar acceso al equipo del club. El rol se valida después.</small></button></div></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#invitation-choice-close')?.addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelectorAll('[data-access-kind]').forEach(b=>b.addEventListener('click',()=>{const k=b.dataset.accessKind;closeModal();if(k==='alumnos')openStudentAccessCode(prefill);else openTeamAccessCode(prefill,prefillRole);}));
}
function accessClubSlug(){
  const slug=selectedClubSlug();
  if(!slug)throw new Error('Primero abre el QR o selecciona el club al que quieres acceder.');
  return slug;
}
function openBoundStudentActivation(info,code,email){
  const clubName=String(info?.club_nombre||'tu club');
  const memberName=String(info?.nombre||'tu ficha de alumno');
  openForm({title:`Activar ficha · ${clubName}`,subtitle:`${memberName} ya está registrado/a administrativamente en el club. Activa esta misma ficha sin crear otra.`,width:'760px',fields:[
    {name:'modo_cuenta',label:'¿Ya tienes una cuenta KOMBAX?',type:'select',required:true,value:'existente',options:[{value:'existente',label:'Sí, ya tengo cuenta KOMBAX'},{value:'nueva',label:'No, crear mi cuenta KOMBAX'}]},
    {name:'email',label:'Email de acceso',type:'email',required:true,value:email,disabled:true,help:'La invitación solo puede activarse con este correo verificado.'},
    {name:'password',label:'Contraseña',type:'password',required:true,help:'Mínimo 8 caracteres.'},
    {name:'nombre',label:'Nombre (solo cuenta nueva)',value:String(info?.nombre||'')},{name:'apellidos',label:'Apellidos (solo cuenta nueva)'},{name:'fecha_nacimiento',label:'Fecha de nacimiento (solo cuenta nueva)',type:'date',help:'Obligatoria al crear una cuenta nueva. Dato privado.'},
    {name:'terms',label:'He leído y acepto las Condiciones de uso de KOMBAX.',type:'checkbox',value:false,required:true,full:true},
    {name:'privacy',label:'He leído la Política de Privacidad global de KOMBAX.',type:'checkbox',value:false,required:true,full:true}
  ],submitText:'Activar mi ficha',onSubmit:async v=>{
    if(v.modo_cuenta==='nueva'&&String(v.password||'').length<8)throw new Error('La contraseña debe tener al menos 8 caracteres.');
    if(!v.terms||!v.privacy)throw new Error('Debes aceptar las Condiciones de uso y confirmar que has leído la Política de Privacidad.');
    if(v.modo_cuenta==='existente'){
      await backend.signInGlobal(email,v.password);if(state.session?.platform_legal_required===true)await backend.acceptPlatformLegal();
      await backend.acceptStudentMembership(code);toast(`Ficha de ${clubName} activada sin duplicados.`,'ok');
      await backend.signOut();renderClubLogin(email);return;
    }
    if(!String(v.nombre||'').trim())throw new Error('Indica tu nombre para crear la cuenta.');
    const birth=validateBirthDate(v.fecha_nacimiento,{minAge:16,minimumMessage:'La cuenta KOMBAX independiente está disponible a partir de los 16 años. Si eres menor, utiliza el acceso familiar/tutor.'});
    const created=await backend.registerGlobalAccount({email,password:v.password,nombre:v.nombre,apellidos:v.apellidos||'',fecha_nacimiento:birth.value,terms:v.terms,privacy:v.privacy});
    if(created.confirmationRequired){localStorage.setItem('uw2_pending_student_membership',JSON.stringify({code,email,club_id:info?.club_id||null,socio_id:info?.socio_id||null}));toast('Cuenta creada. Confirma tu correo y al entrar KOMBAX activará esta misma ficha del club.');renderGatewayRoot();return;}
    await backend.acceptStudentMembership(code);toast(`Cuenta creada y ficha de ${clubName} activada.`,'ok');
    await backend.signOut();renderClubLogin(email);
  }});
}
function openStudentAccessCode(prefill=''){
  let slug;try{slug=accessClubSlug();}catch(error){toast(humanError(error),'error');return;}
  const rawPrefill=String(prefill||'').trim();const oneTime=/^ALU-[A-Z0-9]{10}$/i.test(rawPrefill);
  openForm({title:oneTime?'Invitación personal de alumno o familia':'Código para alumnos y familias',subtitle:oneTime?'Esta invitación es de un solo uso y está vinculada al correo indicado por el club. KOMBAX comprobará el email antes de crear la cuenta.':'Escribe el código de 4 o 5 dígitos del club. El mismo código puede usarse mientras el club no lo cambie.',width:'720px',fields:[
    {name:'code',label:oneTime?'Código personal de invitación':'Código del club',required:true,value:rawPrefill,placeholder:oneTime?'ALU-XXXXXXXXXX':'12345',inputmode:oneTime?'text':'numeric',disabled:oneTime,help:oneTime?'Código personal · 7 días · un solo uso.':'Código general de alumnos/familias.'},
    ...(oneTime?[{name:'email',label:'Correo electrónico invitado',type:'email',required:true,help:'Debe ser exactamente el correo al que el club envió la invitación.'}]:[]),
    {name:'modo',label:'¿Quién se registra?',type:'select',required:true,value:'adulto',options:[{value:'adulto',label:'Alumno/a de 16 años o más'},{value:'tutor',label:'Padre, madre o tutor de un menor'}]}
  ],submitText:'Continuar',onSubmit:async v=>{
    const code=oneTime?rawPrefill:String(v.code||'').trim();
    if(oneTime&&!/^ALU-[A-Z0-9]{10}$/i.test(code))throw new Error('El código personal de invitación no es válido.');
    if(!oneTime&&!/^\d{4,5}$/.test(code))throw new Error('El código debe tener 4 o 5 dígitos.');
    let club=selectedClubPreview()||{slug,nombre:slug};let email='';
    if(oneTime){email=String(v.email||'').trim().toLowerCase();const info=await backend.validateInvitation(code,email);if(!info?.valid||String(info.tipo||'')!=='alumno')throw new Error('La invitación no es válida para este correo o ha caducado.');slug=String(info.club_slug||slug);club={slug,nombre:info.club_nombre||club.nombre};if(info.vincula_ficha&&info.socio_id){setTimeout(()=>openBoundStudentActivation(info,code,email),220);return;}}
    setTimeout(()=>openRegistration(v.modo,{code,club_slug:slug,club_nombre:club.nombre||slug,email}),220);
  }});
}
function openTeamAccessCode(prefill='',prefillRole=''){
  let slug;try{slug=accessClubSlug();}catch(error){toast(humanError(error),'error');return;}
  const rawPrefill=String(prefill||'').trim();const oneTime=/^EQP-[A-Z0-9]{10}$/i.test(rawPrefill);
  const requested=String(prefillRole||'').trim().toLowerCase();const validRequested=TEAM_INVITE_ROLES.some(x=>x.value===requested)?requested:'';
  const fields=[
    {name:'code',label:oneTime?'Código personal de invitación':'Código de equipo',required:true,value:rawPrefill,placeholder:oneTime?'EQP-XXXXXXXXXX':'54321',disabled:oneTime,help:oneTime?'Código de un solo uso vinculado al correo invitado.':'Código general del equipo.'},
    ...(!oneTime?[{name:'rol',label:'Rol solicitado',type:'select',required:true,value:validRequested||'monitor',options:TEAM_INVITE_ROLES}]:[]),
    {name:'modo',label:'¿Ya tienes una cuenta KOMBAX?',type:'select',required:true,value:'existente',options:[{value:'existente',label:'Sí, ya tengo cuenta'},{value:'nueva',label:'No, crear cuenta ahora'}]},
    {name:'email',label:'Email',type:'email',required:true},{name:'password',label:'Contraseña',type:'password',required:true,help:'Mínimo 8 caracteres.'},
    {name:'nombre',label:'Nombre (solo cuenta nueva)'},{name:'apellidos',label:'Apellidos (solo cuenta nueva)'},{name:'fecha_nacimiento',label:'Fecha de nacimiento (solo cuenta nueva)',type:'date',help:'Obligatoria para crear una cuenta KOMBAX nueva. Dato privado.'},
    {name:'terms',label:'He leído y acepto las Condiciones de uso de KOMBAX.',type:'checkbox',value:false,required:true,full:true},
    {name:'privacy',label:'He leído la Política de Privacidad global de KOMBAX.',type:'checkbox',value:false,required:true,full:true}
  ];
  const teamModal=openForm({
    title:oneTime?'Invitación personal al equipo':validRequested?`Invitación al equipo · ${teamInviteRoleLabel(validRequested)}`:'Código para miembros del equipo',
    subtitle:oneTime?'Esta invitación está vinculada al correo indicado por el club. KOMBAX comprobará que inicias sesión o te registras con ese mismo email antes de activar el acceso.':validRequested?`Esta invitación se ha preparado para solicitar acceso como ${teamInviteRoleLabel(validRequested)}. No concede permisos automáticamente. El club debe revisarla y aprobarla antes de activar el acceso.`:'Introduce el código y el rol para el que te han invitado. No concede permisos automáticamente. El club debe revisarla y aprobarla antes de activar el acceso.',
    width:'760px',fields,submitText:oneTime?'Aceptar invitación':'Enviar solicitud',
    onSubmit:async v=>{
      const code=oneTime?rawPrefill:String(v.code||'').trim();if(oneTime&&!/^EQP-[A-Z0-9]{10}$/i.test(code))throw new Error('El código personal de invitación no es válido.');if(!oneTime&&!/^\d{4,5}$/.test(code))throw new Error('El código debe tener 4 o 5 dígitos.');
      if(v.modo==='nueva'&&String(v.password||'').length<8)throw new Error('La contraseña debe tener al menos 8 caracteres.');
      if(!v.terms||!v.privacy)throw new Error('Debes aceptar las Condiciones de uso y confirmar que has leído la Política de Privacidad de KOMBAX.');
      let role=String(v.rol||validRequested||'').trim().toLowerCase();let inviteInfo=null;
      if(oneTime){inviteInfo=await backend.validateTeamInvitation(code,v.email);if(!inviteInfo?.valid)throw new Error('La invitación no es válida para este correo o ha caducado.');role=String(inviteInfo.rol||'').toLowerCase();slug=String(inviteInfo.club_slug||slug);}
      else if(!TEAM_INVITE_ROLES.some(x=>x.value===role))throw new Error('Selecciona el rol para el que has recibido la invitación.');
      if(v.modo==='existente'){
        await backend.signInGlobal(v.email,v.password);if(state.session?.platform_legal_required===true)await backend.acceptPlatformLegal();
        if(oneTime){await backend.acceptTeamInvitation(code);toast(`Invitación aceptada como ${teamInviteRoleLabel(role)}.`,'ok');}
        else{await backend.requestTeamAccess(slug,code,v.email,role);toast(`Solicitud enviada para ${teamInviteRoleLabel(role)}. El club debe aprobarla.`,'ok');}
        await backend.signOut();renderClubLogin(v.email);return;
      }
      if(!String(v.nombre||'').trim()||!String(v.apellidos||'').trim())throw new Error('Indica nombre y apellidos para crear la cuenta.');
      const birth=validateBirthDate(v.fecha_nacimiento,{minAge:16,minimumMessage:'La cuenta KOMBAX independiente está disponible a partir de los 16 años.'});
      const pendingTeamAccess={kind:oneTime?'one_time':'generic',club_slug:slug,code,email:v.email,role};
      const created=await backend.registerGlobalAccount({email:v.email,password:v.password,nombre:v.nombre,apellidos:v.apellidos,fecha_nacimiento:birth.value,terms:v.terms,privacy:v.privacy,pendingTeamAccess});
      if(created.confirmationRequired){
        toast(oneTime?'Cuenta creada. Confirma tu email y después inicia sesión; KOMBAX completará la invitación personal con ese mismo correo.':'Cuenta creada. Confirma tu email y después inicia sesión; KOMBAX enviará entonces la solicitud al club.');
        renderGatewayRoot();return;
      }
      toast(oneTime?`Cuenta creada e invitación aceptada como ${teamInviteRoleLabel(role)}.`:`Cuenta creada y solicitud enviada para ${teamInviteRoleLabel(role)}.`,'ok');
      await backend.signOut();renderClubLogin(v.email);
    }
  });
  bindAccountModeFields(teamModal.form);
  const grid=teamModal.form.querySelector('.form-grid');const legal=document.createElement('div');legal.className='registration-legal-links field full';legal.innerHTML='<strong>Documentos KOMBAX</strong><div class="row-actions"><a class="btn btn-ghost btn-sm" href="./terms.html" target="_blank" rel="noopener noreferrer">Condiciones KOMBAX</a><a class="btn btn-ghost btn-sm" href="./privacy.html" target="_blank" rel="noopener noreferrer">Privacidad global</a></div>';grid?.appendChild(legal);
}
function openPublicInstall(){
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:680px"><div class="modal-head"><div><h2>Instalar KOMBAX</h2><p>Lleva tu portal de club contigo en el móvil.</p></div><button class="icon-btn" id="modal-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:24px;text-align:center"><img src="./assets/install-qr.png" alt="QR" style="width:240px;max-width:70%;background:#fff;padding:10px;border-radius:18px"><p class="muted">Escanea el QR o instala la PWA desde el navegador.</p><div class="row-actions" style="justify-content:center"><button class="btn btn-primary" id="install-now">Instalar aplicación</button></div></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#modal-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelector('#install-now').addEventListener('click',async()=>{if(window.__uwInstallPrompt){window.__uwInstallPrompt.prompt();await window.__uwInstallPrompt.userChoice;window.__uwInstallPrompt=null;}else toast('Usa el menú del navegador → Instalar aplicación.','error')});
}

let localeRerendering=false;
window.addEventListener('kombax:localechange',()=>{if(localeRerendering||document.getElementById('modal-layer'))return;localeRerendering=true;try{if(state.session?.club_id)renderShell();else if(document.getElementById('login-form'))renderClubLogin(document.getElementById('login-email')?.value||'');}finally{queueMicrotask(()=>{localeRerendering=false;});}});

async function boot(){
  const adminPath=/\/admin\/?$/.test(location.pathname);
  if(adminPath){
    const restored=await backend.restorePlatformAdminAccess().catch(()=>null);
    if(restored)renderPlatformAdminConsole();else renderPlatformAdminAccess({onCancel:()=>{location.href='/';},onSuccess:renderPlatformAdminConsole});
    return;
  }
  const entryParams=new URLSearchParams(location.search);
  const publicEventSlug=String(entryParams.get('event')||'').trim();
  const marketingProfile=String(entryParams.get('profile')||entryParams.get('discover')||'').trim().toLowerCase();
  const marketingProfiles=new Set(['club','marca','federacion','competidor','profesional','media','espectador']);
  if(publicEventSlug){await renderPublicKombaxEventLanding(publicEventSlug,entryParams.get('fight')||null);if('serviceWorker' in navigator&&location.protocol.startsWith('http')&&location.hostname!=='appassets.androidplatform.net')navigator.serviceWorker.register(`./service-worker.js?v=${window.UW_CONFIG.release.build}`).catch(()=>{});return;}
  if(entryParams.get('club')){try{const slug=selectClubSlug(entryParams.get('club'));const matches=await client.rpc('app_buscar_clubes_kombax_v040',{p_query:slug,p_limit:5}).catch(()=>[]),club=(matches||[]).find(x=>x.slug===slug);if(club)selectClubSlug(slug,club);}catch(error){console.warn('Enlace de club no válido:',error)}}
  window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();window.__uwInstallPrompt=e;});
  window.addEventListener('uw-native-push-token',async e=>{try{if(state.session&&e.detail){await backend.mutate('push.registrar',{token:e.detail,plataforma:'android'});localStorage.setItem('uw_push_synced_token',`${state.session.id}:${e.detail}`);}}catch(error){console.warn('Push token:',error)}});
  window.addEventListener('popstate',()=>{if(state.session?.club_id)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('hashchange',()=>{if(state.session?.club_id)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('focus',()=>{if(state.session?.club_id)notificationPoller?.trigger()});
  try{
    const session=await backend.restore();
    const paymentsEntry=String(entryParams.get('payments')||''),connectType=String(entryParams.get('connect_type')||''),connectId=String(entryParams.get('connect_id')||''),paymentEntry=String(entryParams.get('payment')||''),paymentKind=String(entryParams.get('payment_kind')||'');
    const validConnect=['club','showcase_provider','federation','event_organizer'].includes(connectType)&&/^[0-9a-f-]{36}$/i.test(connectId);let connectNotice='',paymentNotice='';
    if(session&&paymentsEntry==='refresh'&&validConnect){
      try{const out=await repos.payments.connectOnboarding(connectType,connectId);if(out?.url){location.replace(out.url);return;}throw new Error('STRIPE_CONNECT_URL_MISSING');}
      catch(error){console.warn('Stripe Connect refresh:',error);connectNotice='No se pudo renovar el enlace de Stripe. Abre de nuevo la activación desde KOMBAX.';}
    }else if(session&&paymentsEntry==='return'&&validConnect){
      try{const status=await repos.payments.connectStatus(connectType,connectId);connectNotice=status?.status==='active'?'Stripe Connect está activo y preparado para cobros.':'Stripe ha guardado la información. La verificación todavía puede estar pendiente.';}
      catch(error){console.warn('Stripe Connect return:',error);connectNotice='Has vuelto de Stripe. Revisa el estado de la cuenta desde KOMBAX.';}
    }
    if(session&&paymentEntry==='success')paymentNotice=paymentKind==='event_ticket'?'Pago recibido. Stripe está confirmando la operación; tus entradas aparecerán en KOMBAX Events → Mis entradas.':paymentKind==='showcase_order'?'Pago recibido. Puedes seguir la preparación y el envío desde KOMBAX Showcase → Mis pedidos.':'Pago recibido. La confirmación se actualizará automáticamente.';
    else if(session&&paymentEntry==='cancelled')paymentNotice='Pago cancelado. No se ha confirmado la operación.';
    const marketingIdentity=marketingProfiles.has(marketingProfile)?marketingProfile:'';
    const hasTransactionalEntry=Boolean(paymentsEntry||paymentEntry||validConnect);
    if(marketingIdentity&&!hasTransactionalEntry&&(!session||session?.scope==='kombax')){
      renderIdentityPresentation(marketingIdentity,{onBack:session?.scope==='kombax'?()=>renderDirectProfileHub({onBack:renderGatewayRoot}):renderGatewayRoot});
    }else if(session?.scope==='kombax'){if(hasTransactionalEntry)renderGlobalHome({onBack:renderGatewayRoot});else {const pendingType=sessionStorage.getItem('kombax_pending_profile_type')||'';if(pendingType)renderDirectProfileHub({onBack:renderGatewayRoot,pendingType});else renderGlobalHome({onBack:renderGatewayRoot});}}else if(session)renderClubSessionOrLegal({startAtHome:false});else renderLogin();
    if(connectNotice||paymentNotice){history.replaceState({},'',`${location.pathname}${location.hash||''}`);setTimeout(()=>toast(connectNotice||paymentNotice,paymentEntry==='cancelled'?'error':'ok'),80);}
  }catch(e){console.error(e);renderLogin();if(e?.code==='AUTH_EXPIRED')toast(humanError(e),'error');}
  if('serviceWorker' in navigator&&location.protocol.startsWith('http')&&location.hostname!=='appassets.androidplatform.net')navigator.serviceWorker.register(`./service-worker.js?v=${window.UW_CONFIG.release.build}`).catch(e=>console.warn('Service worker:',e));
}
boot();
