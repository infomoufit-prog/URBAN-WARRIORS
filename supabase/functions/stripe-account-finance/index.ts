import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,json,safeError,serviceRpc,stripe} from '../_shared/stripe.ts';

function compactBalance(rows:any[]=[]){return rows.map(x=>({amount:Number(x?.amount||0),currency:String(x?.currency||'').toUpperCase(),source_types:x?.source_types||{}}));}
Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:{'access-control-allow-origin':'*','access-control-allow-headers':'authorization, apikey, content-type, x-client-info','access-control-allow-methods':'POST, OPTIONS'}});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  try{
    const user:any=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
    const body=await request.json().catch(()=>({}));const scope=String(body?.scope||'');const subjectId=String(body?.subject_id||'');
    if(!['showcase','event'].includes(scope)||!subjectId)return json(400,{ok:false,error:'scope_and_subject_required'});
    const context:any=await serviceRpc('app_stripe_account_finance_context_internal_r65',{p_actor_id:user.id,p_scope:scope,p_subject_id:subjectId});
    if(!context?.stripe_account_id)return json(409,{ok:false,error:'stripe_account_not_connected'});
    const [balance,payouts]=await Promise.all([
      stripe('balance','GET',{},context.stripe_account_id),
      stripe('payouts?limit=10','GET',{},context.stripe_account_id)
    ]);
    return json(200,{ok:true,account:{status:context.status,charges_enabled:context.charges_enabled,payouts_enabled:context.payouts_enabled,charge_model:context.charge_model},
      balance:{available:compactBalance(balance?.available||[]),pending:compactBalance(balance?.pending||[])},
      payouts:(Array.isArray(payouts?.data)?payouts.data:[]).map((p:any)=>({id:p.id,amount:Number(p.amount||0),currency:String(p.currency||'').toUpperCase(),status:p.status,arrival_date:p.arrival_date,created:p.created,method:p.method,type:p.type}))});
  }catch(error){return json(400,{ok:false,error:safeError(error)});}
});
