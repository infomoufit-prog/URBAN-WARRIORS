import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import QRCode from 'npm:qrcode@1.5.4';
import {authenticatedUser,cors,env,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

const SUBJECTS=new Set(['club','showcase_provider','federation','event_organizer']);
const CHANNELS=new Set(['tap_to_pay_android','tap_to_pay_ios','web_qr']);
const SOURCES=new Set(['generic','club_fee','showcase','event_ticket','federation_service']);
const uuid=(value:unknown)=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value||''))?String(value):'';
const clean=(value:unknown,max=180)=>String(value||'').trim().slice(0,max);

async function prepare(userId:string,body:any,channel:string){
  const subjectType=clean(body.subject_type,40),subjectId=uuid(body.subject_id),requestId=uuid(body.request_id)||crypto.randomUUID();
  const amountMinor=Math.round(Number(body.amount_minor||0));const concept=clean(body.concept,180);
  const sourceKind=SOURCES.has(String(body.source_kind))?String(body.source_kind):'generic';const referenceId=uuid(body.reference_id)||null;
  if(!SUBJECTS.has(subjectType)||!subjectId||!CHANNELS.has(channel)||amountMinor<50||!concept)throw new Error('TERMINAL_REQUEST_INVALID');
  const out=await serviceRpc('app_stripe_terminal_sale_prepare_internal_r81',{
    p_actor_id:userId,p_subject_type:subjectType,p_subject_id:subjectId,p_request_id:requestId,p_amount_minor:amountMinor,p_concept:concept,p_source_kind:sourceKind,p_reference_id:referenceId,p_channel:channel
  });
  return {...out,subjectType,subjectId,requestId,sourceKind,referenceId};
}

Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const cfg=env();if(!cfg.supabaseUrl||!cfg.secretKey||!cfg.publishableKey||!cfg.stripeConnectKey||!cfg.appUrl)return json(503,{ok:false,error:'terminal_not_configured'});
  const user=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await request.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const action=String(body.action||'');
  try{
    if(action==='ensure_location'){
      const subjectType=clean(body.subject_type,40),subjectId=uuid(body.subject_id);
      if(!SUBJECTS.has(subjectType)||!subjectId)return json(400,{ok:false,error:'invalid_subject'});
      const ctx=await serviceRpc('app_stripe_terminal_context_internal_r81',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId,p_require_tap:true});
      if(ctx?.stripe_location_id)return json(200,{ok:true,location_id:ctx.location_id,stripe_location_id:ctx.stripe_location_id,reused:true});
      const displayName=clean(body.display_name,100),line1=clean(body.address_line1,180),city=clean(body.city,100),postal=clean(body.postal_code,24),country=(clean(body.country,2)||'ES').toUpperCase();
      if(!displayName||!line1||!city||!postal||!/^[A-Z]{2}$/.test(country))return json(400,{ok:false,error:'terminal_location_fields_required'});
      const location=await stripe('terminal/locations','POST',{'display_name':displayName,'address[line1]':line1,'address[city]':city,'address[postal_code]':postal,'address[country]':country},ctx.stripe_account_id,{idempotencyKey:`kombax-terminal-location-${subjectType}-${subjectId}`});
      const stored=await serviceRpc('app_stripe_terminal_location_upsert_internal_r81',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId,p_stripe_location_id:location.id,p_display_name:displayName,p_address_line1:line1,p_city:city,p_postal_code:postal,p_country:country});
      return json(200,{ok:true,...stored});
    }

    if(action==='connection_token'){
      const subjectType=clean(body.subject_type,40),subjectId=uuid(body.subject_id);
      if(!SUBJECTS.has(subjectType)||!subjectId)return json(400,{ok:false,error:'invalid_subject'});
      const ctx=await serviceRpc('app_stripe_terminal_context_internal_r81',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId,p_require_tap:true});
      if(!ctx?.stripe_location_id)throw new Error('TERMINAL_LOCATION_REQUIRED');
      const token=await stripe('terminal/connection_tokens','POST',{location:ctx.stripe_location_id},ctx.stripe_account_id);
      return json(200,{ok:true,secret:token.secret,location_id:ctx.stripe_location_id,stripe_account_id:ctx.stripe_account_id});
    }

    if(action==='create_intent'){
      const channel=String(body.channel||'tap_to_pay_android');if(!['tap_to_pay_android','tap_to_pay_ios'].includes(channel))return json(400,{ok:false,error:'invalid_native_channel'});
      const prepared=await prepare(user.id,body,channel);
      if(!prepared.stripe_location_id)throw new Error('TERMINAL_LOCATION_REQUIRED');
      const pi=await stripe('payment_intents','POST',{
        amount:String(prepared.amount_minor),currency:'eur','payment_method_types[0]':'card_present',capture_method:'automatic',description:prepared.concept,
        'metadata[terminal_sale_id]':prepared.sale_id,'metadata[attempt_id]':prepared.attempt_id,'metadata[subject_type]':prepared.subjectType,'metadata[subject_id]':prepared.subjectId,
        'metadata[source_kind]':prepared.sourceKind,'metadata[reference_id]':prepared.referenceId||'','metadata[channel]':channel
      },prepared.stripe_account_id,{idempotencyKey:`kombax-terminal-intent-${prepared.sale_id}`});
      await serviceRpc('app_stripe_terminal_sale_attach_internal_r81',{p_sale_id:prepared.sale_id,p_payment_intent_id:pi.id,p_checkout_session_id:null,p_status:'processing'});
      return json(200,{ok:true,sale_id:prepared.sale_id,payment_intent_id:pi.id,client_secret:pi.client_secret,location_id:prepared.stripe_location_id,stripe_account_id:prepared.stripe_account_id,amount_minor:prepared.amount_minor,currency:'eur'});
    }

    if(action==='web_fallback'){
      const prepared=await prepare(user.id,body,'web_qr');
      const success=`${cfg.appUrl}/?pos=success&sale_id=${encodeURIComponent(prepared.sale_id)}`;
      const cancel=`${cfg.appUrl}/?pos=cancelled&sale_id=${encodeURIComponent(prepared.sale_id)}`;
      const session=await stripe('checkout/sessions','POST',{
        mode:'payment','payment_method_types[0]':'card',success_url:success,cancel_url:cancel,
        'line_items[0][price_data][currency]':'eur','line_items[0][price_data][unit_amount]':String(prepared.amount_minor),'line_items[0][price_data][product_data][name]':prepared.concept,'line_items[0][quantity]':'1',
        'metadata[terminal_sale_id]':prepared.sale_id,'metadata[attempt_id]':prepared.attempt_id,'metadata[channel]':'web_qr',
        'payment_intent_data[metadata][terminal_sale_id]':prepared.sale_id,'payment_intent_data[metadata][attempt_id]':prepared.attempt_id,'payment_intent_data[metadata][subject_type]':prepared.subjectType,'payment_intent_data[metadata][subject_id]':prepared.subjectId,
        'payment_intent_data[metadata][source_kind]':prepared.sourceKind,'payment_intent_data[metadata][reference_id]':prepared.referenceId||'','payment_intent_data[metadata][channel]':'web_qr'
      },prepared.stripe_account_id,{idempotencyKey:`kombax-pos-qr-${prepared.sale_id}`});
      await serviceRpc('app_stripe_terminal_sale_attach_internal_r81',{p_sale_id:prepared.sale_id,p_payment_intent_id:session.payment_intent||null,p_checkout_session_id:session.id,p_status:'checkout_created'});
      const svg=await QRCode.toString(String(session.url),{type:'svg',errorCorrectionLevel:'M',margin:2,width:360,color:{dark:'#05070A',light:'#FFFFFF'}});
      const qrDataUrl=`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
      return json(200,{ok:true,sale_id:prepared.sale_id,url:session.url,session_id:session.id,qr_data_url:qrDataUrl,expires_at:session.expires_at});
    }

    return json(400,{ok:false,error:'unknown_action'});
  }catch(error){console.error('stripe-terminal',action,safeError(error));return json(422,{ok:false,error:'terminal_operation_failed',detail:safeError(error)});}
});
