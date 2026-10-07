import assert from 'node:assert/strict';import {PGlite} from '@electric-sql/pglite';import {readFileSync} from 'node:fs';
const db=new PGlite();const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');let checks=0;const ok=(v,n)=>{assert.ok(v,n);checks++;};
try{
await db.exec(`create role anon;create role authenticated;create schema auth;create schema kombax_ai_ops;create function auth.uid() returns uuid language sql as $$select nullif(current_setting('qa.uid',true),'')::uuid$$;
create table clubes(id uuid,nombre text,activo boolean);create table perfiles_kombax_directos(id uuid,tipo text,nombre_publico text,estado text);create table disciplinas(id uuid,club_id uuid,nombre text,activa boolean);create table grupos(id uuid,club_id uuid,nombre text,disciplina_id uuid,activo boolean);create table tarifas(id uuid,club_id uuid,nombre text,disciplina_id uuid,activa boolean);
create table qa_access(uid uuid,ref text);create function kombax_ai_ops.org_assist_access_allowed(uuid,text) returns boolean language sql as $$select exists(select 1 from public.qa_access where uid=$1 and ref=$2)$$;`);
await db.query("insert into clubes values($1,'Alpha',true),($2,'Beta',true)",[id(1),id(2)]);await db.query("insert into perfiles_kombax_directos values($1,'marca','Brand A','activo')",[id(3)]);
await db.query("insert into qa_access values($1,$2),($1,$3)",[id(10),'club:'+id(1),'profile:'+id(3)]);
await db.query("insert into disciplinas values($1,$2,'Boxeo',true),($3,$4,'Other club',true),($5,$2,'Archived',false)",[id(21),id(1),id(22),id(2),id(23)]);await db.query("insert into grupos values($1,$2,'Morning',$3,true)",[id(30),id(1),id(21)]);await db.query("insert into tarifas values($1,$2,'Basic',$3,true)",[id(40),id(1),id(21)]);
const sql=readFileSync('supabase/migrations/20261006211006_permissions_assist_context_fix16.sql','utf8');await db.exec(sql.slice(sql.indexOf('create or replace function kombax_ai_ops.assistant_identity_context_fix16'),sql.indexOf('CREATE OR REPLACE FUNCTION public.app_kombax_assist_turn_internal_v227')));
await db.query("select set_config('qa.uid',$1,false)",[id(10)]);let c=(await db.query('select app_kombax_assist_identity_context_fix16($1) c',['club:'+id(1)])).rows[0].c;
ok(c.entity_name==='Alpha','correct club');ok(c.entity_id===id(1),'correct identity');ok(c.disciplines.length===1&&c.disciplines[0].nombre==='Boxeo','only active scoped disciplines');ok(c.groups[0].disciplina_id===id(21),'scoped group relation');ok(c.tariffs[0].nombre==='Basic','scoped tariffs');ok(!JSON.stringify(c).includes('Other club'),'other tenant excluded');
await assert.rejects(db.query('select app_kombax_assist_identity_context_fix16($1)',['club:'+id(2)]),/ASSIST_CONTEXT_FORBIDDEN/);checks++;
c=(await db.query('select app_kombax_assist_identity_context_fix16($1) c',['profile:'+id(3)])).rows[0].c;ok(c.entity_name==='Brand A'&&c.groups.length===0,'brand cannot inherit club catalog');
await db.query("select set_config('qa.uid','',false)");await assert.rejects(db.query('select app_kombax_assist_identity_context_fix16($1)',['club:'+id(1)]),/ASSIST_CONTEXT_FORBIDDEN/);checks++;
await db.exec('set role authenticated');await assert.rejects(db.query('select kombax_ai_ops.assistant_identity_context_fix16($1,$2)',[id(10),'club:'+id(1)]),/permission denied/);checks++;
console.log('PASS '+checks+' tenant identity catalog authorization checks');
}finally{await db.close();}

