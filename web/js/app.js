import { backend, client } from './core/backend.js';
import { state } from './core/state.js';
import { repos } from './core/repositories.js';
import { humanError, esc } from './core/utils.js';
import { createAdaptivePoller } from './core/adaptive-poller.js';
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
import { renderKombaxGateway, renderClubDirectory, renderDirectProfiles, renderDirectProfileHub } from './modules/gateway.js';
import { renderKombaxSocial } from './modules/kombax-social.js';
import { renderShowcase } from './modules/showcase.js';
import { renderClubKombaxHub } from './modules/club-kombax-hub.js';
import { renderPlatformAdmin } from './modules/platform-admin.js';
import { renderPlatformAdminAccess, renderPlatformAdminConsole } from './modules/platform-admin-access.js';
import { renderWorkScopes } from './modules/work-scopes.js';
import { openPasswordRecovery } from './modules/auth-recovery.js';
import { TEAM_INVITE_ROLES, teamInviteRoleLabel } from './core/invitations.js';

const isPortal=()=>['familia','alumno'].includes(state.session?.rol);
const routes={
  dashboard:()=>isPortal()?renderPortalDashboard():renderDashboard(),catalog:renderCatalog,groups:()=>isPortal()?renderPortalSchedule():renderGroups(),members:renderMembers,enrollments:renderEnrollments,
  sessions:renderSessions,attendance:renderAttendance,progress:renderProgress,finance:renderFinance,reminders:renderReminders,communications:renderCommunications,
  tracking:renderTracking,material:renderMaterial,documents:renderDocuments,notifications:renderNotifications,users:renderUsers,settings:renderSettings,requests:renderPortalRequests,install:renderInstall,profile:()=>isPortal()?renderPortalProfile():(['direccion','coordinacion'].includes(state.session?.rol)?renderClubKombaxHub():renderProfile), 'personal-profile':renderProfile,'platform-admin':renderPlatformAdmin,scopes:renderWorkScopes,community:renderCommunity,social:renderKombaxSocial,showcase:renderShowcase,events:renderEvents,archive:renderLifecycle,help:renderHelpLegal
};
const LABEL={dashboard:'Inicio',catalog:'Disciplinas y grados',groups:'Grupos',members:'Alumnos',enrollments:'Solicitudes',sessions:'Sesiones',attendance:'Asistencia',progress:'Progreso',finance:'Finanzas',reminders:'Avisos de cobro',communications:'Comunicaciones',tracking:'Seguimiento',material:'Material',documents:'Archivo documental',notifications:'Notificaciones del Club',users:'Equipo',settings:'Configuración',profile:'Mi perfil',requests:'Solicitudes',install:'Instalar app',community:'Comunidad del Club',social:'KOMBAX Social',showcase:'KOMBAX Showcase','platform-admin':'Administración KOMBAX','personal-profile':'Mi perfil',scopes:'Ámbitos y privacidad',events:'Eventos',archive:'Archivo y papelera',help:'Manual interactivo'};

