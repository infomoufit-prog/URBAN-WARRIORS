import {PGlite} from '@electric-sql/pglite';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;const uid='00000000-0000-4000-8000-000000000001',club='00000000-0000-4000-8000-000000000002';
const ok=v=>{assert.ok(v);n++;};const deny=async(code,pattern)=>{await assert.rejects(db.query('select app_kombax_invitacion_aceptar_equipo_v059($1)',[code]),pattern);n++;};
try{
await db.exec(`create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$select nullif(current_setting('qa.uid',true),'')::uuid$$;create function auth.jwt() returns jsonb language sql as $$select jsonb_build_object('email',current_setting('qa.email',true))$$;
create table auth.users(id uuid,email text,email_confirmed_at timestamptz,deleted_at timestamptz);insert into auth.users values('${uid}','qa@example.invalid',now(),null);
create type rol_club as enum('direccion','secretaria','economia','comunicacion','monitor','familia');
create table perfiles(id uuid primary key,nombre text,apellidos text);
create table miembros_club(club_id uuid,perfil_id uuid,rol rol_club,activo boolean,coordinacion boolean,unique(club_id,perfil_id,rol));
create table invitaciones_club(id uuid default gen_random_uuid(),club_id uuid,email text,rol rol_club,coordinacion boolean,tipo_invitacion text,codigo text,estado text,expira_en timestamptz,aceptado_por uuid,aceptado_en timestamptz);
insert into invitaciones_club(club_id,email,rol,coordinacion,tipo_invitacion,codigo,estado,expira_en) values
('${club}','qa@example.invalid','secretaria',true,'equipo','COORD','pendiente',now()+interval '1 day'),
('${club}','other@example.invalid','monitor',false,'equipo','OTHER','pendiente',now()+interval '1 day'),
('${club}','qa@example.invalid','monitor',false,'equipo','EXPIRED','pendiente',now()-interval '1 day'),
('${club}','qa@example.invalid','direccion',false,'equipo','OWNER','pendiente',now()+interval '1 day');`);
await db.exec(readFileSync('supabase/migrations/20261006212918_team_invitation_accept_permissions_fix16.sql','utf8'));
ok((await db.query("select has_function_privilege('authenticated','app_kombax_invitacion_aceptar_equipo_v059(text)','execute') v")).rows[0].v);ok(!(await db.query("select has_function_privilege('anon','app_kombax_invitacion_aceptar_equipo_v059(text)','execute') v")).rows[0].v);
await deny('COORD',/AUTH_REQUIRED/);await db.exec(`select set_config('qa.uid','${uid}',false),set_config('qa.email','qa@example.invalid',false)`);
await deny('OTHER',/otro correo/);await deny('EXPIRED',/caducado/);await deny('OWNER',/ROLE_NOT_ALLOWED/);
await db.exec('update auth.users set email_confirmed_at=null');await deny('COORD',/CONFIRMATION_REQUIRED/);await db.exec('update auth.users set email_confirmed_at=now()');
await db.exec("select set_config('qa.email','forged@example.invalid',false)");await deny('COORD',/otro correo/);await db.exec("select set_config('qa.email','qa@example.invalid',false);set role authenticated");
ok((await db.query("select app_kombax_invitacion_aceptar_equipo_v059('COORD') v")).rows[0].v.rol==='coordinacion');await db.exec('reset role');
ok((await db.query('select count(*)::int n from miembros_club where activo and coordinacion')).rows[0].n===3);ok((await db.query("select estado from invitaciones_club where codigo='COORD'")).rows[0].estado==='aceptada');await deny('COORD',/no válido/);
ok((await db.query("select count(*)::int n from miembros_club where rol='direccion'")).rows[0].n===0);
console.log('PASS '+n+' personal team invitation acceptance checks');
}finally{await db.close();}
