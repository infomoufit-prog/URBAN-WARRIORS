import {backend} from '../core/backend.js';
import {openDetail,toast} from '../ui/components.js';
import {esc,humanError} from '../core/utils.js';
import {t} from '../i18n/index.js';
function checkoutDestination(url){const u=new URL(url);if(u.protocol!=='https:'||!['checkout.stripe.com','billing.stripe.com'].includes(u.hostname))throw Error('INVALID_BILLING_URL');return u.href;}
export async function openOrganizationBilling(subjectType,subjectId){
 try{
  const context=await backend.globalReadRpc('app_kombax_billing_context_r118',{p_subject_type:subjectType,p_subject_id:subjectId});
  if(context.pilot){openDetail({title:t('marketing.space.servicesSubscriptions'),body:`<p>${esc(t('marketing.space.pilotActive'))}</p>`});return;}
  const sub=context.subscription,ongoing=sub&&!['canceled','incomplete_expired'].includes(sub.status),plans=context.plans||[],available=plans.filter(p=>p.available);
  const message=!context.verified?t('marketing.space.billingVerify'):!available.length?t('marketing.space.billingPending'):t('marketing.space.billingConsent');
  const {wrap}=openDetail({title:t('marketing.space.servicesSubscriptions'),body:`<p>${esc(message)}</p>${sub?`<p>${esc(sub.status)}${sub.trial_end?` · ${esc(t('marketing.space.trialUntil'))} ${esc(new Date(sub.trial_end).toLocaleDateString())}`:''}${sub.cancel_at_period_end?` · ${esc(t('marketing.space.billingCancels'))}`:''}</p><button class="btn btn-primary" id="kx-billing-portal">${esc(t('marketing.space.billingManage'))}</button>`:''}${!ongoing&&context.verified&&available.length?`<label>${esc(t('marketing.space.billingPlan'))}<select id="kx-billing-plan">${available.map(p=>`<option value="${esc(p.code)}">${esc(p.code)} · ${esc(new Intl.NumberFormat(undefined,{style:'currency',currency:p.currency}).format(p.amount_minor/100))} / ${esc(t('marketing.space.billingMonth'))}</option>`).join('')}</select></label><label><input type="checkbox" id="kx-billing-consent"> ${esc(t('marketing.space.billingConsent'))}</label><button class="btn btn-primary" id="kx-billing-checkout">${esc(t('marketing.space.billingContinue'))}</button>`:''}`});
  const redirect=async(action,plan)=>{const result=await backend.invokeFunction('stripe-subscriptions',{action,subject_type:subjectType,subject_id:subjectId,...(plan?{plan_code:plan.code,terms_version:plan.terms_version,consent:true}:{})},35000);if(!result?.ok||!result.url)throw Error(result?.error||'BILLING_UNAVAILABLE');location.assign(checkoutDestination(result.url));};
  wrap.querySelector('#kx-billing-portal')?.addEventListener('click',async e=>{e.currentTarget.disabled=true;try{await redirect('portal');}catch(error){e.currentTarget.disabled=false;toast(humanError(error),'error');}});
  wrap.querySelector('#kx-billing-checkout')?.addEventListener('click',async e=>{if(!wrap.querySelector('#kx-billing-consent').checked){toast(t('marketing.space.billingConsent'),'error');return;}const plan=available.find(p=>p.code===wrap.querySelector('#kx-billing-plan').value);e.currentTarget.disabled=true;try{await redirect('checkout',plan);}catch(error){e.currentTarget.disabled=false;toast(humanError(error),'error');}});
 }catch(error){toast(humanError(error),'error');}
}

export async function mountOwnedBilling(section){
 if(!section)return;
 try{
  const rows=await backend.globalReadRpc('app_kombax_billing_mine_r118',{});
  if(!section.isConnected||!Array.isArray(rows)||!rows.length)return;
  const panel=document.createElement('div');panel.className='kx-profile-owned-grid';
  panel.innerHTML=rows.map((row,i)=>`<article class="kx-profile-owned"><h3>${esc(row.plan_code)}</h3><p>${esc(row.status)}${row.cancel_at_period_end?` · ${esc(t('marketing.space.billingCancels'))}`:''}</p><button class="btn btn-ghost" data-owned-billing="${i}">${esc(t('marketing.space.billingManage'))}</button></article>`).join('');
  panel.querySelectorAll('[data-owned-billing]').forEach(button=>button.addEventListener('click',()=>{const row=rows[Number(button.dataset.ownedBilling)];openOrganizationBilling(row.subject_type,row.subject_id);}));section.append(panel);
 }catch(error){console.warn('Billing list unavailable',error);}
}
