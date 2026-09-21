-- KOMBAX 20.110 R62.6 · KOMBAX Social Discovery
-- Free Social discovery for competitors and professionals.
-- Availability status is independent from optional public/private date/time slots.

begin;

alter table public.kombax_fighter_discovery_v221
  add column if not exists availability_status text not null default 'unavailable',
  add column if not exists availability_reason text,
  add column if not exists availability_public boolean not null default true,
  add column if not exists accepts_short_notice boolean not null default false,
  add column if not exists fight_count_declared integer,
  add column if not exists wins_declared integer,
  add column if not exists losses_declared integer,
  add column if not exists draws_declared integer,
  add column if not exists affiliation_status text not null default 'unspecified',
  add column if not exists availability_updated_at timestamptz not null default now();

update public.kombax_fighter_discovery_v221
set availability_status=case
    when availability='short_notice' then 'available'
    when availability in ('available','limited','unavailable') then availability
    else 'unavailable'
  end,
  accepts_short_notice=(availability='short_notice')
where availability_status='unavailable'
  and (availability<>'unavailable' or availability='short_notice');

do $$ begin
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_availability_status_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_availability_status_r626 check(availability_status in ('available','limited','unavailable'));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_availability_reason_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_availability_reason_r626 check(availability_reason is null or (length(trim(availability_reason)) between 1 and 120));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_fight_count_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_fight_count_r626 check(fight_count_declared is null or fight_count_declared between 0 and 9999);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_wins_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_wins_r626 check(wins_declared is null or wins_declared between 0 and 9999);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_losses_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_losses_r626 check(losses_declared is null or losses_declared between 0 and 9999);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_draws_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_draws_r626 check(draws_declared is null or draws_declared between 0 and 9999);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_fighter_affiliation_r626') then
    alter table public.kombax_fighter_discovery_v221 add constraint kombax_fighter_affiliation_r626 check(affiliation_status in ('unspecified','federated','independent'));
  end if;
end $$;

create index if not exists idx_kombax_fighter_discovery_r626 on public.kombax_fighter_discovery_v221(discoverable,availability_status,competition_level,updated_at desc);
create index if not exists idx_kombax_fighter_discovery_updated_by_r626 on public.kombax_fighter_discovery_v221(updated_by);

create table if not exists public.kombax_professional_discovery_r626(
  professional_profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade,
  social_profile_id uuid unique references public.kombax_social_perfiles(id) on delete set null,
  discoverable boolean not null default false,
  availability_status text not null default 'unavailable' check(availability_status in ('available','limited','unavailable')),
  availability_reason text check(availability_reason is null or (length(trim(availability_reason)) between 1 and 120)),
  availability_public boolean not null default true,
  contact_enabled boolean not null default true,
  territory text check(territory is null or length(territory)<=160),
  max_travel_km integer check(max_travel_km is null or max_travel_km between 0 and 10000),
  disciplines text[] not null default '{}'::text[],
  work_modes text[] not null default '{}'::text[],
  experience_years integer check(experience_years is null or experience_years between 0 and 80),
  min_notice_hours integer not null default 72 check(min_notice_hours between 0 and 8760),
  updated_by uuid not null,
  updated_at timestamptz not null default now(),
  availability_updated_at timestamptz not null default now()
);

create table if not exists public.kombax_discovery_availability_slots_r626(
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  slot_status text not null default 'available' check(slot_status in ('available','unavailable')),
  visibility text not null default 'public' check(visibility in ('public','private')),
  note text check(note is null or length(note)<=120),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kombax_discovery_slot_range_r626 check(ends_at>starts_at)
);

create index if not exists idx_kombax_prof_discovery_social_r626 on public.kombax_professional_discovery_r626(social_profile_id);
create index if not exists idx_kombax_prof_discovery_search_r626 on public.kombax_professional_discovery_r626(discoverable,availability_status,updated_at desc);
create index if not exists idx_kombax_prof_discovery_disciplines_r626 on public.kombax_professional_discovery_r626 using gin(disciplines);
create index if not exists idx_kombax_discovery_slots_profile_r626 on public.kombax_discovery_availability_slots_r626(profile_id,starts_at,ends_at);

