import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {authenticatedUser,cors,env,json,safeError,serviceRpc,stripeV2,stripeV2AccountState,userRpc} from '../_shared/stripe.ts';

const SUBJECT_TYPES=['club','showcase_provider','federation','event_organizer'];
const ACCOUNT_INCLUDE=['configuration.merchant','identity','requirements','future_requirements','defaults'];

async function syncAccount(accountId:string){
  if(!/^acct_[A-Za-z0-9]+$/.test(accountId))return null;
  const account=await stripeV2(`core/accounts/${accountId}`,'GET',{include:ACCOUNT_INCLUDE});
  const state=stripeV2AccountState(account);
  const cfg=env();
  await serviceRpc('app_stripe_connect_sync_internal_v261',{
    p_stripe_account_id:accountId,
    p_details_submitted:state.detailsSubmitted,
    p_charges_enabled:state.chargesEnabled,
    p_payouts_enabled:state.payoutsEnabled,
    p_requirements_due:state.requirementsDue,
    p_requirements_eventually_due:state.requirementsEventuallyDue,
    p_requirements_pending_verification:state.requirementsPendingVerification,
    p_disabled_reason:state.disabledReason,
    p_api_version:cfg.stripeConnectApiVersion
  });
  return state;
}

Deno.serve(async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(request.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const cfg=env();
  if(!cfg.supabaseUrl||!cfg.publishableKey||!cfg.secretKey||!cfg.stripeConnectKey||!cfg.appUrl)return json(503,{ok:false,error:'connect_not_configured'});
  const user=await authenticatedUser(request);if(!user?.id)return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await request.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const subjectType=String(body.subject_type||'club'),subjectId=String(body.subject_id||'');
  if(!/^[0-9a-f-]{36}$/i.test(subjectId)||!SUBJECT_TYPES.includes(subjectType))return json(400,{ok:false,error:'invalid_subject'});
  try{
    if(body.action==='status'){
      const runtime=await serviceRpc('app_stripe_connect_runtime_internal_v261',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId,p_manage:false});
      const accountId=String(runtime?.stripe_account_id||'');let synced=true;
      if(accountId&&runtime?.configuration_compatible!==false){
        try{await syncAccount(accountId)}catch(error){synced=false;console.warn('stripe-connect-status-sync',safeError(error));}
      }
      const status=await userRpc(request,'app_stripe_connect_status_v259',{p_subject_type:subjectType,p_subject_id:subjectId});
      return json(200,{ok:true,...status,synced});
    }

    const context=await serviceRpc('app_stripe_connect_prepare_internal_v259',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId});
    if(context?.configuration_compatible===false)return json(409,{ok:false,error:'connect_account_recreation_required'});
    let accountId=String(context?.stripe_account_id||'');
    if(!accountId){
      const account=await stripeV2('core/accounts','POST',{
        contact_email:context?.email||undefined,
        display_name:String(context?.display_name||'KOMBAX seller'),
        dashboard:'full',
        identity:{country:'es'},
        configuration:{merchant:{capabilities:{card_payments:{requested:true}}}},
        defaults:{currency:'eur',responsibilities:{fees_collector:'stripe',losses_collector:'stripe'},locales:['es-ES']},
        include:ACCOUNT_INCLUDE
      },{idempotencyKey:`kombax-connect-${subjectType}-${subjectId}`});
      accountId=String(account.id||'');
      if(!/^acct_[A-Za-z0-9]+$/.test(accountId))throw new Error('CONNECTED_ACCOUNT_CREATE_FAILED');
      await serviceRpc('app_stripe_connect_attach_internal_v259',{p_actor_id:user.id,p_subject_type:subjectType,p_subject_id:subjectId,p_stripe_account_id:accountId});
      const state=stripeV2AccountState(account);
      await serviceRpc('app_stripe_connect_sync_internal_v261',{
        p_stripe_account_id:accountId,p_details_submitted:state.detailsSubmitted,p_charges_enabled:state.chargesEnabled,p_payouts_enabled:state.payoutsEnabled,
        p_requirements_due:state.requirementsDue,p_requirements_eventually_due:state.requirementsEventuallyDue,p_requirements_pending_verification:state.requirementsPendingVerification,
        p_disabled_reason:state.disabledReason,p_api_version:cfg.stripeConnectApiVersion
      });
    }else{
      try{await syncAccount(accountId)}catch(error){console.warn('stripe-connect-onboarding-sync',safeError(error));}
    }
    const link=await stripeV2('core/account_links','POST',{account:accountId,use_case:{type:'account_onboarding',account_onboarding:{collection_options:{fields:'eventually_due',future_requirements:'include'},configurations:['merchant'],refresh_url:`${cfg.appUrl}/?payments=refresh&connect_type=${encodeURIComponent(subjectType)}&connect_id=${encodeURIComponent(subjectId)}`,return_url:`${cfg.appUrl}/?payments=return&connect_type=${encodeURIComponent(subjectType)}&connect_id=${encodeURIComponent(subjectId)}`}}});
    return json(200,{ok:true,url:link.url,expires_at:link.expires_at,status:context?.status||'pending'});
  }catch(error){console.error('stripe-connect',safeError(error));return json(403,{ok:false,error:'connect_operation_failed',detail:safeError(error)});}
});
