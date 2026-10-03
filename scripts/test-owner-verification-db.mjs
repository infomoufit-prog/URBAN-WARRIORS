import {PGlite} from '@electric-sql/pglite';
import {readFileSync,readdirSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'..'),db=new PGlite();let passed=0;
const owner='00000000-0000-4000-8000-000000000001',account='00000000-0000-4000-8000-000000000002',profile='00000000-0000-4000-8000-000000000003';
const uuid=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const scalar=async(sql,params=[])=>Object.values((await db.query(sql,params)).rows[0])[0];
const actor=async(id,role='authenticated')=>{await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.role',$2,false)",[id,role]);};
async function check(name,fn){await fn();passed++;console.log('PASS '+name);}
try{
await db.exec(`
create role anon;create role authenticated;create role service_role;
create schema auth;create schema storage;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create function auth.role() returns text language sql stable as $$select current_setting('request.jwt.claim.role',true)$$;
create table public.perfiles(id uuid primary key);
create table public.kombax_platform_admins(perfil_id uuid primary key,activo boolean);
create function public.app_kombax_es_platform_admin_v055() returns boolean language sql stable as $$select exists(select 1 from public.kombax_platform_admins where perfil_id=auth.uid() and activo)$$;
create function public.app_kombax_es_verificador_v117() returns boolean language sql stable as $$select public.app_kombax_es_platform_admin_v055()$$;
create table public.perfiles_kombax_directos(id uuid primary key,perfil_id uuid,tipo text,nombre_publico text,estado text default 'activo',publico boolean default true);
create function public.app_kombax_puede_gestionar_perfil_v070(uuid,text) returns boolean language sql stable as $$select exists(select 1 from public.perfiles_kombax_directos where id=$1 and perfil_id=auth.uid())$$;
create function public.app_kombax_professional_workspace_v198(uuid) returns jsonb language sql as $$select '{}'::jsonb$$;
create table public.kombax_professional_credentials_v198(id uuid primary key default gen_random_uuid(),professional_profile_id uuid,specialty_code text,credential_type text,issuer text,reference_public text,estado text default 'declarada',expires_on date,creado_por uuid,creado_en timestamptz default now(),actualizado_en timestamptz default now());
create table public.app_mutation_requests(request_id uuid primary key,user_id uuid,operation text,result jsonb,completed_at timestamptz);
create table public.kombax_actor_audit(actor_perfil_id uuid,accion text,objeto_tipo text,objeto_id uuid,detalle jsonb);
create table public.kombax_profesional_especialidades_v196(codigo text,activa boolean);
create table public.kombax_profesional_perfiles_v196(perfil_directo_id uuid,especialidad_principal text);
create table public.kombax_profesional_especialidades_secundarias_v196(perfil_directo_id uuid,especialidad_codigo text);
create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
create table public.kombax_solicitudes_alta(id uuid primary key default gen_random_uuid(),perfil_id uuid,tipo text,estado text,nombre_publico text,datos_verificacion jsonb default '{}',declaracion_aceptada boolean default false);
create table public.kombax_verificacion_documentos(id uuid primary key default gen_random_uuid(),solicitud_id uuid,estado text,storage_path text,mime_type text,bytes bigint,tipo_documento text,creado_en timestamptz default now());
create table public.kombax_account_private_r117(perfil_id uuid,fecha_nacimiento date);
create table public.kombax_perfil_persona_privada_v196(perfil_directo_id uuid,fecha_nacimiento date);
create table public.notificaciones(id uuid primary key default gen_random_uuid(),club_id uuid,perfil_id uuid,clave text,tipo text,titulo text,cuerpo text,ruta text,datos jsonb,subject_type text,subject_id uuid,leida boolean default false,leida_en timestamptz,ciclo_estado text default 'activo',archivado_en timestamptz,creado_en timestamptz default now(),push_enviado_en timestamptz,push_intentos int default 0,push_error text);
`);
await db.exec(readFileSync(resolve(root,'supabase/migrations/293_kombax_owner_agents_r105.sql'),'utf8'));
await db.exec(readFileSync(resolve(root,'supabase/migrations/318_kombax_r118_professional_credentials.sql'),'utf8'));
await db.exec(`
create or replace function public.app_kombax_owner_agent_turn_context_r105(p_turn_id uuid) returns jsonb language sql as $$select jsonb_build_object('context','{}'::jsonb,'history','[]'::jsonb,'documents','[]'::jsonb)$$;
create function public.app_kombax_metrics_platform_v133(integer) returns jsonb language sql as $$select '{}'::jsonb$$;
create function public.app_kombax_application_validate_v196(uuid) returns jsonb language plpgsql as $$begin if not exists(select 1 from public.kombax_solicitudes_alta where id=$1 and declaracion_aceptada) then raise exception 'DECLARATION_REQUIRED';end if;return '{"valid":true}'::jsonb;end$$;
create function public.app_kombax_perfil_mutate_v196(text,jsonb,uuid) returns jsonb language plpgsql as $$begin if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;update public.kombax_solicitudes_alta set estado=$2->>'estado' where id=($2->>'solicitud_id')::uuid;return '{"ok":true}'::jsonb;end$$;
`);
const migration=readdirSync(resolve(root,'supabase/migrations')).find(n=>n.endsWith('_owner_verification_flow_r118_fix.sql'));
await db.exec(readFileSync(resolve(root,'supabase/migrations',migration),'utf8'));
await db.query('insert into public.perfiles values($1),($2)',[owner,account]);
await db.query('insert into public.kombax_platform_admins values($1,true)',[owner]);
await db.query("insert into public.perfiles_kombax_directos(id,perfil_id,tipo,nombre_publico) values($1,$2,'profesional','Test Professional')",[profile,account]);
await db.query("insert into public.kombax_account_private_r117 values($1,'1990-01-01')",[account]);
await actor(account);
await check('professional workspace returns declaration text without SQL identifier error',async()=>{const x=await scalar('select public.app_kombax_professional_workspace_r118($1)',[profile]);assert.match(x.credential_declaration_text,/^Declaro/);});
await check('non-Owner cannot read private verification context',async()=>{await assert.rejects(db.query('select public.app_kombax_owner_verification_context_r118($1)',[uuid(99)]));});
async function credential(n,{evidence=true,acceptance=true,expiry=null}={}){
 const id=uuid(n),doc=uuid(n+10000),path=`${account}/professional-credential/${id}/certificate.pdf`;
 await db.query("insert into public.kombax_professional_credentials_v198(id,professional_profile_id,specialty_code,credential_type,issuer,estado,expires_on) values($1,$2,'test','License','Federation','declarada',$3)",[id,profile,expiry]);
 if(evidence){await db.query("insert into public.kombax_professional_credential_evidence_r118(id,credential_id,professional_profile_id,storage_path,mime_type,size_bytes,creado_por) values($1,$2,$3,$4,'application/pdf',100,$5)",[doc,id,profile,path,account]);await db.query("insert into storage.objects(bucket_id,name) values('kombax-verification-docs',$1)",[path]);}
 if(acceptance)await db.query("insert into public.kombax_professional_credential_acceptances_r118(credential_id,professional_profile_id,perfil_id,declaration_version,declaration_text) values($1,$2,$3,'r118','Test declaration')",[id,profile,account]);
 await db.query("update public.kombax_professional_credentials_v198 set estado='pendiente' where id=$1",[id]);
 return {id,doc,path};
}
async function turn(item,n,override={}){
 const action={action:'recommend_status',status:'verificada',target_type:'professional_credential',target_id:item.id,requires_human:false,all_documents_read:true,document_checks:[{id:item.doc,readable:true,relevant:true,uncertain:false,document_type:'license'}],...override.action};
 await db.query("insert into kombax_owner_ai.agent_turns(id,agent,requested_by,client_request_id,user_message,context_type,context_id,status,risk_level,confidence,proposed_action) values($1,'owner_operations',$2,$1,'Test verification','professional_credential',$3,'completed',$4,$5,$6)",[uuid(n),owner,item.id,override.risk||'low',override.confidence??0.98,action]);return uuid(n);
}
const good=await credential(10);
await check('submission creates private job and actionable Owner notification',async()=>{assert.equal(await scalar('select count(*)::int from kombax_owner_ai.verification_jobs_r118 where context_id=$1',[good.id]),1);assert.equal(await scalar("select count(*)::int from public.notificaciones where subject_id=$1 and perfil_id=$2 and datos->>'requiere_accion'='true'",[good.id,owner]),1);});
await check('submission records acceptance and succeeds without double-quoted text error',async()=>{await actor(account);const draft=await credential(11);await db.query("update public.kombax_professional_credentials_v198 set estado='declarada' where id=$1",[draft.id]);const x=await scalar("select public.app_kombax_professional_credential_mutate_r118('professional.credential.submit',$1,$2)",[{professional_profile_id:profile,credential_id:draft.id,declaration_accepted:true},uuid(900)]);assert.equal(x.credential.estado,'pendiente');});
await actor(owner,'service_role');
const tid=await turn(good,100);
await check('readable matching complete license is automatically verified',async()=>{const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[tid]);assert.equal(x.approved,true,x.reason);assert.equal(await scalar('select estado from public.kombax_professional_credentials_v198 where id=$1',[good.id]),'verificada');});
await check('approval is idempotent and restores caller identity',async()=>{await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[tid]);assert.equal(await scalar("select count(*)::int from public.kombax_actor_audit where objeto_id=$1",[good.id]),1);assert.equal(await scalar('select auth.uid()::text'),owner);});
await check('requester receives result and resolved Owner alert is archived',async()=>{assert.equal(await scalar("select count(*)::int from public.notificaciones where subject_id=$1 and perfil_id=$2 and datos->>'estado'='verificada'",[good.id,account]),1);assert.equal(await scalar("select count(*)::int from public.notificaciones where subject_id=$1 and perfil_id=$2 and clave like 'owner:credential:%' and not leida",[good.id,owner]),0);});
let n=20;
for(const [name,opts,override] of [
 ['unreadable',{}, {action:{document_checks:[{id:'wrong',readable:false,relevant:true,uncertain:false,document_type:'license'}]}}],
 ['identity is not a professional license',{}, {action:{document_checks:[{id:uuid(10021),readable:true,relevant:true,uncertain:false,document_type:'identity'}]}}],
 ['uncertain',{}, {action:{requires_human:true}}],['low confidence',{}, {confidence:.8}],['high risk',{}, {risk:'high'}],
 ['missing acceptance',{acceptance:false},{}],['missing evidence',{evidence:false},{}],['expired',{expiry:'2020-01-01'},{}],
 ['wrong target',{}, {action:{target_id:uuid(9999)}}],['partial read',{}, {action:{all_documents_read:false}}]
]){const item=await credential(n++ ,opts),t=await turn(item,n+1000,override);await check(name+' remains pending with manual Owner alert',async()=>{const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[t]);assert.equal(x.approved,false);assert.equal(await scalar('select estado from public.kombax_professional_credentials_v198 where id=$1',[item.id]),'pendiente');assert.equal(await scalar("select count(*)::int from public.notificaciones where subject_id=$1 and datos->>'requiere_accion'='true' and clave like 'owner:verification-ai:%'",[item.id]),1);});}
await actor(account);
await check('authenticated user cannot invoke automatic executor or claim jobs',async()=>{await assert.rejects(db.query('select public.app_kombax_owner_verification_apply_r118($1)',[tid]),/SERVICE_ROLE_REQUIRED/);await assert.rejects(db.query('select public.app_kombax_owner_verification_claim_r118()'),/SERVICE_ROLE_REQUIRED/);});
await actor(owner);
await check('Owner can still verify manually after AI doubt',async()=>{const id=uuid(20);await scalar("select public.app_kombax_professional_credential_mutate_r118('professional.credential.review',$1,$2)",[{professional_profile_id:profile,credential_id:id,decision:'verificada',review_note:'Manual review'},uuid(901)]);assert.equal(await scalar('select estado from public.kombax_professional_credentials_v198 where id=$1',[id]),'verificada');});
await actor(owner,'service_role');
await check('job claiming has lease and worker start records Owner identity',async()=>{const claimed=await scalar('select public.app_kombax_owner_verification_claim_r118()');assert.equal(claimed.job.status,'processing');const started=await scalar('select public.app_kombax_owner_verification_job_start_r118($1)',[claimed.job.id]);assert.equal(started.context_type,'professional_credential');assert.equal(await scalar('select requested_by::text from kombax_owner_ai.agent_turns where id=$1',[started.turn_id]),owner);});

