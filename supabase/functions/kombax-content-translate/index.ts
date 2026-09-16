import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods':'POST, OPTIONS'
};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
const SUPPORTED=new Set(['es','en','fr','pt','it','de','th','fil']);
const NAMES:Record<string,string>={es:'Spanish',en:'English',fr:'French',pt:'Portuguese',it:'Italian',de:'German',th:'Thai',fil:'Filipino'};
const VISIBILITY=new Set(['public','tenant','private']);
function keyFromMap(raw:string|undefined,name='default'){if(!raw)return '';try{const value=JSON.parse(raw);return String(value?.[name]||Object.values(value||{})[0]||'');}catch{return '';}}
function envKeys(){return {publishable:keyFromMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||'',secret:keyFromMap(Deno.env.get('SUPABASE_SECRET_KEYS'))||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||''};}
function normalizeLocale(value:unknown){const raw=String(value||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED.has(raw)?raw:SUPPORTED.has(base)?base:null;}
function cleanToken(value:unknown,max=80){const out=String(value??'').trim().toLowerCase();return /^[a-z0-9_.-]+$/.test(out)&&out.length<=max?out:'';}
function safeText(value:unknown,max=12000){return String(value??'').replace(/\u0000/g,'').trim().slice(0,max);}
async function getUser(base:string,key:string,bearer:string){const r=await fetch(`${base}/auth/v1/user`,{headers:{apikey:key,authorization:bearer},signal:AbortSignal.timeout(7000)});if(!r.ok)return null;return await r.json().catch(()=>null);}
async function sha256(value:string){const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));return [...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,'0')).join('');}
function responseText(response:any){if(typeof response?.output_text==='string'&&response.output_text.trim())return response.output_text;const chunks:string[]=[];for(const item of Array.isArray(response?.output)?response.output:[]){if(item?.type!=='message')continue;for(const part of Array.isArray(item?.content)?item.content:[]){if(part?.type==='output_text'&&typeof part?.text==='string')chunks.push(part.text);}}return chunks.join('\n').trim();}
function parseJson(text:string){const raw=String(text||'').trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();try{return JSON.parse(raw);}catch{}const a=raw.indexOf('{'),b=raw.lastIndexOf('}');if(a>=0&&b>a){try{return JSON.parse(raw.slice(a,b+1));}catch{}}return null;}
async function cacheLookup(base:string,secret:string,args:{contentType:string,contentId:string,field:string,hash:string,target:string,visibility:string,requester:string|null}){
  const q=new URLSearchParams({select:'translated_text,source_locale,target_locale,model_alias,updated_at',content_type:`eq.${args.contentType}`,content_id:`eq.${args.contentId}`,field_name:`eq.${args.field}`,source_hash:`eq.${args.hash}`,target_locale:`eq.${args.target}`,visibility:`eq.${args.visibility}`,limit:'1'});
  q.set('requester_id',args.requester?`eq.${args.requester}`:'is.null');
  const r=await fetch(`${base}/rest/v1/kombax_content_translations_u01?${q}`,{headers:{apikey:secret,authorization:`Bearer ${secret}`},signal:AbortSignal.timeout(7000)});if(!r.ok)return null;const rows=await r.json().catch(()=>[]);return Array.isArray(rows)?rows[0]||null:null;
}
async function cacheWrite(base:string,secret:string,row:Record<string,unknown>){
  const r=await fetch(`${base}/rest/v1/kombax_content_translations_u01`,{method:'POST',headers:{apikey:secret,authorization:`Bearer ${secret}`,'content-type':'application/json','prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify(row),signal:AbortSignal.timeout(8000)});return r.ok;
}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  if(req.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');const {publishable,secret}=envKeys();const openai=Deno.env.get('OPENAI_API_KEY')||'';
  if(!base||!publishable||!secret)return json(503,{ok:false,error:'backend_not_configured'});
  const bearer=req.headers.get('authorization')||'';if(!bearer.toLowerCase().startsWith('bearer '))return json(401,{ok:false,error:'auth_required'});
  const user=await getUser(base,publishable,bearer);if(!user?.id)return json(401,{ok:false,error:'auth_invalid'});
  let body:any={};try{body=await req.json();}catch{return json(400,{ok:false,error:'invalid_json'});}
  const sourceText=safeText(body?.source_text,12000),contentType=cleanToken(body?.content_type,80),contentId=safeText(body?.content_id,180),field=cleanToken(body?.field_name||'text',80);
  const target=normalizeLocale(body?.target_locale),requestedSource=normalizeLocale(body?.source_locale),visibility=VISIBILITY.has(String(body?.visibility||''))?String(body.visibility):'public';
  if(!sourceText||sourceText.length<2||!contentType||!contentId||!field||!target)return json(400,{ok:false,error:'translation_request_invalid'});
  if(sourceText.length>12000)return json(413,{ok:false,error:'translation_source_too_large'});
  const hash=await sha256(sourceText),requester=visibility==='private'?String(user.id):null;
  const cached=await cacheLookup(base,secret,{contentType,contentId,field,hash,target,visibility,requester});
  if(cached?.translated_text)return json(200,{ok:true,cache_hit:true,translated_text:String(cached.translated_text),source_locale:cached.source_locale||requestedSource,target_locale:target,preserve_original:true,source_hash:hash});
  if(requestedSource&&requestedSource===target)return json(200,{ok:true,cache_hit:false,same_language:true,translated_text:sourceText,source_locale:requestedSource,target_locale:target,preserve_original:true,source_hash:hash});
  if(!openai)return json(503,{ok:false,error:'translation_ai_not_configured'});
  const sourceHint=requestedSource?`${NAMES[requestedSource]} (${requestedSource})`:'unknown;const targetName=NAMES[target]||target;
  const instructions=`You are the KOMBAX universal content translation service. Translate user-authored combat-sports platform content into ${targetName} (${target}). Source language hint: ${sourceHint}. Preserve meaning, tone, line breaks, emojis, URLs, @handles, hashtags, measurements, prices, model names, proper names, KOMBAX product names, Stripe, QR identifiers, codes and technical IDs exactly when they should not be translated. Do not add explanations, warnings or marketing copy. Never censor or rewrite the author's meaning. If source and target are already the same language, return the original unchanged. Return ONLY valid JSON: {"detected_source_locale":"es|en|fr|pt|it|de|th|fil|null","translated_text":"..."}.`;
  const requestBody={model:Deno.env.get('KOMBAX_TRANSLATION_MODEL')||'gpt-5.6-luna',instructions,input:[{role:'user',content:[{type:'input_text',text:sourceText}]}],max_output_tokens:Math.min(5000,Math.max(300,Math.ceil(sourceText.length*1.8))),store:false};
  let response:any;try{const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{authorization:`Bearer ${openai}`,'content-type':'application/json'},body:JSON.stringify(requestBody),signal:AbortSignal.timeout(45000)});const raw=await r.text();try{response=raw?JSON.parse(raw):null;}catch{response={error:{message:raw}}}if(!r.ok)throw new Error(String(response?.error?.message||`OPENAI_${r.status}`));}catch{return json(502,{ok:false,error:'translation_temporarily_unavailable'});}
  const parsed=parseJson(responseText(response));const translated=safeText(parsed?.translated_text,16000);let detected=normalizeLocale(parsed?.detected_source_locale)||requestedSource;
  if(!translated)return json(502,{ok:false,error:'translation_response_invalid'});
  const model=String(requestBody.model);
  await cacheWrite(base,secret,{content_type:contentType,content_id:contentId,field_name:field,source_hash:hash,source_locale:detected,target_locale:target,translated_text:translated,visibility,requester_id:requester,model_alias:model,updated_at:new Date().toISOString()});
  return json(200,{ok:true,cache_hit:false,same_language:Boolean(detected&&detected===target),translated_text:translated,source_locale:detected,target_locale:target,preserve_original:true,source_hash:hash,model_alias:model});
});
