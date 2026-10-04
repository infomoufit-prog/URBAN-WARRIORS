import {PGlite} from '@electric-sql/pglite';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const db=new PGlite();let passed=0;const check=(v,n)=>{assert.ok(v,n);passed++};
try{
await db.exec(`create role anon;create role authenticated;create schema auth;create function auth.uid() returns uuid language sql as $$select null::uuid$$;
create table clubes(id uuid primary key,logo_url text);create table perfiles_club_publicos(club_id uuid,logo_url text);
create table kombax_eventos_publicos(id uuid,creador_club_id uuid,creador_perfil_directo_id uuid);
create table kombax_social_perfiles(id uuid,perfil_directo_id uuid,sujeto_tipo text,club_id uuid,nombre_publico text,slug text,verificado boolean);
create table kombax_showcase_marcas(perfil_directo_id uuid,logo_url text,actualizado_en timestamptz);
create table kombax_evento_entidades(id uuid,rol text,origen text,social_profile_id uuid,nombre_externo text,logo_url_externo text,web_externa text,puede_gestionar boolean,estado text,orden smallint,evento_id uuid,creado_en timestamptz);
create function app_kombax_social_avatar_url_v063(uuid) returns text language sql as $$select 'https://old.example/avatar.png'::text$$;
create function app_kombax_evento_puede_gestionar_v160(uuid) returns boolean language sql as $$select false$$;
create function app_kombax_event_can_view_v236(uuid) returns boolean language sql as $$select true$$;
create function app_kombax_social_tipo_v051(uuid) returns text language sql as $$select 'club'::text$$;
create table reports(club_id uuid,snapshot jsonb);create table receipts(club_id uuid,emisor_logo_url text);`);
const sql=await readFile(new URL('../supabase/migrations/20261004114011_kombax_document_identity_logos_r118.sql',import.meta.url),'utf8');
await db.exec(sql.slice(0,sql.indexOf('CREATE OR REPLACE FUNCTION public.app_kombax_report_payload_r77'))+'revoke all on all functions in schema kombax_documents from public,anon,authenticated;commit;');
await db.exec(`create trigger logo before insert on reports for each row execute function app_finance_report_public_logo_r104();create trigger logo before insert on receipts for each row execute function app_receipt_public_logo_r104();
insert into clubes values('00000000-0000-4000-8000-000000000001','https://old.example/old.png'),('00000000-0000-4000-8000-000000000002','https://club2.example/logo.jpg');
insert into perfiles_club_publicos values('00000000-0000-4000-8000-000000000001','https://public.example/current.webp');`);
const logo=async(id)=>(await db.query(`select kombax_documents.club_logo('${id}') v`)).rows[0].v;
const id='00000000-0000-4000-8000-000000000001';check(await logo(id)==='https://public.example/current.webp','current public WebP wins');
await db.exec(`insert into reports values('${id}','{"club":{}}');insert into receipts values('${id}',null)`);
check((await db.query("select snapshot#>>'{club,logo_url}' v from reports")).rows[0].v==='https://public.example/current.webp','report snapshots current logo');
check((await db.query('select emisor_logo_url v from receipts')).rows[0].v==='https://public.example/current.webp','receipt gets club logo');
await db.exec("update perfiles_club_publicos set logo_url='  '");check(await logo(id)==='https://old.example/old.png','blank public logo falls back');
check(await logo('00000000-0000-4000-8000-000000000002')==='https://club2.example/logo.jpg','other club isolated');
check(await logo('00000000-0000-4000-8000-000000000009')===null,'missing club returns no invented logo');
check((await db.query("select snapshot#>>'{club,logo_url}' v from reports")).rows[0].v==='https://public.example/current.webp','historical report immutable');
check(!(await db.query("select has_function_privilege('anon','kombax_documents.club_logo(uuid)','execute') v")).rows[0].v,'helper not publicly executable');
check(!sql.includes('add column ticket_logo_url'),'ticket selection unchanged; no mandatory organizer');
console.log(JSON.stringify({suite:'document-identity-logos-r118',passed}));
}finally{await db.close()}