alter table public.kombax_professional_discovery_r626 enable row level security;
alter table public.kombax_discovery_availability_slots_r626 enable row level security;
revoke all on public.kombax_professional_discovery_r626 from public,anon,authenticated;
revoke all on public.kombax_discovery_availability_slots_r626 from public,anon,authenticated;

drop policy if exists kombax_prof_discovery_rpc_only_r626 on public.kombax_professional_discovery_r626;
create policy kombax_prof_discovery_rpc_only_r626 on public.kombax_professional_discovery_r626 for all to authenticated using(false) with check(false);
drop policy if exists kombax_discovery_slots_rpc_only_r626 on public.kombax_discovery_availability_slots_r626;
create policy kombax_discovery_slots_rpc_only_r626 on public.kombax_discovery_availability_slots_r626 for all to authenticated using(false) with check(false);

create or replace function public.app_kombax_discovery_search_r626(p_filters jsonb default '{}'::jsonb)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_target text:=lower(coalesce(nullif(trim(p_filters->>'target_type'),''),'all'));
  v_query text:=lower(trim(coalesce(p_filters->>'query','')));
  v_discipline text:=lower(trim(coalesce(p_filters->>'discipline','')));
  v_territory text:=lower(trim(coalesce(p_filters->>'territory','')));
  v_availability text:=lower(coalesce(nullif(trim(p_filters->>'availability'),''),'open'));
  v_level text:=lower(trim(coalesce(p_filters->>'competition_level','')));
  v_affiliation text:=lower(trim(coalesce(p_filters->>'affiliation_status','')));
  v_specialty text:=lower(trim(coalesce(p_filters->>'specialty','')));
  v_work_mode text:=lower(trim(coalesce(p_filters->>'work_mode','')));
  v_weight numeric:=nullif(p_filters->>'weight_kg','')::numeric;
  v_min_fights integer:=nullif(p_filters->>'min_fights','')::integer;
  v_min_experience integer:=nullif(p_filters->>'min_experience_years','')::integer;
  v_short_notice boolean:=coalesce(nullif(p_filters->>'short_notice','')::boolean,false);
  v_verified_only boolean:=coalesce(nullif(p_filters->>'verified_only','')::boolean,false);
  v_date_from timestamptz:=nullif(p_filters->>'date_from','')::timestamptz;
  v_date_to timestamptz:=nullif(p_filters->>'date_to','')::timestamptz;
  v_limit integer:=least(100,greatest(1,coalesce(nullif(p_filters->>'limit','')::integer,30)));
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_target not in ('all','competitor','professional') then raise exception 'KOMBAX_DISCOVERY_TARGET_INVALID'; end if;
  if v_availability not in ('open','all','available','limited','unavailable') then raise exception 'KOMBAX_DISCOVERY_AVAILABILITY_INVALID'; end if;
  if v_date_from is not null and v_date_to is null then v_date_to:=v_date_from+interval '1 day'; end if;
  if v_date_to is not null and v_date_from is null then v_date_from:=v_date_to-interval '1 day'; end if;
  if v_date_from is not null and v_date_to<=v_date_from then raise exception 'KOMBAX_DISCOVERY_DATE_RANGE_INVALID'; end if;

  with discovery as (
    select
      d.id as profile_id,s.id as social_profile_id,'competitor'::text as profile_type,d.nombre_publico,d.slug,
      s.avatar_url,s.verificado,coalesce(f.territory,d.ubicacion) as territory,f.max_travel_km,f.disciplines,
      case when f.availability_public then f.availability_status else null end as availability_status,
      case when f.availability_public then f.availability_reason else null end as availability_reason,
      not f.availability_public as availability_private,
      f.availability_updated_at,(coalesce(s.contacto_habilitado,false) and f.discoverable) as contactable,
      f.min_notice_hours,f.competition_level,f.usual_category,f.public_weight_min_kg,f.public_weight_max_kg,
      f.fight_count_declared,f.wins_declared,f.losses_declared,f.draws_declared,f.affiliation_status,f.accepts_short_notice,
      null::text as specialty,null::text[] as specialties,null::integer as experience_years,null::text[] as work_modes,false as credential_verified,
      (case when f.availability_status='available' then 4 when f.availability_status='limited' then 2 else 0 end
       +case when f.accepts_short_notice then 2 else 0 end
       +case when s.verificado then 1 else 0 end) as match_score
    from public.kombax_fighter_discovery_v221 f
    join public.perfiles_kombax_directos d on d.id=f.competitor_profile_id
    join public.kombax_social_perfiles s on s.id=f.social_profile_id
    where v_target in ('all','competitor') and f.discoverable
      and d.tipo='competidor' and d.publico and d.estado='activa' and public.app_kombax_fighter_is_adult_v221(d.id)
      and s.visible and s.estado='activo'
      and (v_query='' or lower(coalesce(d.nombre_publico,'')) like '%'||v_query||'%' or lower(coalesce(d.club_declarado,'')) like '%'||v_query||'%' or lower(coalesce(d.ubicacion,'')) like '%'||v_query||'%')
      and (v_discipline='' or exists(select 1 from unnest(f.disciplines) z where lower(z)=v_discipline))
      and (v_territory='' or lower(coalesce(f.territory,d.ubicacion,'')) like '%'||v_territory||'%')
      and (v_availability='all' or (f.availability_public and ((v_availability='open' and f.availability_status in ('available','limited')) or f.availability_status=v_availability)))
      and (v_level='' or lower(coalesce(f.competition_level,''))=v_level)
      and (v_affiliation='' or lower(f.affiliation_status)=v_affiliation)
      and (v_weight is null or ((f.public_weight_min_kg is null or f.public_weight_min_kg<=v_weight) and (f.public_weight_max_kg is null or f.public_weight_max_kg>=v_weight)))
      and (v_min_fights is null or coalesce(f.fight_count_declared,0)>=v_min_fights)
      and (not v_short_notice or f.accepts_short_notice)
      and (not v_verified_only or s.verificado)
      and (v_date_from is null or exists(select 1 from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=d.id and sl.visibility='public' and sl.slot_status='available' and sl.starts_at<v_date_to and sl.ends_at>v_date_from))

    union all

    select
      d.id as profile_id,s.id as social_profile_id,'professional'::text as profile_type,d.nombre_publico,d.slug,
      s.avatar_url,s.verificado,coalesce(p.territory,d.ubicacion) as territory,p.max_travel_km,p.disciplines,
      case when p.availability_public then p.availability_status else null end as availability_status,
      case when p.availability_public then p.availability_reason else null end as availability_reason,
      not p.availability_public as availability_private,
      p.availability_updated_at,(coalesce(s.contacto_habilitado,false) and p.contact_enabled and p.discoverable) as contactable,
      p.min_notice_hours,null::text as competition_level,null::text as usual_category,null::numeric as public_weight_min_kg,null::numeric as public_weight_max_kg,
      null::integer as fight_count_declared,null::integer as wins_declared,null::integer as losses_declared,null::integer as draws_declared,null::text as affiliation_status,false as accepts_short_notice,
      pp.especialidad_principal as specialty,
      array_prepend(pp.especialidad_principal,coalesce((select array_agg(ps.especialidad_codigo order by ps.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=d.id),'{}'::text[])) as specialties,
      p.experience_years,p.work_modes,
      exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)) as credential_verified,
      (case when p.availability_status='available' then 4 when p.availability_status='limited' then 2 else 0 end
       +case when s.verificado then 1 else 0 end
       +case when exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)) then 2 else 0 end) as match_score
    from public.kombax_professional_discovery_r626 p
    join public.perfiles_kombax_directos d on d.id=p.professional_profile_id
    join public.kombax_social_perfiles s on s.id=p.social_profile_id
    left join public.kombax_profesional_perfiles_v196 pp on pp.perfil_directo_id=d.id
    where v_target in ('all','professional') and p.discoverable
      and d.tipo='profesional' and d.publico and d.estado='activa'
      and s.visible and s.estado='activo'
      and (v_query='' or lower(coalesce(d.nombre_publico,'')) like '%'||v_query||'%' or lower(coalesce(d.ubicacion,'')) like '%'||v_query||'%' or lower(coalesce(pp.especialidad_principal,'')) like '%'||v_query||'%')
      and (v_discipline='' or exists(select 1 from unnest(p.disciplines) z where lower(z)=v_discipline))
      and (v_territory='' or lower(coalesce(p.territory,d.ubicacion,'')) like '%'||v_territory||'%')
      and (v_availability='all' or (p.availability_public and ((v_availability='open' and p.availability_status in ('available','limited')) or p.availability_status=v_availability)))
      and (v_specialty='' or lower(coalesce(pp.especialidad_principal,'')) like '%'||v_specialty||'%' or exists(select 1 from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=d.id and lower(ps.especialidad_codigo) like '%'||v_specialty||'%'))
      and (v_work_mode='' or exists(select 1 from unnest(p.work_modes) z where lower(z)=v_work_mode))
      and (v_min_experience is null or coalesce(p.experience_years,0)>=v_min_experience)
      and (not v_verified_only or s.verificado or exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)))
      and (v_date_from is null or exists(select 1 from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=d.id and sl.visibility='public' and sl.slot_status='available' and sl.starts_at<v_date_to and sl.ends_at>v_date_from))
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.match_score desc,x.nombre_publico),'[]'::jsonb) into v_rows
  from (select * from discovery order by match_score desc,nombre_publico limit v_limit) x;
  return v_rows;
