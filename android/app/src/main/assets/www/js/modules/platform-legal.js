import { backend } from '../core/backend.js';
import { state } from '../core/state.js';
import { openDetail, closeModal, toast, setError } from '../ui/components.js';

export function showPlatformLegalGate({onAccepted,onExit}={}){
  if(state.session?.platform_legal_required!==true){onAccepted?.();return null;}
  const {wrap}=openDetail({
    title:'Antes de continuar en KOMBAX',
    subtitle:'Condiciones globales de plataforma · versión 1.0.0',
    width:'760px',
    body:`<div class="kx-platform-legal-gate">
      <div class="alert"><strong>Cuenta KOMBAX</strong><span>Estas condiciones son independientes de las normas y documentos específicos de tu club.</span></div>
      <label class="checkbox-row"><input type="checkbox" id="kx-platform-terms-ok"><span>He leído y acepto las <a href="./terms.html" target="_blank" rel="noopener noreferrer">Condiciones de uso de KOMBAX</a>.</span></label>
      <label class="checkbox-row"><input type="checkbox" id="kx-platform-privacy-ok"><span>He leído la <a href="./privacy.html" target="_blank" rel="noopener noreferrer">Política de Privacidad global de KOMBAX</a>.</span></label>
      <p class="muted">La lectura de la política de privacidad no se utiliza como consentimiento general. Los consentimientos opcionales se solicitan por separado cuando corresponda.</p>
    </div>`,
    actions:'<button type="button" class="btn btn-ghost" id="kx-platform-legal-exit">Salir</button><button type="button" class="btn btn-primary" id="kx-platform-legal-accept">Aceptar y continuar</button>'
  });
  const accept=wrap.querySelector('#kx-platform-legal-accept');
  accept?.addEventListener('click',async()=>{
    if(!wrap.querySelector('#kx-platform-terms-ok')?.checked||!wrap.querySelector('#kx-platform-privacy-ok')?.checked){toast('Debes aceptar las Condiciones y confirmar que has leído la Política de Privacidad.','error');return;}
    accept.disabled=true;
    try{await backend.acceptPlatformLegal();closeModal();toast('Condiciones KOMBAX registradas');await onAccepted?.();}
    catch(error){accept.disabled=false;setError(error);}
  });
  wrap.querySelector('#kx-platform-legal-exit')?.addEventListener('click',async()=>{
    try{await backend.signOut();}catch{}
    closeModal();await onExit?.();
  });
  return wrap;
}
