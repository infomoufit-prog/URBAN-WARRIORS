import { getLocale as kxGetLocale } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { setAppHtml, setPrivateViewHtml, setError, toast } from '../ui/components.js';
import { icon } from '../ui/icons.js';

const fmt=v=>{try{return v?new Intl.DateTimeFormat(kxLocaleTag(kxGetLocale()),{dateStyle:'medium',timeStyle:'short'}).format(new Date(v)):'—'}catch{return '—'}};
const capsSet=w=>new Set(Array.isArray(w?.capabilities)?w.capabilities:[]);
const btn=(label,action,id,kind='ghost')=>`<button class="btn btn-${kind} btn-sm" type="button" data-pro-action="${esc(action)}" data-pro-id="${esc(id)}">${esc(label)}</button>`;

function incomingHtml(rows=[]){
 if(!rows.length)return '<div class="premium-empty"><strong>Sin solicitudes de representación</strong><p>Un Manager solo puede representarte después de que aceptes una solicitud concreta.</p></div>';
 return `<div class="kx-pro-list">${rows.map(d=>`<article><div><span>Manager</span><strong>${esc(d.manager_name||'Perfil profesional')}</strong><small>${esc(d.status)} · ${esc((d.permissions||[]).join(' · ')||'Sin permisos')}</small></div><div class="kx-pro-row-actions">${d.status==='requested'?btn('Aceptar','delegation-accept',d.id,'primary')+btn('Rechazar','delegation-reject',d.id):''}${d.status==='accepted'?btn('Revocar','delegation-revoke',d.id):''}</div></article>`).join('')}</div>`;
}
function delegationHtml(rows=[]){
 if(!rows.length)return '<div class="premium-empty"><strong>Sin representados</strong><p>Las relaciones aparecen aquí desde la solicitud y solo conceden permisos cuando el Competidor las acepta.</p></div>';
 return `<div class="kx-pro-list">${rows.map(d=>`<article><div><span>Competidor</span><strong>${esc(d.target_name||d.target_profile_id)}</strong><small>${esc(d.status)} · ${esc((d.permissions||[]).join(' · '))}</small></div><div>${d.status==='accepted'||d.status==='requested'?btn('Revocar','delegation-revoke',d.id):''}</div></article>`).join('')}</div>`;
}
function assignmentsHtml(rows=[]){
 if(!rows.length)return '<p class="muted">Sin asignaciones activas en Events.</p>';
 return `<div class="kx-pro-list">${rows.map(a=>`<article><div><span>${a.assignment_type==='medical'?'Asignación sanitaria':'Asignación arbitral'}</span><strong>${esc(a.event_name||'KOMBAX Event')}</strong><small>${esc(a.status)} · permisos: ${esc((a.permissions||[]).join(' · '))}</small></div><div>${a.status==='propuesta'?btn('Aceptar','assignment-accept',a.id,'primary')+btn('Rechazar','assignment-reject',a.id):''}</div></article>`).join('')}</div>`;
}
function clientsHtml(rows=[]){return rows.length?`<div class="kx-pro-list">${rows.map(c=>`<article><div><span>Cliente / deportista propio</span><strong>${esc(c.nombre)}</strong><small>${esc(c.email||c.telefono||c.estado)}</small></div></article>`).join('')}</div>`:'<p class="muted">Aún no hay clientes propios registrados.</p>'}
function sessionsHtml(rows=[]){return rows.length?`<div class="kx-pro-list">${rows.slice(0,12).map(s=>`<article><div><span>${esc(fmt(s.starts_at))}</span><strong>${esc(s.titulo)}</strong><small>${esc(s.estado)}</small></div></article>`).join('')}</div>`:'<p class="muted">Aún no hay sesiones profesionales.</p>'}
const SPECIALTY_LABEL={entrenador:'Entrenador/a',representante_manager:'Representante / Manager',medico_sanitario:'Médico / Sanitario',arbitro_juez:'Árbitro / Juez',promotor_organizador:'Promotor / Organizador'};
const specialtyLabel=value=>SPECIALTY_LABEL[value]||String(value||'Especialidad');
function credentialsHtml(rows=[]){
 if(!rows.length)return '<p class="muted">Aún no hay acreditaciones declaradas.</p>';
 const stateLabel={declarada:'Borrador',pendiente:'En revisión',verificada:'Verificada',rechazada:'Rechazada',expirada:'Expirada'};
 return `<div class="kx-pro-list">${rows.map(c=>{const verified=c.estado==='verificada',expired=c.estado==='expirada';const visibility=verified?`<div class="kx-pro-row-actions"><button class="btn btn-ghost btn-sm" type="button" data-pro-credential-visibility="${esc(c.id)}" data-public="${c.public_visible?'1':'0'}">${c.public_visible?'Ocultar del perfil público':'Publicar credencial verificada'}</button></div>`:'';return `<article><div><span>${esc(specialtyLabel(c.specialty_code))}</span><strong>${esc(c.credential_type)}</strong><small>${esc(c.issuer||'Entidad no indicada')} · ${esc(stateLabel[c.estado]||c.estado)}${c.expires_on?` · vence ${esc(c.expires_on)}`:''}</small>${c.verification_url?`<small>Enlace oficial: ${esc(c.verification_url)}</small>`:''}${Number(c.evidence_count||0)>0?`<small>${Number(c.evidence_count)} evidencia(s) privada(s) registrada(s)</small>`:''}${c.declaration_accepted?'<small>Declaración de autenticidad registrada</small>':''}${expired?'<small>La acreditación caducada no se publica.</small>':''}</div>${visibility}</article>`}).join('')}</div>`;
}

