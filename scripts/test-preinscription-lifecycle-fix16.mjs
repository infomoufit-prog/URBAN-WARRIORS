import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
const db=new PGlite();
try{
await db.exec(`
create role anon;create role authenticated;create schema private;create schema auth;
create function auth.uid() returns uuid language sql as 'select null::uuid';
create type rol_club as enum('direccion','secretaria');
create table perfiles(id uuid);
create table preinscripciones(id uuid primary key,club_id uuid,estado text,nombre text,apellidos text,solicitante_perfil_id uuid);
create table notificaciones(club_id uuid,rol_destino rol_club,clave text,tipo text,titulo text,cuerpo text check(cuerpo<>'FAIL ha enviado una solicitud.'),ruta text,datos jsonb,creada_por uuid,ciclo_estado text default 'activo',archivado_en timestamptz,archivado_por uuid,papelera_en timestamptz,papelera_por uuid,restaurar_hasta timestamptz,leida boolean default false,leida_en timestamptz);
create unique index notice_key on notificaciones(club_id,rol_destino,clave) where clave is not null and rol_destino is not null;
create function guard() returns trigger language plpgsql as $$
begin
 if (new.ciclo_estado,new.archivado_en,new.archivado_por,new.papelera_en,new.papelera_por,new.restaurar_hasta) is distinct from (old.ciclo_estado,old.archivado_en,old.archivado_por,old.papelera_en,old.papelera_por,old.restaurar_hasta)
 and coalesce(current_setting('kombax.lifecycle_gateway',true),'')<>'on' then raise exception 'LIFECYCLE_GATEWAY_REQUIRED';end if;return new;
end $$;
create trigger lifecycle before update on notificaciones for each row execute function guard();
`);
await db.exec(readFileSync('supabase/migrations/20261006201705_preinscription_notification_lifecycle_fix16.sql','utf8'));
await db.exec("create trigger sync after insert or update on preinscripciones for each row execute function private.kombax_preinscripcion_notification_sync_r117();");
await db.exec("insert into preinscripciones values('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','enviada','Student','One',null),('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000010','enviada','Student','Two',null);");
assert.equal((await db.query('select count(*)::int n from notificaciones')).rows[0].n,4);
await db.exec("update preinscripciones set estado='aprobada' where nombre='Student' and apellidos='One';");
assert.equal((await db.query("select count(*)::int n from notificaciones where ciclo_estado='archivado' and leida")).rows[0].n,2);
assert.equal((await db.query("select count(*)::int n from notificaciones where ciclo_estado='activo'")).rows[0].n,2);
assert.equal((await db.query("select coalesce(current_setting('kombax.lifecycle_gateway',true),'') value")).rows[0].value,'');
await assert.rejects(db.exec("update notificaciones set ciclo_estado='archivado' where ciclo_estado='activo';"),/LIFECYCLE_GATEWAY_REQUIRED/);
await db.exec("update preinscripciones set estado='en_revision' where apellidos='One';");
assert.equal((await db.query("select count(*)::int n from notificaciones where ciclo_estado='activo' and archivado_en is null")).rows[0].n,4);
await assert.rejects(db.exec("insert into preinscripciones values('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000010','enviada','FAIL','',null);"),/check constraint/);
assert.equal((await db.query("select coalesce(current_setting('kombax.lifecycle_gateway',true),'') value")).rows[0].value,'');
console.log('PASS 8 pre-enrollment notification lifecycle checks');
}finally{await db.close();}
