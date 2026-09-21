-- KOMBAX 20.101 R34 · Competition preparation & private weight control
-- Private-by-default tracking for competitor direct profiles and club members.
-- This module stores observations only. It does not prescribe dehydration, weight loss,
-- nutrition, medication, or medical protocols.

begin;

create table if not exists public.kombax_competition_preparations_v216(
  id uuid primary key default gen_random_uuid(),
  competitor_profile_id uuid references public.perfiles_kombax_directos(id) on delete cascade,
  socio_id uuid references public.socios(id) on delete cascade,
  club_id uuid references public.clubes(id) on delete cascade,
  event_id uuid references public.kombax_eventos_publicos(id) on delete set null,
  title text not null,
  discipline text,
  category text,
  target_weight_kg numeric(6,2),
  weigh_in_at timestamptz,
  tracking_frequency text not null default 'weekly' check(tracking_frequency in ('weekly','three_per_week','daily','custom')),
  reminder_days smallint[] not null default '{}'::smallint[],
  status text not null default 'active' check(status in ('active','completed','archived')),
  created_by uuid not null references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kombax_preparation_subject_one_v216 check ((competitor_profile_id is not null)::int + (socio_id is not null)::int = 1),
  constraint kombax_preparation_target_weight_v216 check(target_weight_kg is null or target_weight_kg between 15 and 300),
  constraint kombax_preparation_title_v216 check(length(btrim(title)) between 2 and 180)
);

create index if not exists idx_kombax_preparation_profile_v216 on public.kombax_competition_preparations_v216(competitor_profile_id,updated_at desc) where competitor_profile_id is not null;
create index if not exists idx_kombax_preparation_socio_v216 on public.kombax_competition_preparations_v216(socio_id,updated_at desc) where socio_id is not null;
create index if not exists idx_kombax_preparation_club_v216 on public.kombax_competition_preparations_v216(club_id,status,updated_at desc) where club_id is not null;
create index if not exists idx_kombax_preparation_event_v216 on public.kombax_competition_preparations_v216(event_id) where event_id is not null;

