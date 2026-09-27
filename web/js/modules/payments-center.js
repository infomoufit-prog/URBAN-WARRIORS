import { t } from '../i18n/index.js';
import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { openDetail, toast, setError } from '../ui/components.js';

export const PAYMENTS_GUIDE_URL='./assets/docs/GUIA_KOMBAX_COBROS_TAP_TO_PAY_IPHONE_R81.pdf';
const active=value=>String(value||'').toLowerCase()==='active';
const subjectLabel=type=>({club:t('payments.subjectClub'),federation:t('payments.subjectFederation'),showcase_provider:t('payments.subjectBrand'),event_organizer:t('payments.subjectOrganizer')})[type]||type;

if(!window.__kombaxTerminalTokenBridgeInstalled){
  window.__kombaxTerminalTokenBridgeInstalled=true;
  window.addEventListener('kombax-terminal-token-request',async event=>{
    const subjectType=event?.detail?.subject_type,subjectId=event?.detail?.subject_id;if(!subjectType||!subjectId)return;
    try{const token=await repos.payments.terminalConnectionToken(subjectType,subjectId);if(window.UrbanWarriorsNative?.provideTapToPayConnectionToken)window.UrbanWarriorsNative.provideTapToPayConnectionToken(token.secret);else window.webkit?.messageHandlers?.kombaxTerminal?.postMessage?.({action:'connectionToken',token:token.secret,location_id:token.location_id});}catch(error){setError(error);}
  });
}
const pill=(label,on,detail='')=>`<span class="kx-payment-pill ${on?'is-on':'is-off'}"><b>${esc(label)}</b>${detail?`<small>${esc(detail)}</small>`:''}</span>`;
const capability=(value)=>active(value)?t('payments.capabilityActive'):t('payments.capabilityPending');

function nativeTerminal(){
  if(window.UrbanWarriorsNative?.startTapToPay)return 'android';
  if(window.webkit?.messageHandlers?.kombaxTerminal)return 'ios';
  return '';
}
function androidDeviceStatus(){
  try{return JSON.parse(window.UrbanWarriorsNative?.getTapToPayDeviceStatus?.()||'{}');}catch{return {};}
}
function deviceNote(){
  const platform=nativeTerminal();
  if(platform==='android'){
    const state=androidDeviceStatus();
    if(state.supported===true)return t('payments.tapDeviceReady');
    if(state.permission_granted===false)return t('payments.tapPermissionNeeded');
    return t('payments.tapDeviceUnsupported');
  }
  if(platform==='ios')return t('payments.tapDeviceReady');
  if(/iPhone|iPad|iPod/i.test(navigator.userAgent))return t('payments.tapIosWebFallback');
  return t('payments.tapWebFallback');
}

const methodCard=(kind,status,{available=true,body='',note=''})=>{
  const enabled=kind==='card'?status?.card_enabled!==false:kind==='sepa'?status?.sepa_enabled===true:status?.tap_to_pay_enabled===true;
  const cap=kind==='sepa'?status?.sepa_capability_status:kind==='tap'?(status?.terminal_ready===true?'active':'pending'):status?.card_capability_status;
  const title=kind==='card'?t('payments.cardTitle'):kind==='sepa'?t('payments.sepaTitle'):t('payments.tapTitle');
  const icon=kind==='card'?'💳':kind==='sepa'?'🏦':'📱';
  const meta=kind==='sepa'?pill(`${t('payments.mandates')}: ${Number(status?.active_mandates||0)}`,Number(status?.active_mandates||0)>0):kind==='tap'?pill(status?.terminal_location_configured?t('payments.tapLocationReady'):t('payments.tapLocationPending'),status?.terminal_location_configured===true):'';
  const action=kind==='tap'&&enabled?`<button type="button" class="btn btn-primary btn-sm" data-kx-terminal-open ${available?'':'disabled'}>${esc(t('payments.tapCharge'))}</button>`:'';
  const displayState=enabled?(active(cap)?t('payments.enabled'):t('payments.capabilityPending')):t('payments.disabled');
  return `<article class="kx-payment-method ${kind} ${enabled?'is-enabled':''}"><div class="kx-payment-method-icon" aria-hidden="true">${icon}</div><div class="kx-payment-method-copy"><span>${esc(displayState)}</span><h3>${esc(title)}</h3><p>${esc(body)}</p>${note?`<small>${esc(note)}</small>`:''}<div class="kx-payment-method-meta">${pill(capability(cap),active(cap))}${meta}</div>${action}</div><button type="button" class="btn ${enabled?'btn-ghost':'btn-primary'}" data-kx-payment-toggle="${kind}" ${available?'':'disabled'}>${esc(enabled?t('payments.disable'):t('payments.enable'))}</button></article>`;
};

