import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods':'GET, POST, OPTIONS'
};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{...CORS,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
function keyFromMap(raw:string|undefined,name='default'){if(!raw)return '';try{const value=JSON.parse(raw);return String(value?.[name]||Object.values(value||{})[0]||'');}catch{return '';}}
function envKeys(){return {publishable:keyFromMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||'',secret:keyFromMap(Deno.env.get('SUPABASE_SECRET_KEYS'))||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||''};}
function safe(value:unknown,max=12000){return String(value??'').replace(/\u0000/g,'').slice(0,max);}
async function rpc(base:string,key:string,bearer:string,name:string,payload:Record<string,unknown>,timeout=15000){
  const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:key,authorization:bearer,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(timeout)});
  const raw=await r.text();let data:any=null;try{data=raw?JSON.parse(raw):null;}catch{data=raw;}
  if(!r.ok)throw new Error(typeof data==='object'&&data?.message?safe(data.message,240):`RPC_${name}_${r.status}`);return data;
}
async function getUser(base:string,key:string,bearer:string){const r=await fetch(`${base}/auth/v1/user`,{headers:{apikey:key,authorization:bearer},signal:AbortSignal.timeout(7000)});if(!r.ok)return null;return r.json().catch(()=>null);}
function outputText(response:any){if(typeof response?.output_text==='string')return response.output_text;const chunks:string[]=[];for(const item of response?.output||[])for(const part of item?.content||[])if(part?.type==='output_text')chunks.push(String(part.text||''));return chunks.join('\n').trim();}
function parseOutput(response:any){const raw=outputText(response).trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'');try{return JSON.parse(raw);}catch{return null;}}
function bytesToBase64(bytes:Uint8Array){let binary='';const chunk=0x8000;for(let i=0;i<bytes.length;i+=chunk)binary+=String.fromCharCode(...bytes.subarray(i,Math.min(i+chunk,bytes.length)));return btoa(binary);}
async function downloadOwnerDocument(base:string,secret:string,document:any){
  const path=String(document?.storage_path||'').split('/').map(encodeURIComponent).join('/');
  const r=await fetch(`${base}/storage/v1/object/kombax-owner-inbox/${path}`,{headers:{apikey:secret,authorization:`Bearer ${secret}`},signal:AbortSignal.timeout(20000)});
  if(!r.ok)throw new Error(`OWNER_DOCUMENT_DOWNLOAD_${r.status}`);
  const bytes=new Uint8Array(await r.arrayBuffer());
  if(!bytes.length||bytes.length>10485760)throw new Error('OWNER_DOCUMENT_SIZE_INVALID');
  return {bytes,mime:String(document?.mime_type||r.headers.get('content-type')||'application/octet-stream'),filename:safe(document?.filename||'documento',255)};
}

const OWNER_INSTRUCTIONS=`Eres KOMBAX Owner Operations, agente interno de la consola Owner. Analiza solicitudes y documentos adjuntos y facilita su tramitación usando exclusivamente el snapshot autorizado. Ordena los documentos por asunto, categoría, urgencia, estado y acción requerida. No inventes hechos, documentos, pagos ni verificaciones. Clasifica el riesgo, enumera comprobaciones y propone una acción concreta. Puedes recomendar under_review, needs_information, verified, limited, suspended o rejected cuando el tipo de solicitud lo admita. verified solo es admisible si todas las condiciones deterministas del contexto están completas. Nunca autorices pagos, reembolsos, eliminación de cuentas, datos de menores, cambios de privilegios, acceso de soporte, verificación dudosa o decisiones legales: marca requires_human=true. El resultado es una recomendación y no equivale a una acción ejecutada. Escribe en español profesional y breve.`;
const PILOT_INSTRUCTIONS=`Eres KOMBAX Pilot Intelligence, analista interno de solo lectura para el piloto. Examina únicamente métricas agregadas, contexto autorizado y documentos adjuntos. Detecta riesgos, fricción, anomalías, adopción y necesidades de seguimiento. Separa siempre BUG, UX, FEATURE, COMMERCIAL_REQUEST, SECURITY e INCIDENT. Cuando se solicite un informe, prepara un borrador estructurado y verificable listo para revisión Owner. No identifiques personas, no mezcles clubes y no propongas cambios destructivos. Entrega un resumen ejecutivo, hallazgos priorizados y próximos pasos verificables. Cuando falten datos indica NO VERIFICADO. El resultado alimentará informes PDF diarios, semanales y de release gate.`;

