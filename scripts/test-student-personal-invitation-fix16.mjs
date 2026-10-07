import {PGlite} from '@electric-sql/pglite';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;const uid='00000000-0000-4000-8000-000000000001',club='00000000-0000-4000-8000-000000000002';const file=p=>readFileSync(p,'utf8');const ok=v=>{assert.ok(v);n++;};
try{
await db.exec(`create schema auth;create function auth.uid() returns uuid language sql stable as $$select '${uid}'::uuid$$;create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('email',coalesce(nullif(current_setting('qa.email',true),''),'qa@example.invalid'))$$;
create table auth.users(id uuid,email text,email_confirmed_at timestamptz,deleted_at timestamptz);insert into auth.users values('${uid}','qa@example.invalid',now(),null);
create table clubes(id uuid,slug text,activo boolean);insert into clubes values('${club}','qa',true);
create table invitaciones_club(id uuid default gen_random_uuid(),codigo text,tipo_invitacion text,estado text,expira_en timestamptz,email text,club_id uuid,aceptado_por uuid,aceptado_en timestamptz);
insert into invitaciones_club(codigo,tipo_invitacion,estado,expira_en,email,club_id) values('PERSONAL','alumno','pendiente',now()+interval '1 day','qa@example.invalid','${club}');
create table app_mutation_requests(request_id uuid primary key,user_id uuid,operation text,result jsonb);
create function app_kombax_codigo_validar_seguro_v086(text,text,text) returns jsonb language sql as $$select jsonb_build_object('valid',$3='12345','version',1)$$;
create function app_mutate_v160_pre_invites_059(text,jsonb,uuid) returns jsonb language plpgsql as $$declare r jsonb;begin r:=jsonb_build_object('ok',current_setting('qa.fail',true) is distinct from 'yes','data','{}'::jsonb);insert into app_mutation_requests values($3,auth.uid(),$1,r);return r;end$$;`);
await db.exec(file('scripts/fixtures/account-code-live-fix16.sql'));await db.exec(file('scripts/fixtures/student-invitation-live-fix16.sql'));
for(const f of ['20261006213057_family_code_registration_result_fix16.sql','20261006213119_family_registration_variable_fix16.sql'])await db.exec(file('supabase/migrations/'+f));
const request='00000000-0000-4000-8000-000000000010';const call=(code='PERSONAL',slug='qa',id=crypto.randomUUID())=>db.query("select app_mutate_v160_pre_lifecycle_133('cuenta.registrar',$1,$2) v",[JSON.stringify({club_slug:slug,invite_code:code}),id]);
ok((await call()).rows[0].v.ok===false);
for(const f of ['20261006221411_student_personal_invitation_gateway_fix16.sql','20261006221420_student_personal_invitation_slug_fix16.sql'])await db.exec(file('supabase/migrations/'+f));
await db.query("select set_config('qa.email','other@example.invalid',false)");ok((await call()).rows[0].v.ok===false);await db.query("select set_config('qa.email','qa@example.invalid',false)");
ok((await call('PERSONAL','other-club')).rows[0].v.ok===false);
await db.query('update auth.users set email_confirmed_at=null');ok((await call()).rows[0].v.ok===false);await db.query('update auth.users set email_confirmed_at=now()');
await db.query("update invitaciones_club set expira_en=now()-interval '1 day'");await assert.rejects(()=>call(),/caducado/);n++;await db.query("update invitaciones_club set expira_en=now()+interval '1 day'");
await db.query("select set_config('qa.fail','yes',false)");ok((await call()).rows[0].v.ok===false);ok((await db.query('select estado from invitaciones_club')).rows[0].estado==='pendiente');await db.query("select set_config('qa.fail','no',false)");
const out=(await call('PERSONAL','qa',request)).rows[0].v;ok(out.ok===true);ok(out.data.invitation.tipo==='alumno');ok((await db.query('select estado from invitaciones_club')).rows[0].estado==='aceptada');
ok((await call('PERSONAL','qa',request)).rows[0].v.ok===true);await assert.rejects(()=>call(),/no válido/);n++;
ok((await call('12345')).rows[0].v.data.club_access_code.tipo==='alumnos');
for(const f of ['20261006221411_student_personal_invitation_gateway_fix16.sql','20261006221420_student_personal_invitation_slug_fix16.sql'])await db.exec(file('supabase/migrations/'+f));ok((await call('12345')).rows[0].v.ok===true);
console.log(`PASS ${n} pupil personal invitation checks (real gateways; isolated registration stub)`);
}finally{await db.close();}
