import assert from 'node:assert/strict';
import fs from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();
try {
 await db.exec(`create table public.perfiles_kombax_directos(id uuid primary key,perfil_id uuid,tipo text,origen_identidad_social_id uuid);
 create table public.kombax_solicitudes_alta(id uuid primary key,perfil_id uuid,tipo text,perfil_directo_id uuid);
 create table public.identidades_sociales(id uuid primary key,perfil_id uuid,activada_en timestamptz default now());`);
 await db.exec(fs.readFileSync(new URL('../supabase/migrations/20261003194438_pilot_identity_trigger_scope_fix_r118.sql',import.meta.url),'utf8'));
 await db.exec(`create trigger direct_guard before insert or update on public.perfiles_kombax_directos for each row execute function public.app_kombax_account_identity_guard_r100();
 create trigger application_guard before insert or update on public.kombax_solicitudes_alta for each row execute function public.app_kombax_account_identity_guard_r100();`);
 const person='00000000-0000-4000-8000-000000000001',facet='00000000-0000-4000-8000-000000000002',identity='00000000-0000-4000-8000-000000000003';
 await db.query('insert into public.kombax_solicitudes_alta(id,perfil_id,tipo) values(gen_random_uuid(),$1,\'club\')',[person]);
 await db.query('insert into public.identidades_sociales(id,perfil_id) values($1,$2)',[identity,person]);
 await db.query('insert into public.perfiles_kombax_directos(id,perfil_id,tipo) values($1,$2,\'profesional\')',[facet,person]);
 assert.equal((await db.query('select origen_identidad_social_id from public.perfiles_kombax_directos')).rows[0].origen_identidad_social_id,identity);
 await db.query('insert into public.kombax_solicitudes_alta(id,perfil_id,tipo,perfil_directo_id) values(gen_random_uuid(),$1,\'profesional\',$2)',[person,facet]);
 await assert.rejects(db.query('insert into public.kombax_solicitudes_alta(id,perfil_id,tipo,perfil_directo_id) values(gen_random_uuid(),gen_random_uuid(),\'profesional\',$1)',[facet]),/KOMBAX_PROFILE_APPLICATION_MISMATCH/);
 await assert.rejects(db.query('insert into public.kombax_solicitudes_alta(id,perfil_id,tipo,perfil_directo_id) values(gen_random_uuid(),$1,\'competidor\',$2)',[person,facet]),/KOMBAX_PROFILE_APPLICATION_MISMATCH/);
 console.log('PASS 5/5 shared identity trigger: club application, direct facet, identity continuity, ownership and type guards');
} finally {await db.close();}
