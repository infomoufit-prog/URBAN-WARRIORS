import assert from 'node:assert/strict';import {PGlite} from '@electric-sql/pglite';import {readFileSync} from 'node:fs';
const db=new PGlite(),u=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;let n=0;
await db.exec(`create role anon;create role authenticated;create schema kombax_meta;
create table public.kombax_social_perfiles(id uuid,sujeto_tipo text,estado text,club_id uuid,perfil_directo_id uuid,identidad_social_id uuid,visible bool,publicar_habilitado bool);
create table public.miembros_club(club_id uuid,perfil_id uuid,activo bool,rol text);
create table public.perfiles_kombax_directos(id uuid,estado text,tipo text,perfil_id uuid);
create table public.kombax_perfil_gestores(perfil_directo_id uuid,perfil_id uuid,estado text,rol text);
create table public.identidades_sociales(id uuid,perfil_id uuid,tipo text,estado text,socio_origen_id uuid,club_origen_id uuid);
create table public.socios(id uuid,club_id uuid,perfil_id uuid,estado text,fecha_nacimiento date);
insert into public.kombax_social_perfiles values('${u(1)}','miembro','activo',null,null,'${u(2)}',true,true),('${u(10)}','club','activo','${u(11)}',null,null,true,true),('${u(20)}','perfil_directo','activo',null,'${u(21)}',null,true,true);
insert into public.identidades_sociales values('${u(2)}','${u(3)}','miembro','activa','${u(4)}','${u(11)}');
insert into public.socios values('${u(4)}','${u(11)}','${u(3)}','activo',current_date-interval '20 years');
insert into public.miembros_club values('${u(11)}','${u(12)}',true,'direccion'),('${u(11)}','${u(13)}',true,'secretaria');
insert into public.perfiles_kombax_directos values('${u(21)}','activo','marca','${u(22)}');
insert into public.kombax_perfil_gestores values('${u(21)}','${u(23)}','activo','admin'),('${u(21)}','${u(24)}','activo','editor');`);
await db.exec(readFileSync('supabase/migrations/20261014213846_meta_instagram_member_owner_r270.sql','utf8'));
const allowed=async(actor=u(3),social=u(1))=>(await db.query('select kombax_meta.can_manage($1,$2) allowed',[actor,social])).rows[0].allowed;
assert.equal(await allowed(),true);n++;
for(const actor of [null,u(99),u(12)]){assert.equal(await allowed(actor),false);n++;}
const blocked=["update kombax_social_perfiles set estado='suspendido' where sujeto_tipo='miembro'","update kombax_social_perfiles set visible=false where sujeto_tipo='miembro'","update kombax_social_perfiles set publicar_habilitado=false where sujeto_tipo='miembro'","update identidades_sociales set estado='suspendida'","update identidades_sociales set tipo='espectador'",`update identidades_sociales set perfil_id='${u(99)}'`,"update socios set estado='prealta'","update socios set fecha_nacimiento=null","update socios set fecha_nacimiento=current_date-interval '15 years'",`update socios set perfil_id='${u(99)}'`,`update socios set club_id='${u(99)}'`];
for(const sql of blocked){await db.exec('begin;'+sql);assert.equal(await allowed(),false,sql);n++;await db.exec('rollback');}
await db.exec("begin;update socios set fecha_nacimiento=current_date-interval '16 years'");assert.equal(await allowed(),true);n++;await db.exec('rollback');
for(const [actor,social,result] of [[u(12),u(10),true],[u(13),u(10),false],[u(22),u(20),true],[u(23),u(20),true],[u(24),u(20),false]]){assert.equal(await allowed(actor,social),result);n++;}
for(const role of ['anon','authenticated']){const r=await db.query(`select has_function_privilege('${role}','kombax_meta.can_manage(uuid,uuid)','execute') allowed`);assert.equal(r.rows[0].allowed,false);n++;}
await db.close();console.log(`PASS ${n} isolated Meta member ownership/security checks; no external requests`);
