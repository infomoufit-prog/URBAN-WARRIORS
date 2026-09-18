import { t } from '../i18n/index.js';
import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { openDetail, toast, setError } from '../ui/components.js';

export const PAYMENTS_GUIDE_URL='./assets/docs/GUIA_KOMBAX_COBROS_STRIPE_SEPA_R80.pdf';
const active=value=>String(value||'').toLowerCase()==='active';
const subjectLabel=type=>({club:t('payments.subjectClub'),federation:t('payments.subjectFederation'),showcase_provider:t('payments.subjectBrand'),event_organizer:t('payments.subjectOrganizer')})[type]||type;
const pill=(label,on,detail='')=>`<span class="kx-payment-pill ${on?'is-on':'is-off'}"><b>${esc(label)}</b>${detail?`<small>${esc(detail)}</small>`:''}</span>`;
const capability=(value)=>active(value)?t('payments.capabilityActive'):t('payments.capabilityPending');
const methodCard=(kind,status,{available=true,body='',note=''})=>{
  const enabled=kind==='card'?status?.card_enabled!==false:status?.sepa_enabled===true;
  const cap=kind==='card'?status?.card_capability_status:status?.sepa_capability_status;
  const title=kind==='card'?t('payments.cardTitle'):t('payments.sepaTitle');
  return `<article class="kx-payment-method ${kind} ${enabled?'is-enabled':''}"><div class="kx-payment-method-icon" aria-hidden="true">${kind==='card'?'💳':'🏦'}</div><div class="kx-payment-method-copy"><span>${esc(enabled?t('payments.enabled'):t('payments.disabled'))}</span><h3>${esc(title)}</h3><p>${esc(body)}</p>${note?`<small>${esc(note)}</small>`:''}<div class="kx-payment-method-meta">${pill(capability(cap),active(cap))}${kind==='sepa'?pill(`${t('payments.mandates')}: ${Number(status?.active_mandates||0)}`,Number(status?.active_mandates||0)>0):''}</div></div><button type="button" class="btn ${enabled?'btn-ghost':'btn-primary'}" data-kx-payment-toggle="${kind}" ${available?'':'disabled'}>${esc(enabled?t('payments.disable'):t('payments.enable'))}</button></article>`;
};

export function paymentCenterSummaryHtml(status={},options={}){
  const {subjectType='club',title=t('payments.title'),compact=false}=options;
  const connected=status?.stripe_account_connected===true||status?.status&&status.status!=='not_configured';
  const ready=status?.status==='active'&&status?.payouts_enabled===true;
  const sepaAllowed=Array.isArray(status?.use_cases)?status.use_cases.some(value=>String(value).includes('sepa')):['club','federation'].includes(subjectType);
  const sepaNote=sepaAllowed?(subjectType==='club'?t('payments.clubSepa'):t('payments.genericSepa')):t('payments.sepaUnavailable');
  return `<section class="kx-payments-center ${compact?'is-compact':''}" data-kx-payments-center><div class="kx-payments-head"><div><span>${esc(t('payments.kicker'))}</span><h2>${esc(title)}</h2><p>${esc(t('payments.subtitle'))}</p></div><div class="kx-payments-identity"><small>${esc(subjectLabel(subjectType))}</small><strong>${esc(ready?t('payments.ready'):connected?t('payments.needsAction'):t('payments.notConnected'))}</strong></div></div><div class="kx-payment-account-strip">${pill(t('payments.stripeAccount'),connected,connected?t('payments.connected'):t('payments.notConnected'))}${pill(t('payments.payouts'),status?.payouts_enabled===true,status?.payouts_enabled?t('payments.enabled'):t('payments.disabled'))}<button type="button" class="btn btn-ghost btn-sm" data-kx-connect>${esc(connected?t('payments.reviewStripe'):t('payments.configureStripe'))}</button></div><div class="kx-payment-methods">${methodCard('card',status,{body:t('payments.cardBody')})}${methodCard('sepa',status,{available:sepaAllowed,body:t('payments.sepaBody'),note:sepaNote})}</div><div class="kx-payment-safety"><div><strong>${esc(t('payments.direct'))}</strong><p>${esc(t('payments.security'))}</p><p>${esc(t('payments.immediateNote'))}</p></div><div class="row-actions"><button type="button" class="btn btn-ghost" data-kx-payments-guide>${esc(t('payments.guide'))}</button><button type="button" class="btn btn-primary" data-kx-payments-assist>${esc(t('payments.assist'))}</button></div></div></section>`;
}

export async function loadPaymentCenterStatus(subjectType,subjectId){return await repos.payments.paymentMethodsStatus(subjectType,subjectId);}

export function bindPaymentCenter(root,{subjectType,subjectId,onRefresh,assistContext={}}={}){
  if(!root||!subjectType||!subjectId)return;
  root.querySelectorAll('[data-kx-connect]').forEach(button=>button.addEventListener('click',async()=>{button.disabled=true;try{const out=await repos.payments.connectOnboarding(subjectType,subjectId);if(!out?.url)throw new Error('STRIPE_CONNECT_URL_MISSING');location.assign(out.url);}catch(error){button.disabled=false;setError(error);toast(t('payments.connectError'),'error');}}));
  root.querySelectorAll('[data-kx-payment-toggle]').forEach(button=>button.addEventListener('click',async()=>{const method=button.dataset.kxPaymentToggle;button.disabled=true;try{const current=await repos.payments.paymentMethodsStatus(subjectType,subjectId);const enabled=method==='card'?current?.card_enabled!==false:current?.sepa_enabled===true;await repos.payments.paymentMethodToggle(subjectType,subjectId,method,!enabled);toast(t('payments.saved'));if(onRefresh)await onRefresh();}catch(error){button.disabled=false;setError(error);toast(t('payments.toggleError'),'error');}}));
  root.querySelectorAll('[data-kx-payments-guide]').forEach(button=>button.addEventListener('click',()=>window.open(PAYMENTS_GUIDE_URL,'_blank','noopener,noreferrer')));
  root.querySelectorAll('[data-kx-payments-assist]').forEach(button=>button.addEventListener('click',async()=>{button.disabled=true;try{const {renderKombaxAssistHome}=await import('./customer-operations.js');await renderKombaxAssistHome(assistContext);}catch(error){setError(error);}finally{button.disabled=false;}}));
}

export async function openPaymentCenter({subjectType,subjectId,title=t('payments.title'),assistContext={}}={}){
  const status=await loadPaymentCenterStatus(subjectType,subjectId);
  const modal=openDetail({title,subtitle:t('payments.guideHint'),className:'kx-payments-modal',body:paymentCenterSummaryHtml(status,{subjectType,title})});
  const refresh=async()=>{modal.close();await openPaymentCenter({subjectType,subjectId,title,assistContext});};
  bindPaymentCenter(modal.wrap,{subjectType,subjectId,onRefresh:refresh,assistContext});
  return modal;
}
