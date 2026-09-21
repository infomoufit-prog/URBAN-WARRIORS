-- KOMBAX 20.101 R36 · Explicit Mi Club Events <-> KOMBAX Events connection
-- Connecting never means sharing. Publication is opt-in, granular and auditable.

begin;

create table if not exists public.kombax_event_connections_v220(
  id uuid primary key default gen_random_uuid(),
  internal_event_id uuid not null references public.eventos_competicion(id) on delete cascade,
  public_event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
  owner_club_id uuid not null references public.clubes(id) on delete cascade,
  status text not null default 'connected' check(status in ('connected','paused','disconnected')),
  connected_by uuid not null references public.perfiles(id) on delete restrict,
  connected_at timestamptz not null default now(),
  disconnected_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(internal_event_id),
  unique(public_event_id)
);

create table if not exists public.kombax_event_publication_policies_v220(
  connection_id uuid primary key references public.kombax_event_connections_v220(id) on delete cascade,
  publish_general boolean not null default false,
  publish_schedule boolean not null default false,
  publish_location boolean not null default false,
  publish_visuals boolean not null default false,
  publish_organizers boolean not null default false,
  publish_categories boolean not null default false,
  publish_participants boolean not null default false,
  publish_fight_card boolean not null default false,
  publish_official_weigh_in boolean not null default false,
  publish_results boolean not null default false,
  publish_album boolean not null default false,
  publish_highlights boolean not null default false,
  updated_by uuid not null references public.perfiles(id) on delete restrict,
  updated_at timestamptz not null default now()
);

