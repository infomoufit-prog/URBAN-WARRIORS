import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { card, quickRow, openDetail, openForm, toast, setError } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openCustomerOperationsCenter } from './customer-operations.js';

export const SUPPORT_EMAIL='soporte@kombax.es';

const SUBJECT_LABEL={club:'club',direct_profile:'perfil KOMBAX',account:'cuenta'};
const SCOPE_LABEL={
  'support.read':'Consultar configuración y datos necesarios para soporte',
  'support.write':'Aplicar correcciones autorizadas',
  'finance.read':'Consultar Finanzas',
  'documents.read':'Consultar documentos privados',
  'minors.read':'Consultar datos de menores'
};
const statusTone=s=>s==='active'?'ok':s==='claimed'?'warn':'neutral';
const statusLabel=s=>({active:'Disponible',claimed:'En uso',revoked:'Revocado',expired:'Caducado'})[s]||s;

export function supportContactMarkup({compact=false}={}){
  const body=`<div class="kx-support-contact-copy"><strong>Soporte KOMBAX</strong><p><strong>KOMBAX Assist</strong> es el copiloto de gestión. <strong>Soporte KOMBAX</strong> es el canal humano para incidencias técnicas, cuenta, facturación de KOMBAX, privacidad, seguridad y asuntos legales. El contacto general comienza en <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>. Si soporte necesita consultar información privada, te pedirá una autorización temporal.</p><small>La moderación de contenido público y las funciones administrativas de seguridad/cumplimiento son independientes del soporte ordinario.</small></div>`;
  return compact?body:card('Privacidad y soporte',body);
}

function authorizationRows(rows=[]){
  if(!rows.length)return '<div class="empty-card compact"><strong>Sin accesos de soporte</strong><p>No has concedido ninguna autorización temporal.</p></div>';
  return `<div class="kx-support-auth-list">${rows.map(r=>`<article class="kx-support-auth-row"><div><span class="badge ${statusTone(r.status)}">${esc(statusLabel(r.status))}</span><strong>${esc((r.scopes||[]).map(s=>SCOPE_LABEL[s]||s).join(' · '))}</strong><small>${r.ticket_ref?`Caso ${esc(r.ticket_ref)} · `:''}Creado ${dtFmt(r.created_at)} · expira ${dtFmt(r.expires_at)}${r.claimed_by?` · ${esc(r.claimed_by)}`:''}</small></div>${['active','claimed'].includes(r.status)?`<button class="btn btn-ghost btn-sm" data-kx-revoke-support="${esc(r.id)}">Revocar</button>`:''}</article>`).join('')}</div>`;
}

function supportPolicyNotice(){
  return `<div class="kx-support-policy-note">${icon('shieldCheck',{size:20})}<div><strong>Tus datos no se comparten con otros clubes.</strong><p>El soporte ordinario solo usa una autorización temporal y con alcance definido por ti. El Administrador General de KOMBAX conserva una vía privilegiada independiente para seguridad, moderación, cumplimiento legal e incidencias críticas; ese acceso se audita por separado.</p></div></div>`;
}

