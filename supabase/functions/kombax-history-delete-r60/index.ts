import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2.112.3';

const CORS={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods':'POST, OPTIONS'
};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
function keyFromMap(raw:string|undefined){if(!raw)return '';try{const m=JSON.parse(raw);return String(m?.default||Object.values(m||{})[0]||'')}catch{return ''}}
function publicKey(){return keyFromMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY')||''}
function serviceKey(){return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||keyFromMap(Deno.env.get('SUPABASE_SECRET_KEYS'))||''}
async function rpc(base:string,key:string,bearer:string,name:string,payload:Record<string,unknown>,timeout=15000){const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,authorization:bearer,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(timeout)});const text=await r.text();let data:any=null;try{data=text?JSON.parse(text):null}catch{data=text}if(!r.ok)throw new Error(typeof data==='object'&&data?.message?String(data.message):`RPC_${name}_${r.status}`);return data}
async function getUser(base:string,key:string,bearer:string){const r=await fetch(`${base}/auth/v1/user`,{headers:{apikey:key,authorization:bearer},signal:AbortSignal.timeout(7000)});if(!r.ok)return null;return await r.json().catch(()=>null)}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  if(req.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');const pub=publicKey(),secret=serviceKey();
  if(!base||!pub||!secret)return json(503,{ok:false,error:'backend_not_configured'});
  const bearer=req.headers.get('authorization')||'';if(!bearer.toLowerCase().startsWith('bearer '))return json(401,{ok:false,error:'auth_required'});
  const user=await getUser(base,pub,bearer);if(!user?.id)return json(401,{ok:false,error:'auth_invalid'});
  let body:any={};try{body=await req.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const ticketId=typeof body?.ticket_id==='string'&&body.ticket_id.trim()?body.ticket_id.trim().slice(0,80):null;
  const requestedMode=typeof body?.mode==='string'?body.mode.trim().toLowerCase():'';
  const mode=requestedMode==='migration'?'migration':requestedMode==='assist'||requestedMode==='management'?'assist':null;
  if(requestedMode&&!mode)return json(400,{ok:false,error:'invalid_mode'});
  const tenantRef=typeof body?.tenant_ref==='string'&&body.tenant_ref.trim()?body.tenant_ref.trim().slice(0,160):null;
  try{
    const plan=await rpc(base,pub,bearer,'app_kombax_customer_history_delete_plan_r60',{p_ticket_id:ticketId,p_mode:mode,p_tenant_ref:tenantRef});
    const ids=Array.isArray(plan?.ticket_ids)?plan.ticket_ids.map(String).filter(Boolean):[];
    const paths=Array.isArray(plan?.storage_paths)?plan.storage_paths.map(String).filter(Boolean):[];
    if(!ids.length)return json(200,{ok:true,tickets_deleted:0,chat_messages_deleted:0,migration_files_deleted:0,migration_bytes_deleted:0,allowance_preserved:true,idempotent:true});
    if(paths.length){
      const service=createClient(base,secret,{auth:{persistSession:false,autoRefreshToken:false}});
      for(let i=0;i<paths.length;i+=100){const batch=paths.slice(i,i+100);const {error}=await service.storage.from('kombax-migration-staging').remove(batch);if(error)throw new Error(`STORAGE_DELETE_FAILED:${error.message}`)}
    }
    const result=await rpc(base,pub,bearer,'app_kombax_customer_history_delete_finalize_v256',{p_ticket_ids:ids},20000);
    return json(200,{...result,allowance_preserved:true,storage_paths_deleted:paths.length,history_delete_version:'v256'});
  }catch(error){console.error(error);return json(403,{ok:false,error:'history_delete_failed',detail:String(error instanceof Error?error.message:error).slice(0,240)})}
});