create table if not exists public.kombax_preparation_access_v216(
  id uuid primary key default gen_random_uuid(),
  preparation_id uuid not null references public.kombax_competition_preparations_v216(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  role_code text not null check(role_code in ('trainer','preparer','manager','representative','club_staff','guardian')),
  permissions text[] not null default array['read']::text[],
  status text not null default 'active' check(status in ('active','revoked')),
  granted_by uuid not null references public.perfiles(id) on delete restrict,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(preparation_id,perfil_id)
);
create index if not exists idx_kombax_preparation_access_profile_v216 on public.kombax_preparation_access_v216(perfil_id,status,preparation_id);

create table if not exists public.kombax_weight_measurements_v216(
  id uuid primary key default gen_random_uuid(),
  preparation_id uuid not null references public.kombax_competition_preparations_v216(id) on delete cascade,
  weight_kg numeric(6,2) not null check(weight_kg between 15 and 300),
  measured_at timestamptz not null default now(),
  measurement_context text not null default 'normal' check(measurement_context in ('normal','fasted','post_training','other')),
  note text,
  evidence_path text,
  verification_kind text not null default 'self' check(verification_kind in ('self','team','official')),
  recorded_by uuid not null references public.perfiles(id) on delete restrict,
  verified_by uuid references public.perfiles(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint kombax_weight_note_v216 check(note is null or length(note)<=500)
);
create index if not exists idx_kombax_weight_measurements_prep_v216 on public.kombax_weight_measurements_v216(preparation_id,measured_at desc,id desc);
create index if not exists idx_kombax_weight_measurements_recorder_v216 on public.kombax_weight_measurements_v216(recorded_by,created_at desc);

alter table public.kombax_competition_preparations_v216 enable row level security;
alter table public.kombax_preparation_access_v216 enable row level security;
alter table public.kombax_weight_measurements_v216 enable row level security;
revoke all on public.kombax_competition_preparations_v216 from public,anon,authenticated;
revoke all on public.kombax_preparation_access_v216 from public,anon,authenticated;
revoke all on public.kombax_weight_measurements_v216 from public,anon,authenticated;

create policy kombax_preparations_no_direct_v216 on public.kombax_competition_preparations_v216 for all to public using(false) with check(false);
create policy kombax_preparation_access_no_direct_v216 on public.kombax_preparation_access_v216 for all to public using(false) with check(false);
create policy kombax_weight_measurements_no_direct_v216 on public.kombax_weight_measurements_v216 for all to public using(false) with check(false);

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
  select * into v_p from public.kombax_competition_preparations_v216 where id=p_preparation_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;

  if v_p.competitor_profile_id is not null then
    v_profile_access:=case when v_action='read' then 'read' when v_action in ('log','verify') then 'edit' else 'admin' end;
    if v_action<>'official_verify' and public.app_kombax_puede_gestionar_perfil_v070(v_p.competitor_profile_id,v_profile_access) then return true; end if;
    if v_action in ('read','log','verify') and exists(
      select 1 from public.kombax_professional_delegations_v198 d
      where d.target_profile_id=v_p.competitor_profile_id and d.status='accepted'
        and (d.starts_at is null or d.starts_at<=now()) and (d.expires_at is null or d.expires_at>now())
        and public.app_kombax_puede_gestionar_perfil_v070(d.professional_profile_id,'read')
    ) then return true; end if;
  end if;

  if v_p.socio_id is not null and exists(select 1 from public.socios s where s.id=v_p.socio_id and s.perfil_id=v_uid) then
    if v_action<>'official_verify' then return true; end if;
  end if;

  if v_p.club_id is not null and exists(
    select 1 from public.miembros_club mc
    where mc.club_id=v_p.club_id and mc.perfil_id=v_uid and mc.activo
      and (mc.rol::text='direccion' or mc.coordinacion)
  ) then
    if v_action in ('read','log','verify','manage') then return true; end if;
  end if;

  if v_action<>'official_verify' and exists(
    select 1 from public.kombax_preparation_access_v216 a
    where a.preparation_id=v_p.id and a.perfil_id=v_uid and a.status='active'
      and (
        (v_action='read' and 'read'=any(a.permissions)) or
        (v_action='log' and ('log'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='verify' and ('verify'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='manage' and 'manage'=any(a.permissions))
      )
  ) then return true; end if;

  if v_action='official_verify' and v_p.event_id is not null and public.app_kombax_evento_puede_gestionar_v160(v_p.event_id) then return true; end if;
  return false;
end $$;
revoke all on function public.app_kombax_preparation_can_v216(uuid,text) from public,anon,service_role;
grant execute on function public.app_kombax_preparation_can_v216(uuid,text) to authenticated;

create or replace function public.app_kombax_preparations_v216(
  p_competitor_profile_id uuid default null,
  p_socio_id uuid default null,
  p_club_id uuid default null,
  p_limit integer default 100
)
returns table(
  id uuid,competitor_profile_id uuid,socio_id uuid,club_id uuid,event_id uuid,title text,discipline text,category text,
  target_weight_kg numeric,weigh_in_at timestamptz,tracking_frequency text,reminder_days smallint[],status text,
  subject_name text,event_name text,event_starts_at timestamptz,last_weight_kg numeric,last_measured_at timestamptz,measurement_count bigint,
  can_log boolean,can_verify boolean,can_manage boolean,updated_at timestamptz
)
language sql stable security definer set search_path=''
as $$
  select p.id,p.competitor_profile_id,p.socio_id,p.club_id,p.event_id,p.title,p.discipline,p.category,
         p.target_weight_kg,p.weigh_in_at,p.tracking_frequency,p.reminder_days,p.status,
         coalesce(d.nombre_publico,btrim(concat_ws(' ',s.nombre,s.apellidos)),'Competidor') subject_name,
         e.nombre event_name,e.fecha_inicio event_starts_at,
         lm.weight_kg,lm.measured_at,
         (select count(*) from public.kombax_weight_measurements_v216 c where c.preparation_id=p.id) measurement_count,
         public.app_kombax_preparation_can_v216(p.id,'log') can_log,
         public.app_kombax_preparation_can_v216(p.id,'verify') can_verify,
         public.app_kombax_preparation_can_v216(p.id,'manage') can_manage,
         p.updated_at
  from public.kombax_competition_preparations_v216 p
  left join public.perfiles_kombax_directos d on d.id=p.competitor_profile_id
  left join public.socios s on s.id=p.socio_id
  left join public.kombax_eventos_publicos e on e.id=p.event_id
  left join lateral (
    select m.weight_kg,m.measured_at from public.kombax_weight_measurements_v216 m
    where m.preparation_id=p.id order by m.measured_at desc,m.id desc limit 1
  ) lm on true
  where auth.uid() is not null
    and (p_competitor_profile_id is null or p.competitor_profile_id=p_competitor_profile_id)
    and (p_socio_id is null or p.socio_id=p_socio_id)
    and (p_club_id is null or p.club_id=p_club_id)
    and public.app_kombax_preparation_can_v216(p.id,'read')
  order by case p.status when 'active' then 0 when 'completed' then 1 else 2 end,
           p.weigh_in_at asc nulls last,p.updated_at desc
  limit least(greatest(coalesce(p_limit,100),1),300);
$$;
revoke all on function public.app_kombax_preparations_v216(uuid,uuid,uuid,integer) from public,anon,service_role;
grant execute on function public.app_kombax_preparations_v216(uuid,uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_weight_measurements_v216(p_preparation_id uuid,p_limit integer default 120)
returns table(id uuid,preparation_id uuid,weight_kg numeric,measured_at timestamptz,measurement_context text,note text,evidence_path text,verification_kind text,recorded_by uuid,verified_by uuid,verified_at timestamptz,recorded_by_name text,verified_by_name text)
language plpgsql stable security definer set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_preparation_can_v216(p_preparation_id,'read') and not public.app_kombax_preparation_can_v216(p_preparation_id,'official_verify') then raise exception 'KOMBAX_PREPARATION_READ_REQUIRED'; end if;
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

create or replace function public.app_kombax_preparation_candidates_v216(p_preparation_id uuid)
returns table(perfil_id uuid,name text,source text,access_role text,access_permissions text[])
language plpgsql stable security definer set search_path=''
as $$
declare v_p public.kombax_competition_preparations_v216%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_preparation_can_v216(p_preparation_id,'manage') then raise exception 'KOMBAX_PREPARATION_MANAGE_REQUIRED'; end if;
  select * into v_p from public.kombax_competition_preparations_v216 where id=p_preparation_id;
  return query
  with candidates as(
    select mc.perfil_id,btrim(concat_ws(' ',p.nombre,p.apellidos)) name,'club_team'::text source
    from public.miembros_club mc join public.perfiles p on p.id=mc.perfil_id
    where v_p.club_id is not null and mc.club_id=v_p.club_id and mc.activo and mc.rol::text in ('direccion','secretaria','monitor')
    union
    select pd.perfil_id,pd.nombre_publico,'representation'::text
    from public.kombax_professional_delegations_v198 d
    join public.perfiles_kombax_directos pd on pd.id=d.professional_profile_id
    where v_p.competitor_profile_id is not null and d.target_profile_id=v_p.competitor_profile_id and d.status='accepted'
      and (d.starts_at is null or d.starts_at<=now()) and (d.expires_at is null or d.expires_at>now())
  )
  select distinct c.perfil_id,c.name,c.source,a.role_code,a.permissions
  from candidates c left join public.kombax_preparation_access_v216 a on a.preparation_id=v_p.id and a.perfil_id=c.perfil_id and a.status='active'
  where c.perfil_id<>auth.uid() order by c.name;
end $$;
revoke all on function public.app_kombax_preparation_candidates_v216(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_preparation_candidates_v216(uuid) to authenticated;

create or replace function public.app_kombax_preparation_mutate_v216(p_operation text,p_payload jsonb default '{}'::jsonb,p_request_id uuid default gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_op text:=lower(trim(coalesce(p_operation,''))); v_p jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_id uuid; v_prep public.kombax_competition_preparations_v216%rowtype; v_profile uuid; v_socio uuid; v_club uuid; v_event uuid;
  v_weight numeric; v_measured timestamptz; v_kind text; v_role text; v_permissions text[]:='{}'::text[]; v_perm text; v_target_user uuid; v_path text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if v_op='preparation.save' then
    v_id=public.app_kombax_uuid_or_null_v070(v_p->>'id');
    v_profile=public.app_kombax_uuid_or_null_v070(v_p->>'competitor_profile_id');
    v_socio=public.app_kombax_uuid_or_null_v070(v_p->>'socio_id');
    v_club=public.app_kombax_uuid_or_null_v070(v_p->>'club_id');
    v_event=public.app_kombax_uuid_or_null_v070(v_p->>'event_id');
    if (v_profile is null)::int+(v_socio is null)::int<>1 then raise exception 'KOMBAX_PREPARATION_SUBJECT_REQUIRED'; end if;
    if v_profile is not null then
      if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.tipo='competidor') then raise exception 'KOMBAX_COMPETITOR_PROFILE_REQUIRED'; end if;
      if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'edit') then raise exception 'KOMBAX_COMPETITOR_PROFILE_EDIT_REQUIRED'; end if;
      if v_club is not null and not exists(select 1 from public.miembros_club mc where mc.club_id=v_club and mc.perfil_id=v_uid and mc.activo) then v_club=null; end if;
    else
      select s.club_id into v_club from public.socios s where s.id=v_socio;
      if v_club is null then raise exception 'KOMBAX_MEMBER_NOT_FOUND'; end if;
      if not exists(select 1 from public.socios s where s.id=v_socio and s.perfil_id=v_uid)
         and not exists(select 1 from public.miembros_club mc where mc.club_id=v_club and mc.perfil_id=v_uid and mc.activo and (mc.rol::text='direccion' or mc.coordinacion))
      then raise exception 'KOMBAX_PREPARATION_SUBJECT_EDIT_REQUIRED'; end if;
    end if;
    if v_event is not null and not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_event) then raise exception 'KOMBAX_EVENT_NOT_FOUND'; end if;
    if nullif(v_p->>'target_weight_kg','') is not null then
      v_weight=(v_p->>'target_weight_kg')::numeric;
      if v_weight<15 or v_weight>300 then raise exception 'KOMBAX_WEIGHT_OUT_OF_RANGE'; end if;
    else v_weight=null; end if;
    if coalesce(nullif(v_p->>'tracking_frequency',''),'weekly') not in ('weekly','three_per_week','daily','custom') then raise exception 'KOMBAX_TRACKING_FREQUENCY_INVALID'; end if;

    if v_id is null then
      insert into public.kombax_competition_preparations_v216(competitor_profile_id,socio_id,club_id,event_id,title,discipline,category,target_weight_kg,weigh_in_at,tracking_frequency,reminder_days,created_by)
      values(v_profile,v_socio,v_club,v_event,left(btrim(coalesce(v_p->>'title','Preparación de competición')),180),left(nullif(btrim(v_p->>'discipline'),''),120),left(nullif(btrim(v_p->>'category'),''),120),v_weight,nullif(v_p->>'weigh_in_at','')::timestamptz,coalesce(nullif(v_p->>'tracking_frequency',''),'weekly'),
             coalesce(array(select value::smallint from jsonb_array_elements_text(coalesce(v_p->'reminder_days','[]'::jsonb)) where value~'^[0-6]$'),'{}'::smallint[]),v_uid)
      returning id into v_id;
    else
      if not public.app_kombax_preparation_can_v216(v_id,'manage') then raise exception 'KOMBAX_PREPARATION_MANAGE_REQUIRED'; end if;
      update public.kombax_competition_preparations_v216 set event_id=v_event,title=left(btrim(coalesce(v_p->>'title',title)),180),discipline=left(nullif(btrim(v_p->>'discipline'),''),120),category=left(nullif(btrim(v_p->>'category'),''),120),target_weight_kg=v_weight,weigh_in_at=nullif(v_p->>'weigh_in_at','')::timestamptz,tracking_frequency=coalesce(nullif(v_p->>'tracking_frequency',''),tracking_frequency),updated_at=now() where id=v_id;
    end if;
    return jsonb_build_object('ok',true,'operation',v_op,'id',v_id,'request_id',p_request_id);

  elsif v_op='preparation.status' then
    v_id=public.app_kombax_uuid_or_null_v070(v_p->>'preparation_id');
    if not public.app_kombax_preparation_can_v216(v_id,'manage') then raise exception 'KOMBAX_PREPARATION_MANAGE_REQUIRED'; end if;
    v_kind=lower(btrim(v_p->>'status')); if v_kind not in ('active','completed','archived') then raise exception 'KOMBAX_PREPARATION_STATUS_INVALID'; end if;
    update public.kombax_competition_preparations_v216 set status=v_kind,updated_at=now() where id=v_id;
    return jsonb_build_object('ok',true,'operation',v_op,'id',v_id,'status',v_kind,'request_id',p_request_id);

  elsif v_op='measurement.add' then
    v_id=public.app_kombax_uuid_or_null_v070(v_p->>'preparation_id');
    if not public.app_kombax_preparation_can_v216(v_id,'log') then raise exception 'KOMBAX_PREPARATION_LOG_REQUIRED'; end if;
    v_weight=nullif(v_p->>'weight_kg','')::numeric; if v_weight is null or v_weight<15 or v_weight>300 then raise exception 'KOMBAX_WEIGHT_OUT_OF_RANGE'; end if;
    v_measured=coalesce(nullif(v_p->>'measured_at','')::timestamptz,now()); if v_measured>now()+interval '1 day' then raise exception 'KOMBAX_MEASUREMENT_DATE_INVALID'; end if;
    v_kind=coalesce(nullif(lower(btrim(v_p->>'measurement_context')),''),'normal'); if v_kind not in ('normal','fasted','post_training','other') then raise exception 'KOMBAX_MEASUREMENT_CONTEXT_INVALID'; end if;
    insert into public.kombax_weight_measurements_v216(preparation_id,weight_kg,measured_at,measurement_context,note,verification_kind,recorded_by)
    values(v_id,v_weight,v_measured,v_kind,left(nullif(btrim(v_p->>'note'),''),500),'self',v_uid) returning id into v_target_user;
    update public.kombax_competition_preparations_v216 set updated_at=now() where id=v_id;
    return jsonb_build_object('ok',true,'operation',v_op,'id',v_target_user,'preparation_id',v_id,'request_id',p_request_id);

  elsif v_op='measurement.verify' then
    v_target_user=public.app_kombax_uuid_or_null_v070(v_p->>'measurement_id');
    select m.preparation_id into v_id from public.kombax_weight_measurements_v216 m where m.id=v_target_user;
    if v_id is null then raise exception 'KOMBAX_MEASUREMENT_NOT_FOUND'; end if;
    v_kind=coalesce(nullif(lower(btrim(v_p->>'verification_kind')),''),'team');
    if v_kind='official' then
      if not public.app_kombax_preparation_can_v216(v_id,'official_verify') then raise exception 'KOMBAX_OFFICIAL_VERIFICATION_REQUIRED'; end if;
    elsif v_kind='team' then
      if not public.app_kombax_preparation_can_v216(v_id,'verify') then raise exception 'KOMBAX_PREPARATION_VERIFY_REQUIRED'; end if;
    else raise exception 'KOMBAX_VERIFICATION_KIND_INVALID'; end if;
    update public.kombax_weight_measurements_v216 set verification_kind=v_kind,verified_by=v_uid,verified_at=now(),updated_at=now() where id=v_target_user;
    return jsonb_build_object('ok',true,'operation',v_op,'id',v_target_user,'verification_kind',v_kind,'request_id',p_request_id);

  elsif v_op='measurement.attach_photo' then
    v_target_user=public.app_kombax_uuid_or_null_v070(v_p->>'measurement_id'); v_path=left(coalesce(v_p->>'evidence_path',''),500);
    select m.preparation_id into v_id from public.kombax_weight_measurements_v216 m where m.id=v_target_user;
    if v_id is null or not public.app_kombax_preparation_can_v216(v_id,'log') then raise exception 'KOMBAX_PREPARATION_LOG_REQUIRED'; end if;
    if v_path not like v_id::text||'/'||v_target_user::text||'/%' then raise exception 'KOMBAX_EVIDENCE_PATH_INVALID'; end if;
    update public.kombax_weight_measurements_v216 set evidence_path=v_path,updated_at=now() where id=v_target_user;
    return jsonb_build_object('ok',true,'operation',v_op,'id',v_target_user,'request_id',p_request_id);

  elsif v_op='access.grant' then
    v_id=public.app_kombax_uuid_or_null_v070(v_p->>'preparation_id'); v_target_user=public.app_kombax_uuid_or_null_v070(v_p->>'perfil_id');
    if not public.app_kombax_preparation_can_v216(v_id,'manage') then raise exception 'KOMBAX_PREPARATION_MANAGE_REQUIRED'; end if;
    if v_target_user is null or not exists(select 1 from public.perfiles where id=v_target_user) then raise exception 'KOMBAX_ACCESS_PROFILE_REQUIRED'; end if;
    v_role=lower(btrim(v_p->>'role_code')); if v_role not in ('trainer','preparer','manager','representative','club_staff','guardian') then raise exception 'KOMBAX_ACCESS_ROLE_INVALID'; end if;
    if jsonb_typeof(coalesce(v_p->'permissions','[]'::jsonb))<>'array' then raise exception 'KOMBAX_ACCESS_PERMISSIONS_INVALID'; end if;
    for v_perm in select distinct value from jsonb_array_elements_text(coalesce(v_p->'permissions','[]'::jsonb)) loop
      if v_perm not in ('read','log','verify','manage') then raise exception 'KOMBAX_ACCESS_PERMISSION_NOT_ALLOWED'; end if;
      v_permissions=array_append(v_permissions,v_perm);
    end loop;
    if cardinality(v_permissions)=0 then v_permissions=array['read']; end if;
    insert into public.kombax_preparation_access_v216(preparation_id,perfil_id,role_code,permissions,status,granted_by)
    values(v_id,v_target_user,v_role,v_permissions,'active',v_uid)
    on conflict(preparation_id,perfil_id) do update set role_code=excluded.role_code,permissions=excluded.permissions,status='active',granted_by=excluded.granted_by,granted_at=now(),revoked_at=null,updated_at=now();
    return jsonb_build_object('ok',true,'operation',v_op,'preparation_id',v_id,'perfil_id',v_target_user,'request_id',p_request_id);

  elsif v_op='access.revoke' then
    v_id=public.app_kombax_uuid_or_null_v070(v_p->>'preparation_id'); v_target_user=public.app_kombax_uuid_or_null_v070(v_p->>'perfil_id');
    if not public.app_kombax_preparation_can_v216(v_id,'manage') then raise exception 'KOMBAX_PREPARATION_MANAGE_REQUIRED'; end if;
    update public.kombax_preparation_access_v216 set status='revoked',revoked_at=now(),updated_at=now() where preparation_id=v_id and perfil_id=v_target_user;
    return jsonb_build_object('ok',true,'operation',v_op,'preparation_id',v_id,'perfil_id',v_target_user,'request_id',p_request_id);
  else
    raise exception 'KOMBAX_PREPARATION_OPERATION_NOT_ALLOWED';
  end if;
end $$;
revoke all on function public.app_kombax_preparation_mutate_v216(text,jsonb,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_preparation_mutate_v216(text,jsonb,uuid) to authenticated;

-- Private evidence bucket. Paths use <preparation_id>/<measurement_id>/<filename>.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('competition-weight-evidence','competition-weight-evidence',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists kombax_weight_evidence_select_v216 on storage.objects;
create policy kombax_weight_evidence_select_v216 on storage.objects for select to authenticated using(
  bucket_id='competition-weight-evidence' and
  case when coalesce((storage.foldername(name))[1],'') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       then public.app_kombax_preparation_can_v216(((storage.foldername(name))[1])::uuid,'read') else false end
);
drop policy if exists kombax_weight_evidence_insert_v216 on storage.objects;
create policy kombax_weight_evidence_insert_v216 on storage.objects for insert to authenticated with check(
  bucket_id='competition-weight-evidence' and
  case when coalesce((storage.foldername(name))[1],'') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       then public.app_kombax_preparation_can_v216(((storage.foldername(name))[1])::uuid,'log') else false end
);
drop policy if exists kombax_weight_evidence_delete_v216 on storage.objects;
create policy kombax_weight_evidence_delete_v216 on storage.objects for delete to authenticated using(
  bucket_id='competition-weight-evidence' and
  case when coalesce((storage.foldername(name))[1],'') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       then public.app_kombax_preparation_can_v216(((storage.foldername(name))[1])::uuid,'manage') else false end
);

notify pgrst,'reload schema';
commit;
