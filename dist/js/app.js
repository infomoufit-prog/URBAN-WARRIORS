import { backend, client } from './core/backend.js';
import { state } from './core/state.js';
import { repos } from './core/repositories.js';
import { humanError, esc } from './core/utils.js';
import { shell, setAppHtml, bindDismissAlerts, setError, openForm, openDetail, closeModal, toast, setNotificationBadge } from './ui/components.js';
import { navIcon, icon } from './ui/icons.js';
import { renderDashboard, renderCatalog } from './modules/dashboard-catalog.js';
import { renderGroups, renderMembers, renderEnrollments } from './modules/groups-members.js';
import { renderSessions, renderAttendance, renderTracking, renderProgress } from './modules/training.js';
import { renderFinance, renderReminders } from './modules/finance.js';
import { renderCommunications, renderMaterial, renderNotifications } from './modules/comms-material.js';
import { renderUsers, renderSettings, renderProfile, renderDiagnostics, renderCertification, renderInstall } from './modules/admin.js';
import { renderPortalDashboard, renderPortalSchedule, renderPortalRequests, renderPortalProfile } from './modules/portal.js';
import { renderDocuments } from './modules/documents.js';
import { renderCommunity } from './modules/community.js';
import { renderHelpLegal } from './modules/help-legal.js';

const isPortal=()=>['familia','alumno'].includes(state.session?.rol);
const routes={
  dashboard:()=>isPortal()?renderPortalDashboard():renderDashboard(),catalog:renderCatalog,groups:()=>isPortal()?renderPortalSchedule():renderGroups(),members:renderMembers,enrollments:renderEnrollments,
  sessions:renderSessions,attendance:renderAttendance,progress:renderProgress,finance:renderFinance,reminders:renderReminders,communications:renderCommunications,
  tracking:renderTracking,material:renderMaterial,documents:renderDocuments,notifications:renderNotifications,users:renderUsers,settings:renderSettings,diagnostics:renderDiagnostics,
  certification:renderCertification,requests:renderPortalRequests,install:renderInstall,profile:()=>isPortal()?renderPortalProfile():renderProfile,community:renderCommunity,help:renderHelpLegal
};
const LABEL={dashboard:'Inicio',catalog:'Disciplinas y grados',groups:'Grupos',members:'Alumnos',enrollments:'Solicitudes',sessions:'Sesiones',attendance:'Asistencia',progress:'Progreso',finance:'Finanzas',reminders:'Avisos de cobro',communications:'Comunicaciones',tracking:'Seguimiento',material:'Material',documents:'Archivo documental',notifications:'Notificaciones',users:'Equipo',settings:'Configuración',diagnostics:'Diagnóstico',certification:'Certificación E2E',profile:'Mi perfil',requests:'Solicitudes',install:'Instalar app',community:'Comunidad',help:'Manual y ayuda'};

function navFor(session){
  const role=session?.rol;let ids;
  if(role==='direccion'||role==='coordinacion') ids=['dashboard','members','enrollments','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','material','documents','notifications','users','settings','help','install','profile'];
  else if(role==='secretaria') ids=['dashboard','enrollments','members','catalog','groups','sessions','attendance','progress','tracking','finance','reminders','communications','community','material','documents','notifications','users','settings','help','install','profile'];
  else if(role==='economia') ids=['dashboard','finance','reminders','community','material','notifications','settings','help','install','profile'];
  else if(role==='comunicacion') ids=['dashboard','communications','community','notifications','settings','help','install','profile'];
  else if(role==='monitor') ids=['dashboard','groups','sessions','attendance','tracking','progress','community','notifications','help','install','profile'];
  else ids=['dashboard','groups','finance','communications','community','material','notifications','requests','help','install','profile'];
  return [...new Set(ids)].map(id=>({id,label:role==='monitor'&&id==='dashboard'?'Hoy':isPortal()&&id==='groups'?'Horarios':isPortal()&&id==='finance'?'Cuotas':LABEL[id],icon:navIcon(id)}));
}
function mobileNavFor(session){
  const role=session?.rol;let ids;
  if(role==='direccion'||role==='coordinacion')ids=['dashboard','members','sessions','finance','more'];
  else if(role==='secretaria')ids=['dashboard','enrollments','members','sessions','more'];
  else if(role==='economia')ids=['dashboard','finance','reminders','notifications','more'];
  else if(role==='comunicacion')ids=['dashboard','communications','community','notifications','more'];
  else if(role==='monitor')ids=['dashboard','groups','attendance','tracking','profile'];
  else ids=['dashboard','groups','community','finance','profile'];
  const map={more:{id:'more',label:'Más',icon:navIcon('more')}};return ids.map(id=>map[id]||{id,label:isPortal()&&id==='groups'?'Horarios':isPortal()&&id==='finance'?'Cuotas':role==='monitor'&&id==='dashboard'?'Hoy':LABEL[id],icon:navIcon(id)});
}