function navFor(session){
  const role=session?.rol;let ids;
  if(role==='direccion'||role==='coordinacion') ids=['dashboard','members','enrollments','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','events','material','documents','archive','notifications','users','scopes','settings','help','install','profile'];
  else if(role==='secretaria') ids=['dashboard','enrollments','members','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','events','material','documents','archive','notifications','users','settings','help','install','profile'];
  else if(role==='economia') ids=['dashboard','finance','reminders','community','events','material','notifications','settings','help','install','profile'];
  else if(role==='comunicacion') ids=['dashboard','communications','community','events','notifications','settings','help','install','profile'];
  else if(role==='monitor') ids=['dashboard','members','groups','sessions','attendance','tracking','progress','finance','community','events','notifications','help','install','profile'];
  else ids=['dashboard','groups','finance','communications','community','events','material','notifications','requests','help','install','profile'];
  if(platformFeatures().social){const communityIndex=ids.indexOf('community');ids.splice(communityIndex>=0?communityIndex+1:ids.length,0,'social');}
  if(platformFeatures().showcase){const socialIndex=ids.indexOf('social');ids.splice(socialIndex>=0?socialIndex+1:ids.length,0,'showcase');}
  if(role==='direccion'||role==='coordinacion')ids.unshift('personal-profile');
  return [...new Set(ids)].map(id=>({id,label:role==='monitor'&&id==='dashboard'?'Hoy':role==='monitor'&&id==='members'?'Mis alumnos':role==='monitor'&&id==='groups'?'Mis grupos':role==='monitor'&&id==='finance'?'Mi cartera':role==='alumno'&&id==='help'?'Mi manual':isPortal()&&id==='groups'?'Horarios':isPortal()&&id==='finance'?'Cuotas':(role==='direccion'||role==='coordinacion')&&id==='profile'?'Perfil del club':LABEL[id],icon:navIcon(id)}));
}
function mobileNavFor(session){
  const profileId=['direccion','coordinacion'].includes(session?.rol)?'personal-profile':'profile';
  const ids=[profileId];
  if(platformFeatures().social)ids.push('social');
  if(platformFeatures().showcase)ids.push('showcase');
  ids.push('more');
  const map={more:{id:'more',label:'Mi Club',icon:navIcon('community')}};
  return ids.map(id=>map[id]||{id,label:LABEL[id],icon:navIcon(id)});
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
function openSocialView(view){try{sessionStorage.setItem('kombax_social_view',view)}catch{};navigate('social');}
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
    document.querySelectorAll('[data-session-avatar]').forEach(el=>{const img=el.querySelector('img');if(!img)return;img.src=url;img.hidden=false;el.classList.add('has-photo');});
  }catch(error){console.warn('Avatar:',humanError(error));}
}

