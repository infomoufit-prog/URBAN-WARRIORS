import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=new PGlite();let passed=0;
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const u=id(1),club=id(2),member=id(3),d1=id(4),d2=id(5),g1=id(6),g2=id(7),g3=id(8);
const ok=(name,value)=>{assert.ok(value,name);passed++};
try{
 await db.exec(`create schema auth;create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create table socios(id uuid primary key default gen_random_uuid(),club_id uuid,perfil_id uuid,nombre text,apellidos text,fecha_nacimiento date,telefono text,email text,tutor_nombre text,tarifa_id uuid,estado text,kombax_acceso_estado text,creado_en timestamptz default now(),actualizado_en timestamptz);
 create table disciplinas(id uuid,club_id uuid,activa boolean);
 create table grupos(id uuid,club_id uuid,disciplina_id uuid,activo boolean,plazas int);
 create table tarifas(id uuid,club_id uuid,activa boolean);
 create table socio_disciplinas(id uuid primary key default gen_random_uuid(),club_id uuid,socio_id uuid,disciplina_id uuid,grupo_id uuid,activa boolean,fecha_inicio date,fecha_fin date);
 create unique index active_pair on socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id) where activa and grupo_id is not null;
 create table preinscripciones(id uuid primary key default gen_random_uuid(),club_id uuid,solicitante_perfil_id uuid,tipo_solicitud text,nombre text,apellidos text,fecha_nacimiento date,telefono text,disciplina_id uuid,grupo_id uuid,tarifa_id uuid,estado text,email_acceso text,tutor_email text,tutor_nombre text,parentesco text,revisada_por uuid,revisada_en timestamptz,observaciones text);
 create table tutores_socios(club_id uuid,tutor_perfil_id uuid,socio_id uuid,parentesco text,contacto_principal boolean,unique(club_id,tutor_perfil_id,socio_id));
 create table notificaciones(club_id uuid,perfil_id uuid,clave text,tipo text,titulo text,cuerpo text,ruta text,datos jsonb,creada_por uuid);
 create unique index notification_key on notificaciones(club_id,perfil_id,clave) where clave is not null and perfil_id is not null;
 create function tiene_rol_club(uuid,variadic text[]) returns boolean language sql as $$select auth.uid()='${u}'::uuid$$;
 create function puede_ver_socio(uuid) returns boolean language sql as $$select exists(select 1 from socios s where s.id=$1 and s.perfil_id=auth.uid())$$;
 insert into socios(id,club_id,perfil_id,nombre,apellidos,fecha_nacimiento,email,estado) values('${member}','${club}','${u}','QA','Member','1990-01-01','qa@example.invalid','activo');
 insert into disciplinas values('${d1}','${club}',true),('${d2}','${club}',true);
 insert into grupos values('${g1}','${club}','${d1}',true,20),('${g2}','${club}','${d1}',true,20),('${g3}','${club}','${d2}',true,20);`);
 await db.exec(readFileSync(new URL('./fixtures/member-multigroup-live-r120.sql',import.meta.url),'utf8'));
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[u]);
 for(const [d,g] of [[d1,g1],[d1,g2],[d2,g3]]){
  const request=(await db.query('select app_solicitar_nueva_matricula($1,$2,$3) id',[member,d,g])).rows[0].id;
  const approved=(await db.query('select app_aprobar_preinscripcion($1) id',[request])).rows[0].id;
  ok('approval reuses the same member',approved===member);
  ok('approval retry reuses the same member',(await db.query('select app_aprobar_preinscripcion($1) id',[request])).rows[0].id===member);
 }
 ok('one member record',(await db.query('select count(*)::int n from socios')).rows[0].n===1);
 ok('three active group enrollments',(await db.query('select count(*)::int n from socio_disciplinas where activa')).rows[0].n===3);
 ok('two disciplines',(await db.query('select count(distinct disciplina_id)::int n from socio_disciplinas where activa')).rows[0].n===2);
 await assert.rejects(db.query('select app_solicitar_nueva_matricula($1,$2,$3)',[member,d1,g1]),/ya está inscrito/);passed++;
 await assert.rejects(db.query('select app_solicitar_nueva_matricula($1,$2,$3)',[member,d1,g3]),/no pertenece/);passed++;
 const second=(await db.query('select id from socio_disciplinas where grupo_id=$1',[g2])).rows[0].id;
 await db.query('select app_desactivar_matricula($1)',[second]);
 ok('deactivating one group preserves the other groups',(await db.query('select count(*)::int n from socio_disciplinas where activa')).rows[0].n===2);
 ok('deactivation preserves the member account',(await db.query('select perfil_id from socios where id=$1',[member])).rows[0].perfil_id===u);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id(99)]);
 await assert.rejects(db.query('select app_solicitar_nueva_matricula($1,$2,$3)',[member,d1,g2]),/No tienes permiso/);passed++;
 console.log(`PASS ${passed}/${passed} actual database multi-discipline / multi-group flow cases`);
}finally{await db.close();}