export function paymentCenterSummaryHtml(status={},options={}){
  const {subjectType='club',title=t('payments.title'),compact=false}=options;
  const connected=status?.stripe_account_connected===true||status?.status&&status.status!=='not_configured';
  const ready=status?.status==='active'&&status?.payouts_enabled===true;
  const backendReady=status?.backend_pending!==true;
  const sepaAllowed=Array.isArray(status?.use_cases)?status.use_cases.some(value=>String(value).includes('sepa')):['club','federation'].includes(subjectType);
  const sepaNote=sepaAllowed?(subjectType==='club'?t('payments.clubSepa'):t('payments.genericSepa')):t('payments.sepaUnavailable');
  const tapAvailable=backendReady&&status?.terminal_ready===true;
  return `<section class="kx-payments-center ${compact?'is-compact':''}" data-kx-payments-center>${backendReady?'':`<div class="alert alert-warning" style="margin:0 0 14px"><strong>${esc(t('payments.backendPendingTitle'))}</strong><span>${esc(t('payments.backendPendingBody'))}</span></div>`}<div class="kx-payments-head"><div><span>${esc(t('payments.kicker'))}</span><h2>${esc(title)}</h2><p>${esc(t('payments.subtitle'))}</p></div><div class="kx-payments-identity"><small>${esc(subjectLabel(subjectType))}</small><strong>${esc(ready?t('payments.ready'):connected?t('payments.needsAction'):t('payments.notConnected'))}</strong></div></div><div class="kx-payment-account-strip">${pill(t('payments.stripeAccount'),connected,connected?t('payments.connected'):t('payments.notConnected'))}${pill(t('payments.payouts'),status?.payouts_enabled===true,status?.payouts_enabled?t('payments.enabled'):t('payments.disabled'))}<button type="button" class="btn btn-ghost btn-sm" data-kx-connect>${esc(connected?t('payments.reviewStripe'):t('payments.configureStripe'))}</button></div><div class="kx-payment-methods">${methodCard('card',status,{available:backendReady,body:t('payments.cardBody')})}${methodCard('sepa',status,{available:backendReady&&sepaAllowed,body:t('payments.sepaBody'),note:sepaNote})}${methodCard('tap',status,{available:tapAvailable,body:t('payments.tapBody'),note:deviceNote()})}</div><div class="kx-payment-safety"><div><strong>${esc(t('payments.direct'))}</strong><p>${esc(t('payments.security'))}</p><p>${esc(t('payments.tapSecurity'))}</p></div><div class="row-actions"><button type="button" class="btn btn-ghost" data-kx-payments-guide>${esc(t('payments.guide'))}</button><button type="button" class="btn btn-primary" data-kx-payments-assist>${esc(t('payments.assist'))}</button></div></div></section>`;
}

export async function loadPaymentCenterStatus(subjectType,subjectId){return await repos.payments.paymentMethodsStatus(subjectType,subjectId);}