function stopNotificationMonitor(){if(notificationPoller){notificationPoller.stop();notificationPoller=null;}notificationPrimed=false;knownLatestNotificationId='';knownLatestNotificationAt='';}
function startNotificationMonitor(){
  stopNotificationMonitor();
  notificationPoller=createAdaptivePoller(()=>refreshHeaderSummary({announce:true}),{activeMs:45000,hiddenMs:0,maxMs:600000,idleMaxMs:300000,idleAfter:2,jitterRatio:.2});
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

async function navigate(id,{replace=false}={}){
  if(!routes[id])id='dashboard';const allowed=new Set(navFor(state.session).map(x=>x.id));if(['direccion','coordinacion'].includes(state.session?.rol))allowed.add('personal-profile');if(!allowed.has(id))id='dashboard';state.route=id;
  if(replace)history.replaceState({route:id},'',`#${id}`);else if(location.hash!==`#${id}`)history.pushState({route:id},'',`#${id}`);
  document.querySelectorAll('[data-nav]').forEach(b=>b.classList.toggle('active',b.dataset.nav===id));state.clearError();const alerts=document.getElementById('global-alerts');if(alerts)alerts.innerHTML='';await routes[id]();
}
function openClubSwitcher(){
  const memberships=state.session?.memberships||[],clubs=[...new Map(memberships.filter(x=>x.club?.slug).map(x=>[x.club_id,x.club])).values()];
  if(clubs.length<2)return;
  const {wrap}=openDetail({title:'Cambiar de club',subtitle:'La identidad es la misma; datos, permisos, tema y caché cambian con el contexto.',body:`<div class="club-context-list">${clubs.map(club=>`<button type="button" data-club-context="${esc(club.slug)}" class="club-context-row ${club.id===state.session.club_id?'active':''}"><span>${esc(String(club.nombre||'K').slice(0,2).toUpperCase())}</span><div><strong>${esc(club.nombre)}</strong><small>${esc(club.lema||club.slug)}</small></div>${club.id===state.session.club_id?'<b>ACTUAL</b>':'<b>CAMBIAR</b>'}</button>`).join('')}</div>`});
  wrap.querySelectorAll('[data-club-context]').forEach(button=>button.addEventListener('click',async()=>{if(button.dataset.clubContext===state.session?.club?.slug){closeModal();return;}button.disabled=true;try{stopNotificationMonitor();await backend.switchClub(button.dataset.clubContext);closeModal();renderShell();toast(`Contexto cambiado a ${state.session.club.nombre}`);}catch(error){button.disabled=false;startNotificationMonitor();setError(error);}}));
}
function bindShellNavigation(){
  const shell=document.querySelector('.app-shell'),sidebar=document.getElementById('sidebar'),menuButton=document.getElementById('menu-btn'),scrim=document.getElementById('sidebar-scrim'),clubNav=document.getElementById('club-nav-accordion');
  const setSidebarOpen=open=>{const next=Boolean(open);sidebar?.classList.toggle('open',next);shell?.classList.toggle('sidebar-open',next);menuButton?.setAttribute('aria-expanded',String(next));menuButton?.setAttribute('aria-label',next?'Cerrar menú':'Abrir menú');scrim?.classList.toggle('open',next);};
  document.querySelectorAll('[data-nav]').forEach(b=>b.addEventListener('click',()=>{navigate(b.dataset.nav);setSidebarOpen(false)}));
  menuButton?.addEventListener('click',()=>setSidebarOpen(!sidebar?.classList.contains('open')));
  document.getElementById('mobile-more')?.addEventListener('click',()=>{if(clubNav)clubNav.open=true;setSidebarOpen(true)});
  clubNav?.addEventListener('toggle',()=>{try{localStorage.setItem('uw2_club_nav_open',clubNav.open?'1':'0')}catch{}});
  scrim?.addEventListener('click',()=>setSidebarOpen(false));
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&sidebar?.classList.contains('open'))setSidebarOpen(false)},{once:false});
  document.getElementById('logout-btn')?.addEventListener('click',async()=>{stopNotificationMonitor();await backend.signOut();renderLogin();});
  document.getElementById('club-context-button')?.addEventListener('click',openClubSwitcher);
  document.getElementById('kombax-notification-button')?.addEventListener('click',openKombaxActivity);
  document.getElementById('message-button')?.addEventListener('click',()=>openSocialView('contacts'));
}
function renderShell(){
  const nav=navFor(state.session),mobile=mobileNavFor(state.session),initial=(location.hash||'#dashboard').slice(1);const allowed=new Set(nav.map(n=>n.id));const route=allowed.has(initial)?initial:'dashboard';setAppHtml(shell(nav,route,mobile));bindDismissAlerts();bindShellNavigation();hydrateSessionAvatar();startNotificationMonitor();syncNativePushToken();navigate(route,{replace:true});
}

