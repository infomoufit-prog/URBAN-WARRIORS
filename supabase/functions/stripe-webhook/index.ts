import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {env,json,safeError,serviceRpc} from '../_shared/stripe.ts';

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
  try{const result=await serviceRpc('app_stripe_event_apply_v265',{p_event:event});return json(200,result||{ok:true});}
  catch(error){console.error('stripe-webhook',safeError(error));return json(500,{ok:false,error:'event_apply_failed'});}
});