let notificationTimer=null;
let notificationPrimed=false;
let knownNotificationIds=new Set();

const notificationGroupKey=(n)=>{
  const type=String(n?.tipo||'general');
  if(['inscripcion','cuota','material','pago','documento','validacion_pago'].includes(type))return 'accion';
  if(['reserva_sesion','sesion_cambio','clase'].includes(type))return 'sesiones';
  if(type==='comunidad')return 'comunidad';
  if(['comunicacion','evento'].includes(type))return 'comunicaciones';
  return 'otros';
};

async function hydrateSessionAvatar(){
  const path=state.session?.avatar_path;if(!path)return;
  try{
    const url=await repos.settings.avatarUrl(path);
    if(!url)return;
    document.querySelectorAll('[data-session-avatar]').forEach(el=>{const img=el.querySelector('img');if(!img)return;img.src=url;img.hidden=false;el.classList.add('has-photo');});
  }catch(error){console.warn('Avatar:',humanError(error));}
}

function stopNotificationMonitor(){if(notificationTimer){clearInterval(notificationTimer);notificationTimer=null;}notificationPrimed=false;knownNotificationIds=new Set();}
async function refreshNotifications({announce=true}={}){
  if(!state.session)return;
  try{
    const items=await repos.notifications.list();
    const unread=items.filter(n=>!n.leida);
    const unreadGroups=new Set(unread.map(notificationGroupKey));
    state.unreadNotificationCount=unreadGroups.size;setNotificationBadge(unreadGroups.size);
    const ids=new Set(items.map(n=>n.id));
    if(!notificationPrimed){
      if(announce&&unread.length)toast(unreadGroups.size===1?`Tienes ${unread.length} aviso${unread.length===1?'':'s'} en 1 grupo pendiente`:`Tienes ${unread.length} avisos en ${unreadGroups.size} grupos pendientes`);
    }else if(announce){
      const fresh=items.filter(n=>!knownNotificationIds.has(n.id));
      if(fresh.length){
        const n=fresh[0];toast(fresh.length===1?`Nueva notificación: ${n.titulo}`:`${fresh.length} nuevas notificaciones`);
        if('Notification' in window&&Notification.permission==='granted'&&document.hidden){try{new Notification(n.titulo||'Urban Warriors',{body:n.cuerpo||'Tienes una nueva notificación.',icon:'./assets/icons/icon-192.png'})}catch{}}
      }
    }
    knownNotificationIds=ids;notificationPrimed=true;
  }catch(error){console.warn('Centro de notificaciones:',humanError(error));}
}
function startNotificationMonitor(){stopNotificationMonitor();refreshNotifications({announce:true});notificationTimer=setInterval(()=>refreshNotifications({announce:true}),45000);}
async function syncNativePushToken(){
  try{
    if(!state.session||!window.UrbanWarriorsNative?.getPushToken)return;
    const token=String(window.UrbanWarriorsNative.getPushToken()||'').trim();if(!token)return;
    const key=`${state.session.id}:${token}`;if(localStorage.getItem('uw_push_synced_token')===key)return;
    await backend.mutate('push.registrar',{token,plataforma:'android'});localStorage.setItem('uw_push_synced_token',key);
  }catch(error){console.warn('Sincronización push:',error)}
}

const isNativeAndroid=()=>Boolean(window.UrbanWarriorsNative?.getNotificationPermissionStatus);
const nativeNotificationStatus=()=>{try{return String(window.UrbanWarriorsNative?.getNotificationPermissionStatus?.()||'unknown')}catch{return 'unknown'}};

async function enforceNativePushPreferences(){
  if(!state.session||!isNativeAndroid())return;
  try{
    await repos.notifications.savePreferences({push_general:true,push_finanzas:true,push_sesiones:true,push_comunidad:true});
  }catch(error){console.warn('Preferencias push RC11:',humanError(error));}
}

