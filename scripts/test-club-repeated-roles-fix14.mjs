import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=new PGlite();let n=0;const id=x=>`00000000-0000-4000-8000-${String(x).padStart(12,'0')}`;
const club=id(10),owner=id(1),ok=(label,v)=>{assert.ok(v,label);n++};
const as=async(x,email='')=>{await db.query("select set_config('test.uid',$1,false),set_config('test.email',$2,false)",[x,email]);};
try{
 await db.exec(`create schema auth;create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('email',current_setting('test.email',true),'user_metadata','{}'::jsonb)$$;
 create type rol_club as enum('direccion','secretaria','economia','comunicacion','monitor','alumno','familia');
 create table perfiles(id uuid primary key,nombre text,apellidos text);
 create table clubes(id uuid primary key,activo boolean);
 create table miembros_club(id uuid default gen_random_uuid(),club_id uuid,perfil_id uuid,rol rol_club,activo boolean,coordinacion boolean default false,unique(club_id,perfil_id,rol));
 create table invitaciones_club(id uuid primary key default gen_random_uuid(),club_id uuid,email text,rol rol_club,invitado_por uuid,coordinacion boolean,tipo_invitacion text,codigo text,nombre_destinatario text,expira_en timestamptz,email_estado text,estado text default 'pendiente',aceptado_por uuid,aceptado_en timestamptz);
 create table kombax_solicitudes_equipo_club(id uuid primary key default gen_random_uuid(),club_id uuid,perfil_id uuid,estado text default 'pendiente',revisado_en timestamptz,revisado_por uuid,rol_asignado rol_club,coordinacion boolean,nota_revision text,actualizado_en timestamptz);
 create function tiene_rol_club(uuid,variadic text[]) returns boolean language sql stable set search_path=public,auth as $$select exists(select 1 from miembros_club where club_id=$1 and perfil_id=auth.uid() and activo and rol::text=any($2))$$;
 create function app_kombax_club_owner_fix14(uuid) returns boolean language sql stable as $$select public.tiene_rol_club($1,'direccion')$$;
 create function app_puede_gestionar_perfil_club_v035(uuid) returns boolean language sql stable as $$select public.tiene_rol_club($1,'direccion','secretaria')$$;
 create function app_kombax_invitation_code_v059(text) returns text language sql volatile as $$select upper(gen_random_uuid()::text)$$;
 insert into perfiles values('${owner}','Owner','QA');insert into clubes values('${club}',true);insert into miembros_club(club_id,perfil_id,rol,activo) values('${club}','${owner}','direccion',true);`);
 await db.exec(readFileSync(new URL('./fixtures/club-team-live-fix14.sql',import.meta.url),'utf8'));
 for(let x=2;x<=5;x++){
  await as(owner);const invite=(await db.query("select app_kombax_invitacion_crear_v059($1,'equipo',$2,'coordinacion') v",[club,`coordinator${x}@example.invalid`])).rows[0].v;
  await as(id(x),`coordinator${x}@example.invalid`);const accepted=(await db.query('select app_kombax_invitacion_aceptar_equipo_v059($1) v',[invite.codigo])).rows[0].v;
  ok(`coordinator ${x-1} accepted independently`,accepted.rol==='coordinacion');
 }
 ok('four coordinators coexist',(await db.query('select count(distinct perfil_id)::int n from miembros_club where coordinacion and activo')).rows[0].n===4);
 for(let x=6;x<=7;x++){
  const request=(await db.query('insert into kombax_solicitudes_equipo_club(club_id,perfil_id) values($1,$2) returning id',[club,id(x)])).rows[0].id;
  await as(owner);const resolved=(await db.query("select app_kombax_solicitud_equipo_resolver_v060($1,'aprobada','secretaria') v",[request])).rows[0].v;
  ok(`secretary ${x-5} approved independently`,resolved.rol==='secretaria');
 }
 ok('secretaries coexist with coordinators',(await db.query("select count(distinct perfil_id)::int n from miembros_club where rol='secretaria' and activo")).rows[0].n===6);
 const request=(await db.query('insert into kombax_solicitudes_equipo_club(club_id,perfil_id) values($1,$2) returning id',[club,id(8)])).rows[0].id;
 await as(id(2));await assert.rejects(db.query("select app_kombax_solicitud_equipo_resolver_v060($1,'aprobada','coordinacion')",[request]),/No tienes permiso/);n++;
 await as(owner);await db.query("select app_kombax_solicitud_equipo_resolver_v060($1,'aprobada','coordinacion')",[request]);
 ok('new coordination request preserves previous coordinators',(await db.query('select count(distinct perfil_id)::int n from miembros_club where coordinacion and activo')).rows[0].n===5);
 await db.query('update miembros_club set activo=false where club_id=$1 and perfil_id=$2',[club,id(2)]);
 ok('one membership deactivation preserves other coordinators',(await db.query('select count(distinct perfil_id)::int n from miembros_club where coordinacion and activo')).rows[0].n===4);
 ok('coordinator keeps combined functions',(await db.query('select count(*)::int n from miembros_club where perfil_id=$1 and activo',[id(3)])).rows[0].n===3);
 console.log(`PASS ${n}/${n} repeated club team roles using inspected live RPC definitions`);
}finally{await db.close();}
