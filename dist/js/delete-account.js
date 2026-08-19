import { backend } from './core/backend.js';
import { repos } from './core/repositories.js';
import { state } from './core/state.js';
import { esc } from './core/utils.js';

const box=document.getElementById('kx-delete-web-status');
const OPEN_STATES=new Set(['requested','in_review','needs_information','confirmed']);
const CANCELLABLE=new Set(['requested','needs_information']);

const errorText=error=>String(error?.message||error||'No se pudo completar la operación.').replace(/^Error:\s*/,'');
const date=value=>{try{return new Intl.DateTimeFormat('es-ES',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}catch{return String(value||'');}};

function bindLogin(){
  const form=document.getElementById('kx-delete-login-form');
  form?.addEventListener('submit',async event=>{
    event.preventDefault();
    const submit=form.querySelector('button[type="submit"]');submit.disabled=true;
    const feedback=document.getElementById('kx-delete-feedback');feedback.textContent='';
    try{
      const email=form.elements.email.value.trim();const password=form.elements.password.value;
      if(!email||!password)throw new Error('Introduce email y contraseña.');
      await backend.signInGlobal(email,password);await renderAuthenticated();
    }catch(error){feedback.textContent=errorText(error);submit.disabled=false;}
  });
}

function renderLogin(message=''){
  box.innerHTML=`<div class="kx-delete-web-auth"><span class="page-kicker">IDENTIFICACIÓN DEL TITULAR</span><h3>Inicia sesión para solicitar la eliminación</h3><p>No envíes contraseñas ni documentos por correo. La petición se vinculará a la cuenta autenticada.</p>${message?`<div class="alert alert-warning"><span>${esc(message)}</span></div>`:''}<form id="kx-delete-login-form" class="kx-delete-web-form"><label>Email<input type="email" name="email" autocomplete="username" required></label><label>Contraseña<input type="password" name="password" autocomplete="current-password" required></label><p id="kx-delete-feedback" class="form-error" role="alert"></p><button class="btn btn-primary" type="submit">Acceder de forma segura</button></form></div>`;
  bindLogin();
}

async function submitRequest(form){
  const submit=form.querySelector('button[type="submit"]');submit.disabled=true;
  const feedback=document.getElementById('kx-delete-feedback');feedback.textContent='';
  try{
    if(!form.elements.confirm.checked)throw new Error('Confirma que quieres iniciar la solicitud de eliminación.');
    await repos.accountDeletion.request({alcance:'account',motivo:form.elements.motivo.value.trim()});
    await renderAuthenticated('Solicitud de eliminación registrada correctamente.');
  }catch(error){feedback.textContent=errorText(error);submit.disabled=false;}
}

async function cancelRequest(id){
  const feedback=document.getElementById('kx-delete-feedback');if(feedback)feedback.textContent='';
  try{await repos.accountDeletion.cancel(id);await renderAuthenticated('Solicitud cancelada.');}
  catch(error){if(feedback)feedback.textContent=errorText(error);}
}

async function renderAuthenticated(message=''){
  if(!state.session?.id){renderLogin();return;}
  let rows=[];
  try{rows=await repos.accountDeletion.list();}catch(error){renderLogin(`No se pudo consultar el estado: ${errorText(error)}`);return;}
  const open=(rows||[]).filter(row=>row.alcance==='account'&&OPEN_STATES.has(row.estado));
  box.innerHTML=`<div class="kx-delete-web-auth"><span class="page-kicker">CUENTA AUTENTICADA</span><h3>${esc(state.session.email||state.session.nombre||'Cuenta KOMBAX')}</h3>${message?`<div class="alert alert-success"><span>${esc(message)}</span></div>`:''}${open.length?`<div class="kx-delete-web-open"><strong>Solicitud abierta</strong>${open.map(row=>`<article><div><span>${esc(row.estado)}</span><small>Registrada ${esc(date(row.solicitado_en))}</small>${row.nota_retencion?`<p>${esc(row.nota_retencion)}</p>`:''}${row.resolucion?`<p>${esc(row.resolucion)}</p>`:''}</div>${CANCELLABLE.has(row.estado)?`<button type="button" class="btn btn-ghost btn-sm" data-kx-delete-web-cancel="${esc(row.id)}">Cancelar solicitud</button>`:''}</article>`).join('')}</div>`:`<form id="kx-delete-request-form" class="kx-delete-web-form"><label>Motivo (opcional)<textarea name="motivo" rows="4" maxlength="1200" placeholder="Puedes indicar el motivo o dejarlo en blanco."></textarea></label><label class="kx-delete-web-confirm"><input type="checkbox" name="confirm" required><span>Quiero iniciar la solicitud de eliminación de mi cuenta KOMBAX.</span></label><button class="btn btn-danger" type="submit">Solicitar eliminación de mi cuenta</button></form>`}<div class="row-actions"><button type="button" class="btn btn-ghost btn-sm" id="kx-delete-web-signout">Cerrar sesión</button></div><p id="kx-delete-feedback" class="form-error" role="alert"></p></div>`;
  document.getElementById('kx-delete-request-form')?.addEventListener('submit',event=>{event.preventDefault();submitRequest(event.currentTarget);});
  box.querySelectorAll('[data-kx-delete-web-cancel]').forEach(button=>button.addEventListener('click',()=>cancelRequest(button.dataset.kxDeleteWebCancel)));
  document.getElementById('kx-delete-web-signout')?.addEventListener('click',async()=>{await backend.signOut();renderLogin('Sesión cerrada.');});
}

async function init(){
  try{const session=await backend.restore();if(session)await renderAuthenticated();else renderLogin();}
  catch(error){renderLogin(errorText(error));}
}
init();