function showNativeNotificationPrompt(status=nativeNotificationStatus()){
  if(!state.session||!isNativeAndroid()||status==='granted')return;
  const blocked=status==='denied'||status==='blocked';
  const actions=blocked
    ? '<button class="btn btn-ghost" id="push-later">Ahora no</button><button class="btn btn-primary" id="push-open-settings">Abrir ajustes de notificaciones</button>'
    : '<button class="btn btn-ghost" id="push-later">Ahora no</button><button class="btn btn-primary" id="push-activate">Activar notificaciones</button>';
  openDetail({
    title:'Activa las notificaciones',
    subtitle:'Urban Warriors puede avisarte de cuotas, cambios de sesión, comunicaciones y novedades importantes.',
    body:`<div class="native-push-consent"><div class="native-push-consent-icon">${icon('bell')}</div><div><strong>${blocked?'Las notificaciones están desactivadas en Android':'No te pierdas avisos importantes del club'}</strong><p>${blocked?'Abre los ajustes de Android y permite las notificaciones de Urban Warriors.':'Pulsa Activar notificaciones y acepta el permiso que mostrará Android. Puedes cambiar este permiso más adelante desde los ajustes del teléfono.'}</p></div></div>`,
    actions,
    width:'560px',
    className:'native-push-modal'
  });
  document.getElementById('push-later')?.addEventListener('click',closeModal);
  document.getElementById('push-activate')?.addEventListener('click',()=>{window.UrbanWarriorsNative?.requestNotifications?.();});
  document.getElementById('push-open-settings')?.addEventListener('click',()=>{window.UrbanWarriorsNative?.openNotificationSettings?.();});
}

async function ensureNativeNotificationSetup(){
  if(!state.session||!isNativeAndroid())return;
  await enforceNativePushPreferences();
  const status=nativeNotificationStatus();
  if(status==='granted'){
    window.UrbanWarriorsNative?.ensurePushToken?.();
    await syncNativePushToken();
    return;
  }
  showNativeNotificationPrompt(status);
}
window.addEventListener('uw-notifications-changed',()=>refreshNotifications({announce:false}));
window.addEventListener('uw-profile-avatar-changed',()=>hydrateSessionAvatar());

async function navigate(id,{replace=false}={}){
  if(!routes[id])id='dashboard';const allowed=new Set(navFor(state.session).map(x=>x.id));if(state.session?.rol==='direccion'){allowed.add('diagnostics');allowed.add('certification');}if(!allowed.has(id))id='dashboard';state.route=id;
  if(replace)history.replaceState({route:id},'',`#${id}`);else if(location.hash!==`#${id}`)history.pushState({route:id},'',`#${id}`);
  document.querySelectorAll('[data-nav]').forEach(b=>b.classList.toggle('active',b.dataset.nav===id));state.clearError();const alerts=document.getElementById('global-alerts');if(alerts)alerts.innerHTML='';await routes[id]();
}
function bindShellNavigation(){
  document.querySelectorAll('[data-nav]').forEach(b=>b.addEventListener('click',()=>{navigate(b.dataset.nav);document.getElementById('sidebar')?.classList.remove('open')}));
  document.getElementById('menu-btn')?.addEventListener('click',()=>document.getElementById('sidebar')?.classList.toggle('open'));
  document.getElementById('mobile-more')?.addEventListener('click',()=>document.getElementById('sidebar')?.classList.add('open'));
  document.getElementById('logout-btn')?.addEventListener('click',async()=>{stopNotificationMonitor();await backend.signOut();renderLogin();});
}
function renderShell(){
  const nav=navFor(state.session),mobile=mobileNavFor(state.session),initial=(location.hash||'#dashboard').slice(1);const allowed=new Set(nav.map(n=>n.id));if(state.session?.rol==='direccion'){allowed.add('diagnostics');allowed.add('certification');}const route=allowed.has(initial)?initial:'dashboard';setAppHtml(shell(nav,route,mobile));bindDismissAlerts();bindShellNavigation();hydrateSessionAvatar();startNotificationMonitor();syncNativePushToken();navigate(route,{replace:true});ensureNativeNotificationSetup();
}