function posFormHtml(subjectType,status){
  const native=nativeTerminal();
  const nativeLabel=native==='android'?t('payments.tapAndroid'):native==='ios'?t('payments.tapIphone'):t('payments.tapNoNative');
  const locationFields=status?.terminal_location_configured?'':`<div class="kx-pos-location"><h4>${esc(t('payments.tapLocationTitle'))}</h4><p>${esc(t('payments.tapLocationBody'))}</p><div class="form-grid"><label>${esc(t('payments.tapLocationName'))}<input name="display_name" maxlength="100" required></label><label>${esc(t('payments.tapAddress'))}<input name="address_line1" maxlength="180" required></label><label>${esc(t('payments.tapCity'))}<input name="city" maxlength="100" required></label><label>${esc(t('payments.tapPostal'))}<input name="postal_code" maxlength="24" required></label></div></div>`;
  return `<form class="kx-pos-form" data-kx-pos-form><div class="kx-pos-hero"><div><span>${esc(t('payments.tapKicker'))}</span><h3>${esc(t('payments.tapChargeTitle'))}</h3><p>${esc(t('payments.tapChargeBody'))}</p></div><div class="kx-pos-device"><small>${esc(t('payments.tapDevice'))}</small><strong>${esc(nativeLabel)}</strong><span>${esc(deviceNote())}</span></div></div><div class="form-grid"><label>${esc(t('payments.tapAmount'))}<div class="kx-money-input"><input name="amount" type="number" min="0.50" step="0.01" inputmode="decimal" required><span>€</span></div></label><label>${esc(t('payments.tapConcept'))}<input name="concept" maxlength="180" required placeholder="${esc(t('payments.tapConceptPlaceholder'))}"></label><label>${esc(t('payments.tapSource'))}<select name="source_kind"><option value="generic">${esc(t('payments.tapSourceGeneric'))}</option>${subjectType==='club'?`<option value="club_fee">${esc(t('payments.tapSourceFee'))}</option>`:''}${subjectType==='showcase_provider'?`<option value="showcase">${esc(t('payments.tapSourceShowcase'))}</option>`:''}${subjectType==='event_organizer'?`<option value="event_ticket">${esc(t('payments.tapSourceEvent'))}</option>`:''}${subjectType==='federation'?`<option value="federation_service">${esc(t('payments.tapSourceFederation'))}</option>`:''}</select></label><label>${esc(t('payments.tapReference'))}<input name="reference_id" placeholder="UUID ${esc(t('payments.optional'))}"></label></div>${locationFields}<div class="kx-pos-actions">${native?`<button type="button" class="btn btn-primary" data-kx-pos-native>${esc(t('payments.tapChargePhone'))}</button>`:`<button type="button" class="btn btn-primary" data-kx-pos-native disabled>${esc(t('payments.tapChargePhone'))}</button>`}<button type="button" class="btn btn-ghost" data-kx-pos-qr>${esc(t('payments.tapGenerateQr'))}</button></div><div class="kx-pos-result" data-kx-pos-result aria-live="polite"></div></form>`;
}

function formPayload(form,subjectType,subjectId){
  const data=new FormData(form);const amount=Math.round(Number(data.get('amount')||0)*100);const reference=String(data.get('reference_id')||'').trim();
  if(!Number.isFinite(amount)||amount<50)throw new Error(t('payments.tapAmountInvalid'));
  const concept=String(data.get('concept')||'').trim();if(!concept)throw new Error(t('payments.tapConceptRequired'));
  return {subject_type:subjectType,subject_id:subjectId,amount_minor:amount,concept,source_kind:String(data.get('source_kind')||'generic'),reference_id:reference||null};
}
function locationPayload(form,subjectType,subjectId){const d=new FormData(form);return {subject_type:subjectType,subject_id:subjectId,display_name:String(d.get('display_name')||'').trim(),address_line1:String(d.get('address_line1')||'').trim(),city:String(d.get('city')||'').trim(),postal_code:String(d.get('postal_code')||'').trim(),country:'ES'};}
function posMessage(container,kind,title,body=''){container.innerHTML=`<div class="kx-pos-message ${kind}"><strong>${esc(title)}</strong>${body?`<p>${esc(body)}</p>`:''}</div>`;}

async function waitNativeResult(saleId,timeout=120000){
  return await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{cleanup();reject(new Error(t('payments.tapTimeout')));},timeout);const handler=event=>{if(event?.detail?.sale_id&&event.detail.sale_id!==saleId)return;cleanup();event?.detail?.ok?resolve(event.detail):reject(new Error(event?.detail?.message||event?.detail?.error||t('payments.tapFailed')));};const cleanup=()=>{clearTimeout(timer);window.removeEventListener('kombax-tap-to-pay-result',handler);};window.addEventListener('kombax-tap-to-pay-result',handler);});
}
async function startNativeTap(payload){
  const platform=nativeTerminal();if(!platform)throw new Error(t('payments.tapNativeRequired'));
  if(platform==='android'){
    const state=androidDeviceStatus();if(state.permission_granted===false){window.UrbanWarriorsNative?.requestTapToPayPermissions?.();throw new Error(t('payments.tapPermissionNeeded'));}
    window.UrbanWarriorsNative.startTapToPay(JSON.stringify(payload));
  }else window.webkit.messageHandlers.kombaxTerminal.postMessage({action:'startTapToPay',...payload});
}

