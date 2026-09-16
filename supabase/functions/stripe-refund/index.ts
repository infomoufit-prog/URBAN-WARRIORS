import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

const REFUND_COPY:Record<string,{batch:string;event:string}>={
  es:{batch:'Cancelación / reembolso de evento',event:'Cancelación de evento'},
  en:{batch:'Event cancellation / refund',event:'Event cancellation'},
  fr:{batch:'Annulation / remboursement de l’événement',event:'Annulation de l’événement'},
  pt:{batch:'Cancelamento / reembolso do evento',event:'Cancelamento do evento'},
  it:{batch:'Annullamento / rimborso evento',event:'Annullamento evento'},
  de:{batch:'Veranstaltungsstornierung / Rückerstattung',event:'Veranstaltungsstornierung'},
  th:{batch:'ยกเลิก / คืนเงินกิจกรรม',event:'ยกเลิกกิจกรรม'},
  fil:{batch:'Pagkansela / refund ng event',event:'Pagkansela ng event'}
};
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return Object.hasOwn(REFUND_COPY,raw)?raw:Object.hasOwn(REFUND_COPY,base)?base:'es';}

function numberOrNull(value:unknown){
  if(value===null||value===undefined||value==='')return null;
  const n=Number(value);return Number.isFinite(n)?Math.trunc(n):null;
}
function bool(value:unknown){return value===true||value==='true'||value===1||value==='1';}
async function deterministicUuid(seed:string){
  const hash=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(seed)));
  const b=hash.slice(0,16);b[6]=(b[6]&0x0f)|0x40;b[8]=(b[8]&0x3f)|0x80;
  const h=[...b].map(x=>x.toString(16).padStart(2,'0')).join('');
  return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;
}

async function runRefund(actorId:string,payload:any,requestId:string){
  const scope=String(payload?.scope||'').toLowerCase();
  const orderId=String(payload?.order_id||'');
  const prepared:any=await serviceRpc('app_stripe_refund_prepare_internal_r65',{
    p_actor_id:actorId,p_scope:scope,p_order_id:orderId,
    p_amount_minor:numberOrNull(payload?.amount_minor),p_ticket_quantity:numberOrNull(payload?.ticket_quantity),
    p_reason:String(payload?.reason||'').slice(0,500)||null,p_restock:bool(payload?.restock),p_restock_quantity:numberOrNull(payload?.restock_quantity)||0,
    p_request_id:requestId
  });
  if(prepared?.status==='succeeded')return {ok:true,...prepared,idempotent:true};
  if(!prepared?.refund_id||!prepared?.stripe_account_id||!prepared?.payment_intent_id||!prepared?.amount_minor)throw new Error('REFUND_PREPARE_INCOMPLETE');
  let refund:any=null;let stripeStatus='';let finalized=false;
  try{
    refund=await stripe('refunds','POST',{
      payment_intent:prepared.payment_intent_id,
      amount:prepared.amount_minor,
      ...(prepared.refund_application_fee?{refund_application_fee:'true'}:{}),
      'metadata[kombax_refund_id]':prepared.refund_id,
      'metadata[kombax_scope]':scope,
      'metadata[kombax_order_id]':orderId
    },prepared.stripe_account_id,{idempotencyKey:`kombax-r65-refund-${prepared.refund_id}`});
    stripeStatus=String(refund?.status||'');
    const finalStatus=stripeStatus==='succeeded'?'succeeded':stripeStatus==='pending'?'processing':'failed';
    const final:any=await serviceRpc('app_stripe_refund_finalize_internal_r65',{
      p_refund_id:prepared.refund_id,p_status:finalStatus,p_stripe_refund:refund,p_error:finalStatus==='failed'?String(refund?.failure_reason||'STRIPE_REFUND_FAILED'):null
    });
    finalized=true;
    if(finalStatus==='failed')throw new Error(String(refund?.failure_reason||'STRIPE_REFUND_FAILED'));
    return {ok:true,refund_id:prepared.refund_id,stripe_refund_id:refund?.id||null,status:stripeStatus||finalStatus,amount_minor:prepared.amount_minor,ticket_quantity:prepared.ticket_quantity||0,...final};
  }catch(error){
    const detail=safeError(error);
    if(!finalized){
      const status=refund?.id&&(stripeStatus==='succeeded'||stripeStatus==='pending')?'processing':'failed';
      await serviceRpc('app_stripe_refund_finalize_internal_r65',{p_refund_id:prepared.refund_id,p_status:status,p_stripe_refund:refund||{},p_error:status==='failed'?detail:null}).catch(()=>{});
    }
    throw error;
  }
}

Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:{'access-control-allow-origin':'*','access-control-allow-headers':'authorization, apikey, content-type, x-client-info','access-control-allow-methods':'POST, OPTIONS'}});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  try{
    const user:any=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
    const body=await request.json().catch(()=>({}));const action=String(body?.action||'single');const locale=normalizeLocale(body?.user_locale),copy=REFUND_COPY[locale]||REFUND_COPY.es;
    if(action==='single'){
      const requestId=String(body?.request_id||crypto.randomUUID());
      const out=await runRefund(user.id,body,requestId);return json(200,out);
    }
    if(action==='event_batch'){
      const eventId=String(body?.event_id||'');if(!eventId)return json(400,{ok:false,error:'event_id_required'});
      const requestId=String(body?.request_id||crypto.randomUUID());
      const batch:any=await serviceRpc('app_kombax_event_refund_batch_internal_r65',{p_actor_id:user.id,p_event_id:eventId,p_reason:String(body?.reason||copy.batch).slice(0,500),p_request_id:requestId,p_limit:25});
      const orders=Array.isArray(batch?.orders)?batch.orders:[];let succeeded=0,failed=0;const results:any[]=[];
      for(const raw of orders){
        const orderId=String(raw);const childRequest=await deterministicUuid(`${batch.batch_id}:${orderId}`);
        try{const result=await runRefund(user.id,{scope:'event',order_id:orderId,reason:batch.reason||body?.reason||copy.event},childRequest);if(String(result?.status||'')==='succeeded')succeeded++;results.push({order_id:orderId,ok:true,refund_id:result.refund_id,status:result?.status||'processing'});}
        catch(error){failed++;results.push({order_id:orderId,ok:false,error:safeError(error)});}
      }
      const final:any=await serviceRpc('app_kombax_event_refund_batch_finalize_internal_r65',{p_batch_id:batch.batch_id,p_succeeded:succeeded,p_failed:failed});
      return json(200,{ok:failed===0,batch_id:batch.batch_id,processed:orders.length,succeeded,failed,remaining:final?.remaining??batch?.pending??0,status:final?.status||'processing',results});
    }
    return json(400,{ok:false,error:'action_not_supported'});
  }catch(error){return json(400,{ok:false,error:safeError(error)});}
});
