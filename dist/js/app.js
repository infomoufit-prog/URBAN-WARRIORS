import { backend, client } from './core/backend.js';
import { state } from './core/state.js';
import { humanError, esc } from './core/utils.js';
import { shell, setAppHtml, bindDismissAlerts, setError, openForm, toast } from './ui/components.js';
import { renderDashboard, renderCatalog } from './modules/dashboard-catalog.js';
import { renderGroups, renderMembers, renderEnrollments } from './modules/groups-members.js';
import { renderSessions, renderAttendance, renderTracking, renderProgress } from './modules/training.js';
import { renderFinance, renderReminders } from './modules/finance.js';
import { renderCommunications, renderMaterial, renderNotifications } from './modules/comms-material.js';
import { renderUsers, renderSettings, renderProfile, renderDiagnostics, renderCertification } from './modules/admin.js';

const routes={
  dashboard:renderDashboard,catalog:renderCatalog,groups:renderGroups,members:renderMembers,enrollments:renderEnrollments,
  sessions:renderSessions,attendance:renderAttendance,progress:renderProgress,finance:renderFinance,reminders:renderReminders,communications:renderCommunications,
  tracking:renderTracking,material:renderMaterial,notifications:renderNotifications,users:renderUsers,settings:renderSettings,
  diagnostics:renderDiagnostics,certification:renderCertification,profile:renderProfile
};
const ICON={dashboard:'⌂',catalog:'◈',groups:'▦',members:'◉',enrollments:'✦',sessions:'◷',attendance:'✓',progress:'↗',finance:'€',reminders:'⚑',communications:'✉',tracking:'↗',material:'□',notifications:'●',users:'♟',settings:'⚙',diagnostics:'⌁',certification:'✓',profile:'◎'};
const LABEL={dashboard:'Inicio',catalog:'Disciplinas y grados',groups:'Grupos',members:'Alumnos',enrollments:'Preinscripciones',sessions:'Sesiones',attendance:'Asistencia',progress:'Progreso',finance:'Finanzas',reminders:'Avisos de cobro',communications:'Comunicaciones',tracking:'Seguimiento',material:'Material',notifications:'Notificaciones',users:'Usuarios',settings:'Configuración',diagnostics:'Diagnóstico',certification:'Certificación E2E',profile:'Mi perfil'};

function navFor(session){
  const role=session?.rol;
  let ids;
  if(['direccion','secretaria'].includes(role)) ids=['dashboard','catalog','groups','members','enrollments','sessions','attendance','progress','finance','reminders','communications','tracking','material','notifications','users','settings','diagnostics','profile'];
  else if(role==='economia') ids=['dashboard','finance','reminders','material','notifications','settings','diagnostics','profile'];
  else if(role==='comunicacion') ids=['dashboard','communications','notifications','settings','diagnostics','profile'];
  else if(role==='monitor') ids=['dashboard','catalog','groups','sessions','attendance','progress','tracking','notifications','diagnostics','profile'];
  else ids=['dashboard','groups','progress','finance','material','notifications','diagnostics','profile'];
  if(session?.roles?.includes('direccion')) ids.splice(ids.length-1,0,'certification');
  return [...new Set(ids)].map(id=>({id,label:LABEL[id],icon:ICON[id]}));
}

async function navigate(id,{replace=false}={}){
  if(!routes[id])id='dashboard';
  const allowed=new Set(navFor(state.session).map(x=>x.id));if(!allowed.has(id))id='dashboard';
  state.route=id;
  if(replace)history.replaceState({route:id},'',`#${id}`);else if(location.hash!==`#${id}`)history.pushState({route:id},'',`#${id}`);
  document.querySelectorAll('[data-nav]').forEach(b=>b.classList.toggle('active',b.dataset.nav===id));
  state.clearError();document.getElementById('global-alerts').innerHTML='';
  await routes[id]();
}

function renderShell(){
  const nav=navFor(state.session);const initial=(location.hash||'#dashboard').slice(1);
  setAppHtml(shell(nav,nav.some(n=>n.id===initial)?initial:'dashboard'));bindDismissAlerts();
  document.querySelectorAll('[data-nav]').forEach(b=>b.addEventListener('click',()=>{navigate(b.dataset.nav);document.getElementById('sidebar')?.classList.remove('open')}));
  document.getElementById('menu-btn')?.addEventListener('click',()=>document.getElementById('sidebar')?.classList.toggle('open'));
  document.getElementById('logout-btn')?.addEventListener('click',async()=>{await backend.signOut();renderLogin();});
  navigate(nav.some(n=>n.id===initial)?initial:'dashboard',{replace:true});
}