export async function openInPersonPayment({subjectType,subjectId,status:initialStatus}={}){
  let status=initialStatus||await repos.payments.paymentMethodsStatus(subjectType,subjectId);
  const modal=openDetail({title:t('payments.tapChargeTitle'),subtitle:t('payments.tapChargeBody'),className:'kx-pos-modal',body:posFormHtml(subjectType,status)});
  const form=modal.wrap.querySelector('[data-kx-pos-form]'),result=modal.wrap.querySelector('[data-kx-pos-result]');
  const setBusy=busy=>modal.wrap.querySelectorAll('[data-kx-pos-native],[data-kx-pos-qr]').forEach(b=>b.disabled=busy||(b.hasAttribute('data-kx-pos-native')&&!nativeTerminal()));
  const ensureLocation=async()=>{if(status?.terminal_location_configured)return status;const lp=locationPayload(form,subjectType,subjectId);if(!lp.display_name||!lp.address_line1||!lp.city||!lp.postal_code)throw new Error(t('payments.tapLocationRequired'));await repos.payments.terminalEnsureLocation(lp);status=await repos.payments.paymentMethodsStatus(subjectType,subjectId);return status;};
  modal.wrap.querySelector('[data-kx-pos-native]')?.addEventListener('click',async()=>{setBusy(true);try{const base=formPayload(form,subjectType,subjectId);await ensureLocation();const token=await repos.payments.terminalConnectionToken(subjectType,subjectId);const platform=nativeTerminal();const intent=await repos.payments.terminalCreateIntent({...base,channel:platform==='ios'?'tap_to_pay_ios':'tap_to_pay_android'});posMessage(result,'processing',t('payments.tapWaiting'),t('payments.tapWaitingBody'));await startNativeTap({sale_id:intent.sale_id,client_secret:intent.client_secret,connection_token:token.secret,location_id:token.location_id,stripe_account_id:token.stripe_account_id,subject_type:subjectType,subject_id:subjectId});await waitNativeResult(intent.sale_id);posMessage(result,'success',t('payments.tapSucceeded'),t('payments.tapSucceededBody'));toast(t('payments.tapSucceeded'));}catch(error){setError(error);posMessage(result,'error',t('payments.tapFailed'),error?.message||t('payments.tapFailed'));}finally{setBusy(false);}});
  modal.wrap.querySelector('[data-kx-pos-qr]')?.addEventListener('click',async()=>{setBusy(true);try{const base=formPayload(form,subjectType,subjectId);const out=await repos.payments.terminalWebFallback(base);result.innerHTML=`<div class="kx-pos-qr"><img src="${esc(out.qr_data_url)}" alt="${esc(t('payments.tapQrAlt'))}"><div><strong>${esc(t('payments.tapQrReady'))}</strong><p>${esc(t('payments.tapQrBody'))}</p><div class="row-actions"><a class="btn btn-primary" href="${esc(out.url)}" target="_blank" rel="noopener noreferrer">${esc(t('payments.tapOpenLink'))}</a><button type="button" class="btn btn-ghost" data-kx-copy-link>${esc(t('payments.tapCopyLink'))}</button></div></div></div>`;result.querySelector('[data-kx-copy-link]')?.addEventListener('click',async()=>{await navigator.clipboard?.writeText(out.url);toast(t('payments.tapLinkCopied'));});}catch(error){setError(error);posMessage(result,'error',t('payments.tapFailed'),error?.message||t('payments.tapFailed'));}finally{setBusy(false);}});
  return modal;
}

export function bindPaymentCenter(root,{subjectType,subjectId,onRefresh,assistContext={}}={}){
  if(!root||!subjectType||!subjectId)return;
  root.querySelectorAll('[data-kx-connect]').forEach(button=>button.addEventListener('click',async()=>{button.disabled=true;try{const out=await repos.payments.connectOnboarding(subjectType,subjectId);if(!out?.url)throw new Error('STRIPE_CONNECT_URL_MISSING');location.assign(out.url);}catch(error){button.disabled=false;setError(error);toast(t('payments.connectError'),'error');}}));
  root.querySelectorAll('[data-kx-payment-toggle]').forEach(button=>button.addEventListener('click',async()=>{const method=button.dataset.kxPaymentToggle;button.disabled=true;try{const current=await repos.payments.paymentMethodsStatus(subjectType,subjectId);const enabled=method==='card'?current?.card_enabled!==false:method==='sepa'?current?.sepa_enabled===true:current?.tap_to_pay_enabled===true;if(method==='tap')await repos.payments.terminalToggle(subjectType,subjectId,!enabled);else await repos.payments.paymentMethodToggle(subjectType,subjectId,method,!enabled);toast(t('payments.saved'));if(onRefresh)await onRefresh();}catch(error){button.disabled=false;setError(error);toast(t('payments.toggleError'),'error');}}));
  root.querySelectorAll('[data-kx-terminal-open]').forEach(button=>button.addEventListener('click',async()=>{button.disabled=true;try{const status=await repos.payments.paymentMethodsStatus(subjectType,subjectId);await openInPersonPayment({subjectType,subjectId,status});}catch(error){setError(error);toast(t('payments.tapFailed'),'error');}finally{button.disabled=false;}}));
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
