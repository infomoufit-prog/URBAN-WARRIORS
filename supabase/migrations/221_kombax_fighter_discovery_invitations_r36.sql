-- KOMBAX 20.101 R36 · Fighter Discovery & Fight Invitations
-- Public competitive availability is separate from private preparation/weight history.

begin;

create table if not exists public.kombax_fighter_discovery_v221(
  competitor_profile_id uuid primary key references public.perfiles_kombax_directos(id) on delete cascade,
  social_profile_id uuid unique references public.kombax_social_perfiles(id) on delete set null,
  discoverable boolean not null default false,
  availability text not null default 'unavailable' check(availability in ('available','short_notice','limited','unavailable')),
  contact_mode text not null default 'direct' check(contact_mode in ('direct','club','manager','direct_or_representative')),
  disciplines text[] not null default '{}'::text[],
  competition_level text check(competition_level is null or competition_level in ('amateur','semi_pro','professional','elite')),
  usual_category text,
  public_weight_min_kg numeric(6,2) check(public_weight_min_kg is null or public_weight_min_kg between 15 and 300),
  public_weight_max_kg numeric(6,2) check(public_weight_max_kg is null or public_weight_max_kg between 15 and 300),
  territory text,
  max_travel_km integer check(max_travel_km is null or max_travel_km between 0 and 10000),
  min_notice_hours integer not null default 72 check(min_notice_hours between 0 and 8760),
  accepts_federated_only boolean not null default false,
  accepts_professional_only boolean not null default false,
  updated_by uuid not null references public.perfiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  constraint kombax_fighter_public_weight_range_v221 check(public_weight_min_kg is null or public_weight_max_kg is null or public_weight_min_kg<=public_weight_max_kg)
);