const schema={type:'object',additionalProperties:false,properties:{
  assistant_message:{type:'string'},risk_level:{type:'string',enum:['low','medium','high','critical']},confidence:{type:'number',minimum:0,maximum:1},
  findings:{type:'array',items:{type:'object',additionalProperties:false,properties:{category:{type:'string',enum:['OPERATIONS','BUG','UX','FEATURE','COMMERCIAL_REQUEST','SECURITY','INCIDENT','DATA_QUALITY']},priority:{type:'string',enum:['P0','P1','P2','P3']},title:{type:'string'},detail:{type:'string'},evidence:{type:'string'}},required:['category','priority','title','detail','evidence']}},
  next_steps:{type:'array',items:{type:'string'}},
  proposed_action:{type:'object',additionalProperties:false,properties:{action:{type:'string',enum:['none','open_review','request_information','recommend_status','create_pilot_report']},status:{type:['string','null']},target_type:{type:['string','null']},target_id:{type:['string','null']},reason:{type:'string'},requires_human:{type:'boolean'}},required:['action','status','target_type','target_id','reason','requires_human']}
},required:['assistant_message','risk_level','confidence','findings','next_steps','proposed_action']};

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  const base=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');const {publishable,secret}=envKeys();const openai=Deno.env.get('OPENAI_API_KEY')||'';
  if(req.method==='GET')return json(200,{ok:true,version:'r106',model:'gpt-6-luna',configured:Boolean(base&&publishable&&secret&&openai)});
  if(req.method!=='POST')return json(405,{ok:false,error:'method_not_allowed'});
  if(!base||!publishable||!secret)return json(503,{ok:false,error:'backend_not_configured'});
  const bearer=req.headers.get('authorization')||'';if(!bearer.toLowerCase().startsWith('bearer '))return json(401,{ok:false,error:'auth_required'});
  const user=await getUser(base,publishable,bearer);if(!user?.id)return json(401,{ok:false,error:'auth_invalid'});
  let body:any={};try{body=await req.json();}catch{return json(400,{ok:false,error:'invalid_json'});}
  const agent=String(body?.agent||'');const message=safe(body?.message,4000).trim();const effort=body?.reasoning_effort==='medium'?'medium':'low';
  const documentIds=Array.isArray(body?.document_ids)?[...new Set(body.document_ids.map((x:unknown)=>String(x||'').trim()).filter(Boolean))].slice(0,3):[];
  if(!['owner_operations','pilot_intelligence'].includes(agent)||!message)return json(400,{ok:false,error:'agent_and_message_required'});
  const contextType=['platform_application','seller_application','pilot_summary','platform_summary'].includes(String(body?.context_type||''))?String(body.context_type):agent==='pilot_intelligence'?'pilot_summary':'platform_summary';
  const contextId=body?.context_id||null,clientRequestId=body?.client_request_id||crypto.randomUUID(),conversationId=body?.conversation_id||null;
  let started:any;try{started=await rpc(base,publishable,bearer,'app_kombax_owner_agent_turn_start_r105',{p_agent:agent,p_message:message,p_context_type:contextType,p_context_id:contextId,p_reasoning_effort:effort,p_conversation_id:conversationId,p_client_request_id:clientRequestId});}catch(error){return json(403,{ok:false,error:'owner_agent_not_authorized',detail:safe(error instanceof Error?error.message:error,240)});}
  const turnId=String(started?.turn_id||'');if(!turnId)return json(500,{ok:false,error:'turn_not_created'});
  if(documentIds.length)try{await rpc(base,publishable,bearer,'app_kombax_owner_agent_turn_attach_documents_r106',{p_turn_id:turnId,p_document_ids:documentIds});}catch(error){await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'DOCUMENT_ATTACH_ERROR'}).catch(()=>{});return json(400,{ok:false,error:'owner_document_not_available',detail:safe(error instanceof Error?error.message:error,240)});}
  if(!openai){if(documentIds.length)await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_documents_finish_r106',{p_turn_id:turnId,p_success:false}).catch(()=>{});await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'OPENAI_API_KEY_MISSING'}).catch(()=>{});return json(503,{ok:false,error:'ai_not_configured'});}
  let context:any;try{context=await rpc(base,publishable,bearer,'app_kombax_owner_agent_turn_context_r105',{p_turn_id:turnId});}catch{await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'CONTEXT_ERROR'}).catch(()=>{});return json(500,{ok:false,error:'context_error'});}
  const model=Deno.env.get('KOMBAX_OWNER_AGENT_MODEL')||'gpt-6-luna';const instructions=agent==='owner_operations'?OWNER_INSTRUCTIONS:PILOT_INSTRUCTIONS;
  const inputText=`Conversación reciente:\n${safe(JSON.stringify(context?.history||[]),8000)}\n\nSnapshot autorizado:\n${safe(JSON.stringify(context?.context||{}),12000)}\n\nDocumentos adjuntos autorizados:\n${safe(JSON.stringify((context?.documents||[]).map((d:any)=>({filename:d.filename,mime_type:d.mime_type,category:d.category,title:d.title}))),3000)}\n\nSolicitud Owner:\n${message}`;
  const content:any[]=[{type:'input_text',text:inputText}];
  try{
    const docs=Array.isArray(context?.documents)?context.documents:[];let total=0;
    for(const document of docs){
      total+=Number(document?.size_bytes||0);if(total>18874368)throw new Error('OWNER_DOCUMENT_TOTAL_TOO_LARGE');
      const file=await downloadOwnerDocument(base,secret,document),data=`data:${file.mime};base64,${bytesToBase64(file.bytes)}`;
      if(file.mime.startsWith('image/'))content.push({type:'input_image',image_url:data,detail:'auto'});
      else content.push({type:'input_file',filename:file.filename,file_data:data});
    }
  }catch{await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_documents_finish_r106',{p_turn_id:turnId,p_success:false}).catch(()=>{});await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'DOCUMENT_READ_ERROR'}).catch(()=>{});return json(422,{ok:false,error:'owner_document_read_failed'});}
  let response:any;
  try{
    const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{authorization:`Bearer ${openai}`,'content-type':'application/json'},body:JSON.stringify({model,reasoning:{effort},instructions,input:[{role:'user',content}],store:false,max_output_tokens:1600,text:{format:{type:'json_schema',name:'kombax_owner_agent_output',strict:true,schema}}}),signal:AbortSignal.timeout(55000)});
    const raw=await r.text();try{response=raw?JSON.parse(raw):null;}catch{response={error:{message:raw}}}if(!r.ok)throw new Error(safe(response?.error?.message||`OPENAI_${r.status}`,240));
  }catch{if(documentIds.length)await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_documents_finish_r106',{p_turn_id:turnId,p_success:false}).catch(()=>{});await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'MODEL_ERROR'}).catch(()=>{});return json(502,{ok:false,error:'owner_agent_temporarily_unavailable'});}
  const parsed=parseOutput(response);if(!parsed||!response?.id||!response?.usage){if(documentIds.length)await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_documents_finish_r106',{p_turn_id:turnId,p_success:false}).catch(()=>{});await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_fail_r105',{p_turn_id:turnId,p_error_code:'STRUCTURED_OUTPUT_MISSING'}).catch(()=>{});return json(502,{ok:false,error:'owner_agent_output_invalid'});}
  let report:any=null;
  try{
    await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_turn_complete_r105',{p_turn_id:turnId,p_response_id:String(response.id),p_assistant_message:safe(parsed.assistant_message,12000),p_risk_level:parsed.risk_level,p_confidence:Number(parsed.confidence||0),p_proposed_action:parsed.proposed_action||{},p_findings:parsed.findings||[],p_next_steps:parsed.next_steps||[],p_usage:response.usage},15000);
    if(documentIds.length)await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_agent_documents_finish_r106',{p_turn_id:turnId,p_success:true});
    if(agent==='pilot_intelligence'&&parsed?.proposed_action?.action==='create_pilot_report'){
      const lowered=message.toLowerCase(),reportType=lowered.includes('release')||lowered.includes('gate')?'release_gate':lowered.includes('incidenc')?'incident':lowered.includes('diario')?'daily':'weekly';
      report=await rpc(base,secret,`Bearer ${secret}`,'app_kombax_owner_pilot_report_from_turn_r106',{p_turn_id:turnId,p_report_type:reportType});
    }
  }catch{return json(500,{ok:false,error:'owner_agent_audit_write_failed'});}
  return json(200,{ok:true,turn_id:turnId,conversation_id:started.conversation_id,agent,reasoning_effort:effort,documents_processed:documentIds.length,report,message:parsed.assistant_message,risk_level:parsed.risk_level,confidence:parsed.confidence,findings:parsed.findings,next_steps:parsed.next_steps,proposed_action:parsed.proposed_action});
});
