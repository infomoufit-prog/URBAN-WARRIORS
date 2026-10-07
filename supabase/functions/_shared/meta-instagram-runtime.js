import {createMetaIntegration,configFrom} from './meta-instagram-core.js';

function keyMap(raw){try{const map=JSON.parse(raw||'{}');return String(map.default||Object.values(map)[0]||'');}catch{return '';}}
function credentials(){
 return {url:(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,''),
  publicKey:keyMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||'',
  serviceKey:keyMap(Deno.env.get('SUPABASE_SECRET_KEYS'))||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||''};
}
async function dbRpc(name,payload,bearer=''){
 const cfg=credentials(),service=!bearer,key=service?cfg.serviceKey:cfg.publicKey;
 if(!cfg.url||!key)throw new Error('META_DATABASE_CONFIGURATION');
 // New secret keys are API keys, not JWTs. Only legacy service-role JWTs
 // belong on Authorization; user requests always retain their own JWT.
 const headers={apikey:key,'content-type':'application/json'};
 if(bearer)headers.authorization=bearer;
 else if(!key.startsWith('sb_secret_'))headers.authorization=`Bearer ${key}`;
 const response=await fetch(`${cfg.url}/rest/v1/rpc/${name}`,{method:'POST',headers,body:JSON.stringify(payload),signal:AbortSignal.timeout(12000)});
 if(!response.ok)throw new Error('META_DATABASE_OPERATION_FAILED');
 return response.json();
}
export const metaInstagram=createMetaIntegration({
 config:()=>configFrom(k=>Deno.env.get(k)),
 rpc:payload=>dbRpc('app_kombax_meta_internal_fix20',payload),
 userContext:(request,social)=>dbRpc('app_kombax_meta_context_fix20',{p_social_id:social},request.headers.get('authorization')||''),
 authenticate:async request=>{
  const bearer=request.headers.get('authorization')||'';if(!/^Bearer\s+\S+$/i.test(bearer))return null;
  const cfg=credentials();
  const response=await fetch(`${cfg.url}/auth/v1/user`,{headers:{apikey:cfg.publicKey,authorization:bearer},signal:AbortSignal.timeout(8000)});
  return response.ok?response.json():null;
 },
 log:record=>console.info(JSON.stringify(record))
});
