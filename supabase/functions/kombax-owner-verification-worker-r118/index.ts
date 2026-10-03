import {authorizeCronRequest,jsonResponse} from '../_shared/cron-security.ts';
Deno.serve(async(req:Request)=>{
 const auth=await authorizeCronRequest(req);if(auth.response)return auth.response;
 const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');
 const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
 if(!base||!secret)return jsonResponse({ok:false,error:'backend_not_configured'},503);
 // Authenticated diagnostic only: reuse the agent's existing health response.
 // Do not claim a verification job or return any credentials.
 if(auth.body.action==='health'){
  try{
   const r=await fetch(`${base}/functions/v1/kombax-owner-agents-r105`,{headers:{apikey:secret,authorization:`Bearer ${secret}`},signal:AbortSignal.timeout(15000)});
   const agent=await r.json();const configured=r.ok&&agent?.configured===true;
   return jsonResponse({ok:configured,agent_configured:configured,agent_version:agent?.version||null,model:agent?.model||null},configured?200:503);
  }catch{return jsonResponse({ok:false,error:'agent_health_unavailable'},503);}
 }
 const rpc=async(name:string,payload:Record<string,unknown>)=>{
  const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:secret,authorization:`Bearer ${secret}`,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(15000)});
  if(!r.ok)throw new Error(`DATABASE_${r.status}`);return await r.json();
 };
 let job:any;
 try{const claimed=await rpc('app_kombax_owner_verification_claim_r118',{});job=claimed?.job;if(!job)return jsonResponse({ok:true,processed:0});}
 catch{return jsonResponse({ok:false,error:'queue_unavailable'},503);}
 try{
  const r=await fetch(`${base}/functions/v1/kombax-owner-agents-r105`,{method:'POST',headers:{apikey:secret,authorization:`Bearer ${secret}`,'content-type':'application/json'},body:JSON.stringify({verification_job_id:job.id}),signal:AbortSignal.timeout(135000)});
  const result=await r.json();if(!r.ok||!result?.ok)throw new Error(String(result?.error||`AGENT_${r.status}`));
  await rpc('app_kombax_owner_verification_job_finish_r118',{p_job_id:job.id,p_result:result.automation||{approved:false},p_error:null});
  return jsonResponse({ok:true,processed:1,approved:result.automation?.approved===true});
 }catch(error){
  await rpc('app_kombax_owner_verification_job_finish_r118',{p_job_id:job.id,p_result:null,p_error:String(error instanceof Error?error.message:error).slice(0,300)}).catch(()=>{});
  return jsonResponse({ok:false,error:'verification_pending_manual_or_retry'},502);
 }
});
