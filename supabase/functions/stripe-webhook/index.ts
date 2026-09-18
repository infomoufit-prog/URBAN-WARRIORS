import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {env,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

function bytesFromHex(value:string){const out=new Uint8Array(value.length/2);for(let i=0;i<out.length;i++)out[i]=parseInt(value.slice(i*2,i*2+2),16);return out;}
async function verify(raw:string,header:string,secret:string){
  const parts=header.split(',').map(x=>x.trim().split('='));const timestamp=parts.find(x=>x[0]==='t')?.[1]||'';const signatures=parts.filter(x=>x[0]==='v1').map(x=>x[1]);
  if(!/^\d+$/.test(timestamp)||Math.abs(Date.now()/1000-Number(timestamp))>300||!signatures.length)return false;
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  const data=new TextEncoder().encode(`${timestamp}.${raw}`);
  for(const signature of signatures)if(/^[0-9a-f]{64}$/i.test(signature)&&await crypto.subtle.verify('HMAC',key,bytesFromHex(signature),data))return true;
  return false;
}

Deno.serve(async(request:Request)=>{
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const secret=Deno.env.get('STRIPE_CONNECT_WEBHOOK_SECRET')||'';const cfg=env();if(!secret||!cfg.secretKey)return json(503,{ok:false,error:'webhook_not_configured'});
  const raw=await request.text();const signature=request.headers.get('stripe-signature')||'';
  if(!await verify(raw,signature,secret))return json(400,{ok:false,error:'invalid_signature'});
  let event:any;try{event=JSON.parse(raw)}catch{return json(400,{ok:false,error:'invalid_json'})}
  try{
    if(event?.type==='setup_intent.succeeded'&&event?.account&&event?.data?.object){
      const obj=event.data.object;const paymentMethodId=String(obj.payment_method||'');let enrichment:any={customer_id:String(obj.customer||''),payment_method_id:paymentMethodId};
      if(/^pm_/.test(paymentMethodId)){
        try{const pm=await stripe(`payment_methods/${paymentMethodId}`,'GET',{},event.account);enrichment.last4=pm?.sepa_debit?.last4||'';enrichment.holder_name=pm?.billing_details?.name||'';}catch(error){console.warn('stripe-webhook-sepa-pm',safeError(error));}
      }
      try{const attempts=await stripe(`setup_attempts?setup_intent=${encodeURIComponent(String(obj.id||''))}&limit=1`,'GET',{},event.account);const latest=Array.isArray(attempts?.data)?attempts.data[0]:null;enrichment.mandate_id=latest?.payment_method_details?.sepa_debit?.mandate||'';}catch(error){console.warn('stripe-webhook-sepa-mandate',safeError(error));}
      obj.kombax_enrichment=enrichment;
    }
    let result:any;
    try{result=await serviceRpc('app_stripe_event_apply_v266',{p_event:event});}
    catch(error){if(/function|schema cache|PGRST202|404/i.test(String(error?.message||error)))result=await serviceRpc('app_stripe_event_apply_v265',{p_event:event});else throw error;}
    return json(200,result||{ok:true});
  }catch(error){console.error('stripe-webhook',safeError(error));return json(500,{ok:false,error:'event_apply_failed'});}
});
