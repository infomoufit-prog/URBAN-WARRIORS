import {createClient} from 'npm:@supabase/supabase-js@2.112.3';
import {authorizeCronRequest,jsonResponse} from '../_shared/cron-security.ts';
import {drainCleanup} from './worker.ts';
Deno.serve(async request=>{
 const auth=await authorizeCronRequest(request);if(auth.response)return auth.response;
 try{
  let key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  if(!key){const keys=JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')||'{}');key=keys.default||Object.values(keys)[0]||'';}
  if(!key)throw new Error('configuration_missing');
  const client=createClient(Deno.env.get('SUPABASE_URL')||'',key,{auth:{persistSession:false}});
  return jsonResponse(await drainCleanup(client),200,auth.requestId);
 }catch{return jsonResponse({error:'cleanup_failed'},500,auth.requestId);}
});
