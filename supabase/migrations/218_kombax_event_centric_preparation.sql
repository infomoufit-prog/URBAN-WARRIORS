-- KOMBAX 20.101 R35 · Event-centric competition preparation
-- Preparation belongs to a concrete registration. Private weight history stays private;
-- organizers/federations receive only registration and official weigh-in information.

begin;

alter table public.kombax_competition_preparations_v216
  add column if not exists event_source text,
  add column if not exists public_participant_id uuid references public.kombax_evento_participantes_publicos(id) on delete set null,
  add column if not exists internal_event_id uuid references public.eventos_competicion(id) on delete set null,
  add column if not exists internal_participant_id uuid references public.evento_participantes(id) on delete set null;

-- Legacy R34 preparations remain readable even if they were linked directly to an event.
-- New R35 records always receive an explicit event_source + registration id.

alter table public.kombax_competition_preparations_v216
  drop constraint if exists kombax_preparation_event_source_v218;
alter table public.kombax_competition_preparations_v216
  add constraint kombax_preparation_event_source_v218 check(
    event_source is null or event_source in ('kombax_event','club_event')
  );

alter table public.kombax_competition_preparations_v216
  drop constraint if exists kombax_preparation_registration_shape_v218;
alter table public.kombax_competition_preparations_v216
  add constraint kombax_preparation_registration_shape_v218 check(
    (event_source is null and public_participant_id is null and internal_event_id is null and internal_participant_id is null)
    or
    (event_source='kombax_event' and event_id is not null and public_participant_id is not null and internal_event_id is null and internal_participant_id is null)
    or
    (event_source='club_event' and event_id is null and public_participant_id is null and internal_event_id is not null and internal_participant_id is not null)
  ) not valid;
alter table public.kombax_competition_preparations_v216 validate constraint kombax_preparation_registration_shape_v218;

create unique index if not exists uq_kombax_preparation_public_registration_v218
  on public.kombax_competition_preparations_v216(public_participant_id)
  where public_participant_id is not null;
create unique index if not exists uq_kombax_preparation_internal_registration_v218
  on public.kombax_competition_preparations_v216(internal_participant_id)
  where internal_participant_id is not null;
create index if not exists idx_kombax_preparation_internal_event_v218
  on public.kombax_competition_preparations_v216(internal_event_id,status,updated_at desc)
  where internal_event_id is not null;

create table if not exists public.kombax_event_official_weigh_ins_v218(
  id uuid primary key default gen_random_uuid(),
  event_source text not null check(event_source in ('kombax_event','club_event')),
  public_event_id uuid references public.kombax_eventos_publicos(id) on delete cascade,
  public_participant_id uuid references public.kombax_evento_participantes_publicos(id) on delete cascade,
  internal_event_id uuid references public.eventos_competicion(id) on delete cascade,
  internal_participant_id uuid references public.evento_participantes(id) on delete cascade,
  preparation_id uuid references public.kombax_competition_preparations_v216(id) on delete set null,
  measurement_id uuid references public.kombax_weight_measurements_v216(id) on delete set null,
  weight_kg numeric(6,2) not null check(weight_kg between 15 and 300),
  weighed_at timestamptz not null default now(),
  verified_by uuid not null references public.perfiles(id) on delete restrict,
  locked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint kombax_official_weigh_in_shape_v218 check(
    (event_source='kombax_event' and public_event_id is not null and public_participant_id is not null and internal_event_id is null and internal_participant_id is null)
    or
    (event_source='club_event' and public_event_id is null and public_participant_id is null and internal_event_id is not null and internal_participant_id is not null)
  )
);
create unique index if not exists uq_kombax_official_public_registration_v218
  on public.kombax_event_official_weigh_ins_v218(public_participant_id)
  where public_participant_id is not null;
create unique index if not exists uq_kombax_official_internal_registration_v218
  on public.kombax_event_official_weigh_ins_v218(internal_participant_id)
  where internal_participant_id is not null;
create index if not exists idx_kombax_official_event_v218
  on public.kombax_event_official_weigh_ins_v218(event_source,public_event_id,internal_event_id,weighed_at desc);

