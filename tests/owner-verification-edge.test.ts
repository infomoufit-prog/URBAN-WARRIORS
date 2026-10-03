import {assertEquals,assert} from 'jsr:@std/assert';
let handler:any;
(Deno as any).serve=(fn:any)=>{handler=fn;return {};};
for(const [k,v] of Object.entries({SUPABASE_URL:'https://fixture.invalid',SUPABASE_ANON_KEY:'public-test',SUPABASE_SERVICE_ROLE_KEY:'eyJ.fixture.service',SUPABASE_SECRET_KEYS:'{"default":"sb_secret_fixture"}',OPENAI_API_KEY:'test-model-key'}))Deno.env.set(k,v);
await import('../supabase/functions/kombax-owner-agents-r105/index.ts');
const id='00000000-0000-4000-8000-000000000010',doc='00000000-0000-4000-8000-000000000020';
let allRead:boolean|undefined,completed=0,authCalls=0,downloaded=0,applyCalls=0;
let docs:any[]=[{id:doc,storage_bucket:'kombax-verification-docs',storage_path:'fixture/license.pdf',mime_type:'application/pdf',size_bytes:20,filename:'license.pdf'}];
let failStorage=false;const calls:any[]=[];
const response=(x:any,status=200)=>new Response(JSON.stringify(x),{status,headers:{'content-type':'application/json'}});
globalThis.fetch=(async(url:any,init:any)=>{
 const u=String(url),body=init?.body?JSON.parse(init.body):null;calls.push({url:u,headers:init?.headers,body});
 if(u.endsWith('/auth/v1/user')){authCalls++;return response({id:'owner'});}
 if(u.includes('/storage/')){downloaded++;return failStorage?new Response('',{status:404}):new Response('test-readable-document');}
 if(u.endsWith('/v1/responses'))return response({id:'response-test',usage:{input_tokens:10,output_tokens:10},output_text:JSON.stringify({assistant_message:'Test review',risk_level:'low',confidence:.98,findings:[],next_steps:[],proposed_action:{action:'recommend_status',status:'verificada',target_type:'professional_credential',target_id:id,reason:'All checks passed',requires_human:false},document_checks:docs.map(d=>({id:d.id,readable:true,relevant:true,uncertain:false,document_type:'license'}))})});
 if(u.includes('/rest/v1/rpc/')){
  const name=u.split('/').pop();
  if(name==='app_kombax_owner_credential_turn_start_r118')return response({turn_id:id,conversation_id:id});
  if(name==='app_kombax_owner_verification_job_start_r118')return response({turn_id:id,conversation_id:id,context_type:'professional_credential',context_id:id,message:'Automatic document verification'});
  if(name==='app_kombax_owner_verification_context_r118')return response({context:{name:'Test',id,kind:'professional_credential'},history:[],documents:[],verification_documents:docs});
  if(name==='app_kombax_owner_agent_turn_complete_r105'){completed++;allRead=body.p_proposed_action.all_documents_read;assertEquals(body.p_proposed_action.document_checks.length,docs.length);assertEquals(init.headers.authorization,'Bearer eyJ.fixture.service');return response({ok:true});}
  if(name==='app_kombax_owner_verification_apply_r118'){applyCalls++;return response({approved:allRead===true});}
  return response({ok:true});
 }
 throw new Error('Unexpected network call: '+u);
}) as any;
const send=(body:any,token='owner-token')=>handler(new Request('https://fixture.invalid/agent',{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(body)}));
const ownerBody={agent:'owner_operations',message:'Verify license',context_type:'professional_credential',context_id:id};
Deno.test('complete related document reaches AI and automatic executor with valid service JWT',async()=>{
 const r=await send(ownerBody),x=await r.json();assertEquals(r.status,200);assertEquals(x.automation.approved,true);assertEquals(downloaded,1);assertEquals(completed,1);assertEquals(applyCalls,1);
 assert(calls.some(c=>c.url.includes('/object/kombax-verification-docs/')));
});
Deno.test('more than three target documents cannot claim complete reading',async()=>{
 docs=Array.from({length:4},(_,i)=>({...docs[0],id:doc+i}));const r=await send(ownerBody);assertEquals(r.status,200);assertEquals(allRead,false);assertEquals((await r.json()).automation.approved,false);
});
Deno.test('unavailable private storage never completes or approves a turn',async()=>{
 const before=completed,applies=applyCalls;docs=docs.slice(0,1);failStorage=true;const r=await send(ownerBody);assertEquals(r.status,422);assertEquals(completed,before);assertEquals(applyCalls,applies);failStorage=false;
});
Deno.test('service worker uses claimed job and does not accept client supplied target',async()=>{
 const before=authCalls;const r=await send({verification_job_id:id,context_id:'wrong-target'},'eyJ.fixture.service');assertEquals(r.status,200);assertEquals(authCalls,before);
 assert(calls.some(c=>c.url.endsWith('app_kombax_owner_verification_job_start_r118')&&c.body.p_job_id===id));
});
Deno.test('user token cannot enter worker mode',async()=>{
 const before=calls.filter(c=>c.url.endsWith('app_kombax_owner_verification_job_start_r118')).length;const r=await send({verification_job_id:id});assertEquals(r.status,400);assertEquals(calls.filter(c=>c.url.endsWith('app_kombax_owner_verification_job_start_r118')).length,before);
});
