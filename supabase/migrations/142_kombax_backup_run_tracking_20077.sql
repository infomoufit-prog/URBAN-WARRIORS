-- KOMBAX 20077 · Backup run tracking and cryptographic verification register.

create table if not exists public.kombax_backup_runs_v142 (
  id uuid primary key default gen_random_uuid(),
  snapshot_id text not null unique,
  build integer not null default 20077,
  status text not null check (status in ('created','verified','failed')),
  database_files integer not null default 0,
  storage_objects integer not null default 0,
  total_bytes bigint not null default 0,
  manifest_sha256 text,
  verification_failures integer not null default 0,
  created_at timestamptz not null default now(),
  verified_at timestamptz,
  detail jsonb not null default '{}'::jsonb
);

alter table public.kombax_backup_runs_v142 enable row level security;
revoke all on table public.kombax_backup_runs_v142 from public, anon, authenticated;
grant select, insert, update, delete on table public.kombax_backup_runs_v142 to service_role;

comment on table public.kombax_backup_runs_v142 is
  'KOMBAX 20077 backup snapshot and cryptographic verification register; closed to client roles.';
