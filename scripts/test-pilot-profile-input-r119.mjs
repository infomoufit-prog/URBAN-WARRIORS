import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=new PGlite();let count=0;
const ok=(name,value)=>{assert.ok(value,name);count++};
const migration=readFileSync(new URL('../supabase/migrations/20261004193838_kombax_pilot_profile_input_r119.sql',import.meta.url),'utf8');
const legacy=readFileSync(new URL('../supabase/migrations/307_kombax_pilot_club_direct_self_service_r117.sql',import.meta.url),'utf8').split('do $$')[0];
try{
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;
 create table public.perfiles(id uuid primary key);create table auth.users(id uuid primary key,email text,deleted_at timestamptz);
 create function public.app_kombax_slug_v043(text) returns text language sql as $$select lower(replace($1,' ','-'))$$;
 create table public.clubes(id uuid primary key default gen_random_uuid(),nombre text,slug text,lema text,cif text,telefono text,email text,direccion text,web text,activo boolean,theme_id text,branding_actualizado_por uuid,branding_actualizado_en timestamptz);
 create table public.miembros_club(club_id uuid,perfil_id uuid,rol text,activo boolean,coordinacion boolean,unique(club_id,perfil_id,rol));
 create table public.perfiles_club_publicos(club_id uuid,nombre_publico text,lema text,descripcion text check(length(descripcion)<=1200),ciudad text,provincia text,pais text,contacto_publico text,web_publica text check(web_publica is null or web_publica ~ '^https://'),instagram text check(instagram is null or instagram ~ '^https://'),tiktok text check(tiktok is null or tiktok ~ '^https://'),youtube text check(youtube is null or youtube ~ '^https://'),visible boolean,moderacion_oculta boolean,actualizado_por uuid,actualizado_en timestamptz);
 create function public.test_club_profile() returns trigger language plpgsql as $$begin insert into public.perfiles_club_publicos(club_id,nombre_publico) values(new.id,new.nombre);return new;end$$;
 create trigger test_profile after insert on public.clubes for each row execute function public.test_club_profile();
 create table public.disciplinas(club_id uuid,nombre text,activa boolean,orden smallint,unique(club_id,nombre));
 create table public.kombax_actor_audit(actor_perfil_id uuid,club_id uuid,accion text,objeto_tipo text,objeto_id uuid,detalle jsonb);
 insert into public.perfiles values('00000000-0000-4000-8000-000000000001');insert into auth.users(id,email) select id,'qa@example.invalid' from public.perfiles;`);
 await db.exec(legacy);
 const u='00000000-0000-4000-8000-000000000001';
 const create=(name,data)=>db.query('select public.app_kombax_create_pilot_club_core_r117($1,$2,$3,$4,$1) id',[u,name,JSON.stringify(data),'{}']);
 await assert.rejects(create('QA before',{instagram:'urbanwarriors13'}),/check constraint/);count++;
 await db.exec(migration);
 for(const [input,network,expected] of [
 ['urbanwarriors13','instagram','https://www.instagram.com/urbanwarriors13/'],
 [' @urbanwarriors13 ','instagram','https://www.instagram.com/urbanwarriors13/'],
 ['instagram.com/club','instagram','https://instagram.com/club'],
 ['http://www.instagram.com/club','instagram','https://www.instagram.com/club'],
 ['https://club.example/event','web','https://club.example/event'],
 ['club.example','web','https://club.example'],
 ['@club','tiktok','https://www.tiktok.com/@club'],
 ['@club','youtube','https://www.youtube.com/@club'],
 ['','instagram',null]]){
 const r=await db.query('select public.app_kombax_club_public_link_r119($1,$2) v',[input,network]);ok(input,r.rows[0].v===expected);
 }
 for(const input of ['javascript:alert(1)','https://','a b','https://user:pass@host.example','https://evil.example\\bad']){
 await assert.rejects(db.query('select public.app_kombax_club_public_link_r119($1)',[input]),/PUBLIC_LINK_INVALID/);count++;}
 const r=await create('QA after',{instagram:'urbanwarriors13',ciudad:'Girona',descripcion:''});
 const p=(await db.query('select * from public.perfiles_club_publicos where club_id=$1',[r.rows[0].id])).rows[0];
 ok('profile canonical Instagram',p.instagram==='https://www.instagram.com/urbanwarriors13/');
 ok('empty description remains optional',p.descripcion===null);
 ok('director membership',(await db.query('select * from miembros_club where club_id=$1',[r.rows[0].id])).rows[0].rol==='direccion');
 await create('QA limit',{descripcion:'a'.repeat(1200)});count++;
 await assert.rejects(create('QA excess',{descripcion:'a'.repeat(1201)}),/DESCRIPTION_TOO_LONG/);count++;
 ok('failed creation leaves no partial club',(await db.query("select count(*)::int n from clubes where nombre='QA excess'")).rows[0].n===0);
 await assert.rejects(create('QA after',{}),/ALREADY_EXISTS/);count++;
 ok('anonymous cannot call core',(await db.query("select has_function_privilege('anon','public.app_kombax_create_pilot_club_core_r117(uuid,text,jsonb,jsonb,uuid)','execute') v")).rows[0].v===false);
 console.log('PASS '+count+'/'+count+' pilot input database regression');
}finally{await db.close();}