create table if not exists public.kombax_event_organizer_permissions_v220(
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.kombax_event_connections_v220(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  role_code text not null check(role_code in ('owner','coorganizer','federation','official','collaborator')),
  permissions text[] not null default '{}'::text[],
  status text not null default 'active' check(status in ('active','revoked')),
  granted_by uuid not null references public.perfiles(id) on delete restrict,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(connection_id,perfil_id)
);

create table if not exists public.kombax_event_public_projection_v220(
  connection_id uuid primary key references public.kombax_event_connections_v220(id) on delete cascade,
  projection jsonb not null default '{}'::jsonb,
  published_by uuid not null references public.perfiles(id) on delete restrict,
  published_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.kombax_event_connection_audit_v220(
  id bigint generated always as identity primary key,
  connection_id uuid references public.kombax_event_connections_v220(id) on delete set null,
  actor_id uuid not null references public.perfiles(id) on delete restrict,
  action text not null,
  object_type text not null,
  object_id uuid,
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_kombax_event_connections_owner_v220 on public.kombax_event_connections_v220(owner_club_id,status,updated_at desc);
create index if not exists idx_kombax_event_permissions_connection_v220 on public.kombax_event_organizer_permissions_v220(connection_id,status);
create index if not exists idx_kombax_event_audit_connection_v220 on public.kombax_event_connection_audit_v220(connection_id,created_at desc);

alter table public.kombax_event_connections_v220 enable row level security;
alter table public.kombax_event_publication_policies_v220 enable row level security;
alter table public.kombax_event_organizer_permissions_v220 enable row level security;
alter table public.kombax_event_public_projection_v220 enable row level security;
alter table public.kombax_event_connection_audit_v220 enable row level security;

revoke all on public.kombax_event_connections_v220 from public,anon,authenticated;
revoke all on public.kombax_event_publication_policies_v220 from public,anon,authenticated;
revoke all on public.kombax_event_organizer_permissions_v220 from public,anon,authenticated;
revoke all on public.kombax_event_public_projection_v220 from public,anon,authenticated;
revoke all on public.kombax_event_connection_audit_v220 from public,anon,authenticated;

create or replace function public.app_kombax_event_connection_can_v220(p_connection_id uuid,p_action text default 'read')
returns boolean language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_c public.kombax_event_connections_v220%rowtype;
  v_action text:=lower(coalesce(nullif(trim(p_action),''),'read'));
begin
  if v_uid is null or p_connection_id is null then return false; end if;
  if v_action not in ('read','manage','publish','participants','official_weigh_in','results') then return false; end if;
  select * into v_c from public.kombax_event_connections_v220 where id=p_connection_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;
  if exists(select 1 from public.miembros_club mc where mc.club_id=v_c.owner_club_id and mc.perfil_id=v_uid and mc.activo and (mc.rol::text='direccion' or mc.coordinacion)) then return true; end if;
  if exists(
    select 1 from public.kombax_event_organizer_permissions_v220 op
    where op.connection_id=v_c.id and op.perfil_id=v_uid and op.status='active'
      and (
        op.role_code='owner'
        or (v_action='read')
        or (v_action='manage' and 'manage'=any(op.permissions))
        or (v_action='publish' and 'publish'=any(op.permissions))
        or (v_action='participants' and 'participants'=any(op.permissions))
        or (v_action='official_weigh_in' and 'official_weigh_in'=any(op.permissions))
        or (v_action='results' and 'results'=any(op.permissions))
      )
  ) then return true; end if;
  return false;
end $$;
revoke all on function public.app_kombax_event_connection_can_v220(uuid,text) from public,anon,service_role;
grant execute on function public.app_kombax_event_connection_can_v220(uuid,text) to authenticated;

create or replace function public.app_kombax_event_connections_v220(p_internal_event_id uuid default null,p_public_event_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_c public.kombax_event_connections_v220%rowtype;
  v_policy public.kombax_event_publication_policies_v220%rowtype;
  v_internal public.eventos_competicion%rowtype;
  v_public public.kombax_eventos_publicos%rowtype;
  v_out jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_c from public.kombax_event_connections_v220 c
    where (p_internal_event_id is not null and c.internal_event_id=p_internal_event_id)
       or (p_public_event_id is not null and c.public_event_id=p_public_event_id)
    order by c.updated_at desc limit 1;
  if not found then return null; end if;
  if not public.app_kombax_event_connection_can_v220(v_c.id,'read') and not public.app_kombax_evento_puede_gestionar_v160(v_c.public_event_id) then return null; end if;
  select * into v_policy from public.kombax_event_publication_policies_v220 where connection_id=v_c.id;
  select * into v_internal from public.eventos_competicion where id=v_c.internal_event_id;
  select * into v_public from public.kombax_eventos_publicos where id=v_c.public_event_id;
  v_out:=jsonb_build_object(
    'id',v_c.id,'status',v_c.status,'internal_event_id',v_c.internal_event_id,'public_event_id',v_c.public_event_id,
    'owner_club_id',v_c.owner_club_id,'connected_at',v_c.connected_at,'updated_at',v_c.updated_at,
    'internal_event',jsonb_build_object('id',v_internal.id,'nombre',v_internal.nombre,'fecha',v_internal.fecha,'lugar',v_internal.lugar),
    'public_event',jsonb_build_object('id',v_public.id,'nombre',v_public.nombre,'slug',v_public.slug,'estado',v_public.estado),
    'policy',to_jsonb(v_policy)-'connection_id'-'updated_by'
  );
  return v_out;
end $$;
revoke all on function public.app_kombax_event_connections_v220(uuid,uuid) from public,anon,service_role;
grant execute on function public.app_kombax_event_connections_v220(uuid,uuid) to authenticated;

create or replace function public.app_kombax_event_connection_mutate_v220(p_operation text,p_payload jsonb default '{}'::jsonb,p_request_id text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_op text:=lower(trim(coalesce(p_operation,'')));
  v_internal_id uuid:=nullif(p_payload->>'internal_event_id','')::uuid;
  v_public_id uuid:=nullif(p_payload->>'public_event_id','')::uuid;
  v_connection_id uuid:=nullif(p_payload->>'connection_id','')::uuid;
  v_internal public.eventos_competicion%rowtype;
  v_c public.kombax_event_connections_v220%rowtype;
  v_before jsonb;
  v_policy jsonb;
  v_projection jsonb;
  v_status text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if v_op='connect' then
    if v_internal_id is null or v_public_id is null then raise exception 'KOMBAX_EVENT_CONNECTION_IDS_REQUIRED'; end if;
    select * into v_internal from public.eventos_competicion where id=v_internal_id;
    if not found then raise exception 'KOMBAX_INTERNAL_EVENT_NOT_FOUND'; end if;
    if not public.app_puede_gestionar_eventos_v033(v_internal.club_id) then raise exception 'KOMBAX_INTERNAL_EVENT_MANAGE_REQUIRED'; end if;
    if not public.app_kombax_evento_puede_gestionar_v160(v_public_id) then raise exception 'KOMBAX_PUBLIC_EVENT_MANAGE_REQUIRED'; end if;
    if exists(select 1 from public.kombax_event_connections_v220 where internal_event_id=v_internal_id or public_event_id=v_public_id) then raise exception 'KOMBAX_EVENT_ALREADY_CONNECTED'; end if;
    insert into public.kombax_event_connections_v220(internal_event_id,public_event_id,owner_club_id,connected_by)
      values(v_internal_id,v_public_id,v_internal.club_id,v_uid) returning * into v_c;
    insert into public.kombax_event_publication_policies_v220(connection_id,updated_by) values(v_c.id,v_uid);
    insert into public.kombax_event_organizer_permissions_v220(connection_id,perfil_id,role_code,permissions,granted_by)
      values(v_c.id,v_uid,'owner',array['manage','publish','participants','official_weigh_in','results'],v_uid)
      on conflict(connection_id,perfil_id) do update set role_code='owner',permissions=excluded.permissions,status='active',revoked_at=null;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,'connect','event_connection',v_c.id,to_jsonb(v_c));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'request_id',p_request_id);
  end if;

  if v_connection_id is null then raise exception 'KOMBAX_CONNECTION_ID_REQUIRED'; end if;
  select * into v_c from public.kombax_event_connections_v220 where id=v_connection_id;
  if not found then raise exception 'KOMBAX_CONNECTION_NOT_FOUND'; end if;
  if not public.app_kombax_event_connection_can_v220(v_c.id,case when v_op like 'policy.%' or v_op='projection.publish' then 'publish' else 'manage' end) then raise exception 'KOMBAX_CONNECTION_PERMISSION_REQUIRED'; end if;

  if v_op='status.set' then
    v_status:=lower(coalesce(nullif(trim(p_payload->>'status'),''),'connected'));
    if v_status not in ('connected','paused','disconnected') then raise exception 'KOMBAX_CONNECTION_STATUS_INVALID'; end if;
    v_before:=to_jsonb(v_c);
    update public.kombax_event_connections_v220 set status=v_status,disconnected_at=case when v_status='disconnected' then now() else null end,updated_at=now() where id=v_c.id returning * into v_c;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,before_state,after_state)
      values(v_c.id,v_uid,'status.set','event_connection',v_c.id,v_before,to_jsonb(v_c));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status);
  elsif v_op='policy.set' then
    v_policy:=coalesce(p_payload->'policy','{}'::jsonb);
    update public.kombax_event_publication_policies_v220 set
      publish_general=coalesce((v_policy->>'publish_general')::boolean,publish_general),
      publish_schedule=coalesce((v_policy->>'publish_schedule')::boolean,publish_schedule),
      publish_location=coalesce((v_policy->>'publish_location')::boolean,publish_location),
      publish_visuals=coalesce((v_policy->>'publish_visuals')::boolean,publish_visuals),
      publish_organizers=coalesce((v_policy->>'publish_organizers')::boolean,publish_organizers),
      publish_categories=coalesce((v_policy->>'publish_categories')::boolean,publish_categories),
      publish_participants=coalesce((v_policy->>'publish_participants')::boolean,publish_participants),
      publish_fight_card=coalesce((v_policy->>'publish_fight_card')::boolean,publish_fight_card),
      publish_official_weigh_in=coalesce((v_policy->>'publish_official_weigh_in')::boolean,publish_official_weigh_in),
      publish_results=coalesce((v_policy->>'publish_results')::boolean,publish_results),
      publish_album=coalesce((v_policy->>'publish_album')::boolean,publish_album),
      publish_highlights=coalesce((v_policy->>'publish_highlights')::boolean,publish_highlights),
      updated_by=v_uid,updated_at=now()
      where connection_id=v_c.id returning to_jsonb(kombax_event_publication_policies_v220.*) into v_policy;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,'policy.set','publication_policy',v_c.id,v_policy);
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'policy',v_policy-'connection_id'-'updated_by');
  elsif v_op='projection.publish' then
    select jsonb_strip_nulls(jsonb_build_object(
      'general',case when p.publish_general then jsonb_build_object('nombre',i.nombre,'descripcion',i.descripcion) end,
      'schedule',case when p.publish_schedule then jsonb_build_object('fecha',i.fecha,'hora_inicio',i.hora_inicio,'hora_fin',i.hora_fin) end,
      'location',case when p.publish_location then jsonb_build_object('lugar',i.lugar) end,
      'categories',case when p.publish_categories then jsonb_build_object('categoria',i.categoria_texto,'peso_min',i.peso_min,'peso_max',i.peso_max,'edad_min',i.edad_min,'edad_max',i.edad_max) end,
      'publish_participants',p.publish_participants,'publish_fight_card',p.publish_fight_card,'publish_official_weigh_in',p.publish_official_weigh_in,
      'publish_results',p.publish_results,'publish_album',p.publish_album,'publish_highlights',p.publish_highlights,
      'generated_at',now()
    )) into v_projection
    from public.eventos_competicion i join public.kombax_event_publication_policies_v220 p on p.connection_id=v_c.id where i.id=v_c.internal_event_id;
    insert into public.kombax_event_public_projection_v220(connection_id,projection,published_by) values(v_c.id,coalesce(v_projection,'{}'::jsonb),v_uid)
      on conflict(connection_id) do update set projection=excluded.projection,published_by=excluded.published_by,published_at=now(),updated_at=now();
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,'projection.publish','public_projection',v_c.public_event_id,v_projection);
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'projection',v_projection);
  end if;
  raise exception 'KOMBAX_CONNECTION_OPERATION_INVALID';
end $$;
revoke all on function public.app_kombax_event_connection_mutate_v220(text,jsonb,text) from public,anon,service_role;
grant execute on function public.app_kombax_event_connection_mutate_v220(text,jsonb,text) to authenticated;

notify pgrst,'reload schema';
commit;