end $$;

create or replace function public.app_kombax_discovery_profile_r626(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_type text; v_row jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_READ_REQUIRED'; end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=p_profile_id;
  if v_type='competidor' then
    select to_jsonb(f)||jsonb_build_object('profile_type','competitor') into v_row from public.kombax_fighter_discovery_v221 f where f.competitor_profile_id=p_profile_id;
    return coalesce(v_row,jsonb_build_object('profile_id',p_profile_id,'profile_type','competitor','discoverable',false,'availability_status','unavailable','availability_public',true,'accepts_short_notice',false,'affiliation_status','unspecified'));
  elsif v_type='profesional' then
    select to_jsonb(p)||jsonb_build_object('profile_type','professional','specialty',pp.especialidad_principal,'specialties',coalesce((select jsonb_agg(ps.especialidad_codigo order by ps.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=p_profile_id),'[]'::jsonb)) into v_row
    from public.kombax_professional_discovery_r626 p left join public.kombax_profesional_perfiles_v196 pp on pp.perfil_directo_id=p.professional_profile_id where p.professional_profile_id=p_profile_id;
    return coalesce(v_row,jsonb_build_object('profile_id',p_profile_id,'profile_type','professional','discoverable',false,'availability_status','unavailable','availability_public',true,'contact_enabled',true));
  end if;
  raise exception 'KOMBAX_DISCOVERY_PROFILE_TYPE_INVALID';
end $$;

create or replace function public.app_kombax_discovery_mutate_r626(p_profile_id uuid,p_payload jsonb default '{}'::jsonb,p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_type text; v_social uuid; v_status text:=lower(coalesce(nullif(trim(p_payload->>'availability_status'),''),'unavailable'));
  v_discoverable boolean:=coalesce(nullif(p_payload->>'discoverable','')::boolean,false);
  v_short boolean:=coalesce(nullif(p_payload->>'accepts_short_notice','')::boolean,false);
  v_reason text:=nullif(trim(coalesce(p_payload->>'availability_reason','')),'');
  v_disciplines text[]:=coalesce(array(select trim(x) from jsonb_array_elements_text(case when jsonb_typeof(p_payload->'disciplines')='array' then p_payload->'disciplines' else '[]'::jsonb end) x where trim(x)<>''),'{}'::text[]);
  v_work_modes text[]:=coalesce(array(select trim(x) from jsonb_array_elements_text(case when jsonb_typeof(p_payload->'work_modes')='array' then p_payload->'work_modes' else '[]'::jsonb end) x where trim(x)<>''),'{}'::text[]);
  v_out jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit') then raise exception 'KOMBAX_PROFILE_EDIT_REQUIRED'; end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=p_profile_id;
  if v_type not in ('competidor','profesional') then raise exception 'KOMBAX_DISCOVERY_PROFILE_TYPE_INVALID'; end if;
  if v_status not in ('available','limited','unavailable') then raise exception 'KOMBAX_DISCOVERY_AVAILABILITY_INVALID'; end if;
  if length(coalesce(v_reason,''))>120 then raise exception 'KOMBAX_DISCOVERY_REASON_TOO_LONG'; end if;
  select id into v_social from public.kombax_social_perfiles where perfil_directo_id=p_profile_id and sujeto_tipo='perfil_directo' order by actualizado_en desc limit 1;
  if v_discoverable and v_social is null then raise exception 'KOMBAX_SOCIAL_PROFILE_REQUIRED'; end if;

  if v_type='competidor' then
    if v_discoverable and not public.app_kombax_fighter_is_adult_v221(p_profile_id) then raise exception 'KOMBAX_FIGHTER_DISCOVERY_ADULT_ONLY'; end if;
    insert into public.kombax_fighter_discovery_v221(
      competitor_profile_id,social_profile_id,discoverable,availability,contact_mode,disciplines,competition_level,usual_category,
      public_weight_min_kg,public_weight_max_kg,territory,max_travel_km,min_notice_hours,accepts_federated_only,accepts_professional_only,updated_by,
      availability_status,availability_reason,availability_public,accepts_short_notice,fight_count_declared,wins_declared,losses_declared,draws_declared,affiliation_status,availability_updated_at)
    values(
      p_profile_id,v_social,v_discoverable,case when v_status='available' and v_short then 'short_notice' else v_status end,
      coalesce(nullif(p_payload->>'contact_mode',''),'direct'),v_disciplines,nullif(p_payload->>'competition_level',''),nullif(trim(p_payload->>'usual_category'),''),
      nullif(p_payload->>'public_weight_min_kg','')::numeric,nullif(p_payload->>'public_weight_max_kg','')::numeric,nullif(trim(p_payload->>'territory'),''),nullif(p_payload->>'max_travel_km','')::integer,
      coalesce(nullif(p_payload->>'min_notice_hours','')::integer,72),coalesce(nullif(p_payload->>'accepts_federated_only','')::boolean,false),coalesce(nullif(p_payload->>'accepts_professional_only','')::boolean,false),v_uid,
      v_status,v_reason,coalesce(nullif(p_payload->>'availability_public','')::boolean,true),v_short,nullif(p_payload->>'fight_count_declared','')::integer,nullif(p_payload->>'wins_declared','')::integer,
      nullif(p_payload->>'losses_declared','')::integer,nullif(p_payload->>'draws_declared','')::integer,coalesce(nullif(p_payload->>'affiliation_status',''),'unspecified'),now())
    on conflict(competitor_profile_id) do update set
      social_profile_id=excluded.social_profile_id,discoverable=excluded.discoverable,availability=excluded.availability,contact_mode=excluded.contact_mode,disciplines=excluded.disciplines,competition_level=excluded.competition_level,
      usual_category=excluded.usual_category,public_weight_min_kg=excluded.public_weight_min_kg,public_weight_max_kg=excluded.public_weight_max_kg,territory=excluded.territory,max_travel_km=excluded.max_travel_km,
      min_notice_hours=excluded.min_notice_hours,accepts_federated_only=excluded.accepts_federated_only,accepts_professional_only=excluded.accepts_professional_only,updated_by=v_uid,updated_at=now(),
      availability_status=excluded.availability_status,availability_reason=excluded.availability_reason,availability_public=excluded.availability_public,accepts_short_notice=excluded.accepts_short_notice,
      fight_count_declared=excluded.fight_count_declared,wins_declared=excluded.wins_declared,losses_declared=excluded.losses_declared,draws_declared=excluded.draws_declared,affiliation_status=excluded.affiliation_status,availability_updated_at=now()
    returning to_jsonb(kombax_fighter_discovery_v221.*)||jsonb_build_object('profile_type','competitor') into v_out;
  else
    insert into public.kombax_professional_discovery_r626(
      professional_profile_id,social_profile_id,discoverable,availability_status,availability_reason,availability_public,contact_enabled,territory,max_travel_km,disciplines,work_modes,experience_years,min_notice_hours,updated_by,availability_updated_at)
    values(p_profile_id,v_social,v_discoverable,v_status,v_reason,coalesce(nullif(p_payload->>'availability_public','')::boolean,true),coalesce(nullif(p_payload->>'contact_enabled','')::boolean,true),
      nullif(trim(p_payload->>'territory'),''),nullif(p_payload->>'max_travel_km','')::integer,v_disciplines,v_work_modes,nullif(p_payload->>'experience_years','')::integer,coalesce(nullif(p_payload->>'min_notice_hours','')::integer,72),v_uid,now())
    on conflict(professional_profile_id) do update set
      social_profile_id=excluded.social_profile_id,discoverable=excluded.discoverable,availability_status=excluded.availability_status,availability_reason=excluded.availability_reason,
      availability_public=excluded.availability_public,contact_enabled=excluded.contact_enabled,territory=excluded.territory,max_travel_km=excluded.max_travel_km,disciplines=excluded.disciplines,
      work_modes=excluded.work_modes,experience_years=excluded.experience_years,min_notice_hours=excluded.min_notice_hours,updated_by=v_uid,updated_at=now(),availability_updated_at=now()
    returning to_jsonb(kombax_professional_discovery_r626.*)||jsonb_build_object('profile_type','professional') into v_out;
  end if;
  return v_out;
end $$;

create or replace function public.app_kombax_discovery_slots_r626(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_READ_REQUIRED'; end if;
  select coalesce(jsonb_agg(to_jsonb(s) order by s.starts_at),'[]'::jsonb) into v_rows from public.kombax_discovery_availability_slots_r626 s where s.profile_id=p_profile_id and s.ends_at>now()-interval '1 day';
  return v_rows;
end $$;

create or replace function public.app_kombax_discovery_slot_mutate_r626(p_profile_id uuid,p_operation text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_type text; v_op text:=lower(trim(coalesce(p_operation,''))); v_id uuid:=nullif(p_payload->>'id','')::uuid; v_row public.kombax_discovery_availability_slots_r626%rowtype;
  v_start timestamptz:=nullif(p_payload->>'starts_at','')::timestamptz; v_end timestamptz:=nullif(p_payload->>'ends_at','')::timestamptz;
  v_status text:=lower(coalesce(nullif(p_payload->>'slot_status',''),'available')); v_visibility text:=lower(coalesce(nullif(p_payload->>'visibility',''),'public'));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'edit') then raise exception 'KOMBAX_PROFILE_EDIT_REQUIRED'; end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=p_profile_id;
  if v_type not in ('competidor','profesional') then raise exception 'KOMBAX_DISCOVERY_PROFILE_TYPE_INVALID'; end if;
  if v_op='delete' then
    delete from public.kombax_discovery_availability_slots_r626 where id=v_id and profile_id=p_profile_id returning * into v_row;
    if not found then raise exception 'KOMBAX_DISCOVERY_SLOT_NOT_FOUND'; end if;
    return jsonb_build_object('ok',true,'deleted',v_id);
  end if;
  if v_op not in ('save','upsert') then raise exception 'KOMBAX_DISCOVERY_SLOT_OPERATION_INVALID'; end if;
  if v_start is null or v_end is null or v_end<=v_start then raise exception 'KOMBAX_DISCOVERY_SLOT_RANGE_INVALID'; end if;
  if v_status not in ('available','unavailable') then raise exception 'KOMBAX_DISCOVERY_SLOT_STATUS_INVALID'; end if;
  if v_visibility not in ('public','private') then raise exception 'KOMBAX_DISCOVERY_SLOT_VISIBILITY_INVALID'; end if;
  if v_id is null and (select count(*) from public.kombax_discovery_availability_slots_r626 where profile_id=p_profile_id and ends_at>now()-interval '1 day')>=100 then raise exception 'KOMBAX_DISCOVERY_SLOT_LIMIT'; end if;
  if v_id is null then
    insert into public.kombax_discovery_availability_slots_r626(profile_id,starts_at,ends_at,slot_status,visibility,note,created_by)
    values(p_profile_id,v_start,v_end,v_status,v_visibility,nullif(left(trim(coalesce(p_payload->>'note','')),120),''),v_uid) returning * into v_row;
  else
    update public.kombax_discovery_availability_slots_r626 set starts_at=v_start,ends_at=v_end,slot_status=v_status,visibility=v_visibility,note=nullif(left(trim(coalesce(p_payload->>'note','')),120),''),updated_at=now()
    where id=v_id and profile_id=p_profile_id returning * into v_row;
    if not found then raise exception 'KOMBAX_DISCOVERY_SLOT_NOT_FOUND'; end if;
  end if;
  return to_jsonb(v_row);
end $$;

create or replace function public.app_kombax_discovery_public_profile_r626(p_social_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_profile uuid; v_type text; v_manage boolean:=false; v_out jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select perfil_directo_id into v_profile from public.kombax_social_perfiles where id=p_social_profile_id and sujeto_tipo='perfil_directo' and visible and estado='activo';
  if v_profile is null then return null; end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=v_profile;
  v_manage:=coalesce(public.app_kombax_puede_gestionar_perfil_v070(v_profile,'read'),false);
  if v_type='competidor' then
    select jsonb_build_object(
      'profile_id',v_profile,'profile_type','competitor','discoverable',f.discoverable,
      'availability_status',case when v_manage or f.availability_public then f.availability_status else null end,
      'availability_reason',case when v_manage or f.availability_public then f.availability_reason else null end,
      'availability_private',not f.availability_public,'availability_updated_at',f.availability_updated_at,
      'disciplines',f.disciplines,'competition_level',f.competition_level,'usual_category',f.usual_category,
      'public_weight_min_kg',f.public_weight_min_kg,'public_weight_max_kg',f.public_weight_max_kg,
      'fight_count_declared',f.fight_count_declared,'wins_declared',f.wins_declared,'losses_declared',f.losses_declared,'draws_declared',f.draws_declared,
      'affiliation_status',f.affiliation_status,'accepts_short_notice',f.accepts_short_notice,'territory',f.territory,'max_travel_km',f.max_travel_km,
      'slots',coalesce((select jsonb_agg(jsonb_build_object('id',sl.id,'starts_at',sl.starts_at,'ends_at',sl.ends_at,'slot_status',sl.slot_status,'note',sl.note) order by sl.starts_at) from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=v_profile and (v_manage or sl.visibility='public') and sl.ends_at>now()-interval '1 day'),'[]'::jsonb)
    ) into v_out from public.kombax_fighter_discovery_v221 f where f.competitor_profile_id=v_profile and (f.discoverable or v_manage);
  elsif v_type='profesional' then
    select jsonb_build_object(
      'profile_id',v_profile,'profile_type','professional','discoverable',p.discoverable,
      'availability_status',case when v_manage or p.availability_public then p.availability_status else null end,
      'availability_reason',case when v_manage or p.availability_public then p.availability_reason else null end,
      'availability_private',not p.availability_public,'availability_updated_at',p.availability_updated_at,
      'disciplines',p.disciplines,'specialty',pp.especialidad_principal,
      'specialties',coalesce((select jsonb_agg(ps.especialidad_codigo order by ps.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=v_profile),'[]'::jsonb),
      'experience_years',p.experience_years,'work_modes',p.work_modes,'territory',p.territory,'max_travel_km',p.max_travel_km,
      'credential_verified',exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=v_profile and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)),
      'slots',coalesce((select jsonb_agg(jsonb_build_object('id',sl.id,'starts_at',sl.starts_at,'ends_at',sl.ends_at,'slot_status',sl.slot_status,'note',sl.note) order by sl.starts_at) from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=v_profile and (v_manage or sl.visibility='public') and sl.ends_at>now()-interval '1 day'),'[]'::jsonb)
    ) into v_out from public.kombax_professional_discovery_r626 p left join public.kombax_profesional_perfiles_v196 pp on pp.perfil_directo_id=p.professional_profile_id where p.professional_profile_id=v_profile and (p.discoverable or v_manage);
  end if;
  return v_out;
end $$;

revoke all on function public.app_kombax_discovery_search_r626(jsonb) from public,anon,service_role;
revoke all on function public.app_kombax_discovery_profile_r626(uuid) from public,anon,service_role;
revoke all on function public.app_kombax_discovery_mutate_r626(uuid,jsonb,uuid) from public,anon,service_role;
revoke all on function public.app_kombax_discovery_slots_r626(uuid) from public,anon,service_role;
revoke all on function public.app_kombax_discovery_slot_mutate_r626(uuid,text,jsonb,uuid) from public,anon,service_role;
revoke all on function public.app_kombax_discovery_public_profile_r626(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_discovery_search_r626(jsonb) to authenticated;
grant execute on function public.app_kombax_discovery_profile_r626(uuid) to authenticated;
grant execute on function public.app_kombax_discovery_mutate_r626(uuid,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_discovery_slots_r626(uuid) to authenticated;
grant execute on function public.app_kombax_discovery_slot_mutate_r626(uuid,text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_discovery_public_profile_r626(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
