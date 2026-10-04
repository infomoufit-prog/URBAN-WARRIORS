import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;const ok=(label,v)=>{assert.ok(v,label);n++};
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
try{
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function auth.jwt() returns jsonb language sql as $$select '{}'::jsonb$$;
 create table auth.users(id uuid primary key default gen_random_uuid(),raw_user_meta_data jsonb,email text,deleted_at timestamptz);
 create table public.perfiles(id uuid primary key,nombre text,apellidos text,actualizado_en timestamptz);
 create table public.kombax_account_private_r117(perfil_id uuid primary key,fecha_nacimiento date,age_gate_version text,source text,actualizado_en timestamptz);
 create table public.clubes(id uuid primary key,slug text,activo boolean);
 insert into public.clubes values('00000000-0000-4000-8000-000000000010','qa',true);
 `);
 await db.exec(read('supabase/migrations/308_kombax_registration_birth_date_contract_r117.sql').split('create or replace function public.crear_perfil_usuario()')[0]);
 await db.exec(read('supabase/tests/fixtures-registration-before-fix11.sql'));
 await db.exec(`create trigger signup after insert on auth.users for each row execute function public.crear_perfil_usuario();`);
 const signup=(date,type='kombax_global')=>db.query('insert into auth.users(raw_user_meta_data) values($1) returning id',[JSON.stringify({nombre:'QA',apellidos:'Test',fecha_nacimiento:date,tipo_cuenta:type})]);
 await signup('2015-01-01');ok('baseline proves server age was not enforced',(await db.query('select count(*)::int n from auth.users')).rows[0].n===1);
 await db.exec(read('supabase/migrations/20261004195147_kombax_registration_validation_r119.sql'));
 const adult=await signup('1990-01-01');
 ok('profile persisted',(await db.query('select count(*)::int n from public.perfiles where id=$1',[adult.rows[0].id])).rows[0].n===1);
 ok('private DOB persisted',(await db.query('select fecha_nacimiento::text d from public.kombax_account_private_r117 where perfil_id=$1',[adult.rows[0].id])).rows[0].d==='1990-01-01');
 for(const [date,type,pattern] of [
 ['',null,/BIRTH_DATE_REQUIRED/],['2030-01-01',null,/BIRTH_DATE_INVALID/],['1899-01-01',null,/BIRTH_DATE_INVALID/],['2000-02-30',null,/BIRTH_DATE_INVALID/],['01-01-1990',null,/BIRTH_DATE_INVALID/],['2015-01-01',null,/MINOR_MUST_USE_TUTOR_FLOW/],['2009-01-01','tutor',/TUTOR_MIN_AGE_18/]
 ]){await assert.rejects(signup(date,type||'kombax_global'),pattern);n++;}
 await signup('2009-01-01');n++;await signup('1990-01-01','tutor');n++;
 const body=(await db.query("select pg_get_functiondef('public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid)'::regprocedure) d")).rows[0].d;
 ok('club DOB cannot override canonical account DOB',body.includes('v_account_dob<>p_fecha_nacimiento_adulto'));
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[adult.rows[0].id]);
 await assert.rejects(db.query("select public.app_crear_preinscripcion('00000000-0000-4000-8000-000000000010','menor','QA','Child','2030-01-01','QA','qa@example.invalid','',null,null,null,null,null)"),/BIRTH_DATE_INVALID/);n++;
 ok('failures leave no orphan profile',(await db.query('select count(*)::int n from auth.users u left join perfiles p on p.id=u.id where p.id is null')).rows[0].n===0);
 console.log('PASS '+n+'/'+n+' registration validation database regression');
}finally{await db.close();}