await check('manual resolution cancels queued work without creating a stale alert',async()=>{
 const item=await credential(40),t=await turn(item,1040);await db.query("update public.kombax_professional_credentials_v198 set estado='rechazada' where id=$1",[item.id]);
 const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[t]);assert.equal(x.already_resolved,true);assert.equal(x.manual_required,false);
 assert.equal(await scalar("select status from kombax_owner_ai.verification_jobs_r118 where context_id=$1",[item.id]),'completed');
});
await check('worker retries bounded errors and alerts Owner after third failure',async()=>{
 const item=await credential(41);const job=await scalar('select id::text from kombax_owner_ai.verification_jobs_r118 where context_id=$1',[item.id]);
 for(let i=1;i<=3;i++){await db.query("update kombax_owner_ai.verification_jobs_r118 set status='processing',attempts=$1 where id=$2",[i,job]);await db.query('select public.app_kombax_owner_verification_job_finish_r118($1,null,$2)',[job,'MODEL_TEST_ERROR']);}
 assert.equal(await scalar('select status from kombax_owner_ai.verification_jobs_r118 where id=$1',[job]),'manual');
});
async function application(n,type='profesional'){
 const id=uuid(n),doc=uuid(n+10000),path=`${account}/request/${id}/identity.pdf`;
 await db.query("insert into public.kombax_solicitudes_alta(id,perfil_id,tipo,estado,declaracion_aceptada) values($1,$2,$3,'submitted',true)",[id,account,type]);
 await db.query("insert into public.kombax_verificacion_documentos(id,solicitud_id,estado,storage_path,mime_type,bytes,tipo_documento) values($1,$2,'active',$3,'application/pdf',100,'identity')",[doc,id,path]);
 await db.query("insert into storage.objects(bucket_id,name) values('kombax-verification-docs',$1)",[path]);
 const t=await turn({id,doc},n+5000,{action:{target_type:'platform_application',status:'verified',document_checks:[{id:doc,readable:true,relevant:true,uncertain:false,document_type:'identity'}]}});
 await db.query("update kombax_owner_ai.agent_turns set context_type='platform_application' where id=$1",[t]);return {id,t};
}
await check('adult identity application uses existing backend review validator',async()=>{const a=await application(50);const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[a.t]);assert.equal(x.approved,true,x.reason);assert.equal(await scalar('select estado from public.kombax_solicitudes_alta where id=$1',[a.id]),'verified');});
await check('club application is never approved by document AI',async()=>{const a=await application(51,'club');const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[a.t]);assert.equal(x.approved,false);assert.equal(await scalar('select estado from public.kombax_solicitudes_alta where id=$1',[a.id]),'submitted');});
await check('minor account requires Owner review',async()=>{await db.query("update public.kombax_account_private_r117 set fecha_nacimiento='2015-01-01' where perfil_id=$1",[account]);const a=await application(52);const x=await scalar('select public.app_kombax_owner_verification_apply_r118($1)',[a.t]);assert.equal(x.approved,false);});

await check('Owner report shows actual alerts and preserves full agents dashboard',async()=>{const x=await scalar('select public.app_kombax_owner_report_payload_r114(90)');assert.equal(x.ok,true);assert(x.owner_alerts.unread>0);assert(Array.isArray(x.agents.turns));assert.notEqual(x.owner_alerts.source,'not_available_in_current_backend');});
console.log(`Owner verification database regression: ${passed} PASS`);
}catch(error){console.error(error.message,error.where||'');process.exitCode=1;}finally{await db.close();}



