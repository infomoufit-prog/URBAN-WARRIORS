import {backend} from './core/backend.js';
import {state} from './core/state.js';
import {esc} from './core/utils.js';
import {flowStorageKey} from './modules/instagram-integration.js';
import {installLegacyRuntimeLocalization} from './i18n/legacy-runtime.js';

installLegacyRuntimeLocalization();

const root=document.getElementById('meta-instagram-result');
async function complete(){
 const params=new URLSearchParams(location.search),flow=params.get('flow'),handoff=params.get('handoff');
 // Opaque continuation token is removed immediately; no codes or tokens in the URL.
 history.replaceState(null,'',location.pathname);
 let pending;try{pending=JSON.parse(sessionStorage.getItem(flowStorageKey(flow))||'null');}catch{}
 if(!flow||!handoff||!pending||pending.expires<Date.now())throw new Error();
 await backend.restore();
 if(!state.session||state.session.platform_legal_required)throw new Error();
 const data=await backend.invokeFunction('meta-instagram',{action:'finish',flow_id:flow,handoff,proof:pending.proof},60000);
 sessionStorage.removeItem(flowStorageKey(flow));
 const options=data.accounts||[];if(!options.length)throw new Error();
 root.innerHTML=`<p>Selecciona la página y cuenta de Instagram que quieres conectar a esta identidad.</p><label>Cuenta profesional<select id="meta-account">${options.map(a=>`<option value="${esc(a.page_id)}">${esc(a.page_name)} · @${esc(a.username)}</option>`).join('')}</select></label><p><button class="btn btn-primary" id="meta-confirm">Confirmar conexión</button></p><p id="meta-feedback" role="status"></p>`;
 document.getElementById('meta-confirm').addEventListener('click',async e=>{
  const button=e.currentTarget;button.disabled=true;
  try{await backend.invokeFunction('meta-instagram',{action:'select',flow_id:flow,page_id:document.getElementById('meta-account').value},60000);root.textContent='Instagram conectado. Ya puedes volver a KOMBAX y consultar la conexión desde Social.';}
  catch{document.getElementById('meta-feedback').textContent='No se ha podido conectar la cuenta. Vuelve a intentarlo o inicia una nueva conexión.';button.disabled=false;}
 });
}
complete().catch(()=>{root.textContent='No se ha podido completar la conexión. Vuelve a KOMBAX e inicia de nuevo la conexión desde el mismo navegador y cuenta.';});