function renderLogin(){
  state.session=null;
  setAppHtml(`<div class="login-shell"><section class="login-visual"><div><img src="./assets/urban-warriors-logo.png" alt="Urban Warriors"><h1>URBAN<br>WARRIORS</h1><p>Gestión del club con persistencia verificable sobre Supabase.</p></div><small>${esc(window.UW_CONFIG.release.version)} · backend ${esc(window.UW_CONFIG.release.backendVersion)}</small></section><section class="login-card-wrap"><form class="login-card" id="login-form"><h2>Acceso</h2><p>Inicia sesión con tu cuenta del club.</p><div id="login-error" class="login-error" hidden></div><div class="field"><label>Email</label><input name="email" type="email" autocomplete="username" required></div><div class="field"><label>Contraseña</label><input name="password" type="password" autocomplete="current-password" required></div><button class="btn btn-primary" id="login-submit" type="submit">Entrar</button><div style="display:flex;gap:8px;margin-top:16px"><button class="btn btn-ghost btn-sm" type="button" id="register-btn">Crear cuenta</button><button class="btn btn-ghost btn-sm" type="button" id="invite-btn">Tengo invitación</button></div></form></section></div>`);
  const form=document.getElementById('login-form'),btn=document.getElementById('login-submit'),box=document.getElementById('login-error');
  form.addEventListener('submit',async e=>{e.preventDefault();e.stopPropagation();if(!form.reportValidity())return;btn.disabled=true;btn.textContent='Validando…';box.hidden=true;try{const fd=new FormData(form);await backend.signIn(fd.get('email'),fd.get('password'));renderShell();}catch(error){box.hidden=false;box.textContent=humanError(error);btn.disabled=false;btn.textContent='Entrar';}});
  document.getElementById('register-btn')?.addEventListener('click',openRegistration);
  document.getElementById('invite-btn')?.addEventListener('click',openInvitation);
  const params=new URLSearchParams(location.search);if(params.get('invite'))setTimeout(()=>openInvitation(params.get('invite')),50);
}

async function publicCatalog(){
  const clubs=await client.select('clubes',`select=id,nombre&slug=eq.${encodeURIComponent(window.UW_CONFIG.clubSlug)}&activo=eq.true&limit=1`,false);const club=clubs?.[0];if(!club)throw new Error('Club no disponible.');
  const [d,g,t]=await Promise.all([client.select('disciplinas',`select=*&club_id=eq.${club.id}&activa=eq.true&order=orden`,false),client.select('grupos',`select=*&club_id=eq.${club.id}&activo=eq.true&order=nombre`,false),client.select('tarifas',`select=*&club_id=eq.${club.id}&activa=eq.true&order=nombre`,false)]);return {d,g,t};
}
async function openRegistration(){
  try{
    const c=await publicCatalog();
    openForm({title:'Crear cuenta',subtitle:'Registro de adulto o tutor/familia',width:'880px',fields:[
      {name:'tipo_cuenta',label:'Tipo de cuenta',type:'select',required:true,options:[{value:'adulto',label:'Adulto / alumno'},{value:'tutor',label:'Tutor / familia'}]},
      {name:'email',label:'Email',type:'email',required:true},{name:'password',label:'Contraseña',type:'password',required:true},
      {name:'adulto_nombre',label:'Nombre del adulto',required:true},{name:'adulto_apellidos',label:'Apellidos del adulto',required:true},{name:'adulto_fecha_nacimiento',label:'Nacimiento adulto',type:'date'},
      {name:'telefono',label:'Teléfono',required:true},{name:'menor_nombre',label:'Nombre del menor'},{name:'menor_apellidos',label:'Apellidos del menor'},{name:'menor_fecha_nacimiento',label:'Nacimiento menor',type:'date'},
      {name:'disciplina_id',label:'Disciplina',type:'select',options:c.d.map(x=>({value:x.id,label:x.nombre}))},{name:'grupo_id',label:'Grupo',type:'select',options:c.g.map(x=>({value:x.id,label:x.nombre}))},{name:'tarifa_id',label:'Tarifa',type:'select',options:c.t.map(x=>({value:x.id,label:`${x.nombre} · ${Number(x.importe||0).toFixed(2)} €`}))}
    ],submitText:'Crear cuenta',onSubmit:async v=>{const r=await backend.registerAccount(v);if(r.confirmationRequired){toast('Revisa tu email para confirmar la cuenta');}else{toast('Cuenta creada');renderShell();}}});
  }catch(e){setError(e)}
}
function openInvitation(prefill=''){
  openForm({title:'Aceptar invitación',subtitle:'Si todavía no has iniciado sesión, guardaremos el token y se aceptará al entrar con el email invitado.',fields:[{name:'token',label:'Token de invitación',required:true,value:prefill},{name:'email',label:'Email invitado',type:'email'}],submitText:'Continuar',onSubmit:async v=>{const r=await backend.acceptInvitation(v.token,v.email);if(r.loginRequired)toast('Invitación preparada. Inicia sesión con el email invitado.');else{toast('Invitación aceptada. Vuelve a iniciar sesión para cargar el rol.');await backend.signOut();renderLogin();}}});
}

async function boot(){
  window.addEventListener('uw-native-push-token',async e=>{try{if(state.session&&e.detail)await backend.mutate('push.registrar',{token:e.detail,plataforma:'android'});}catch(error){console.warn('Push token:',error)}});
  window.addEventListener('popstate',()=>{if(state.session)navigate((location.hash||'#dashboard').slice(1),{replace:true})});
  try{const session=await backend.restore();if(session)renderShell();else renderLogin();}catch(e){console.error(e);renderLogin();}
  if('serviceWorker' in navigator&&location.protocol.startsWith('http')&&location.hostname!=='appassets.androidplatform.net')navigator.serviceWorker.register('./service-worker.js?v=20003').catch(e=>console.warn('Service worker:',e));
}

boot();
