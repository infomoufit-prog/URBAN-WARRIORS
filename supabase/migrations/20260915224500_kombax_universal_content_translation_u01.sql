-- KOMBAX Universal Content Translation U01
-- Additive cache only. Original authored content remains the source of truth.
create table if not exists public.kombax_content_translations_u01 (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type ~ '^[a-z0-9_.-]{2,80}$'),
  content_id text not null check (char_length(content_id) between 1 and 180),
  field_name text not null check (field_name ~ '^[a-z0-9_.-]{1,80}$'),
  source_hash text not null check (source_hash ~ '^[a-f0-9]{64}$'),
  source_locale text null check (source_locale is null or source_locale in ('es','en','fr','pt','it','de','th','fil')),
  target_locale text not null check (target_locale in ('es','en','fr','pt','it','de','th','fil')),
  translated_text text not null,
  visibility text not null default 'public' check (visibility in ('public','tenant','private')),
  requester_id uuid null references auth.users(id) on delete cascade,
  model_alias text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists kombax_content_translations_u01_public_uq
  on public.kombax_content_translations_u01(content_type,content_id,field_name,source_hash,target_locale,visibility)
  where requester_id is null;

create unique index if not exists kombax_content_translations_u01_private_uq
  on public.kombax_content_translations_u01(content_type,content_id,field_name,source_hash,target_locale,visibility,requester_id)
  where requester_id is not null;

create index if not exists kombax_content_translations_u01_lookup_idx
  on public.kombax_content_translations_u01(content_type,content_id,field_name,target_locale,updated_at desc);

alter table public.kombax_content_translations_u01 enable row level security;
revoke all on public.kombax_content_translations_u01 from anon, authenticated;

-- Public translations are derived from already-public authored content and may be read anonymously.
-- Tenant/private translations remain service-role only; private cache rows are scoped to requester_id.
grant select on public.kombax_content_translations_u01 to anon, authenticated;

drop policy if exists kombax_content_translations_u01_public_read on public.kombax_content_translations_u01;
create policy kombax_content_translations_u01_public_read
  on public.kombax_content_translations_u01
  for select
  to anon, authenticated
  using (visibility = 'public' and requester_id is null);

comment on table public.kombax_content_translations_u01 is
'KOMBAX derived translation cache. Never stores/replaces the authored source text; cache identity includes source_hash so edits invalidate old translations automatically.';
comment on column public.kombax_content_translations_u01.visibility is
'public/tenant translations may be shared by identical content identity+hash; private translations are scoped to requester_id.';