function renderGatewayRoot(){
  renderKombaxGateway({onClubDirectory:()=>renderClubDirectory({onBack:renderGatewayRoot,onSelect:club=>{selectClubSlug(club.slug,club);renderClubLogin();},onAdminAccess:()=>renderPlatformAdminAccess({onCancel:renderGatewayRoot,onSuccess:renderPlatformAdminConsole})}),onDirectProfiles:()=>renderDirectProfiles({onBack:renderGatewayRoot})});
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
  setAppHtml(`<div class="login-shell ${esc(theme.className)}"><section class="login-visual">${kombaxMark}<div class="login-brand"><img src="${esc(logo)}" alt="${esc(clubName)}"><div class="slogan">${esc(clubSlogan)}</div><h1>${esc(clubName.toUpperCase())}</h1><p>Tu club, tus clases y tu evolución. Gestión profesional para equipo, alumnado y familias.</p></div><div class="login-foot">${esc(clubName)} · tecnología ${esc(KOMBAX_BRAND.name)}</div></section><section class="login-card-wrap"><form class="login-card" id="login-form">${kombaxMark}<div class="login-mini-brand"><img src="${esc(logo)}" alt=""><div><strong>${esc(clubName.toUpperCase())}</strong><small>${esc(clubSlogan)}</small></div></div><div class="login-kicker">ACCESO PRIVADO DEL CLUB</div><h2>Bienvenido/a</h2><p>Accede a tu cuenta de ${esc(clubName)}.</p><div id="login-error" class="login-error" hidden></div><div class="field login-field"><label for="login-email">Email</label><div class="login-input-shell">${icon('mail',{size:18})}<input id="login-email" name="email" type="email" autocomplete="username" value="${esc(prefillEmail)}" required></div></div><div class="field login-field login-password-wrap"><label for="login-password">Contraseña</label><div class="login-input-shell">${icon('key',{size:18})}<input id="login-password" name="password" type="password" autocomplete="current-password" required><button class="login-password-toggle" id="password-toggle" type="button" aria-label="Mostrar contraseña">${icon('eye',{size:18})}</button></div></div><button class="btn btn-primary" id="login-submit" type="submit">Entrar ${icon('chevronRight',{size:17})}</button><button class="login-recovery-link" type="button" id="forgot-password-btn">¿Has olvidado tu contraseña?</button><div class="login-link-row"><button class="btn btn-ghost btn-sm" type="button" id="register-btn">Crear cuenta</button><button class="btn btn-ghost btn-sm" type="button" id="invite-btn">Tengo código del club</button></div>${platformFeatures().gateway?`<button class="club-login-back" type="button" id="back-to-kombax">${icon('chevronLeft',{size:15})} Elegir otro club</button>`:''}<div class="login-install"><button type="button" id="public-install">Instalar ${esc(KOMBAX_BRAND.name)}</button></div></form></section></div>`);
  const form=document.getElementById('login-form'),btn=document.getElementById('login-submit'),box=document.getElementById('login-error'),password=document.getElementById('login-password'),toggle=document.getElementById('password-toggle');
  toggle?.addEventListener('click',()=>{const visible=password.type==='text';password.type=visible?'password':'text';toggle.setAttribute('aria-label',visible?'Mostrar contraseña':'Ocultar contraseña');toggle.innerHTML=icon(visible?'eye':'eyeOff',{size:18});password.focus();});
  form.addEventListener('submit',async e=>{e.preventDefault();e.stopPropagation();if(!form.reportValidity())return;btn.disabled=true;btn.textContent='Validando…';box.hidden=true;try{const fd=new FormData(form);await backend.signIn(fd.get('email'),fd.get('password'));renderShell();}catch(error){box.hidden=false;box.textContent=humanError(error);btn.disabled=false;btn.innerHTML=`Entrar ${icon('chevronRight',{size:17})}`;}});
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
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:760px"><div class="modal-head"><div><div class="registration-platform-mark"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><span>Tecnología KOMBAX</span></div><h2>Crear cuenta</h2><p>Selecciona cómo vas a utilizar el entorno de tu club.</p></div><button class="icon-btn" id="registration-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:22px"><div class="registration-choice"><button class="choice-card" data-registration="adulto"><strong>Tengo 16 años o más y quiero inscribirme como alumno</strong><small>Crearé mi propia cuenta y enviaré mi solicitud deportiva al club.</small></button><button class="choice-card" data-registration="tutor"><strong>Soy padre, madre o tutor</strong><small>Crearé mi cuenta y añadiré a un menor.</small></button></div><button class="choice-card" style="width:100%" data-registration="invite"><strong>Formo parte del equipo</strong><small>Usa el código de equipo del club. Tu solicitud quedará pendiente hasta que Gestor o Coordinación valide tu acceso y rol.</small></button><p class="muted" style="font-size:11px;line-height:1.5;margin:18px 0 0">Si eres menor de 16 años no crees una cuenta de alumno independiente: tu alta se gestiona mediante el club o la cuenta de tu padre, madre o tutor.</p></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#registration-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelectorAll('[data-registration]').forEach(b=>b.addEventListener('click',()=>{const type=b.dataset.registration;closeModal();if(type==='invite')openInvitationChoice();else openRegistration(type)}));
}
function showPublicLegal(doc){
  const d=document.createElement('dialog');d.className='legal-dialog';d.innerHTML=`<div class="legal-dialog-head"><div><strong>${esc(({condiciones_uso:'Condiciones de uso',privacidad:'Política de privacidad',comunidad:'Normas de Comunidad del Club',derechos_imagen:'Autorización de imagen'})[doc.tipo]||doc.tipo)}</strong><small>Versión ${esc(doc.version||'')}</small></div><button class="icon-btn" aria-label="Cerrar">${icon('close')}</button></div><div class="legal-dialog-body">${esc(doc.cuerpo||'').replace(/\n/g,'<br>')}</div>`;document.body.appendChild(d);d.querySelector('button').addEventListener('click',()=>{d.close();d.remove()});d.addEventListener('close',()=>d.remove());d.showModal();}