export async function openSupportPrivacyCenter({subjectType='account',subjectId=null,title='Privacidad y soporte',canAuthorize=true}={}){
  const id=subjectId||state.session?.id;
  if(!id){toast('No se pudo identificar la cuenta.','error');return;}
  let rows=[];
  try{rows=canAuthorize?await repos.supportPrivacy.list(subjectType,id,25):[];}catch(error){if(canAuthorize)setError(error);}
  const {wrap}=openDetail({title,subtitle:`Soporte autorizado para este ${SUBJECT_LABEL[subjectType]||'perfil'}`,width:'820px',body:`
    <div class="kx-support-center">
      ${supportPolicyNotice()}
      <section class="kx-support-contact-card"><div><span>SOPORTE HUMANO</span><h3>Soporte KOMBAX</h3><p>Canal separado del agente de gestión. Atiende plataforma, cuenta, facturación KOMBAX, privacidad, seguridad y cuestiones legales.</p></div><button class="btn btn-primary" id="kx-open-customer-ops">Ver canales de soporte</button></section>
      <section class="kx-support-contact-card"><div><span>CANAL DE ENTRADA</span><h3>${SUPPORT_EMAIL}</h3><p>Utiliza el correo para incidencias técnicas, cuenta, facturación de KOMBAX o seguimiento con una persona. KOMBAX Assist queda reservado a la gestión de tu organización.</p></div><a class="btn btn-ghost" href="mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Soporte KOMBAX')}">${icon('mail',{size:16})} Escribir a soporte</a></section>
      ${canAuthorize?`<section><div class="section-title"><div><span>ACCESO TEMPORAL</span><h3>Autorizaciones de soporte</h3></div><button type="button" class="btn btn-primary btn-sm" id="kx-create-support-auth">Autorizar soporte</button></div>${authorizationRows(rows)}</section>`:''}
      <section class="kx-support-legal-copy"><strong>Qué significa esta autorización</strong><p>No concede propiedad ni convierte a KOMBAX en miembro de tu equipo. Solo crea una credencial temporal, con código de un solo uso y fecha de caducidad, para que el canal de soporte pueda validar el alcance autorizado.</p></section>
    </div>`});
  wrap.querySelector('#kx-open-customer-ops')?.addEventListener('click',()=>openCustomerOperationsCenter(subjectType==='direct_profile'&&subjectId?{profileId:subjectId}:{}));
  if(!canAuthorize)return;
  wrap.querySelector('#kx-create-support-auth')?.addEventListener('click',()=>openForm({
    title:'Autorizar soporte KOMBAX',
    subtitle:'El código se mostrará una sola vez. Compártelo únicamente dentro de tu caso de soporte.',
    fields:[
      {name:'ticket_ref',label:'Referencia del caso (opcional)',placeholder:'Ej. KX-2026-0042',help:`Puedes obtenerla escribiendo a ${SUPPORT_EMAIL}.`},
      {name:'duration_minutes',label:'Duración',type:'select',required:true,value:'120',options:[{value:'30',label:'30 minutos'},{value:'120',label:'2 horas'},{value:'480',label:'8 horas'},{value:'1440',label:'24 horas'}]},
      {name:'support_read',label:'Permitir consulta para soporte',type:'checkbox',value:true,full:true},
      {name:'support_write',label:'Permitir correcciones técnicas',type:'checkbox',value:false,full:true},
      {name:'finance_read',label:'Permitir consultar Finanzas',type:'checkbox',value:false,full:true},
      {name:'documents_read',label:'Permitir consultar documentos privados',type:'checkbox',value:false,full:true},
      {name:'minors_read',label:'Permitir consultar datos de menores',type:'checkbox',value:false,full:true}
    ],
    submitText:'Generar autorización',
    onSubmit:async v=>{
      const scopes=[];if(v.support_read!==false)scopes.push('support.read');if(v.support_write===true)scopes.push('support.write');if(v.finance_read===true)scopes.push('finance.read');if(v.documents_read===true)scopes.push('documents.read');if(v.minors_read===true)scopes.push('minors.read');
      const out=await repos.supportPrivacy.create({subject_type:subjectType,subject_id:id,ticket_ref:v.ticket_ref||'',duration_minutes:Number(v.duration_minutes||120),scopes});
      setTimeout(()=>{const detail=openDetail({title:'Autorización creada',subtitle:'Este código solo se muestra ahora',width:'620px',body:`<div class="kx-support-code"><span>CÓDIGO TEMPORAL</span><strong>${esc(out.code||'')}</strong><p>Válido hasta ${dtFmt(out.expires_at)}.</p><small>Envíalo únicamente dentro de tu conversación con ${SUPPORT_EMAIL}. Puedes revocarlo en cualquier momento desde Privacidad y soporte.</small></div>`});detail.wrap.querySelector('.kx-support-code strong')?.addEventListener('click',async()=>{try{await navigator.clipboard.writeText(String(out.code||''));toast('Código copiado')}catch{}});},250);
    }
  }));
  wrap.querySelectorAll('[data-kx-revoke-support]').forEach(button=>button.addEventListener('click',async()=>{button.disabled=true;try{await repos.supportPrivacy.revoke(button.dataset.kxRevokeSupport);toast('Autorización revocada');wrap.remove();await openSupportPrivacyCenter({subjectType,subjectId:id,title,canAuthorize});}catch(error){button.disabled=false;toast(humanError(error),'error');}}));
}

export function supportQuickRow({subjectType='account',subjectId=null,canAuthorize=true}={}){
  const mailSubject=encodeURIComponent('Soporte KOMBAX');
  return quickRow(icon('shieldCheck'),'Privacidad y soporte',`Soporte KOMBAX es el canal humano para plataforma, cuenta, privacidad, seguridad y cuestiones formales. Contacto general: ${SUPPORT_EMAIL}. KOMBAX Assist queda separado como copiloto de gestión.`,`<a class="btn btn-primary btn-sm" href="mailto:${SUPPORT_EMAIL}?subject=${mailSubject}">${icon('mail',{size:15})} Escribir correo</a><button type="button" class="btn btn-ghost btn-sm" data-kx-open-support-privacy="${esc(subjectType)}" data-kx-support-subject-id="${esc(subjectId||'')}">Privacidad y acceso</button>`);
}
