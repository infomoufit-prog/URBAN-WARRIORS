import { backend } from '../core/backend.js';
import { state } from '../core/state.js';
import { esc, humanError, dtFmt } from '../core/utils.js';
import { setAppHtml, setMainHtml, empty, toast } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { repos } from '../core/repositories.js';
import { renderPlatformAdmin } from './platform-admin.js';

const ADMIN_IDLE_MS=15*60*1000;
let idleTimer=null;
let idleBindings=[];

function clearIdle(){
  if(idleTimer){clearTimeout(idleTimer);idleTimer=null;}
  for(const [target,event,handler] of idleBindings)target.removeEventListener(event,handler);
  idleBindings=[];
}

function armIdle(onExpired){
  clearIdle();
  const reset=()=>{if(idleTimer)clearTimeout(idleTimer);idleTimer=setTimeout(onExpired,ADMIN_IDLE_MS);};
  for(const event of ['pointerdown','keydown','touchstart']){window.addEventListener(event,reset,{passive:true});idleBindings.push([window,event,reset]);}
  reset();
}

function accessMark(){return `<div class="kx-admin-access-mark"><img src="${esc(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""><div><strong>KOMBAX</strong><small>Consola de Plataforma</small></div></div>`;}

function renderCredentials({onCancel,onSuccess,message=''}){
  clearIdle();
  setAppHtml(`<main class="kx-admin-access-shell"><section class="kx-admin-access-card">${accessMark()}<div class="kx-admin-access-kicker">ACCESO MAESTRO</div><h1>Administración global KOMBAX</h1><p>Acceso independiente del rol de cualquier club. Introduce el correo Owner autorizado y valida de nuevo tu contraseña para abrir la Consola KOMBAX.</p>${message?`<div class="alert alert-warning"><strong>Sesión cerrada</strong><span>${esc(message)}</span></div>`:''}<form id="kx-admin-credentials"><div class="field"><label for="kx-admin-email">Correo autorizado</label><input id="kx-admin-email" name="email" type="email" autocomplete="username" required></div><div class="field"><label for="kx-admin-password">Contraseña</label><input id="kx-admin-password" name="password" type="password" autocomplete="current-password" required></div><div id="kx-admin-access-error" class="login-error" hidden></div><button class="btn btn-primary" id="kx-admin-continue" type="submit">Abrir Consola KOMBAX ${icon('chevronRight',{size:17})}</button></form><div class="kx-admin-access-footer"><span>La puerta oculta no concede permisos.</span><button class="btn btn-ghost btn-sm" id="kx-admin-cancel" type="button">Salir</button></div></section></main>`);
  const form=document.getElementById('kx-admin-credentials'),button=document.getElementById('kx-admin-continue'),errorBox=document.getElementById('kx-admin-access-error');
  form?.addEventListener('submit',async event=>{
    event.preventDefault();if(!form.reportValidity())return;button.disabled=true;button.textContent='Verificando…';errorBox.hidden=true;
    const fd=new FormData(form);
    try{
      await backend.beginPlatformAdminAccess(fd.get('email'),fd.get('password'));
      toast('Acceso maestro verificado');onSuccess?.();
    }catch(error){errorBox.hidden=false;errorBox.textContent=humanError(error);button.disabled=false;button.innerHTML=`Abrir Consola KOMBAX ${icon('chevronRight',{size:17})}`;}
  });
  document.getElementById('kx-admin-cancel')?.addEventListener('click',async()=>{await backend.signOutPlatformAdmin().catch(()=>{});onCancel?.();});
}

export function renderPlatformAdminAccess({onCancel,onSuccess,message=''}={}){renderCredentials({onCancel,onSuccess,message});}

