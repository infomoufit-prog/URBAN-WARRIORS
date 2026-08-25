import { backend, client } from './backend.js';
import { repos } from './repositories.js';
import { state } from './state.js';

// KOMBAX 20.084 · Security Go-Live client hardening.
// Server gates remain authoritative. This module adds the AAL2 Owner flow,
// routes support entry through migration 149 and exposes read-only readiness UI.

const AUTH_STORAGE='uw2_supabase_session';
const originalStart=repos.platformAdmin?.entitySessionStart;
const originalBeginPlatformAdminAccess=backend.beginPlatformAdminAccess?.bind(backend);
const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const errText=error=>String(error?.message||error?.details||error||'');
const isAal2Required=error=>/OWNER_AAL2_REQUIRED/i.test(errText(error));

if(repos.platformAdmin){
  repos.platformAdmin.entitySessionStart=(type,id,reason)=>backend.globalWriteRpc('app_kombax_platform_entity_session_start_v149',{
    p_entidad_tipo:type,p_entidad_id:id,p_motivo:reason
  });
  repos.platformAdmin.securityStatus=()=>backend.globalReadRpc('app_kombax_security_status_v149',{});
  repos.platformAdmin.securitySurface=()=>backend.globalReadRpc('app_kombax_security_surface_v149',{});
}

function decodeJwt(token){
  try{
    const part=String(token||'').split('.')[1];
    if(!part)return {};
    const normalized=part.replace(/-/g,'+').replace(/_/g,'/').padEnd(Math.ceil(part.length/4)*4,'=');
    return JSON.parse(decodeURIComponent(Array.from(atob(normalized),c=>`%${c.charCodeAt(0).toString(16).padStart(2,'0')}`).join('')));
  }catch{return {};}
}
function currentAal(){return decodeJwt(client.session?.access_token)?.aal||'aal1';}
function saveAuthResponse(payload){
  const source=payload?.session?.access_token?payload.session:payload;
  if(!source?.access_token)return client.session;
  const next={...(client.session||{}),...source,user:source.user||client.session?.user};
  if(!next.expires_at&&next.expires_in)next.expires_at=Math.floor(Date.now()/1000)+Number(next.expires_in);
  client.session=next;
  try{localStorage.setItem(AUTH_STORAGE,JSON.stringify(next));}catch{}
  return next;
}
function factorsFrom(value){
  const rows=[];
  if(Array.isArray(value))rows.push(...value);
  for(const key of ['totp','all','factors'])if(Array.isArray(value?.[key]))rows.push(...value[key]);
  const unique=new Map();
  for(const f of rows){if(f?.id)unique.set(String(f.id),f);}
  return [...unique.values()];
}
function verifiedTotp(value){
  return factorsFrom(value).find(f=>String(f.factor_type||f.factorType||f.type||'').toLowerCase()==='totp'&&String(f.status||'').toLowerCase()==='verified')||null;
}
async function listMfaFactors(){const user=await client.request('/auth/v1/user',{method:'GET'});return {all:Array.isArray(user?.factors)?user.factors:[]};}
async function enrollTotp(){
  return client.request('/auth/v1/factors',{method:'POST',body:JSON.stringify({factor_type:'totp',friendly_name:'KOMBAX Owner'})},false);
}
async function challengeTotp(factorId){
  return client.request(`/auth/v1/factors/${encodeURIComponent(factorId)}/challenge`,{method:'POST',body:JSON.stringify({channel:null})},false);
}
async function verifyTotp(factorId,challengeId,code){
  const result=await client.request(`/auth/v1/factors/${encodeURIComponent(factorId)}/verify`,{method:'POST',body:JSON.stringify({challenge_id:challengeId,code:String(code||'').replace(/\s+/g,'')})},false);
  saveAuthResponse(result);
  return result;
}

