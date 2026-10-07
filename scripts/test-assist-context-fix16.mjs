import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
const source=readFileSync('supabase/functions/kombax-assist-r38/index.ts','utf8').replace(/^import .*edge-runtime.*;\r?\n/,'');
const js=stripTypeScriptTypes(source);let handler,captured,maxReads=0,activeReads=0,calls=[],category='MIGRATION',auth=true,reserve=true;
const context={category,identity_context:{entity_id:'club-a',entity_type:'club',entity_name:'Club Alpha',groups:[{id:'g-a',nombre:'Boxeo mañana'}]},files:[{file_id:'f1',storage_path:'a/f1',mime_type:'image/png',original_name:'One.png'},{file_id:'f2',storage_path:'a/f2',mime_type:'image/png',original_name:'Two.png'}],messages:[],model_alias:'test-existing-model',max_output_tokens:500};
const fetch=async(url,opts={})=>{
 calls.push(url);
 if(url.endsWith('/auth/v1/user'))return new Response(JSON.stringify({id:'user-a'}),{status:auth?200:401});
 if(url.includes('/storage/v1/')){activeReads++;maxReads=Math.max(maxReads,activeReads);await new Promise(r=>setTimeout(r,15));activeReads--;return new Response(new Uint8Array([1,2,3]));}
 if(url.includes('api.openai.com')){captured=JSON.parse(opts.body);return new Response(JSON.stringify({id:'response-test',usage:{input_tokens:30,output_tokens:30},output_text:category==='MIGRATION'?JSON.stringify({assistant_message:'Datos listos para revisar.',file_analyses:context.files.map(f=>({file_id:f.file_id,summary:'Ficha',needs_review:false,preview:{records:[{source_ref:f.file_id+':1',kind:'student',fields:{name:'QA',surname:'Test',discipline_name:'Boxeo',group_name:'Boxeo mañana'},needs_review:false}]}})),field_updates:[]}):'Club Alpha: revisa las solicitudes en Mi Club.'}));}
 if(url.endsWith('/app_kombax_assist_turn_reserve_v227'))return new Response(JSON.stringify(reserve?{ok:true,turn_id:'turn-a'}:{ok:false,reason:'limit'}));
 if(url.endsWith('/app_kombax_assist_turn_internal_v227'))return new Response(JSON.stringify({...context,category,files:category==='MIGRATION'?context.files:[]}));
 if(url.endsWith('/app_kombax_migration_records_v271'))return new Response('{"files":[]}');
 return new Response('{"ok":true}');
};
vm.runInNewContext(js,{Deno:{env:{get:n=>({SUPABASE_URL:'https://qa.invalid',SUPABASE_ANON_KEY:'qa',SUPABASE_SERVICE_ROLE_KEY:'qa-secret',OPENAI_API_KEY:'mock-only'}[n])},serve:fn=>handler=fn},fetch,Response,Request,URL,AbortSignal,Uint8Array,btoa,console});
const request=(extra={})=>new Request('https://edge.invalid',{method:'POST',headers:{authorization:'Bearer qa','content-type':'application/json'},body:JSON.stringify({ticket_id:'ticket-a',message:'Revisa mis datos',client_request_id:'request-a',tenant_ref:'club-b',identity_context:{entity_name:'Club Beta'},...extra})});
let checks=0;const ok=(v,msg)=>{assert.ok(v,msg);checks++;};
let response=await handler(request());let out=await response.json();ok(response.status===200,'migration completed');ok(out.files_processed===2,'both files processed');ok(maxReads===2,'downloads run concurrently');ok(captured.model==='test-existing-model','model remains server selected');ok(captured.input[0].content[0].text.includes('Club Alpha')&&!captured.input[0].content[0].text.includes('Club Beta'),'client cannot inject another tenant context');ok(captured.instructions.includes('No pidas autorización en assistant_message'),'single interface confirmation');ok(captured.instructions.includes('No repitas datos ni confirmaciones'),'avoid repeated questions');ok(captured.instructions.includes('No inventes asociaciones'),'preserve ambiguous data handling');ok(captured.store===false,'no provider conversation storage');ok(calls.some(x=>x.endsWith('/app_kombax_assist_turn_complete_v103')),'usage accounting preserved');
category='MANAGEMENT';for(const specialty of ['management','memberships','finance','stripe','events','showcase','marketing','federation']){response=await handler(request({specialty}));ok(response.status===200,'specialty '+specialty);ok(captured.instructions.includes('contexto identity_context')&&captured.instructions.includes('Agrupa toda duda imprescindible'),'shared platform knowledge '+specialty);}
auth=false;const previous=calls.filter(x=>x.includes('api.openai.com')).length;response=await handler(request());ok(response.status===401,'unauthenticated caller denied');ok(calls.filter(x=>x.includes('api.openai.com')).length===previous,'unauthenticated request never calls model');auth=true;reserve=false;response=await handler(request());ok(response.status===429,'allowance protection preserved');
console.log('PASS '+checks+' Assist/Migrations handler checks (mock provider; no real inference or writes)');