export async function renderProfessionalOperations(profileId,{onBack,onEvents}={}){
 setPrivateViewHtml('<main class="kx-professional-ops"><div class="loading-card">Cargando operaciones profesionales…</div></main>');
 try{
  const [w,hub]=await Promise.all([repos.kombaxProfiles.professionalWorkspace(profileId),repos.kombaxProfiles.workspace(profileId)]);const profile=hub?.profile||{};
  if(w?.clinical_health_records_enabled!==false)throw new Error('Estado clínico no verificable: operación detenida.');
  if(w.type==='competidor'){
   setPrivateViewHtml(`<main class="kx-professional-ops"><header class="kx-managed-top"><button class="gateway-icon-button" id="pro-back" type="button">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><span>PERFIL COMPETIDOR</span><strong>Representación</strong></div></header><section class="kx-pro-intro"><h1>Quién puede representarme</h1><p>Ningún Manager obtiene permisos por declararlo. Tú aceptas, rechazas o revocas cada relación.</p></section><section class="premium-surface kx-pro-section"><h2>Solicitudes y delegaciones</h2>${incomingHtml(w.incoming_delegations||[])}</section></main>`);
  }else{
   const caps=capsSet(w),specialty=hub?.professional_specialty?.principal||'',secondary=Array.isArray(hub?.professional_specialty?.secundarias)?hub.professional_specialty.secundarias:[],specialties=[...new Set([specialty,...secondary].filter(Boolean))];
   setPrivateViewHtml(`<main class="kx-professional-ops"><header class="kx-managed-top"><button class="gateway-icon-button" id="pro-back" type="button">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><span>MI ACTIVIDAD</span><strong>${esc(profile.nombre_publico||'Operaciones profesionales')}</strong></div></header><section class="kx-pro-intro"><h1>Operaciones profesionales</h1><p>Herramientas separadas del Club y habilitadas por especialidad/capacidad. Este entorno no contiene expediente sanitario ni datos clínicos.</p></section>
   ${caps.has('professional.clients.manage')?`<section class="premium-surface kx-pro-section"><div class="kx-pro-head"><div><span>ENTRENADOR</span><h2>Clientes / deportistas propios</h2></div></div><form id="pro-client-form" class="kx-pro-form"><label>Nombre<input name="nombre" required minlength="2" maxlength="160"></label><label>Email opcional<input name="email" type="email"></label><label>Teléfono opcional<input name="telefono"></label><label class="wide">Notas operativas no clínicas<textarea name="notas_operativas" maxlength="3000"></textarea></label><button class="btn btn-primary" type="submit">Guardar cliente</button></form>${clientsHtml(w.clients||[])}</section>
   <section class="premium-surface kx-pro-section"><h2>Sesiones</h2><form id="pro-session-form" class="kx-pro-form"><label>Título<input name="titulo" required minlength="2"></label><label>Inicio<input name="starts_at" type="datetime-local" required></label><label>Fin<input name="ends_at" type="datetime-local"></label><label class="wide">Nota operativa<textarea name="notas_operativas" maxlength="3000"></textarea></label><button class="btn btn-primary" type="submit">Añadir sesión</button></form>${sessionsHtml(w.sessions||[])}</section>`:''}
   ${caps.has('professional.delegations.manage')?`<section class="premium-surface kx-pro-section"><div class="kx-pro-head"><div><span>MANAGER</span><h2>Representados</h2></div></div><div class="kx-managed-boundary"><strong>Consentimiento obligatorio</strong><p>La solicitud no concede acceso. Solo una aceptación del Competidor activa los permisos seleccionados y puede revocarse en cualquier momento.</p></div><form id="pro-delegation-form" class="kx-pro-form"><label class="wide">ID del Perfil Competidor<input name="target_profile_id" required placeholder="UUID del Perfil Competidor"></label><fieldset class="wide"><legend>Permisos solicitados</legend><label><input type="checkbox" name="permissions" value="calendar.read" checked> Calendario compartido</label><label><input type="checkbox" name="permissions" value="opportunities.manage" checked> Oportunidades</label><label><input type="checkbox" name="permissions" value="events.requests.manage"> Solicitudes Events</label><label><input type="checkbox" name="permissions" value="professional_fields.edit"> Campos profesionales autorizados</label></fieldset><button class="btn btn-primary" type="submit">Solicitar representación</button></form>${delegationHtml(w.delegations||[])}</section>`:''}
   <section class="premium-surface kx-pro-section"><div class="kx-pro-head"><div><span>VERIFICACIÓN DOCUMENTAL</span><h2>Acreditaciones profesionales</h2></div></div><div class="kx-managed-boundary"><strong>Cada credencial se verifica por separado</strong><p>El documento se guarda de forma privada. Solo publicaremos los datos de una credencial después de verificarla y cuando tú decidas hacerla visible.</p></div><form id="pro-credential-form" class="kx-pro-form"><label>Especialidad<select name="specialty_code" required>${specialties.map(code=>`<option value="${esc(code)}">${esc(specialtyLabel(code))}</option>`).join('')}</select></label><label>Tipo de acreditación<input name="credential_type" required minlength="2" maxlength="160" placeholder="Licencia, titulación, colegiación…"></label><label>Entidad emisora<input name="issuer" required minlength="2" maxlength="220"></label><label>Referencia pública opcional<input name="reference_public" maxlength="260" placeholder="N.º de licencia o referencia que quieras asociar"></label><label class="wide">Enlace oficial de verificación opcional<input name="verification_url" type="url" placeholder="https://federacion.example/licencia/..."></label><label>Caducidad<input name="expires_on" type="date"></label><label class="wide">Documento de evidencia<input name="evidence" type="file" required accept="application/pdf,image/jpeg,image/png,image/webp"><small>PDF, JPG, PNG o WEBP · máximo 15 MB · almacenamiento privado.</small></label><label class="wide"><input name="public_reference_visible" type="checkbox" checked> Si la credencial se verifica y posteriormente la publico, permitir mostrar también la referencia pública.</label><label class="wide"><input name="declaration_accepted" type="checkbox" required> ${esc(w.credential_declaration_text||'Declaro que la información y documentación aportadas son auténticas y autorizo a KOMBAX a utilizarlas para verificar esta credencial.')}</label><button class="btn btn-primary" type="submit">Enviar acreditación a verificación</button></form>${credentialsHtml(w.credentials||[])}</section>
   ${caps.has('professional.schedule.manage')?`<section class="premium-surface kx-pro-section"><h2>Disponibilidad profesional</h2><form id="pro-availability-form" class="kx-pro-form"><label>Desde<input name="starts_at" type="datetime-local" required></label><label>Hasta<input name="ends_at" type="datetime-local" required></label><label class="wide">Nota<input name="nota" maxlength="500"></label><button class="btn btn-primary" type="submit">Añadir disponibilidad</button></form></section>`:''}
   <section class="premium-surface kx-pro-section"><h2>Asignaciones KOMBAX Events</h2>${assignmentsHtml(w.assignments||[])}${caps.has('events.public.organize')?'<button class="btn btn-primary" id="pro-open-events" type="button">Abrir KOMBAX Events</button>':''}</section></main>`);
  }
  document.getElementById('pro-back')?.addEventListener('click',onBack);
  document.getElementById('pro-open-events')?.addEventListener('click',onEvents);
  const mutate=async(operation,payload)=>{try{await repos.kombaxProfiles.professionalMutate(operation,payload);toast('Guardado');return renderProfessionalOperations(profileId,{onBack,onEvents});}catch(e){setError(e)}};
  document.getElementById('pro-client-form')?.addEventListener('submit',e=>{e.preventDefault();const f=new FormData(e.currentTarget);mutate('professional.client.save',{professional_profile_id:profileId,nombre:f.get('nombre'),email:f.get('email'),telefono:f.get('telefono'),notas_operativas:f.get('notas_operativas')})});
  document.getElementById('pro-session-form')?.addEventListener('submit',e=>{e.preventDefault();const f=new FormData(e.currentTarget);mutate('professional.session.save',{professional_profile_id:profileId,titulo:f.get('titulo'),starts_at:f.get('starts_at'),ends_at:f.get('ends_at')||null,notas_operativas:f.get('notas_operativas')})});
  document.getElementById('pro-delegation-form')?.addEventListener('submit',e=>{e.preventDefault();const f=new FormData(e.currentTarget);mutate('professional.delegation.request',{professional_profile_id:profileId,target_profile_id:f.get('target_profile_id'),permissions:f.getAll('permissions')})});
  document.getElementById('pro-credential-form')?.addEventListener('submit',async e=>{
    e.preventDefault();const form=e.currentTarget,f=new FormData(form),button=form.querySelector('button[type="submit"]'),file=form.elements.evidence?.files?.[0]||null;
    if(!file){setError(new Error('Adjunta la evidencia de la acreditación.'));return;}
    if(!form.elements.declaration_accepted?.checked){setError(new Error('Debes aceptar la declaración de autenticidad antes de enviar la credencial.'));return;}
    button.disabled=true;button.textContent='Preparando acreditación…';
    try{
      const saved=await repos.kombaxProfiles.professionalCredentialMutate('professional.credential.save',{
        professional_profile_id:profileId,specialty_code:f.get('specialty_code'),credential_type:f.get('credential_type'),issuer:f.get('issuer'),
        reference_public:f.get('reference_public'),verification_url:f.get('verification_url'),expires_on:f.get('expires_on')||null,
        public_reference_visible:form.elements.public_reference_visible?.checked===true
      });
      const credential=saved?.credential||saved?.data?.credential||saved;const credentialId=credential?.id;
      if(!credentialId)throw new Error('KOMBAX no devolvió una credencial verificable.');
      button.textContent='Subiendo evidencia privada…';
      await repos.kombaxProfiles.uploadProfessionalCredentialEvidence(profileId,credentialId,file);
      button.textContent='Enviando a revisión…';
      await repos.kombaxProfiles.professionalCredentialMutate('professional.credential.submit',{
        professional_profile_id:profileId,credential_id:credentialId,declaration_accepted:true,user_agent:navigator.userAgent
      });
      toast('Acreditación enviada a revisión KOMBAX');await renderProfessionalOperations(profileId,{onBack,onEvents});
    }catch(error){setError(error);button.disabled=false;button.textContent='Enviar acreditación a verificación';}
  });
  document.querySelectorAll('[data-pro-credential-visibility]').forEach(button=>button.addEventListener('click',async()=>{
    if(button.disabled)return;button.disabled=true;
    try{await repos.kombaxProfiles.professionalCredentialMutate('professional.credential.visibility',{
      professional_profile_id:profileId,credential_id:button.dataset.proCredentialVisibility,
      public_visible:button.dataset.public!=='1',public_reference_visible:true
    });toast(button.dataset.public==='1'?'Credencial ocultada del perfil público':'Credencial publicada en el perfil');await renderProfessionalOperations(profileId,{onBack,onEvents});}
    catch(error){button.disabled=false;setError(error);}
  }));
  document.getElementById('pro-availability-form')?.addEventListener('submit',e=>{e.preventDefault();const f=new FormData(e.currentTarget);mutate('professional.availability.save',{professional_profile_id:profileId,starts_at:f.get('starts_at'),ends_at:f.get('ends_at'),nota:f.get('nota')})});
  document.querySelectorAll('[data-pro-action]').forEach(b=>b.addEventListener('click',()=>{const id=b.dataset.proId,action=b.dataset.proAction;if(action==='delegation-accept')return mutate('professional.delegation.respond',{delegation_id:id,status:'accepted'});if(action==='delegation-reject')return mutate('professional.delegation.respond',{delegation_id:id,status:'rejected'});if(action==='delegation-revoke')return mutate('professional.delegation.revoke',{delegation_id:id});if(action==='assignment-accept')return mutate('professional.assignment.respond',{assignment_id:id,status:'aceptada'});if(action==='assignment-reject')return mutate('professional.assignment.respond',{assignment_id:id,status:'rechazada'});}));
 }catch(e){setError(e);onBack?.()}
}
