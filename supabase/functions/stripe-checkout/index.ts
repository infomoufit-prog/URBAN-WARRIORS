import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,cors,env,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

const SUPPORTED_LOCALES=new Set(['es','en','fr','pt','it','de','th','fil']);
const STRIPE_LOCALE:Record<string,string>={es:'es',en:'en',fr:'fr',pt:'pt',it:'it',de:'de',th:'th',fil:'fil'};
const CHECKOUT_COPY:Record<string,{ticket:string;fee:string;payment:string;soldBy:string}>={
  es:{ticket:'Entrada KOMBAX Events',fee:'Gastos de gestión KOMBAX',payment:'Pago KOMBAX',soldBy:'Vendido por'},
  en:{ticket:'KOMBAX Events ticket',fee:'KOMBAX service fee',payment:'KOMBAX payment',soldBy:'Sold by'},
  fr:{ticket:'Billet KOMBAX Events',fee:'Frais de service KOMBAX',payment:'Paiement KOMBAX',soldBy:'Vendu par'},
  pt:{ticket:'Bilhete KOMBAX Events',fee:'Taxa de serviço KOMBAX',payment:'Pagamento KOMBAX',soldBy:'Vendido por'},
  it:{ticket:'Biglietto KOMBAX Events',fee:'Commissione di servizio KOMBAX',payment:'Pagamento KOMBAX',soldBy:'Venduto da'},
  de:{ticket:'KOMBAX Events-Ticket',fee:'KOMBAX-Servicegebühr',payment:'KOMBAX-Zahlung',soldBy:'Verkauft von'},
  th:{ticket:'บัตร KOMBAX Events',fee:'ค่าบริการ KOMBAX',payment:'การชำระเงิน KOMBAX',soldBy:'จำหน่ายโดย'},
  fil:{ticket:'KOMBAX Events ticket',fee:'KOMBAX service fee',payment:'KOMBAX payment',soldBy:'Ibinebenta ni'}
};
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED_LOCALES.has(raw)?raw:SUPPORTED_LOCALES.has(base)?base:'es';}

Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const cfg=env();if(!cfg.supabaseUrl||!cfg.publishableKey||!cfg.secretKey||!cfg.stripeConnectKey||!cfg.appUrl)return json(503,{ok:false,error:'connect_not_configured'});
  const user=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await request.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const kind=String(body.kind||''),referenceId=String(body.reference_id||''),requestId=String(body.request_id||crypto.randomUUID());
  const userLocale=normalizeLocale(body.user_locale),copy=CHECKOUT_COPY[userLocale]||CHECKOUT_COPY.es;
  if(!['club_fee','showcase_order','event_ticket'].includes(kind)||!/^[0-9a-f-]{36}$/i.test(referenceId)||!/^[0-9a-f-]{36}$/i.test(requestId))return json(400,{ok:false,error:'invalid_checkout'});
  try{
    if(kind==='showcase_order'||kind==='event_ticket'){
      await serviceRpc('app_kombax_checkout_adult_gate_r629',{p_actor_id:user.id,p_kind:kind});
    }
    if(kind==='showcase_order'){
      await serviceRpc('app_showcase_checkout_gate_r627',{p_actor_id:user.id,p_product_id:referenceId});
    }
    if(kind==='event_ticket'){
      await serviceRpc('app_event_ticket_checkout_gate_r628',{p_actor_id:user.id,p_event_id:referenceId});
    }
    const prepared=await serviceRpc('app_stripe_checkout_prepare_internal_v259',{p_actor_id:user.id,p_kind:kind,p_reference_id:referenceId,p_quantity:Number(body.quantity||1),p_request_id:requestId});
    const account=String(prepared.stripe_account_id||'');
    if(!/^acct_[A-Za-z0-9]+$/.test(account))throw new Error('CONNECTED_ACCOUNT_REQUIRED');
    if(prepared?.stripe_checkout_session_id){const existing=await stripe(`checkout/sessions/${prepared.stripe_checkout_session_id}`,'GET',{},account);return json(200,{ok:true,url:existing.url,session_id:existing.id,reused:true});}
    const attemptId=String(prepared.attempt_id);
    const form:Record<string,unknown>={
      mode:'payment',success_url:`${cfg.appUrl}/?payment=success&payment_kind=${encodeURIComponent(kind)}&session_id={CHECKOUT_SESSION_ID}`,cancel_url:`${cfg.appUrl}/?payment=cancelled&payment_kind=${encodeURIComponent(kind)}`,
      'payment_intent_data[metadata][attempt_id]':attemptId,'metadata[attempt_id]':attemptId,'metadata[kind]':kind,
      'payment_intent_data[metadata][seller_amount_minor]':String(prepared.seller_amount_minor||prepared.amount_minor||0),
      'payment_intent_data[metadata][buyer_service_fee_minor]':String(prepared.buyer_service_fee_minor||0),
      'payment_intent_data[metadata][platform_percentage_fee_minor]':String(prepared.platform_percentage_fee_minor||0),
      'customer_email':user.email||undefined,'locale':STRIPE_LOCALE[userLocale]||'auto','billing_address_collection':'auto'
    };
    if(kind==='event_ticket'){
      const qty=Math.max(1,Number(prepared.ticket_quantity||body.quantity||1));
      const unit=Math.max(0,Number(prepared.ticket_unit_amount_minor||0));
      const buyerFeeTotal=Math.max(0,Number(prepared.buyer_service_fee_minor||0));
      const buyerFeeUnit=qty>0?Math.round(buyerFeeTotal/qty):0;
      form['line_items[0][quantity]']=String(qty);
      form['line_items[0][price_data][currency]']=prepared.currency||'eur';
      form['line_items[0][price_data][unit_amount]']=String(unit);
      form['line_items[0][price_data][product_data][name]']=prepared.name||copy.ticket;
      if(buyerFeeUnit>0){
        form['line_items[1][quantity]']=String(qty);
        form['line_items[1][price_data][currency]']=prepared.currency||'eur';
        form['line_items[1][price_data][unit_amount]']=String(buyerFeeUnit);
        form['line_items[1][price_data][product_data][name]']=copy.fee;
      }
    }else{
      form['line_items[0][quantity]']='1';
      form['line_items[0][price_data][currency]']=prepared.currency||'eur';
      form['line_items[0][price_data][unit_amount]']=String(prepared.amount_minor);
      form['line_items[0][price_data][product_data][name]']=prepared.name||copy.payment;
    }
    const applicationFee=Math.max(0,Number(prepared.platform_fee_minor||0));
    if(applicationFee>0)form['payment_intent_data[application_fee_amount]']=String(applicationFee);
    if(prepared.collect_shipping===true){
      form['shipping_address_collection[allowed_countries][0]']='ES';
      form['shipping_address_collection[allowed_countries][1]']='PT';
      form['shipping_address_collection[allowed_countries][2]']='FR';
      form['phone_number_collection[enabled]']='true';
    }
    if(prepared.seller_name)form['line_items[0][price_data][product_data][description]']=`${copy.soldBy}: ${prepared.seller_name}`;
    const session=await stripe('checkout/sessions','POST',form,account,{idempotencyKey:`kombax-checkout-${attemptId}`});
    await serviceRpc('app_stripe_attempt_attach_internal_v259',{p_attempt_id:attemptId,p_checkout_session_id:session.id,p_payment_intent_id:session.payment_intent||null,p_setup_intent_id:null});
    return json(200,{ok:true,url:session.url,session_id:session.id,request_id:requestId});
  }catch(error){console.error('stripe-checkout',safeError(error));return json(422,{ok:false,error:'checkout_failed',detail:safeError(error)});}
});