function removeMfaOverlay(){document.querySelectorAll('.kx-owner-mfa-overlay-20084').forEach(x=>x.remove());}
function mfaOverlayShell({title,subtitle,body}){
  removeMfaOverlay();
  const wrap=document.createElement('div');
  wrap.className='kx-owner-mfa-overlay-20084';
  Object.assign(wrap.style,{position:'fixed',inset:'0',zIndex:'2147483600',background:'rgba(0,0,0,.82)',display:'grid',placeItems:'center',padding:'20px'});
  wrap.innerHTML=`<section style="width:min(520px,100%);background:#111217;color:#fff;border:1px solid #3b3d46;border-radius:18px;padding:22px;box-shadow:0 24px 80px #000"><div style="font:700 11px/1.2 system-ui;letter-spacing:.16em;color:#ff4057">KOMBAX · SECURITY 20.084</div><h2 style="margin:8px 0 5px;font:750 24px/1.15 system-ui">${esc(title)}</h2><p style="margin:0 0 18px;color:#b8bbc7;font:14px/1.5 system-ui">${esc(subtitle)}</p>${body}</section>`;
  document.body.appendChild(wrap);
  return wrap;
}
function codeFormMarkup(label='Código de 6 dígitos'){
  return `<form data-kx-mfa-code><label style="display:block;font:600 13px system-ui;margin-bottom:7px">${esc(label)}</label><input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" required style="width:100%;box-sizing:border-box;background:#090a0d;color:#fff;border:1px solid #555966;border-radius:10px;padding:13px;font-size:20px;letter-spacing:.18em"><div data-kx-mfa-error style="display:none;color:#ff7f8f;font:13px/1.4 system-ui;margin-top:10px"></div><button type="submit" style="width:100%;margin-top:14px;padding:12px;border:0;border-radius:10px;background:#b80f2c;color:white;font-weight:750;cursor:pointer">Verificar segundo factor</button></form>`;
}
async function runTotpChallenge(factor,{title='Verificación Owner',subtitle='Introduce el código de tu aplicación autenticadora para elevar esta sesión a AAL2.'}={}){
  const challenge=await challengeTotp(factor.id);
  const challengeId=challenge?.id||challenge?.challenge_id;
  if(!challengeId)throw new Error('No se pudo iniciar el desafío MFA Owner.');
  return new Promise((resolve,reject)=>{
    const wrap=mfaOverlayShell({title,subtitle,body:codeFormMarkup()});
    const form=wrap.querySelector('[data-kx-mfa-code]'),box=wrap.querySelector('[data-kx-mfa-error]'),button=form.querySelector('button');
    form.addEventListener('submit',async event=>{
      event.preventDefault();button.disabled=true;box.style.display='none';
      try{
        await verifyTotp(factor.id,challengeId,form.elements.code.value);
        if(currentAal()!=='aal2')throw new Error('La sesión no alcanzó AAL2 después de verificar el factor.');
        removeMfaOverlay();resolve(true);
      }catch(error){box.textContent=errText(error)||'Código no válido.';box.style.display='block';button.disabled=false;}
    });
  });
}
async function setupOwnerMfa(){
  if(currentAal()==='aal2'){
    await backend.globalWriteRpc('app_kombax_security_owner_mfa_enforce_v149',{p_confirmacion:'EXIGIR MFA OWNER'});
    return true;
  }
  const existing=await listMfaFactors();
  const verified=verifiedTotp(existing);
  if(verified){
    await runTotpChallenge(verified,{title:'Confirmar MFA del Owner',subtitle:'Verifica el factor TOTP ya registrado antes de convertir AAL2 en requisito obligatorio.'});
  }else{
    const factor=await enrollTotp();
    const id=factor?.id||factor?.factor?.id;
    const totp=factor?.totp||factor?.factor?.totp||{};
    if(!id)throw new Error('Supabase Auth no devolvió un factor TOTP válido.');
    const qrRaw=totp.qr_code||totp.qrCode||'';
    const qr=String(qrRaw).trim().startsWith('<svg')?`data:image/svg+xml;charset=utf-8,${encodeURIComponent(qrRaw)}`:qrRaw;
    const secret=totp.secret||'';
    const body=`${qr?`<div style="display:grid;place-items:center;background:#fff;border-radius:12px;padding:12px;margin-bottom:14px"><img alt="QR MFA Owner" src="${esc(qr)}" style="max-width:230px;width:100%"></div>`:''}${secret?`<details style="margin:0 0 14px;font:13px system-ui"><summary>Introducir clave manualmente</summary><code style="display:block;word-break:break-all;margin-top:8px;padding:9px;background:#08090c;border-radius:8px">${esc(secret)}</code></details>`:''}${codeFormMarkup('Código generado después de escanear el QR')}`;
    await new Promise((resolve,reject)=>{
      const wrap=mfaOverlayShell({title:'Activar MFA del Owner',subtitle:'Escanea el QR con una aplicación autenticadora. El secreto no se guarda en KOMBAX.',body});
      const form=wrap.querySelector('[data-kx-mfa-code]'),box=wrap.querySelector('[data-kx-mfa-error]'),button=form.querySelector('button');
      form.addEventListener('submit',async event=>{
        event.preventDefault();button.disabled=true;box.style.display='none';
        try{
          const challenge=await challengeTotp(id);const challengeId=challenge?.id||challenge?.challenge_id;
          if(!challengeId)throw new Error('No se pudo iniciar el desafío de activación.');
          await verifyTotp(id,challengeId,form.elements.code.value);
          if(currentAal()!=='aal2')throw new Error('La activación no elevó la sesión a AAL2.');
          removeMfaOverlay();resolve(true);
        }catch(error){box.textContent=errText(error)||'No se pudo verificar el código.';box.style.display='block';button.disabled=false;}
      });
    });
  }
  await backend.globalWriteRpc('app_kombax_security_owner_mfa_enforce_v149',{p_confirmacion:'EXIGIR MFA OWNER'});
  return true;
}

