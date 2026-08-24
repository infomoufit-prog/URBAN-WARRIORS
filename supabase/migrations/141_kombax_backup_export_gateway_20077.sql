-- KOMBAX 20077 · Backup export gateway token registry.
-- Operational recovery control for Free-plan logical/off-site backups.

create table if not exists public.kombax_backup_export_tokens_v141 (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  purpose text not null default 'pilot_backup' check (char_length(purpose) between 3 and 80),
  expires_at timestamptz not null,
  active boolean not null default true,
  uses integer not null default 0 check (uses >= 0),
  max_uses integer not null default 160 check (max_uses between 1 and 500),
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  constraint kombax_backup_export_expiry_future_v141 check (expires_at > created_at)
);

alter table public.kombax_backup_export_tokens_v141 enable row level security;
revoke all on table public.kombax_backup_export_tokens_v141 from public, anon, authenticated;
grant select, insert, update, delete on table public.kombax_backup_export_tokens_v141 to service_role;

comment on table public.kombax_backup_export_tokens_v141 is
  'KOMBAX 20077: short-lived hashed capabilities for the admin-only backup export Edge Function. No anon/authenticated access.';

create index if not exists idx_kombax_backup_export_active_expiry_v141
  on public.kombax_backup_export_tokens_v141(active, expires_at)
  where active;
