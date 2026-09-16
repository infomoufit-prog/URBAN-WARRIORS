-- KOMBAX 20.101 R37 · Brand Business Hub foundation
begin;

create table if not exists public.kombax_brand_profiles_v223(
  brand_profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade,
  sector text,
  territories text[] not null default '{}'::text[],
  disciplines text[] not null default '{}'::text[],
  collaboration_open boolean not null default false,
  inbound_proposals boolean not null default true,
  public_business_summary text,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.kombax_brand_campaigns_v223(
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  title text not null,
  campaign_type text not null check(campaign_type in ('ambassadors','fighters','clubs','events','launch','content','other')),
  visibility text not null default 'private' check(visibility in ('private','open')),
  status text not null default 'draft' check(status in ('draft','active','paused','closed')),
  description text,
  territory text,
  disciplines text[] not null default '{}'::text[],
  audience_types text[] not null default '{}'::text[],
  compensation_type text check(compensation_type is null or compensation_type in ('product','fee','mixed','other')),
  compensation_summary text,
  conditions_summary text,
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(ends_at is null or starts_at is null or ends_at >= starts_at)
);

create table if not exists public.kombax_brand_collaboration_preferences_v223(
  direct_profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade,
  discoverable_by_brands boolean not null default false,
  inbound_enabled boolean not null default false,
  categories text[] not null default '{}'::text[],
  contact_mode text not null default 'profile' check(contact_mode in ('profile','manager','club','profile_or_representative')),
  collaboration_note text,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.kombax_brand_proposals_v223(
  id uuid primary key default gen_random_uuid(),
  brand_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  campaign_id uuid references public.kombax_brand_campaigns_v223(id) on delete set null,
  target_type text not null check(target_type in ('direct_profile','club','event')),
  target_direct_profile_id uuid references public.perfiles_kombax_directos(id) on delete cascade,
  target_club_id uuid references public.clubes(id) on delete cascade,
  target_event_id uuid references public.kombax_eventos_publicos(id) on delete cascade,
  source text not null default 'brand_invite' check(source in ('brand_invite','open_campaign_application')),
  status text not null default 'pending' check(status in ('pending','interested','in_review','accepted','declined','withdrawn','completed')),
  message text,
  terms_summary text,
  response_note text,
  created_by uuid not null,
  responded_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz,
  check(
    (target_type='direct_profile' and target_direct_profile_id is not null and target_club_id is null and target_event_id is null)
    or (target_type='club' and target_club_id is not null and target_direct_profile_id is null and target_event_id is null)
    or (target_type='event' and target_event_id is not null and target_direct_profile_id is null and target_club_id is null)
  )
);

create table if not exists public.kombax_brand_team_roles_v223(
  brand_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  perfil_id uuid not null,
  business_role text not null check(business_role in ('admin','marketing','social_media','commercial','sponsorships','catalog','collaborator')),
  updated_by uuid not null,
  updated_at timestamptz not null default now(),
  primary key(brand_profile_id,perfil_id)
);

create table if not exists public.kombax_brand_audit_v223(
  id bigserial primary key,
  brand_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  actor_id uuid,
  action text not null,
  object_type text not null,
  object_id uuid,
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_kombax_brand_campaigns_v223_brand_status on public.kombax_brand_campaigns_v223(brand_profile_id,status,updated_at desc);
create index if not exists idx_kombax_brand_campaigns_v223_open on public.kombax_brand_campaigns_v223(status,visibility,starts_at,ends_at);
create index if not exists idx_kombax_brand_proposals_v223_brand on public.kombax_brand_proposals_v223(brand_profile_id,status,updated_at desc);
create index if not exists idx_kombax_brand_proposals_v223_direct on public.kombax_brand_proposals_v223(target_direct_profile_id,status,updated_at desc) where target_direct_profile_id is not null;
create index if not exists idx_kombax_brand_proposals_v223_club on public.kombax_brand_proposals_v223(target_club_id,status,updated_at desc) where target_club_id is not null;
create index if not exists idx_kombax_brand_proposals_v223_event on public.kombax_brand_proposals_v223(target_event_id,status,updated_at desc) where target_event_id is not null;
create index if not exists idx_kombax_brand_audit_v223_brand on public.kombax_brand_audit_v223(brand_profile_id,created_at desc);

alter table public.kombax_brand_profiles_v223 enable row level security;
alter table public.kombax_brand_campaigns_v223 enable row level security;
alter table public.kombax_brand_collaboration_preferences_v223 enable row level security;
alter table public.kombax_brand_proposals_v223 enable row level security;
alter table public.kombax_brand_team_roles_v223 enable row level security;
alter table public.kombax_brand_audit_v223 enable row level security;

-- RPC-only data surface. Direct table access is intentionally closed.
revoke all on public.kombax_brand_profiles_v223 from public,anon,authenticated;
revoke all on public.kombax_brand_campaigns_v223 from public,anon,authenticated;
revoke all on public.kombax_brand_collaboration_preferences_v223 from public,anon,authenticated;
revoke all on public.kombax_brand_proposals_v223 from public,anon,authenticated;
revoke all on public.kombax_brand_team_roles_v223 from public,anon,authenticated;
revoke all on public.kombax_brand_audit_v223 from public,anon,authenticated;

commit;
