import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {json,serviceRpc} from '../_shared/stripe.ts';
import {billingStripe,billingAccount} from '../_shared/billing.ts';
import {subscriptionIdForEvent,verifyBillingSignature} from '../_shared/billing-policy.js';
Deno.serve(async request=>{
 if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
 const secret=Deno.env.get('STRIPE_BILLING_WEBHOOK_SECRET');if(!secret)return json(503,{ok:false,error:'billing_webhook_not_configured'});
 const raw=await request.text();if(!await verifyBillingSignature(raw,request.headers.get('stripe-signature'),secret))return json(400,{ok:false,error:'invalid_signature'});
 let event;try{event=JSON.parse(raw);}catch{return json(400,{ok:false,error:'invalid_json'});}
 if(event.account)return json(400,{ok:false,error:'connected_events_not_allowed'});
 const id=subscriptionIdForEvent(event);if(!/^sub_[A-Za-z0-9]+$/.test(id||''))return json(200,{ok:true,ignored:true});
 try{
  await billingAccount();const syncAt=new Date().toISOString();
  const subscription=await billingStripe('subscriptions/'+id+'?expand[]=default_payment_method&expand[]=latest_invoice');
  const requestId=subscription.metadata?.kombax_request_id;if(!requestId||subscription.metadata?.kombax_billing!=='r118')return json(200,{ok:true,ignored:true});
  subscription.default_payment_method=typeof subscription.default_payment_method==='string'?subscription.default_payment_method:subscription.default_payment_method?.id||null;
  subscription.customer=typeof subscription.customer==='string'?subscription.customer:subscription.customer?.id;
  const result=await serviceRpc('app_kombax_billing_sync_internal_r118',{p_request_id:requestId,p_subscription:subscription,p_event_id:event.id,p_event_type:event.type,p_sync_at:syncAt});
  return json(200,result);
 }catch(error){console.error('stripe-billing-webhook',(error instanceof Error?error.message:'billing_error'));return json(500,{ok:false,error:'billing_event_apply_failed'});}
});