// Replace only the privileged Owner login entry point. Normal user authentication is untouched.
// The established password check remains server-side; if migration 149 requires AAL2, the flow
// challenges the verified TOTP factor and retries creation of the 30-minute Owner session.
if(originalBeginPlatformAdminAccess){
  backend.beginPlatformAdminAccess=async(email,password)=>{
    const normalized=String(email||'').trim().toLowerCase();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized))throw new Error('Indica un correo electrónico válido.');
    if(!String(password||''))throw new Error('Introduce tu contraseña.');
    try{
      await client.signIn(normalized,String(password));
      let result;
      try{result=await client.rpc('app_kombax_platform_admin_password_session_v139',{});}
      catch(error){
        if(!isAal2Required(error))throw error;
        const factors=await listMfaFactors();const factor=verifiedTotp(factors);
        if(!factor)throw new Error('OWNER_MFA_FACTOR_REQUIRED: el Owner exige MFA pero no existe un factor TOTP verificado.');
        await runTotpChallenge(factor);
        result=await client.rpc('app_kombax_platform_admin_password_session_v139',{});
      }
      if(result?.authorized!==true)throw new Error('No se pudo abrir la sesión de administración.');
      const restored=await backend.restorePlatformAdminAccess();
      if(!restored?.platform_admin)throw new Error('No se pudo confirmar la autorización global KOMBAX.');
      const out={...restored,platform_auth_mode:currentAal()==='aal2'?'password+totp':'password',admin_expires_at:result.expires_at||restored.admin_expires_at||null};
      state.session=out;
      try{sessionStorage.setItem('uw2_platform_admin_session',JSON.stringify({id:out.id,email:out.email,expires_at:out.admin_expires_at||null,auth_mode:out.platform_auth_mode}));}catch{}
      return out;
    }catch(error){
      await client.signOut().catch(()=>{});
      throw error;
    }
  };
}

function clearPrivateIntentState(){
  try{
    ['kombax_social_open_contact','kombax_social_view','kombax_owner_pending_entity','kombax_support_return'].forEach(k=>sessionStorage.removeItem(k));
  }catch{}
}

let lastBoundary=`${state.session?.id||'guest'}:${state.session?.club_id||'global'}:${state.session?.scope||'none'}`;
function boundaryCheck(){
  const next=`${state.session?.id||'guest'}:${state.session?.club_id||'global'}:${state.session?.scope||'none'}`;
  if(next===lastBoundary)return;
  lastBoundary=next;clearPrivateIntentState();
  window.dispatchEvent(new CustomEvent('uw-kombax-security-boundary-changed',{detail:{boundary:next}}));
}
window.addEventListener('hashchange',boundaryCheck);
window.addEventListener('popstate',boundaryCheck);
window.addEventListener('pageshow',boundaryCheck);

async function supportBanner(){
  if(!repos.platformAdmin?.entitySessionContext)return;
  try{
    const ctx=await repos.platformAdmin.entitySessionContext();
    document.querySelectorAll('.kx-security-support-banner').forEach(x=>x.remove());
    if(!ctx?.authorized)return;
    const bar=document.createElement('div');
    bar.className='kx-security-support-banner';
    bar.setAttribute('role','status');
    bar.innerHTML=`<strong>MODO SOPORTE KOMBAX</strong><span>${esc(ctx.entidad_tipo||'entidad')} · sesión auditada y temporal</span>`;
    Object.assign(bar.style,{position:'fixed',left:'0',right:'0',top:'0',zIndex:'2147483000',padding:'7px 12px',background:'#7a0012',color:'#fff',font:'600 12px/1.3 system-ui',display:'flex',gap:'10px',justifyContent:'center',alignItems:'center',boxShadow:'0 2px 12px #0008'});
    document.body.appendChild(bar);
  }catch{/* normal users have no platform context */}
}
window.addEventListener('uw-kombax-private-context-changed',supportBanner);
window.addEventListener('hashchange',supportBanner);
setTimeout(supportBanner,900);