function renderLogin(prefillEmail=''){
  state.session=null;
  setAppHtml(`<div class="login-shell"><section class="login-visual"><div class="login-brand"><img src="./assets/urban-warriors-logo.png" alt="Urban Warriors"><div class="slogan">Bring the Pain</div><h1>URBAN<br>WARRIORS</h1><p>Tu gimnasio, tus clases y tu evolución. Gestión premium para equipo, alumnado y familias.</p></div><div class="login-foot">Urban Warriors · Bring the Pain</div></section><section class="login-card-wrap"><form class="login-card" id="login-form"><div class="login-mini-brand"><img src="./assets/urban-warriors-logo.png" alt=""><div><strong>URBAN WARRIORS</strong><small>Bring the Pain</small></div></div><h2>Bienvenido/a</h2><p>Accede a tu cuenta del club.</p><div id="login-error" class="login-error" hidden></div><div class="field"><label>Email</label><input name="email" type="email" autocomplete="username" value="${esc(prefillEmail)}" required></div><div class="field"><label>Contraseña</label><input name="password" type="password" autocomplete="current-password" required></div><button class="btn btn-primary" id="login-submit" type="submit">Entrar</button><div class="login-link-row"><button class="btn btn-ghost btn-sm" type="button" id="register-btn">Crear cuenta</button><button class="btn btn-ghost btn-sm" type="button" id="invite-btn">Tengo invitación</button></div><div class="login-install"><button type="button" id="public-install">Instalar Urban Warriors</button></div></form></section></div>`);
  const form=document.getElementById('login-form'),btn=document.getElementById('login-submit'),box=document.getElementById('login-error');
  form.addEventListener('submit',async e=>{e.preventDefault();e.stopPropagation();if(!form.reportValidity())return;btn.disabled=true;btn.textContent='Validando…';box.hidden=true;try{const fd=new FormData(form);await backend.signIn(fd.get('email'),fd.get('password'));renderShell();}catch(error){box.hidden=false;box.textContent=humanError(error);btn.disabled=false;btn.textContent='Entrar';}});
  document.getElementById('register-btn')?.addEventListener('click',openRegistrationChoice);document.getElementById('invite-btn')?.addEventListener('click',()=>openInvitation());document.getElementById('public-install')?.addEventListener('click',openPublicInstall);
  const params=new URLSearchParams(location.search);if(params.get('invite'))setTimeout(()=>openInvitation(params.get('invite')),50);
}

async function publicCatalog(){
  const clubs=await client.select('clubes',`select=id,nombre&slug=eq.${encodeURIComponent(window.UW_CONFIG.clubSlug)}&activo=eq.true&limit=1`,false);const club=clubs?.[0];if(!club)throw new Error('Club no disponible.');
  const [d,g,t,legal]=await Promise.all([client.select('disciplinas',`select=*&club_id=eq.${club.id}&activa=eq.true&order=orden`,false),client.select('grupos',`select=*&club_id=eq.${club.id}&activo=eq.true&order=nombre`,false),client.select('tarifas',`select=*&club_id=eq.${club.id}&activa=eq.true&order=nombre`,false),client.select('textos_legales',`select=id,tipo,version,cuerpo&club_id=eq.${club.id}&vigente=eq.true&order=tipo`,false).catch(()=>[])]);return {club,d,g,t,legal};
}
function openRegistrationChoice(){
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:760px"><div class="modal-head"><div><h2>Crear cuenta</h2><p>Selecciona cómo vas a utilizar Urban Warriors.</p></div><button class="icon-btn" id="registration-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:22px"><div class="registration-choice"><button class="choice-card" data-registration="adulto"><strong>Soy una persona adulta</strong><small>Crearé mi cuenta y solicitaré mi propia inscripción.</small></button><button class="choice-card" data-registration="tutor"><strong>Soy padre, madre o tutor</strong><small>Crearé mi cuenta y añadiré a un menor.</small></button></div><button class="choice-card" style="width:100%" data-registration="invite"><strong>Formo parte del equipo</strong><small>El personal accede mediante una invitación del Gestor de la app.</small></button><p class="muted" style="font-size:11px;line-height:1.5;margin:18px 0 0">Los menores no crean una cuenta independiente. La cuenta y los consentimientos corresponden a una persona adulta responsable.</p></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#registration-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelectorAll('[data-registration]').forEach(b=>b.addEventListener('click',()=>{const type=b.dataset.registration;closeModal();if(type==='invite')openInvitation();else openRegistration(type)}));
}
function showPublicLegal(doc){
  const d=document.createElement('dialog');d.className='legal-dialog';d.innerHTML=`<div class="legal-dialog-head"><div><strong>${esc(({condiciones_uso:'Condiciones de uso',privacidad:'Política de privacidad',comunidad:'Normas de Comunidad',derechos_imagen:'Autorización de imagen'})[doc.tipo]||doc.tipo)}</strong><small>Versión ${esc(doc.version||'')}</small></div><button class="icon-btn" aria-label="Cerrar">${icon('close')}</button></div><div class="legal-dialog-body">${esc(doc.cuerpo||'').replace(/\n/g,'<br>')}</div>`;document.body.appendChild(d);d.querySelector('button').addEventListener('click',()=>{d.close();d.remove()});d.addEventListener('close',()=>d.remove());d.showModal();}
