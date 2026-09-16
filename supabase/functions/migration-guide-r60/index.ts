import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { GUIDE_PDF_BASE64_BY_LOCALE } from './guide-pdfs-i18n.ts';

const CORS={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods':'POST, OPTIONS'
};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
function keyFromMap(raw:string|undefined){if(!raw)return '';try{const m=JSON.parse(raw);return String(m?.default||Object.values(m||{})[0]||'')}catch{return ''}}
function publicKey(){return keyFromMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY')||''}
async function rpc(base:string,key:string,bearer:string,name:string,payload:Record<string,unknown>){const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,authorization:bearer,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(10000)});const text=await r.text();let data:any=null;try{data=text?JSON.parse(text):null}catch{data=text}if(!r.ok)throw new Error(typeof data==='object'&&data?.message?String(data.message):`RPC_${r.status}`);return data}
const SUPPORTED_LOCALES=new Set(['es','en','fr','pt','it','de','th','fil']);
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED_LOCALES.has(raw)?raw:SUPPORTED_LOCALES.has(base)?base:'es'}
function decodeBase64(value:string){const raw=atob(value);const out=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)out[i]=raw.charCodeAt(i);return out}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  if(req.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');const key=publicKey();
  if(!base||!key)return json(503,{ok:false,error:'backend_not_configured'});
  const bearer=req.headers.get('authorization')||'';if(!bearer.toLowerCase().startsWith('bearer '))return json(401,{ok:false,error:'auth_required'});
  let body:any={};try{body=await req.json()}catch{return json(400,{ok:false,error:'invalid_json'})}
  const tenantRef=typeof body?.tenant_ref==='string'?body.tenant_ref.slice(0,160):null;const locale=normalizeLocale(body?.user_locale);
  try{
    const access=await rpc(base,key,bearer,'app_kombax_org_guide_access_r60',{p_tenant_ref:tenantRef});
    if(access?.allowed!==true)return json(403,{ok:false,error:'guide_not_authorized'});
    const bytes=decodeBase64(GUIDE_PDF_BASE64_BY_LOCALE[locale]||GUIDE_PDF_BASE64_BY_LOCALE.es);
    return new Response(bytes,{status:200,headers:{...CORS,'content-type':'application/pdf','content-disposition':`attachment; filename="KOMBAX_MIGRATIONS_GUIDE_${locale.toUpperCase()}_R60.pdf"`,'content-language':locale,'cache-control':'private, no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer','x-kombax-guide-scope':String(access?.organization_type||'organization')}});
  }catch(error){console.error(error);return json(403,{ok:false,error:'guide_not_authorized'})}
});
