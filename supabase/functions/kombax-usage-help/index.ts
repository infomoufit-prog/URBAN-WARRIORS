import {USAGE_HELP_INSTRUCTIONS,usageHelpContent} from '../_shared/usage-help-guide.ts';
import catalog from '../_shared/usage-help-catalog.json' with {type:'json'};
import {selectHelpTopics} from '../_shared/usage-help-knowledge.js';

const headers={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, apikey, content-type, x-client-info','access-control-allow-methods':'POST, OPTIONS','content-type':'application/json','cache-control':'no-store'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers});
function envKey(map:string,legacy:string){try{const keys=JSON.parse(Deno.env.get(map)||'{}');return String(keys.default||Object.values(keys)[0]||Deno.env.get(legacy)||'');}catch{return Deno.env.get(legacy)||'';}}
function textOf(data:any){return String(data.output_text||data.output?.filter((x:any)=>x.type==='message').flatMap((x:any)=>x.content||[]).filter((x:any)=>x.type==='output_text').map((x:any)=>x.text).join('\n')||'').trim();}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers});
 if(req.method!=='POST')return reply(405,{error:'method_not_allowed'});
 const base=Deno.env.get('SUPABASE_URL')||'',anon=envKey('SUPABASE_PUBLISHABLE_KEYS','SUPABASE_ANON_KEY'),secret=envKey('SUPABASE_SECRET_KEYS','SUPABASE_SERVICE_ROLE_KEY'),key=Deno.env.get('OPENAI_API_KEY')||'';
 if(!base||!anon||!secret)return reply(503,{error:'unavailable'});
 const bearer=req.headers.get('authorization')||'';
 if(!/^Bearer .+/i.test(bearer))return reply(401,{error:'authentication_required'});
 const rpc=async(name:string,body:unknown,internal=false,timeout=10000)=>{
  const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:internal?secret:anon,authorization:internal?`Bearer ${secret}`:bearer,'content-type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(timeout)});
  if(!r.ok)throw Error('rpc_unavailable');return r.json();
 };
 let turn='';
 try{
  const auth=await fetch(`${base}/auth/v1/user`,{headers:{apikey:anon,authorization:bearer},signal:AbortSignal.timeout(7000)});
  if(!auth.ok)return reply(401,{error:'authentication_required'});
  const user=await auth.json();if(!user?.id||user.is_anonymous===true)return reply(401,{error:'authentication_required'});
  if(Number(req.headers.get('content-length')||0)>12000)return reply(400,{error:'invalid_request'});
  const raw=await req.text();if(raw.length>12000)return reply(400,{error:'invalid_request'});
  let body:any;try{body=JSON.parse(raw)}catch{return reply(400,{error:'invalid_request'})}
  const audience=await rpc('app_usage_help_audience_r274',{p_tenant_ref:String(body.tenant_ref||'').slice(0,100),p_ticket_id:null});
  if(body.action==='status')return reply(200,{...(await rpc('app_usage_help_status_r274',{})),audience,configured:Boolean(key),version:'r274'});
  const question=String(body.message||'').trim(),id=String(body.request_id||'');
  if(!question||question.length>1500||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id))return reply(400,{error:'invalid_request'});
  if(!key)return reply(503,{error:'unavailable'});
  if(audience.paid===true)return reply(403,{error:'use_shared_paid_channel'});
  const reservation=await rpc('app_usage_help_reserve_r274',{p_request_id:id,p_question:question});
  if(!reservation.ok)return reply(reservation.reason==='in_progress'?409:429,{error:reservation.reason});
  if(reservation.reused)return reply(200,{message:reservation.answer,reused:true});
  turn=reservation.turn_id;
  // Audience is resolved on the server. Only bounded dialog supplied by this help channel is added; no operational records.
  const locale=['es','en','fr','pt','it','de','th','fil'].includes(body.locale)?body.locale:'es';
  const learning:any={};
  let helpContent=usageHelpContent(question,{entity_type:audience.type||'public'},locale,audience,body.usage_history,[],[],learning);
  const lessons=learning.guide_ids?.length?await rpc('app_kombax_help_knowledge_read_r277',{p_guide_ids:learning.guide_ids},true,1200).catch(()=>[]):[];
  if(Array.isArray(lessons)&&lessons.length)helpContent=usageHelpContent(question,{entity_type:audience.type||'public'},locale,audience,body.usage_history,[],lessons);
  const response=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{authorization:`Bearer ${key}`,'content-type':'application/json'},signal:AbortSignal.timeout(45000),body:JSON.stringify({model:'gpt-6-luna',instructions:`${USAGE_HELP_INSTRUCTIONS}\nResponde en el idioma ${locale}. Limítate a la capa autorizada: ${JSON.stringify({kind:audience.kind,type:audience.type,role:audience.role,paid:audience.paid})}. Sin identidad solo orientación genérica. No expliques procedimientos de otros perfiles ni funciones de pago ausentes de las fuentes. Si faltan fuentes, explica qué falta y ofrece soporte.`,input:[{role:'user',content:helpContent}],max_output_tokens:500,store:false})});
  if(!response.ok)throw Error('provider_unavailable');
  const data=await response.json(),answer=textOf(data),usage=data.usage;
  if(!data.id||!answer||answer.length>12000||!Number.isSafeInteger(usage?.input_tokens)||!Number.isSafeInteger(usage?.output_tokens)||usage.input_tokens<0||usage.output_tokens<0)throw Error('invalid_measurement');
  const saved=await rpc('app_usage_help_finish_r274',{p_turn_id:turn,p_answer:answer,p_input_tokens:usage.input_tokens,p_output_tokens:usage.output_tokens,p_success:true},true);
  if(saved!==true)throw Error('accounting_unavailable');
  if(['faq_gap','correction'].includes(learning.reason))await rpc('app_kombax_help_learning_observe_r277',{p_turn_id:turn,p_channel:'free',p_guide_ids:learning.guide_ids||[],p_reason:learning.reason},true,1200).catch(()=>{});
  turn='';return reply(200,{message:answer});
 }catch{
  if(turn)await rpc('app_usage_help_finish_r274',{p_turn_id:turn,p_answer:null,p_input_tokens:0,p_output_tokens:0,p_success:false},true).catch(()=>{});
  return reply(502,{error:'help_unavailable'});
 }
});
