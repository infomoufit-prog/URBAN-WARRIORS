// ============================================================================
// Urban Warriors · Verificación REAL de las migraciones (1.6.1)
//
// Por qué existe: las suites 1.6.0 solo hacían análisis estático de texto y
// simulaban el servidor con un mock. Ninguna podía fallar por una causa de
// servidor, así que no detectaron que 015 abortaba en una base limpia y dejaba
// la aplicación sin puerta de escritura.
//
// Esta suite levanta un PostgreSQL real (PGlite/WASM), aplica 001 → 017 en
// orden sobre una base vacía y comprueba que la puerta queda instalada.
//
// Dependencia opcional. Si PGlite no está instalado, la suite se omite sin
// romper el build de Netlify:
//     npm install --no-save @electric-sql/pglite
//     node scripts/test-sql-migrations-v161.mjs
// ============================================================================
import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const MIG = resolve(root, 'supabase/migrations');

// Dos modos, para que un SKIP nunca pueda leerse como una certificación:
//   - modo rápido (por defecto, el que usa Netlify): si PGlite no está, se omite
//     y se avisa en voz alta, pero no rompe el build.
//   - modo estricto (--require-db o UW_REQUIRE_DB=1): si PGlite no está, FALLA.
const REQUIRE_DB = process.argv.includes('--require-db') || process.env.UW_REQUIRE_DB === '1';

let PGlite, pgcrypto;
try {
  ({ PGlite } = await import('@electric-sql/pglite'));
  ({ pgcrypto } = await import('@electric-sql/pglite/contrib/pgcrypto'));
} catch (_) {
  if (REQUIRE_DB) {
    console.error('');
    console.error('================================================================');
    console.error('  CERTIFICACIÓN SQL FALLIDA');
    console.error('  @electric-sql/pglite no está instalado, así que NO se ha');
    console.error('  verificado ninguna migración contra un PostgreSQL real.');
    console.error('  Instálalo y repite:  npm install --no-save @electric-sql/pglite');
    console.error('================================================================');
    console.error('');
    process.exit(1);
  }
  console.log('');
  console.log('****************************************************************');
  console.log('  ATENCIÓN · CERTIFICACIÓN SQL OMITIDA (NO ES UN APROBADO)');
  console.log('  Las migraciones NO se han ejecutado contra PostgreSQL.');
  console.log('  Para certificar de verdad:  npm run certify');
  console.log('****************************************************************');
  console.log('');
  process.exit(0);
}

const db = new PGlite({ extensions: { pgcrypto } });

// Stub mínimo del entorno Supabase (schemas auth y storage, roles, helpers).
await db.exec(`
  create extension if not exists pgcrypto;
  create schema if not exists auth;
  create schema if not exists storage;
  do $$ begin
    if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
    if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
    if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
  end $$;
  create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text unique, raw_user_meta_data jsonb default '{}'::jsonb, created_at timestamptz default now());
  create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid; $$;
  create or replace function auth.role() returns text language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'authenticated'); $$;
  create or replace function auth.email() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.email', true), ''); $$;
  create or replace function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb); $$;
  create table if not exists storage.buckets (id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[], owner uuid, created_at timestamptz default now(), updated_at timestamptz default now());
  create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]; $$;
  create or replace function storage.filename(name text) returns text language sql immutable as $$ select (string_to_array(name,'/'))[array_length(string_to_array(name,'/'),1)]; $$;
  create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text, owner uuid, created_at timestamptz default now());
`);

const files = (await readdir(MIG)).filter((f) => f.endsWith('.sql')).sort();
const failures = [];
for (const file of files) {
  try {
    await db.exec(await readFile(resolve(MIG, file), 'utf8'));
    console.log(`OK    ${file}`);
  } catch (error) {
    failures.push(`${file}: ${String(error.message).split('\n')[0]}`);
    console.log(`FAIL  ${file} — ${String(error.message).split('\n')[0]}`);
  }
}
if (failures.length) throw new Error(`Migraciones con error sobre base limpia:\n  ${failures.join('\n  ')}`);

const one = async (sql) => (await db.query(sql)).rows[0];
const asserts = [
  ['puerta app_mutate_v160 instalada', (await one(`select to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null as x`)).x],
  ['contrato app_runtime_contract_v160 instalado', (await one(`select to_regprocedure('public.app_runtime_contract_v160(uuid)') is not null as x`)).x],
  ['sonda app_write_channel_probe_v160 instalada', (await one(`select to_regprocedure('public.app_write_channel_probe_v160(uuid)') is not null as x`)).x],
  ['bootstrap de dirección disponible (017)', (await one(`select to_regprocedure('public.app_bootstrap_direccion(text,text)') is not null as x`)).x],
  ['diagnóstico de persistencia disponible (017)', (await one(`select to_regprocedure('public.app_diagnostico_persistencia_v161()') is not null as x`)).x],
  ['tabla de recibos creada (016)', (await one(`select to_regclass('public.recibos_cuota') is not null as x`)).x],
  ['contrato = 1.6.0 / 160 / app_mutate_v160', (await one(`select exists(select 1 from public.app_runtime_meta where singleton and backend_version='1.6.0' and schema_epoch=160 and mutation_endpoint='app_mutate_v160') as x`)).x],
  ['authenticated puede ejecutar la puerta', (await one(`select has_function_privilege('authenticated','public.app_mutate_v160(text,jsonb,uuid)','EXECUTE') as x`)).x],
  ['RPC heredada de disciplinas cerrada a authenticated', !(await one(`select has_function_privilege('authenticated','public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint)','EXECUTE') as x`)).x],
  ['DML directo cerrado en disciplinas', !(await one(`select has_table_privilege('authenticated','public.disciplinas','INSERT') as x`)).x]
];

const failed = asserts.filter(([, ok]) => !ok);
for (const [name, ok] of asserts) console.log(`${ok ? 'OK' : 'FAIL'} ${name}`);
if (failed.length) throw new Error(`Gobernanza SQL real: ${failed.length} fallo(s): ${failed.map(([n]) => n).join(', ')}`);

// Escritura real de extremo a extremo a través de la puerta.
const CLUB = '11111111-1111-4111-8111-111111111111';
const DIR = '22222222-2222-4222-8222-222222222222';
await db.exec(await readFile(resolve(root, 'supabase/setup/bootstrap_urban_warriors_club.sql'), 'utf8'));
await db.exec(`
  insert into auth.users(id,email) values('${DIR}','direccion@urbanwarriors.test') on conflict do nothing;
  select public.app_bootstrap_direccion('direccion@urbanwarriors.test');
  select set_config('request.jwt.claim.sub','${DIR}',false);
`);
const created = await one(`select public.app_mutate_v160('disciplina.guardar', jsonb_build_object('club_id','${CLUB}','nombre','Suite Muay Thai','activa',true,'orden',1), gen_random_uuid()) as r`);
if (created.r?.ok !== true || !created.r?.data?.id) throw new Error('La puerta no confirmó la escritura real');
const persisted = await one(`select count(*)::int n from public.disciplinas where nombre='Suite Muay Thai'`);
if (persisted.n !== 1) throw new Error('La escritura no quedó persistida');
console.log('OK    escritura real a través de app_mutate_v160 persistida y verificada');

console.log(`OK: CERTIFICACIÓN SQL REAL SUPERADA — migraciones 001→017 aplicadas sobre PostgreSQL y ${asserts.length} controles de gobernanza verificados.`);