create table if not exists public.kombax_fight_invitations_v221(
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
  fight_id uuid references public.kombax_evento_combates_publicos(id) on delete set null,
  target_competitor_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete cascade,
  target_social_profile_id uuid references public.kombax_social_perfiles(id) on delete set null,
  sender_profile_id uuid not null references public.perfiles(id) on delete restrict,
  discipline text,
  category text,
  proposed_weight_kg numeric(6,2) check(proposed_weight_kg is null or proposed_weight_kg between 15 and 300),
  event_at timestamptz,
  location text,
  message text,
  status text not null default 'pending' check(status in ('pending','accepted','declined','withdrawn','expired','registered')),
  response_note text,
  responded_at timestamptz,
  expires_at timestamptz,
  registered_participant_id uuid references public.kombax_evento_participantes_publicos(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_kombax_fighter_discovery_search_v221 on public.kombax_fighter_discovery_v221(discoverable,availability,competition_level,updated_at desc);
create index if not exists idx_kombax_fight_invitations_target_v221 on public.kombax_fight_invitations_v221(target_competitor_profile_id,status,created_at desc);
create index if not exists idx_kombax_fight_invitations_event_v221 on public.kombax_fight_invitations_v221(event_id,status,created_at desc);

alter table public.kombax_fighter_discovery_v221 enable row level security;
alter table public.kombax_fight_invitations_v221 enable row level security;
revoke all on public.kombax_fighter_discovery_v221 from public,anon,authenticated;
revoke all on public.kombax_fight_invitations_v221 from public,anon,authenticated;

create or replace function public.app_kombax_fighter_is_adult_v221(p_competitor_profile_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
  select coalesce((d.fecha_nacimiento_verificada <= (current_date - interval '18 years')::date),false)
  from public.perfiles_kombax_directos d where d.id=p_competitor_profile_id and d.tipo='competidor'
$$;
revoke all on function public.app_kombax_fighter_is_adult_v221(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_fighter_is_adult_v221(uuid) to authenticated;

create or replace function public.app_kombax_fighter_discovery_search_v221(
  p_query text default '',p_discipline text default null,p_category text default null,p_weight_kg numeric default null,p_level text default null,p_territory text default null,p_short_notice boolean default false,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_q text:=lower(trim(coalesce(p_query,'')));
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.match_score desc,x.nombre_publico), '[]'::jsonb) into v_rows
  from (
    select d.id as competitor_profile_id,s.id as social_profile_id,d.nombre_publico,d.slug,d.ubicacion,d.club_declarado,d.verificacion_estado,
      s.avatar_url,s.verificado,f.availability,f.contact_mode,f.disciplines,f.competition_level,f.usual_category,
      f.public_weight_min_kg,f.public_weight_max_kg,f.territory,f.max_travel_km,f.min_notice_hours,
      (case when p_discipline is not null and lower(p_discipline)=any(select lower(z) from unnest(f.disciplines) z) then 4 else 0 end
       +case when p_category is not null and lower(coalesce(f.usual_category,''))=lower(p_category) then 3 else 0 end
       +case when p_weight_kg is not null and (f.public_weight_min_kg is null or f.public_weight_min_kg<=p_weight_kg) and (f.public_weight_max_kg is null or f.public_weight_max_kg>=p_weight_kg) then 3 else 0 end
       +case when f.availability='short_notice' then 2 when f.availability='available' then 1 else 0 end
       +case when s.verificado then 1 else 0 end) as match_score
    from public.kombax_fighter_discovery_v221 f
    join public.perfiles_kombax_directos d on d.id=f.competitor_profile_id
    left join public.kombax_social_perfiles s on s.id=f.social_profile_id
    where f.discoverable and f.availability<>'unavailable'
      and d.tipo='competidor' and d.publico and d.estado='activa' and public.app_kombax_fighter_is_adult_v221(d.id)
      and (s.id is null or (s.visible and s.estado='activo'))
      and (v_q='' or lower(coalesce(d.nombre_publico,'')) like '%'||v_q||'%' or lower(coalesce(d.club_declarado,'')) like '%'||v_q||'%' or lower(coalesce(d.ubicacion,'')) like '%'||v_q||'%')
      and (p_discipline is null or lower(p_discipline)=any(select lower(z) from unnest(f.disciplines) z))
      and (p_category is null or lower(coalesce(f.usual_category,'')) like '%'||lower(p_category)||'%')
      and (p_weight_kg is null or ((f.public_weight_min_kg is null or f.public_weight_min_kg<=p_weight_kg) and (f.public_weight_max_kg is null or f.public_weight_max_kg>=p_weight_kg)))
      and (p_level is null or f.competition_level=p_level)
      and (p_territory is null or lower(coalesce(f.territory,d.ubicacion,'')) like '%'||lower(p_territory)||'%')
      and (not p_short_notice or f.availability='short_notice' or f.min_notice_hours<=72)
    limit least(100,greatest(1,coalesce(p_limit,30)))
  ) x;
  return v_rows;
end $$;
revoke all on function public.app_kombax_fighter_discovery_search_v221(text,text,text,numeric,text,text,boolean,integer) from public,anon,service_role;
grant execute on function public.app_kombax_fighter_discovery_search_v221(text,text,text,numeric,text,text,boolean,integer) to authenticated;

create or replace function public.app_kombax_fighter_discovery_me_v221(p_competitor_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_row jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_competitor_profile_id,'read') then raise exception 'KOMBAX_PROFILE_READ_REQUIRED'; end if;
  select to_jsonb(f) into v_row from public.kombax_fighter_discovery_v221 f where f.competitor_profile_id=p_competitor_profile_id;
  return coalesce(v_row,jsonb_build_object('competitor_profile_id',p_competitor_profile_id,'discoverable',false,'availability','unavailable','contact_mode','direct'));
end $$;
revoke all on function public.app_kombax_fighter_discovery_me_v221(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_fighter_discovery_me_v221(uuid) to authenticated;

create or replace function public.app_kombax_fighter_discovery_mutate_v221(p_competitor_profile_id uuid,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_direct public.perfiles_kombax_directos%rowtype; v_social uuid; v_out jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_direct from public.perfiles_kombax_directos where id=p_competitor_profile_id and tipo='competidor';
  if not found then raise exception 'KOMBAX_COMPETITOR_PROFILE_NOT_FOUND'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_competitor_profile_id,'edit') then raise exception 'KOMBAX_PROFILE_EDIT_REQUIRED'; end if;
  if coalesce((p_payload->>'discoverable')::boolean,false) and not public.app_kombax_fighter_is_adult_v221(p_competitor_profile_id) then raise exception 'KOMBAX_FIGHTER_DISCOVERY_ADULT_ONLY'; end if;
  select id into v_social from public.kombax_social_perfiles where perfil_directo_id=p_competitor_profile_id and sujeto_tipo='perfil_directo' order by actualizado_en desc limit 1;
  insert into public.kombax_fighter_discovery_v221(competitor_profile_id,social_profile_id,discoverable,availability,contact_mode,disciplines,competition_level,usual_category,public_weight_min_kg,public_weight_max_kg,territory,max_travel_km,min_notice_hours,accepts_federated_only,accepts_professional_only,updated_by)
  values(p_competitor_profile_id,v_social,coalesce((p_payload->>'discoverable')::boolean,false),coalesce(nullif(p_payload->>'availability',''),'unavailable'),coalesce(nullif(p_payload->>'contact_mode',''),'direct'),
    coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplines','[]'::jsonb))),'{}'::text[]),nullif(p_payload->>'competition_level',''),nullif(p_payload->>'usual_category',''),nullif(p_payload->>'public_weight_min_kg','')::numeric,nullif(p_payload->>'public_weight_max_kg','')::numeric,nullif(p_payload->>'territory',''),nullif(p_payload->>'max_travel_km','')::integer,coalesce(nullif(p_payload->>'min_notice_hours','')::integer,72),coalesce((p_payload->>'accepts_federated_only')::boolean,false),coalesce((p_payload->>'accepts_professional_only')::boolean,false),v_uid)
  on conflict(competitor_profile_id) do update set social_profile_id=excluded.social_profile_id,discoverable=excluded.discoverable,availability=excluded.availability,contact_mode=excluded.contact_mode,disciplines=excluded.disciplines,competition_level=excluded.competition_level,usual_category=excluded.usual_category,public_weight_min_kg=excluded.public_weight_min_kg,public_weight_max_kg=excluded.public_weight_max_kg,territory=excluded.territory,max_travel_km=excluded.max_travel_km,min_notice_hours=excluded.min_notice_hours,accepts_federated_only=excluded.accepts_federated_only,accepts_professional_only=excluded.accepts_professional_only,updated_by=v_uid,updated_at=now()
  returning to_jsonb(kombax_fighter_discovery_v221.*) into v_out;
  return v_out;
end $$;
revoke all on function public.app_kombax_fighter_discovery_mutate_v221(uuid,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_fighter_discovery_mutate_v221(uuid,jsonb) to authenticated;

create or replace function public.app_kombax_fight_invitations_v221(p_event_id uuid default null,p_competitor_profile_id uuid default null,p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_event_id is not null and not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED'; end if;
  if p_competitor_profile_id is not null and not public.app_kombax_puede_gestionar_perfil_v070(p_competitor_profile_id,'read') then raise exception 'KOMBAX_PROFILE_READ_REQUIRED'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_rows from (
    select i.*,d.nombre_publico,d.slug,s.avatar_url,e.nombre as event_name,e.fecha_inicio
    from public.kombax_fight_invitations_v221 i
    join public.perfiles_kombax_directos d on d.id=i.target_competitor_profile_id
    left join public.kombax_social_perfiles s on s.id=i.target_social_profile_id
    join public.kombax_eventos_publicos e on e.id=i.event_id
    where (p_event_id is not null and i.event_id=p_event_id) or (p_competitor_profile_id is not null and i.target_competitor_profile_id=p_competitor_profile_id)
    limit least(200,greatest(1,coalesce(p_limit,50)))
  ) x;
  return v_rows;
end $$;
revoke all on function public.app_kombax_fight_invitations_v221(uuid,uuid,integer) from public,anon,service_role;
grant execute on function public.app_kombax_fight_invitations_v221(uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_fight_invitation_mutate_v221(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_op text:=lower(trim(coalesce(p_operation,''))); v_id uuid:=nullif(p_payload->>'invitation_id','')::uuid;
  v_event uuid:=nullif(p_payload->>'event_id','')::uuid; v_target uuid:=nullif(p_payload->>'target_competitor_profile_id','')::uuid;
  v_social uuid; v_row public.kombax_fight_invitations_v221%rowtype; v_status text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_op='invite' then
    if v_event is null or v_target is null then raise exception 'KOMBAX_INVITATION_TARGET_REQUIRED'; end if;
    if not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED'; end if;
    if not exists(select 1 from public.kombax_fighter_discovery_v221 f where f.competitor_profile_id=v_target and f.discoverable and f.availability<>'unavailable') then raise exception 'KOMBAX_FIGHTER_NOT_DISCOVERABLE'; end if;
    if not public.app_kombax_fighter_is_adult_v221(v_target) then raise exception 'KOMBAX_FIGHTER_DISCOVERY_ADULT_ONLY'; end if;
    select social_profile_id into v_social from public.kombax_fighter_discovery_v221 where competitor_profile_id=v_target;
    insert into public.kombax_fight_invitations_v221(event_id,fight_id,target_competitor_profile_id,target_social_profile_id,sender_profile_id,discipline,category,proposed_weight_kg,event_at,location,message,expires_at)
    values(v_event,nullif(p_payload->>'fight_id','')::uuid,v_target,v_social,v_uid,nullif(p_payload->>'discipline',''),nullif(p_payload->>'category',''),nullif(p_payload->>'proposed_weight_kg','')::numeric,nullif(p_payload->>'event_at','')::timestamptz,nullif(p_payload->>'location',''),left(coalesce(p_payload->>'message',''),1200),coalesce(nullif(p_payload->>'expires_at','')::timestamptz,now()+interval '7 days')) returning * into v_row;
    return jsonb_build_object('ok',true,'invitation_id',v_row.id,'status',v_row.status);
  end if;
  if v_id is null then raise exception 'KOMBAX_INVITATION_ID_REQUIRED'; end if;
  select * into v_row from public.kombax_fight_invitations_v221 where id=v_id;
  if not found then raise exception 'KOMBAX_INVITATION_NOT_FOUND'; end if;
  if v_op='respond' then
    if not public.app_kombax_puede_gestionar_perfil_v070(v_row.target_competitor_profile_id,'edit') then raise exception 'KOMBAX_INVITATION_TARGET_ACCESS_REQUIRED'; end if;
    if v_row.status<>'pending' then raise exception 'KOMBAX_INVITATION_NOT_PENDING'; end if;
    v_status:=lower(coalesce(nullif(p_payload->>'status',''),'declined')); if v_status not in ('accepted','declined') then raise exception 'KOMBAX_INVITATION_RESPONSE_INVALID'; end if;
    update public.kombax_fight_invitations_v221 set status=v_status,response_note=left(coalesce(p_payload->>'response_note',''),1000),responded_at=now(),updated_at=now() where id=v_id returning * into v_row;
  elsif v_op='withdraw' then
    if v_row.sender_profile_id<>v_uid and not public.app_kombax_evento_puede_gestionar_v160(v_row.event_id) then raise exception 'KOMBAX_INVITATION_WITHDRAW_REQUIRED'; end if;
    if v_row.status not in ('pending','accepted') then raise exception 'KOMBAX_INVITATION_CANNOT_WITHDRAW'; end if;
    update public.kombax_fight_invitations_v221 set status='withdrawn',updated_at=now() where id=v_id returning * into v_row;
  elsif v_op='register' then
    if not public.app_kombax_evento_puede_gestionar_v160(v_row.event_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED'; end if;
    if v_row.status<>'accepted' then raise exception 'KOMBAX_INVITATION_ACCEPTANCE_REQUIRED'; end if;
    update public.kombax_fight_invitations_v221 set status='registered',registered_participant_id=nullif(p_payload->>'registered_participant_id','')::uuid,updated_at=now() where id=v_id returning * into v_row;
  else raise exception 'KOMBAX_INVITATION_OPERATION_INVALID'; end if;
  return jsonb_build_object('ok',true,'invitation_id',v_row.id,'status',v_row.status,'registered_participant_id',v_row.registered_participant_id);
end $$;
revoke all on function public.app_kombax_fight_invitation_mutate_v221(text,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_fight_invitation_mutate_v221(text,jsonb) to authenticated;

notify pgrst,'reload schema';
commit;