alter table public.kombax_event_official_weigh_ins_v218 enable row level security;
revoke all on public.kombax_event_official_weigh_ins_v218 from public,anon,authenticated;
drop policy if exists kombax_official_weigh_ins_no_direct_v218 on public.kombax_event_official_weigh_ins_v218;
create policy kombax_official_weigh_ins_no_direct_v218 on public.kombax_event_official_weigh_ins_v218
  for all to public using(false) with check(false);

-- Private-history gate. R35 intentionally removes event-organizer access to daily measurements.
create or replace function public.app_kombax_preparation_can_v216(p_preparation_id uuid,p_action text default 'read')
returns boolean
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_p public.kombax_competition_preparations_v216%rowtype;
  v_action text:=lower(coalesce(nullif(trim(p_action),''),'read'));
  v_profile_access text;
begin
  if v_uid is null or p_preparation_id is null then return false; end if;
  if v_action not in ('read','log','verify','manage','official_verify') then return false; end if;
  -- Official verification is separated from the private log in R35.
  if v_action='official_verify' then return false; end if;
  select * into v_p from public.kombax_competition_preparations_v216 where id=p_preparation_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;

  if v_p.competitor_profile_id is not null then
    v_profile_access:=case when v_action='read' then 'read' when v_action in ('log','verify') then 'edit' else 'admin' end;
    if public.app_kombax_puede_gestionar_perfil_v070(v_p.competitor_profile_id,v_profile_access) then return true; end if;
    if v_action in ('read','log','verify') and exists(
      select 1 from public.kombax_professional_delegations_v198 d
      where d.target_profile_id=v_p.competitor_profile_id and d.status='accepted'
        and (d.starts_at is null or d.starts_at<=now()) and (d.expires_at is null or d.expires_at>now())
        and public.app_kombax_puede_gestionar_perfil_v070(d.professional_profile_id,'read')
    ) then return true; end if;
  end if;

  if v_p.socio_id is not null then
    if v_action='read' and public.puede_ver_socio(v_p.socio_id) then return true; end if;
    if exists(select 1 from public.socios s where s.id=v_p.socio_id and s.perfil_id=v_uid) then return true; end if;
  end if;

  if v_p.club_id is not null and exists(
    select 1 from public.miembros_club mc
    where mc.club_id=v_p.club_id and mc.perfil_id=v_uid and mc.activo
      and (mc.rol::text='direccion' or mc.coordinacion or (v_action in ('read','log','verify') and mc.rol::text='monitor'))
  ) then return true; end if;

  if exists(
    select 1 from public.kombax_preparation_access_v216 a
    where a.preparation_id=v_p.id and a.perfil_id=v_uid and a.status='active'
      and (
        (v_action='read' and 'read'=any(a.permissions)) or
        (v_action='log' and ('log'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='verify' and ('verify'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='manage' and 'manage'=any(a.permissions))
      )
  ) then return true; end if;
  return false;
end $$;
revoke all on function public.app_kombax_preparation_can_v216(uuid,text) from public,anon,service_role;
grant execute on function public.app_kombax_preparation_can_v216(uuid,text) to authenticated;

create or replace function public.app_kombax_weight_measurements_v216(p_preparation_id uuid,p_limit integer default 120)
returns table(id uuid,preparation_id uuid,weight_kg numeric,measured_at timestamptz,measurement_context text,note text,evidence_path text,verification_kind text,recorded_by uuid,verified_by uuid,verified_at timestamptz,recorded_by_name text,verified_by_name text)
language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_preparation_can_v216(p_preparation_id,'read') then raise exception 'KOMBAX_PREPARATION_READ_REQUIRED'; end if;
  return query
  select m.id,m.preparation_id,m.weight_kg,m.measured_at,m.measurement_context,m.note,m.evidence_path,m.verification_kind,m.recorded_by,m.verified_by,m.verified_at,
         btrim(concat_ws(' ',r.nombre,r.apellidos)),btrim(concat_ws(' ',v.nombre,v.apellidos))
  from public.kombax_weight_measurements_v216 m
  left join public.perfiles r on r.id=m.recorded_by left join public.perfiles v on v.id=m.verified_by
  where m.preparation_id=p_preparation_id order by m.measured_at desc,m.id desc
  limit least(greatest(coalesce(p_limit,120),1),500);
end $$;
revoke all on function public.app_kombax_weight_measurements_v216(uuid,integer) from public,anon,service_role;
grant execute on function public.app_kombax_weight_measurements_v216(uuid,integer) to authenticated;

create or replace function public.app_kombax_public_registration_private_manager_v218(p_registration_id uuid)
returns boolean language plpgsql stable security definer set search_path=''
as $$
declare v_r record; v_sp public.kombax_social_perfiles%rowtype; v_identity public.identidades_sociales%rowtype;
begin
  if auth.uid() is null or p_registration_id is null then return false; end if;
  select p.*,sp.sujeto_tipo,sp.perfil_directo_id,sp.identidad_social_id
    into v_r
  from public.kombax_evento_participantes_publicos p
  left join public.kombax_social_perfiles sp on sp.id=p.competidor_social_profile_id
  where p.id=p_registration_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;
  if v_r.competidor_social_profile_id is not null and public.app_kombax_eventos_puede_actuar_social_v160(v_r.competidor_social_profile_id) then return true; end if;
  if v_r.presentado_por_social_profile_id is not null and public.app_kombax_eventos_puede_actuar_social_v160(v_r.presentado_por_social_profile_id)
     and exists(select 1 from public.kombax_social_perfiles psp where psp.id=v_r.presentado_por_social_profile_id and psp.sujeto_tipo='club') then return true; end if;
  return false;
end $$;
revoke all on function public.app_kombax_public_registration_private_manager_v218(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_public_registration_private_manager_v218(uuid) to authenticated;

create or replace function public.app_kombax_event_preparation_roster_v218(p_event_source text,p_event_id uuid)
returns table(
  event_source text,event_id uuid,registration_id uuid,participant_name text,registration_state text,category_label text,registration_weight_kg numeric,
  preparation_id uuid,target_weight_kg numeric,current_weight_kg numeric,last_measured_at timestamptz,measurement_count bigint,
  can_view_private boolean,can_log_private boolean,can_manage_private boolean,can_official_weigh_in boolean,
  official_weight_kg numeric,official_weighed_at timestamptz,is_external boolean,competitor_profile_id uuid,socio_id uuid
)
language plpgsql stable security definer set search_path=''
as $$
declare v_source text:=lower(trim(coalesce(p_event_source,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_source='kombax_event' then
    return query
    select 'kombax_event'::text,p.evento_id,p.id,p.nombre_publico,p.estado_inscripcion,p.categoria,p.peso,
      pr.id,pr.target_weight_kg,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then lm.weight_kg else null end,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then lm.measured_at else null end,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then coalesce(mc.n,0) else 0 end,
      coalesce(pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read'),false),
      coalesce(pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'log'),false),
      public.app_kombax_public_registration_private_manager_v218(p.id),
      public.app_kombax_evento_puede_gestionar_v160(p.evento_id),
      ow.weight_kg,ow.weighed_at,(p.origen='externa'),pr.competitor_profile_id,pr.socio_id
    from public.kombax_evento_participantes_publicos p
    left join public.kombax_competition_preparations_v216 pr on pr.public_participant_id=p.id
    left join lateral(select m.weight_kg,m.measured_at from public.kombax_weight_measurements_v216 m where m.preparation_id=pr.id order by m.measured_at desc,m.id desc limit 1) lm on true
    left join lateral(select count(*)::bigint n from public.kombax_weight_measurements_v216 m where m.preparation_id=pr.id) mc on true
    left join public.kombax_event_official_weigh_ins_v218 ow on ow.public_participant_id=p.id
    where p.evento_id=p_event_id and (
      public.app_kombax_evento_puede_gestionar_v160(p.evento_id)
      or public.app_kombax_public_registration_private_manager_v218(p.id)
    )
    order by p.nombre_publico,p.id;
  elsif v_source='club_event' then
    return query
    select 'club_event'::text,p.evento_id,p.id,btrim(concat_ws(' ',p.nombre,p.apellidos)),p.estado,p.categoria_texto,p.peso,
      pr.id,pr.target_weight_kg,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then lm.weight_kg else null end,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then lm.measured_at else null end,
      case when pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read') then coalesce(mc.n,0) else 0 end,
      coalesce(pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'read'),false),
      coalesce(pr.id is not null and public.app_kombax_preparation_can_v216(pr.id,'log'),false),
      (not p.externo and p.socio_id is not null and (public.app_puede_gestionar_eventos_v033(p.club_id) or public.puede_ver_socio(p.socio_id))),
      public.app_puede_gestionar_eventos_v033(p.club_id),
      ow.weight_kg,ow.weighed_at,p.externo,pr.competitor_profile_id,coalesce(pr.socio_id,p.socio_id)
    from public.evento_participantes p
    left join public.kombax_competition_preparations_v216 pr on pr.internal_participant_id=p.id
    left join lateral(select m.weight_kg,m.measured_at from public.kombax_weight_measurements_v216 m where m.preparation_id=pr.id order by m.measured_at desc,m.id desc limit 1) lm on true
    left join lateral(select count(*)::bigint n from public.kombax_weight_measurements_v216 m where m.preparation_id=pr.id) mc on true
    left join public.kombax_event_official_weigh_ins_v218 ow on ow.internal_participant_id=p.id
    where p.evento_id=p_event_id and (
      public.app_puede_gestionar_eventos_v033(p.club_id)
      or (not p.externo and p.socio_id is not null and public.puede_ver_socio(p.socio_id))
    )
    order by p.apellidos,p.nombre,p.id;
  else
    raise exception 'KOMBAX_EVENT_SOURCE_INVALID';
  end if;
end $$;
revoke all on function public.app_kombax_event_preparation_roster_v218(text,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_event_preparation_roster_v218(text,uuid) to authenticated;

create or replace function public.app_kombax_event_preparation_mutate_v218(p_operation text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_op text:=lower(trim(coalesce(p_operation,''))); v_p jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_source text:=lower(trim(coalesce(v_p->>'event_source',''))); v_registration uuid:=public.app_kombax_uuid_or_null_v070(v_p->>'registration_id');
  v_prep public.kombax_competition_preparations_v216%rowtype; v_prep_id uuid; v_event uuid; v_internal_event uuid; v_subject_profile uuid; v_subject_socio uuid; v_club uuid;
  v_title text; v_discipline text; v_category text; v_weight numeric; v_weigh_at timestamptz; v_frequency text; v_measurement uuid; v_official uuid;
  v_public public.kombax_evento_participantes_publicos%rowtype; v_internal public.evento_participantes%rowtype; v_sp public.kombax_social_perfiles%rowtype; v_identity public.identidades_sociales%rowtype; v_evt_name text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_source not in ('kombax_event','club_event') then raise exception 'KOMBAX_EVENT_SOURCE_INVALID'; end if;
  if v_registration is null then raise exception 'KOMBAX_REGISTRATION_REQUIRED'; end if;

  if v_op='registration.preparation.activate' then
    v_frequency=coalesce(nullif(lower(trim(v_p->>'tracking_frequency')),''),'weekly');
    if v_frequency not in ('weekly','three_per_week','daily','custom') then raise exception 'KOMBAX_TRACKING_FREQUENCY_INVALID'; end if;
    if nullif(v_p->>'target_weight_kg','') is not null then v_weight=(v_p->>'target_weight_kg')::numeric; if v_weight<15 or v_weight>300 then raise exception 'KOMBAX_WEIGHT_OUT_OF_RANGE'; end if; else v_weight=null; end if;
    v_weigh_at=nullif(v_p->>'weigh_in_at','')::timestamptz;

    if v_source='kombax_event' then
      select * into v_public from public.kombax_evento_participantes_publicos where id=v_registration;
      if not found then raise exception 'KOMBAX_REGISTRATION_NOT_FOUND'; end if;
      if v_public.origen='externa' or v_public.competidor_social_profile_id is null then raise exception 'KOMBAX_PRIVATE_PREPARATION_REQUIRES_LINKED_PROFILE'; end if;
      if not public.app_kombax_public_registration_private_manager_v218(v_registration) then raise exception 'KOMBAX_PREPARATION_SUBJECT_EDIT_REQUIRED'; end if;
      select * into v_sp from public.kombax_social_perfiles where id=v_public.competidor_social_profile_id;
      if v_sp.sujeto_tipo='perfil_directo' then v_subject_profile=v_sp.perfil_directo_id;
      elsif v_sp.sujeto_tipo='miembro' then select * into v_identity from public.identidades_sociales where id=v_sp.identidad_social_id; v_subject_socio=v_identity.socio_origen_id;
      end if;
      if (v_subject_profile is null)::int+(v_subject_socio is null)::int<>1 then raise exception 'KOMBAX_PRIVATE_PREPARATION_REQUIRES_LINKED_PROFILE'; end if;
      if v_public.presentado_por_social_profile_id is not null then
        select club_id into v_club from public.kombax_social_perfiles where id=v_public.presentado_por_social_profile_id and sujeto_tipo='club';
      end if;
      if v_subject_socio is not null then select club_id into v_club from public.socios where id=v_subject_socio; end if;
      select nombre into v_evt_name from public.kombax_eventos_publicos where id=v_public.evento_id;
      v_title=left(btrim(concat_ws(' · ',coalesce(v_evt_name,'KOMBAX Evento'),nullif(v_public.categoria,''))),180);
      v_discipline=nullif(v_public.disciplina,''); v_category=nullif(v_public.categoria,''); v_event=v_public.evento_id;
      select id into v_prep_id from public.kombax_competition_preparations_v216 where public_participant_id=v_registration;
      if v_prep_id is null then
        insert into public.kombax_competition_preparations_v216(competitor_profile_id,socio_id,club_id,event_id,event_source,public_participant_id,title,discipline,category,target_weight_kg,weigh_in_at,tracking_frequency,created_by)
        values(v_subject_profile,v_subject_socio,v_club,v_event,'kombax_event',v_registration,v_title,v_discipline,v_category,v_weight,v_weigh_at,v_frequency,v_uid) returning id into v_prep_id;
      else
        update public.kombax_competition_preparations_v216 set title=v_title,discipline=v_discipline,category=v_category,target_weight_kg=coalesce(v_weight,target_weight_kg),weigh_in_at=coalesce(v_weigh_at,weigh_in_at),tracking_frequency=v_frequency,status='active',updated_at=now() where id=v_prep_id;
      end if;
    else
      select * into v_internal from public.evento_participantes where id=v_registration;
      if not found then raise exception 'KOMBAX_REGISTRATION_NOT_FOUND'; end if;
      if v_internal.externo or v_internal.socio_id is null then raise exception 'KOMBAX_PRIVATE_PREPARATION_REQUIRES_LINKED_PROFILE'; end if;
      if not public.app_puede_gestionar_eventos_v033(v_internal.club_id) and not public.puede_ver_socio(v_internal.socio_id) then raise exception 'KOMBAX_PREPARATION_SUBJECT_EDIT_REQUIRED'; end if;
      select nombre into v_evt_name from public.eventos_competicion where id=v_internal.evento_id;
      v_title=left(btrim(concat_ws(' · ',coalesce(v_evt_name,'Evento del club'),nullif(v_internal.categoria_texto,''))),180);
      v_discipline=nullif(v_internal.disciplina_texto,''); v_category=nullif(v_internal.categoria_texto,''); v_internal_event=v_internal.evento_id; v_subject_socio=v_internal.socio_id; v_club=v_internal.club_id;
      select id into v_prep_id from public.kombax_competition_preparations_v216 where internal_participant_id=v_registration;
      if v_prep_id is null then
        insert into public.kombax_competition_preparations_v216(socio_id,club_id,event_source,internal_event_id,internal_participant_id,title,discipline,category,target_weight_kg,weigh_in_at,tracking_frequency,created_by)
        values(v_subject_socio,v_club,'club_event',v_internal_event,v_registration,v_title,v_discipline,v_category,v_weight,v_weigh_at,v_frequency,v_uid) returning id into v_prep_id;
      else
        update public.kombax_competition_preparations_v216 set title=v_title,discipline=v_discipline,category=v_category,target_weight_kg=coalesce(v_weight,target_weight_kg),weigh_in_at=coalesce(v_weigh_at,weigh_in_at),tracking_frequency=v_frequency,status='active',updated_at=now() where id=v_prep_id;
      end if;
    end if;
    return jsonb_build_object('ok',true,'operation',v_op,'preparation_id',v_prep_id,'registration_id',v_registration,'event_source',v_source,'request_id',p_request_id);

  elsif v_op='official_weigh_in.set' then
    v_weight=nullif(v_p->>'weight_kg','')::numeric; if v_weight is null or v_weight<15 or v_weight>300 then raise exception 'KOMBAX_WEIGHT_OUT_OF_RANGE'; end if;
    v_weigh_at=coalesce(nullif(v_p->>'weighed_at','')::timestamptz,now());
    if v_source='kombax_event' then
      select * into v_public from public.kombax_evento_participantes_publicos where id=v_registration;
      if not found then raise exception 'KOMBAX_REGISTRATION_NOT_FOUND'; end if;
      if not public.app_kombax_evento_puede_gestionar_v160(v_public.evento_id) then raise exception 'KOMBAX_OFFICIAL_WEIGH_IN_MANAGE_REQUIRED'; end if;
      if exists(select 1 from public.kombax_event_official_weigh_ins_v218 where public_participant_id=v_registration) then raise exception 'KOMBAX_OFFICIAL_WEIGH_IN_LOCKED'; end if;
      select id into v_prep_id from public.kombax_competition_preparations_v216 where public_participant_id=v_registration;
      if v_prep_id is not null then
        insert into public.kombax_weight_measurements_v216(preparation_id,weight_kg,measured_at,measurement_context,note,verification_kind,recorded_by,verified_by,verified_at)
        values(v_prep_id,v_weight,v_weigh_at,'other','Pesaje oficial del evento','official',v_uid,v_uid,v_weigh_at) returning id into v_measurement;
      end if;
      insert into public.kombax_event_official_weigh_ins_v218(event_source,public_event_id,public_participant_id,preparation_id,measurement_id,weight_kg,weighed_at,verified_by)
      values('kombax_event',v_public.evento_id,v_registration,v_prep_id,v_measurement,v_weight,v_weigh_at,v_uid) returning id into v_official;
      update public.kombax_evento_participantes_publicos set peso=v_weight,actualizado_en=now() where id=v_registration;
    else
      select * into v_internal from public.evento_participantes where id=v_registration;
      if not found then raise exception 'KOMBAX_REGISTRATION_NOT_FOUND'; end if;
      if not public.app_puede_gestionar_eventos_v033(v_internal.club_id) then raise exception 'KOMBAX_OFFICIAL_WEIGH_IN_MANAGE_REQUIRED'; end if;
      if exists(select 1 from public.kombax_event_official_weigh_ins_v218 where internal_participant_id=v_registration) then raise exception 'KOMBAX_OFFICIAL_WEIGH_IN_LOCKED'; end if;
      select id into v_prep_id from public.kombax_competition_preparations_v216 where internal_participant_id=v_registration;
      if v_prep_id is not null then
        insert into public.kombax_weight_measurements_v216(preparation_id,weight_kg,measured_at,measurement_context,note,verification_kind,recorded_by,verified_by,verified_at)
        values(v_prep_id,v_weight,v_weigh_at,'other','Pesaje oficial del evento','official',v_uid,v_uid,v_weigh_at) returning id into v_measurement;
      end if;
      insert into public.kombax_event_official_weigh_ins_v218(event_source,internal_event_id,internal_participant_id,preparation_id,measurement_id,weight_kg,weighed_at,verified_by)
      values('club_event',v_internal.evento_id,v_registration,v_prep_id,v_measurement,v_weight,v_weigh_at,v_uid) returning id into v_official;
      update public.evento_participantes set peso=v_weight,actualizado_por=v_uid,actualizado_en=now() where id=v_registration;
    end if;
    return jsonb_build_object('ok',true,'operation',v_op,'official_weigh_in_id',v_official,'measurement_id',v_measurement,'registration_id',v_registration,'weight_kg',v_weight,'locked',true,'request_id',p_request_id);
  else
    raise exception 'KOMBAX_EVENT_PREPARATION_OPERATION_NOT_ALLOWED';
  end if;
end $$;
revoke all on function public.app_kombax_event_preparation_mutate_v218(text,jsonb,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_event_preparation_mutate_v218(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