async function openRegistration(type,invite=null){
  try{
    const c=await publicCatalog();const tutor=type==='tutor';const byType=Object.fromEntries((c.legal||[]).map(x=>[x.tipo,x]));
    const modal=openForm({title:tutor?'Cuenta familiar':'Cuenta de alumno',subtitle:'Cuenta → datos → solicitud deportiva → consentimientos',width:'900px',fields:[
      {name:'email',label:'Email de acceso',type:'email',required:true,value:invite?.email||''},{name:'password',label:'Contraseña',type:'password',required:true},{name:'adulto_nombre',label:tutor?'Nombre del adulto':'Nombre',required:true},{name:'adulto_apellidos',label:tutor?'Apellidos del adulto':'Apellidos',required:true},{name:'adulto_fecha_nacimiento',label:tutor?'Nacimiento adulto (opcional)':'Fecha de nacimiento',type:'date',required:!tutor},{name:'telefono',label:'Teléfono',required:true},
      ...(tutor?[{name:'menor_nombre',label:'Nombre del menor',required:true},{name:'menor_apellidos',label:'Apellidos del menor',required:true},{name:'menor_fecha_nacimiento',label:'Nacimiento menor',type:'date',required:true}]:[]),
      {name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:c.d.map(x=>({value:x.id,label:x.nombre}))},{name:'grupo_id',label:'Grupo preferido',type:'select',options:c.g.map(x=>({value:x.id,label:x.nombre}))},{name:'tarifa_id',label:'Tarifa',type:'select',options:c.t.map(x=>({value:x.id,label:`${x.nombre} · ${Number(x.importe||0).toFixed(2)} €`}))},
      {name:'terms',label:'He leído y acepto las Condiciones de uso.',type:'checkbox',value:false,required:true,full:true},{name:'privacy',label:'He leído la Política de privacidad.',type:'checkbox',value:false,required:true,full:true},{name:'image_rights',label:tutor?'Autorizo, de forma opcional, el uso de la imagen del menor dentro del club.':'Autorizo, de forma opcional, el uso de mi imagen dentro del club.',type:'checkbox',value:false,full:true}
    ],submitText:'Crear cuenta y enviar solicitud',onSubmit:async v=>{
      if(!v.terms||!v.privacy)throw new Error('Debes aceptar las Condiciones de uso y confirmar que has leído la Política de privacidad.');
      if(!tutor){const years=ageYears(v.adulto_fecha_nacimiento);if(years==null)throw new Error('Indica una fecha de nacimiento válida.');if(years<16)throw new Error('El autorregistro como alumno está disponible a partir de los 16 años. Si eres menor, utiliza el alta mediante tutor o contacta con el club.');}
      const legal_acceptances=[{tipo:'condiciones_uso',version:byType.condiciones_uso?.version||'2.0.0',aceptado:true},{tipo:'privacidad',version:byType.privacidad?.version||'2.0.0',aceptado:true},{tipo:'derechos_imagen',version:byType.derechos_imagen?.version||'2.0.0',aceptado:v.image_rights===true}];
      const r=await backend.registerAccount({...v,tipo_cuenta:type,legal_acceptances,invite_code:invite?.code||null,club_slug:invite?.club_slug||selectedClubSlug()});if(r.confirmationRequired){toast('Revisa tu email para confirmar la cuenta');renderLogin(v.email);}else{toast('Cuenta creada');renderShell();}
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
function openStudentAccessCode(prefill=''){
  let slug;try{slug=accessClubSlug();}catch(error){toast(humanError(error),'error');return;}
  openForm({title:'Código para alumnos y familias',subtitle:'Escribe el código de 4 o 5 dígitos del club. El mismo código puede usarse mientras el club no lo cambie.',width:'720px',fields:[{name:'code',label:'Código del club',required:true,value:prefill,placeholder:'12345',inputmode:'numeric'},{name:'modo',label:'¿Quién se registra?',type:'select',required:true,value:'adulto',options:[{value:'adulto',label:'Alumno/a de 16 años o más'},{value:'tutor',label:'Padre, madre o tutor de un menor'}]}],submitText:'Continuar',onSubmit:async v=>{
    const code=String(v.code||'').trim();if(!/^\d{4,5}$/.test(code))throw new Error('El código debe tener 4 o 5 dígitos.');
    const club=selectedClubPreview()||{slug,nombre:slug};
    setTimeout(()=>openRegistration(v.modo,{code,club_slug:slug,club_nombre:club.nombre||slug}),220);
  }});
}
function openTeamAccessCode(prefill='',prefillRole=''){
  let slug;try{slug=accessClubSlug();}catch(error){toast(humanError(error),'error');return;}
  const requested=String(prefillRole||'').trim().toLowerCase();const validRequested=TEAM_INVITE_ROLES.some(x=>x.value===requested)?requested:'';
  openForm({title:validRequested?`Invitación al equipo · ${teamInviteRoleLabel(validRequested)}`:'Código para miembros del equipo',subtitle:validRequested?`Esta invitación se ha preparado para solicitar acceso como ${teamInviteRoleLabel(validRequested)}. No concede permisos automáticamente. El club debe revisarla y aprobarla antes de activar el acceso.`:'Introduce el código y el rol para el que te han invitado. No concede permisos automáticamente. El club debe revisarla y aprobarla antes de activar el acceso.',width:'760px',fields:[{name:'code',label:'Código de equipo',required:true,value:prefill,placeholder:'54321',inputmode:'numeric'},{name:'rol',label:'Rol solicitado',type:'select',required:true,value:validRequested||'monitor',options:TEAM_INVITE_ROLES},{name:'modo',label:'¿Ya tienes una cuenta KOMBAX?',type:'select',required:true,value:'existente',options:[{value:'existente',label:'Sí, ya tengo cuenta'},{value:'nueva',label:'No, crear cuenta ahora'}]},{name:'email',label:'Email',type:'email',required:true},{name:'password',label:'Contraseña',type:'password',required:true},{name:'nombre',label:'Nombre (solo cuenta nueva)'},{name:'apellidos',label:'Apellidos (solo cuenta nueva)'}],submitText:'Enviar solicitud',onSubmit:async v=>{
    const code=String(v.code||'').trim();if(!/^\d{4,5}$/.test(code))throw new Error('El código debe tener 4 o 5 dígitos.');
    const role=String(v.rol||'').trim().toLowerCase();if(!TEAM_INVITE_ROLES.some(x=>x.value===role))throw new Error('Selecciona el rol para el que has recibido la invitación.');
    if(String(v.password||'').length<6)throw new Error('La contraseña debe tener al menos 6 caracteres.');
    if(v.modo==='existente'){
      await backend.signInGlobal(v.email,v.password);await backend.requestTeamAccess(slug,code,v.email,role);
      toast(`Solicitud enviada para ${teamInviteRoleLabel(role)}. El club debe aprobarla.`,'ok');await backend.signOut();renderClubLogin(v.email);return;
    }
    if(!String(v.nombre||'').trim()||!String(v.apellidos||'').trim())throw new Error('Indica nombre y apellidos para crear la cuenta.');
    const created=await backend.registerGlobalAccount({email:v.email,password:v.password,nombre:v.nombre,apellidos:v.apellidos});
    if(created.confirmationRequired){localStorage.setItem('uw2_pending_team_access',JSON.stringify({club_slug:slug,code,email:v.email,role}));toast('Cuenta creada. Confirma tu email y después accede a KOMBAX; la solicitud quedará registrada.');renderGatewayRoot();return;}
    await backend.requestTeamAccess(slug,code,v.email,role);toast(`Cuenta creada y solicitud enviada para ${teamInviteRoleLabel(role)}.`,'ok');await backend.signOut();renderClubLogin(v.email);
  }});
}
function openPublicInstall(){
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:680px"><div class="modal-head"><div><h2>Instalar KOMBAX</h2><p>Lleva tu portal de club contigo en el móvil.</p></div><button class="icon-btn" id="modal-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:24px;text-align:center"><img src="./assets/install-qr.png" alt="QR" style="width:240px;max-width:70%;background:#fff;padding:10px;border-radius:18px"><p class="muted">Escanea el QR o instala la PWA desde el navegador.</p><div class="row-actions" style="justify-content:center"><button class="btn btn-primary" id="install-now">Instalar aplicación</button></div></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#modal-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelector('#install-now').addEventListener('click',async()=>{if(window.__uwInstallPrompt){window.__uwInstallPrompt.prompt();await window.__uwInstallPrompt.userChoice;window.__uwInstallPrompt=null;}else toast('Usa el menú del navegador → Instalar aplicación.','error')});
}

async function boot(){
  const adminPath=/\/admin\/?$/.test(location.pathname);
  if(adminPath){
    const restored=await backend.restorePlatformAdminAccess().catch(()=>null);
    if(restored)renderPlatformAdminConsole();else renderPlatformAdminAccess({onCancel:()=>{location.href='/';},onSuccess:renderPlatformAdminConsole});
    return;
  }
  const entryParams=new URLSearchParams(location.search);if(entryParams.get('club')){try{const slug=selectClubSlug(entryParams.get('club'));const matches=await client.rpc('app_buscar_clubes_kombax_v040',{p_query:slug,p_limit:5}).catch(()=>[]),club=(matches||[]).find(x=>x.slug===slug);if(club)selectClubSlug(slug,club);}catch(error){console.warn('Enlace de club no válido:',error)}}
  window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();window.__uwInstallPrompt=e;});
  window.addEventListener('uw-native-push-token',async e=>{try{if(state.session&&e.detail){await backend.mutate('push.registrar',{token:e.detail,plataforma:'android'});localStorage.setItem('uw_push_synced_token',`${state.session.id}:${e.detail}`);}}catch(error){console.warn('Push token:',error)}});
  window.addEventListener('popstate',()=>{if(state.session?.club_id)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('hashchange',()=>{if(state.session?.club_id)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('focus',()=>{if(state.session?.club_id)notificationPoller?.trigger()});
  try{const session=await backend.restore();if(session?.scope==='kombax')renderDirectProfileHub({onBack:renderGatewayRoot});else if(session)renderShell();else renderLogin();}catch(e){console.error(e);renderLogin();if(e?.code==='AUTH_EXPIRED')toast(humanError(e),'error');}
  if('serviceWorker' in navigator&&location.protocol.startsWith('http')&&location.hostname!=='appassets.androidplatform.net')navigator.serviceWorker.register(`./service-worker.js?v=${window.UW_CONFIG.release.build}`).catch(e=>console.warn('Service worker:',e));
}
boot();