async function openRegistration(type){
  try{
    const c=await publicCatalog();const tutor=type==='tutor';const byType=Object.fromEntries((c.legal||[]).map(x=>[x.tipo,x]));
    const modal=openForm({title:tutor?'Cuenta familiar':'Cuenta de alumno adulto',subtitle:'Cuenta → datos → solicitud deportiva → consentimientos',width:'900px',fields:[
      {name:'email',label:'Email de acceso',type:'email',required:true},{name:'password',label:'Contraseña',type:'password',required:true},{name:'adulto_nombre',label:'Nombre del adulto',required:true},{name:'adulto_apellidos',label:'Apellidos del adulto',required:true},{name:'adulto_fecha_nacimiento',label:'Nacimiento adulto',type:'date'},{name:'telefono',label:'Teléfono',required:true},
      ...(tutor?[{name:'menor_nombre',label:'Nombre del menor',required:true},{name:'menor_apellidos',label:'Apellidos del menor',required:true},{name:'menor_fecha_nacimiento',label:'Nacimiento menor',type:'date',required:true}]:[]),
      {name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:c.d.map(x=>({value:x.id,label:x.nombre}))},{name:'grupo_id',label:'Grupo preferido',type:'select',options:c.g.map(x=>({value:x.id,label:x.nombre}))},{name:'tarifa_id',label:'Tarifa',type:'select',options:c.t.map(x=>({value:x.id,label:`${x.nombre} · ${Number(x.importe||0).toFixed(2)} €`}))},
      {name:'terms',label:'He leído y acepto las Condiciones de uso.',type:'checkbox',value:false,required:true,full:true},{name:'privacy',label:'He leído la Política de privacidad.',type:'checkbox',value:false,required:true,full:true},{name:'image_rights',label:tutor?'Autorizo, de forma opcional, el uso de la imagen del menor dentro de Urban Warriors.':'Autorizo, de forma opcional, el uso de mi imagen dentro de Urban Warriors.',type:'checkbox',value:false,full:true}
    ],submitText:'Crear cuenta y enviar solicitud',onSubmit:async v=>{
      if(!v.terms||!v.privacy)throw new Error('Debes aceptar las Condiciones de uso y confirmar que has leído la Política de privacidad.');
      const legal_acceptances=[{tipo:'condiciones_uso',version:byType.condiciones_uso?.version||'2.0.0',aceptado:true},{tipo:'privacidad',version:byType.privacidad?.version||'2.0.0',aceptado:true},{tipo:'comunidad',version:byType.comunidad?.version||'2.0.0',aceptado:true},{tipo:'derechos_imagen',version:byType.derechos_imagen?.version||'2.0.0',aceptado:v.image_rights===true}];
      const r=await backend.registerAccount({...v,tipo_cuenta:type,legal_acceptances});if(r.confirmationRequired){toast('Revisa tu email para confirmar la cuenta');renderLogin(v.email);}else{toast('Cuenta creada');renderShell();}
    }});
    const grid=modal.form.querySelector('.form-grid');const legalBox=document.createElement('div');legalBox.className='registration-legal-links field full';legalBox.innerHTML=`<strong>Lee antes de aceptar</strong><div class="row-actions">${['condiciones_uso','privacidad','comunidad','derechos_imagen'].filter(k=>byType[k]).map(k=>`<button type="button" class="btn btn-ghost btn-sm legal-preview" data-type="${esc(k)}">${esc(({condiciones_uso:'Condiciones de uso',privacidad:'Privacidad',comunidad:'Comunidad',derechos_imagen:'Derechos de imagen'})[k])}</button>`).join('')}</div><small>La autorización de imagen es opcional y puede retirarse posteriormente.</small>`;grid.appendChild(legalBox);legalBox.querySelectorAll('.legal-preview').forEach(b=>b.addEventListener('click',()=>showPublicLegal(byType[b.dataset.type])));
  }catch(e){setError(e)}
}
function openInvitation(prefill=''){
  openForm({title:'Acceso del equipo',subtitle:'Acepta una invitación con una cuenta existente o crea una nueva.',width:'720px',fields:[{name:'token',label:'Token de invitación',required:true,value:prefill},{name:'modo',label:'¿Ya tienes cuenta?',type:'select',required:true,value:'existente',options:[{value:'existente',label:'Sí, ya tengo cuenta'},{value:'nueva',label:'No, crear cuenta ahora'}]},{name:'email',label:'Email invitado',type:'email',required:true},{name:'nombre',label:'Nombre (solo cuenta nueva)'},{name:'apellidos',label:'Apellidos (solo cuenta nueva)'},{name:'password',label:'Contraseña (solo cuenta nueva)',type:'password'}],submitText:'Continuar',onSubmit:async v=>{
    if(v.modo==='existente'){await backend.acceptInvitation(v.token,v.email);toast('Invitación preparada. Inicia sesión con el email invitado.');renderLogin(v.email);return;}
    if(!v.password||v.password.length<6)throw new Error('Indica una contraseña de al menos 6 caracteres para crear la cuenta.');const auth=await client.signUp(v.email,v.password,{nombre:v.nombre||'',apellidos:v.apellidos||'',tipo_cuenta:'personal_invitado',club_slug:window.UW_CONFIG.clubSlug});
    if(!auth?.access_token){localStorage.setItem('uw2_pending_invitation',JSON.stringify({token:v.token,email:v.email}));toast('Cuenta creada. Confirma tu email y después inicia sesión para aceptar la invitación.');renderLogin(v.email);return;}
    const r=await backend.acceptInvitation(v.token,v.email);if(r.loginRequired){toast('Inicia sesión para completar la invitación');renderLogin(v.email);}else{toast('Invitación aceptada. Inicia sesión con tu nueva cuenta.');await backend.signOut();renderLogin(v.email);}
  }});
}
function openPublicInstall(){
  closeModal();const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';wrap.innerHTML=`<div class="modal" style="--modal-width:680px"><div class="modal-head"><div><h2>Instalar Urban Warriors</h2><p>Lleva el club contigo en el móvil.</p></div><button class="icon-btn" id="modal-close" aria-label="Cerrar">${icon('close')}</button></div><div style="padding:24px;text-align:center"><img src="./assets/install-qr.png" alt="QR" style="width:240px;max-width:70%;background:#fff;padding:10px;border-radius:18px"><p class="muted">Escanea el QR o instala la PWA desde el navegador.</p><div class="row-actions" style="justify-content:center"><button class="btn btn-primary" id="install-now">Instalar aplicación</button><a class="btn btn-ghost" href="./assets/docs/manual-usuario/01_portada_manual_usuario.png" target="_blank">Ver guía visual</a></div></div></div>`;document.body.appendChild(wrap);wrap.querySelector('#modal-close').addEventListener('click',closeModal);wrap.addEventListener('click',e=>{if(e.target===wrap)closeModal()});wrap.querySelector('#install-now').addEventListener('click',async()=>{if(window.__uwInstallPrompt){window.__uwInstallPrompt.prompt();await window.__uwInstallPrompt.userChoice;window.__uwInstallPrompt=null;}else toast('Usa el menú del navegador → Instalar aplicación.','error')});
}