async function renderMaintenance(){
  setMainHtml('<div class="loading-card">Comprobando estado de plataforma…</div>');
  try{
    const [context,contract]=await Promise.all([repos.platformAdmin.context(),repos.platformAdmin.releaseContract().catch(()=>null)]);
    const traces=state.trace.slice(0,40);
    const sessionExpiry=state.session?.admin_expires_at?dtFmt(state.session.admin_expires_at):'Controlado por backend';
    setMainHtml(`<div class="kx-platform-admin"><div class="page-head"><div><span class="page-kicker">MANTENIMIENTO</span><h1>Estado de KOMBAX</h1><p>Área técnica visible únicamente dentro de la Consola de Plataforma.</p></div></div><div class="kx-platform-stats"><article><span>Build web</span><strong>${Number(window.UW_CONFIG?.release?.build||0)}</strong></article><article><span>Acceso global</span><strong>${context?.authorized?'OK':'Bloqueado'}</strong></article><article><span>Nivel</span><strong>${esc(context?.nivel||state.session?.platform_level||'—')}</strong></article><article><span>Sesión admin</span><strong>${esc(sessionExpiry)}</strong></article></div>${contract?`<section class="kx-platform-section kx-technical-panel"><div class="section-title"><div><span class="page-kicker">CONTRATO DE PLATAFORMA</span><h3>Backend KOMBAX</h3></div></div><div class="kx-admin-club-stats"><span>Identidades <strong>${contract.identity_context?'OK':'Pendiente'}</strong></span><span>Perfiles públicos <strong>${contract.public_profiles?'OK':'Pendiente'}</strong></span><span>Social <strong>${contract.social_media?'OK':'Pendiente'}</strong></span><span>Showcase <strong>${contract.showcase_actions?'OK':'Pendiente'}</strong></span><span>Admin global <strong>${contract.platform_admin?'OK':'Pendiente'}</strong></span></div></section>`:''}<section class="kx-platform-section kx-technical-panel"><div class="section-title"><div><span class="page-kicker">TRAZA TÉCNICA</span><h3>Últimas operaciones de esta sesión</h3></div></div>${traces.length?`<div class="kx-platform-audit">${traces.map(t=>`<article><div><strong>${esc(t.label||t.kind||'Operación')}</strong><small>${esc(t.at||'')} ${t.ms!=null?`· ${esc(t.ms)} ms`:''}</small></div><code>${esc(t.error||t.detail||'OK')}</code></article>`).join('')}</div>`:empty('Sin trazas','Todavía no se han registrado operaciones en esta sesión.')}</section></div>`);
  }catch(error){setMainHtml(empty('No se pudo cargar Mantenimiento',humanError(error)));}
}

export async function renderPlatformAdminConsole(){
  const valid=await backend.restorePlatformAdminAccess().catch(()=>null);
  if(!valid){renderPlatformAdminAccess({onCancel:()=>{location.href='/';},onSuccess:renderPlatformAdminConsole,message:'La verificación de administración ha caducado.'});return;}
  const level=state.session?.platform_level||'owner';
  setAppHtml(`<div class="kx-admin-console"><header class="kx-admin-console-top">${accessMark()}<div class="kx-admin-console-status"><span>ACCESO VERIFICADO</span><strong>${esc(String(level).toUpperCase())}</strong></div><button class="btn btn-ghost btn-sm" id="kx-admin-console-exit" type="button">Cerrar administración</button></header><nav class="kx-admin-console-nav"><button type="button" class="active" data-admin-console="platform">${icon('key',{size:18})} Plataforma</button><button type="button" data-admin-console="maintenance">${icon('activity',{size:18})} Mantenimiento</button></nav><main id="main-view" class="main-view"><div class="loading-card">Abriendo Consola KOMBAX…</div></main></div>`);
  const buttons=[...document.querySelectorAll('[data-admin-console]')];
  const open=async view=>{buttons.forEach(b=>b.classList.toggle('active',b.dataset.adminConsole===view));if(view==='maintenance')await renderMaintenance();else await renderPlatformAdmin();};
  buttons.forEach(button=>button.addEventListener('click',()=>open(button.dataset.adminConsole)));
  document.getElementById('kx-admin-console-exit')?.addEventListener('click',async()=>{clearIdle();await backend.signOutPlatformAdmin();if(/\/admin\/?$/.test(location.pathname))location.href='/';else location.reload();});
  armIdle(async()=>{await backend.signOutPlatformAdmin().catch(()=>{});renderPlatformAdminAccess({onCancel:()=>{if(/\/admin\/?$/.test(location.pathname))location.href='/';else location.reload();},onSuccess:renderPlatformAdminConsole,message:'La sesión de administración se cerró por inactividad.'});});
  await open('platform');
}
