import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,cors,env,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

function uuid(value:unknown){return /^[0-9a-f-]{36}$/i.test(String(value||''))?String(value):'';}

Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const cfg=env();
  if(!cfg.supabaseUrl||!cfg.publishableKey||!cfg.secretKey||!cfg.stripeConnectKey||!cfg.appUrl)return json(503,{ok:false,error:'sepa_not_configured'});
  const user=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await request.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const action=String(body.action||'');const feeId=uuid(body.fee_id);const requestId=uuid(body.request_id)||crypto.randomUUID();
  if(!feeId||!['setup','charge_fee'].includes(action))return json(400,{ok:false,error:'invalid_sepa_request'});
  try{
    if(action==='setup'){
      const prepared=await serviceRpc('app_stripe_sepa_setup_prepare_internal_r80',{p_actor_id:user.id,p_fee_id:feeId,p_request_id:requestId});
      const account=String(prepared?.stripe_account_id||'');if(!/^acct_[A-Za-z0-9]+$/.test(account))throw new Error('CONNECTED_ACCOUNT_REQUIRED');
      let customer=String(prepared?.stripe_customer_id||'');
      if(!/^cus_[A-Za-z0-9]+$/.test(customer)){
        const created=await stripe('customers','POST',{email:prepared?.payer_email||user.email||undefined,name:prepared?.payer_name||undefined,'metadata[kombax_payer_user_id]':user.id},account,{idempotencyKey:`kombax-sepa-customer-${prepared.connected_account_id}-${user.id}`});
        customer=String(created?.id||'');if(!/^cus_[A-Za-z0-9]+$/.test(customer))throw new Error('STRIPE_CUSTOMER_CREATE_FAILED');
        await serviceRpc('app_stripe_connected_customer_upsert_internal_r80',{p_connected_account_id:prepared.connected_account_id,p_payer_user_id:user.id,p_stripe_customer_id:customer,p_email:prepared?.payer_email||user.email||'',p_name:prepared?.payer_name||''});
      }
      const attemptId=String(prepared.attempt_id);
      const session=await stripe('checkout/sessions','POST',{
        mode:'setup',customer,'payment_method_types[0]':'sepa_debit','locale':'auto',
        success_url:`${cfg.appUrl}/?sepa=setup_success&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url:`${cfg.appUrl}/?sepa=setup_cancelled`,
        'setup_intent_data[metadata][attempt_id]':attemptId,'setup_intent_data[metadata][kind]':'club_fee_sepa_setup',
        'setup_intent_data[metadata][fee_id]':feeId,'metadata[attempt_id]':attemptId,'metadata[kind]':'club_fee_sepa_setup'
      },account,{idempotencyKey:`kombax-sepa-setup-${attemptId}`});
      await serviceRpc('app_stripe_attempt_attach_internal_v259',{p_attempt_id:attemptId,p_checkout_session_id:session.id,p_payment_intent_id:null,p_setup_intent_id:session.setup_intent||null});
      return json(200,{ok:true,url:session.url,session_id:session.id,request_id:requestId});
    }

    const prepared=await serviceRpc('app_stripe_sepa_charge_prepare_internal_r80',{p_actor_id:user.id,p_fee_id:feeId,p_request_id:requestId});
    const account=String(prepared?.stripe_account_id||'');if(!/^acct_[A-Za-z0-9]+$/.test(account))throw new Error('CONNECTED_ACCOUNT_REQUIRED');
    const attemptId=String(prepared.attempt_id);
    const intent=await stripe('payment_intents','POST',{
      amount:String(prepared.amount_minor),currency:prepared.currency||'eur',customer:prepared.stripe_customer_id,payment_method:prepared.stripe_payment_method_id,
      confirm:'true',off_session:'true','payment_method_types[0]':'sepa_debit','metadata[attempt_id]':attemptId,'metadata[kind]':'club_fee',
      'metadata[payment_method]':'sepa_debit','metadata[fee_id]':feeId
    },account,{idempotencyKey:`kombax-sepa-charge-${attemptId}`});
    await serviceRpc('app_stripe_payment_intent_attach_internal_r80',{p_attempt_id:attemptId,p_payment_intent_id:intent.id,p_status:String(intent.status||'processing')==='succeeded'?'succeeded':'processing'});
    return json(200,{ok:true,payment_intent_id:intent.id,status:intent.status||'processing',request_id:requestId});
  }catch(error){console.error('stripe-sepa',safeError(error));return json(422,{ok:false,error:'sepa_operation_failed',detail:safeError(error)});}
});