async function boot(){
  window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();window.__uwInstallPrompt=e;});
  window.addEventListener('uw-native-push-token',async e=>{try{if(state.session&&e.detail){await backend.mutate('push.registrar',{token:e.detail,plataforma:'android'});localStorage.setItem('uw_push_synced_token',`${state.session.id}:${e.detail}`);}}catch(error){console.warn('Push token:',error)}});
  window.addEventListener('uw-native-notification-permission',async e=>{if(!state.session||!isNativeAndroid())return;const status=String(e.detail||nativeNotificationStatus());if(status==='granted'){closeModal();window.UrbanWarriorsNative?.ensurePushToken?.();await syncNativePushToken();toast('Notificaciones activadas');}else if(status==='denied'||status==='blocked'){closeModal();showNativeNotificationPrompt(status);}});
  window.addEventListener('popstate',()=>{if(state.session)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('hashchange',()=>{if(state.session)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  window.addEventListener('focus',()=>{if(state.session)refreshNotifications({announce:true})});
  try{const session=await backend.restore();if(session)renderShell();else renderLogin();}catch(e){console.error(e);renderLogin();}
  if('serviceWorker' in navigator&&location.protocol.startsWith('http')&&location.hostname!=='appassets.androidplatform.net')navigator.serviceWorker.register('./service-worker.js?v=20012').catch(e=>console.warn('Service worker:',e));
}
boot();