function statusPill(ok,label){return `<span style="display:inline-flex;padding:4px 8px;border-radius:999px;background:${ok?'#123c2b':'#4a1820'};color:${ok?'#9ff0c8':'#ffabb6'};font:700 11px system-ui">${esc(label)}</span>`;}
async function renderSecurityPanel20084(){
  const main=document.getElementById('main-view');if(!main)return;
  main.innerHTML='<div class="loading-card">Comprobando Security Go-Live…</div>';
  try{
    const status=await repos.platformAdmin.securityStatus();
    const controls=Array.isArray(status?.controls)?status.controls:[];
    main.innerHTML=`<div class="kx-platform-admin"><div class="page-head"><div><span class="page-kicker">SECURITY GO-LIVE · 20.084</span><h1>Preparación de seguridad del piloto</h1><p>El piloto solo puede abrirse cuando todos los controles obligatorios tienen evidencia. Esta pantalla no activa el piloto.</p></div></div><div class="kx-platform-stats"><article><span>AAL actual</span><strong>${esc(status?.current_aal||currentAal())}</strong></article><article><span>MFA Owner</span><strong>${status?.owner_mfa_required?'OBLIGATORIO':'PENDIENTE'}</strong></article><article><span>Controles</span><strong>${Number(status?.verified||0)}/${Number(status?.required||0)}</strong></article><article><span>Pilot Security</span><strong>${status?.pilot_enabled?'ACTIVO':status?.pilot_ready?'READY':'CERRADO'}</strong></article></div><section class="kx-platform-section"><div class="section-title"><div><span class="page-kicker">AUTENTICACIÓN PRIVILEGIADA</span><h3>Owner · AAL2</h3></div></div><p>Una vez exigido, la contraseña por sí sola ya no puede abrir una sesión Owner ni una sesión de soporte.</p><div class="row-actions">${status?.owner_mfa_required?statusPill(true,'MFA Owner exigido'):'<button type="button" class="btn btn-primary" id="kx-owner-mfa-setup-20084">Configurar y exigir MFA Owner</button>'}<button type="button" class="btn btn-ghost" id="kx-security-refresh-20084">Actualizar estado</button></div></section><section class="kx-platform-section"><div class="section-title"><div><span class="page-kicker">CHECKLIST DE SALIDA</span><h3>Controles obligatorios</h3></div></div><div class="kx-platform-audit">${controls.map(c=>`<article><div><strong>${esc(c.control)}</strong><small>${esc(c.category)} · ${c.required_for_pilot?'obligatorio':'informativo'}</small></div><div>${statusPill(c.status==='verified',String(c.status||'pending').toUpperCase())}</div>${c.evidence?`<p style="grid-column:1/-1;margin:6px 0 0;color:#aeb1bd">${esc(c.evidence)}</p>`:''}</article>`).join('')}</div></section><section class="kx-platform-section"><div class="section-title"><div><span class="page-kicker">GATE FINAL</span><h3>${status?.pilot_ready?'Preparado para habilitación controlada':'Todavía cerrado'}</h3></div></div><p>${status?.pilot_ready?'Todos los controles exigidos por 20.084 están verificados. La habilitación sigue requiriendo AAL2 y una confirmación explícita fuera de esta pantalla.':'Faltan evidencias reales. 20.084 no permite declarar el piloto seguro mediante una casilla de frontend.'}</p></section></div>`;
    document.getElementById('kx-owner-mfa-setup-20084')?.addEventListener('click',async event=>{const b=event.currentTarget;b.disabled=true;try{await setupOwnerMfa();await renderSecurityPanel20084();}catch(error){alert(`MFA Owner: ${errText(error)}`);b.disabled=false;}});
    document.getElementById('kx-security-refresh-20084')?.addEventListener('click',renderSecurityPanel20084);
  }catch(error){main.innerHTML=`<div class="empty"><strong>Security Go-Live no disponible</strong><p>${esc(errText(error))}</p></div>`;}
}

function installSecurityTab(){
  const nav=document.querySelector('.kx-admin-console-nav');
  if(!nav||nav.querySelector('[data-security-console="20084"]'))return;
  const button=document.createElement('button');button.type='button';button.dataset.securityConsole='20084';button.textContent='Seguridad';nav.appendChild(button);
  button.addEventListener('click',()=>{nav.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b===button));renderSecurityPanel20084();});
  nav.addEventListener('click',event=>{const target=event.target.closest('button');if(target&&target!==button&&target.hasAttribute('data-admin-console'))button.classList.remove('active');},true);
}
const adminObserver=new MutationObserver(()=>installSecurityTab());
adminObserver.observe(document.documentElement,{subtree:true,childList:true});
setTimeout(installSecurityTab,800);

console.info('KOMBAX 20.084 · Security Go-Live client hardening installed');
export { originalStart, setupOwnerMfa, currentAal };
