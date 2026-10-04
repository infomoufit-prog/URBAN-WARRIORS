import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,cors,env,json,serviceRpc,userRpc} from '../_shared/stripe.ts';
import {billingStripe,billingConfigured,billingAccount} from '../_shared/billing.ts';
import {validateRecurringPrice} from '../_shared/billing-policy.js';
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
 const user=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
 if(!billingConfigured())return json(503,{ok:false,error:'billing_not_configured'});
 let body;try{body=await request.json();}catch{return json(400,{ok:false,error:'invalid_json'});}
 if(!['club','direct_profile'].includes(body.subject_type)||!/^[0-9a-f-]{36}$/i.test(body.subject_id||''))return json(400,{ok:false,error:'invalid_subject'});
 try{
  await billingAccount();const appUrl=env().appUrl;
  if(body.action==='portal'){
   const prepared=await userRpc(request,'app_kombax_billing_portal_r118',{p_subject_type:body.subject_type,p_subject_id:body.subject_id});
   const session=await billingStripe('billing_portal/sessions','POST',{customer:prepared.customer_id,return_url:appUrl+'/?billing=return'});
   return json(200,{ok:true,url:session.url});
  }
  if(body.action!=='checkout'||body.consent!==true)return json(400,{ok:false,error:'renewal_consent_required'});
  if(Deno.env.get('STRIPE_BILLING_TAX_READY')!=='true')return json(503,{ok:false,error:'billing_tax_not_configured'});
  let prepared=await userRpc(request,'app_kombax_billing_prepare_r118',{p_subject_type:body.subject_type,p_subject_id:body.subject_id,p_plan_code:body.plan_code,p_terms_version:body.terms_version,p_consent:true});
  if(prepared.session_id){
   const prior=await billingStripe('checkout/sessions/'+prepared.session_id);
   if(prior.status==='open')return json(200,{ok:true,url:prior.url,session_id:prior.id});
   if(prior.status==='complete')return json(409,{ok:false,error:'checkout_completed_wait_for_confirmation'});
   if(prior.status!=='expired')throw new Error('CHECKOUT_PENDING');
   await serviceRpc('app_kombax_billing_expire_internal_r118',{p_request_id:prepared.request_id});
   prepared=await userRpc(request,'app_kombax_billing_prepare_r118',{p_subject_type:body.subject_type,p_subject_id:body.subject_id,p_plan_code:body.plan_code,p_terms_version:body.terms_version,p_consent:true});
  }
  const price=await billingStripe('prices/'+prepared.price_id);validateRecurringPrice(price,prepared);
  const form:Record<string,unknown>={mode:'subscription',payment_method_collection:'always','line_items[0][price]':prepared.price_id,'line_items[0][quantity]':1,'automatic_tax[enabled]':true,'billing_address_collection':'required',customer_email:user.email,success_url:appUrl+'/?billing=success&session_id={CHECKOUT_SESSION_ID}',cancel_url:appUrl+'/?billing=cancelled','metadata[kombax_request_id]':prepared.request_id,'subscription_data[metadata][kombax_request_id]':prepared.request_id,'subscription_data[metadata][kombax_billing]':'r118','custom_text[submit][message]':'Aceptas el precio y la renovación mostrados. Puedes cancelar desde Mis servicios antes del primer cobro.','integration_identifier':'kombax-billing-r118-'+String(prepared.request_id).replace(/-/g,'').slice(0,8).split('').map(c=>String.fromCharCode(97+parseInt(c,16))).join('')};
  if(prepared.trial_days>0){form['subscription_data[trial_period_days]']=prepared.trial_days;form['subscription_data[trial_settings][end_behavior][missing_payment_method]']='cancel';}
  const session=await billingStripe('checkout/sessions','POST',form,'kombax-subscription-'+prepared.request_id);
  await serviceRpc('app_kombax_billing_session_internal_r118',{p_request_id:prepared.request_id,p_session_id:session.id});
  return json(200,{ok:true,url:session.url,session_id:session.id});
 }catch(error){console.error('stripe-subscriptions',(error instanceof Error?error.message:'billing_error'));return json(409,{ok:false,error:String((error instanceof Error?error.message:'billing_error')||'subscription_request_failed')});}
});
