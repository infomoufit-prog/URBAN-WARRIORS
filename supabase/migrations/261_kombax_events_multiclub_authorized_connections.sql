-- KOMBAX R74 / 261 · Authorized multi-club private-event <-> public-event connections.
-- One public event may receive multiple club connections. Public-event organizers approve/reject them.
-- Participant/license transfer is reference-based: no fighter identity, license document or Stripe/ticket record is duplicated.
begin;

alter table public.kombax_event_connections_v220
  drop constraint if exists kombax_event_connections_v220_public_event_id_key;

drop index if exists public.kombax_event_connections_v220_public_event_id_key;

alter table public.kombax_event_connections_v220
  add column if not exists authorization_status text not null default 'approved',
  add column if not exists requested_by uuid references public.perfiles(id) on delete restrict,
  add column if not exists requested_at timestamptz not null default now(),
  add column if not exists authorized_by uuid references public.perfiles(id) on delete set null,
  add column if not exists authorized_at timestamptz,
  add column if not exists authorization_note text;

update public.kombax_event_connections_v220
set requested_by=coalesce(requested_by,connected_by),
    requested_at=coalesce(requested_at,connected_at),
    authorized_by=coalesce(authorized_by,connected_by),
    authorized_at=coalesce(authorized_at,connected_at),
    authorization_status=coalesce(nullif(authorization_status,''),'approved')
where requested_by is null or authorized_by is null or authorized_at is null or authorization_status is null or authorization_status='';

alter table public.kombax_event_connections_v220
  alter column requested_by set not null;

alter table public.kombax_event_connections_v220
  drop constraint if exists kombax_event_connections_v220_authorization_status_check;
alter table public.kombax_event_connections_v220
  add constraint kombax_event_connections_v220_authorization_status_check
  check (authorization_status in ('pending','approved','rejected','revoked'));

create unique index if not exists uq_kombax_event_connection_public_club_v261
  on public.kombax_event_connections_v220(public_event_id,owner_club_id);
create index if not exists idx_kombax_event_connection_public_auth_v261
  on public.kombax_event_connections_v220(public_event_id,authorization_status,status,updated_at desc);

create table if not exists public.kombax_event_connection_participant_shares_v261(
  connection_id uuid not null references public.kombax_event_connections_v220(id) on delete cascade,
  internal_participant_id uuid not null references public.evento_participantes(id) on delete cascade,
  license_id uuid references public.kombax_federation_licenses_v200(id) on delete set null,
  shared_by uuid not null references public.perfiles(id) on delete restrict,
  shared_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(connection_id,internal_participant_id)
);
create index if not exists idx_event_connection_participant_license_v261
  on public.kombax_event_connection_participant_shares_v261(license_id) where license_id is not null;
alter table public.kombax_event_connection_participant_shares_v261 enable row level security;
revoke all on table public.kombax_event_connection_participant_shares_v261 from public,anon,authenticated;
drop policy if exists kombax_event_connection_participant_shares_deny_v261 on public.kombax_event_connection_participant_shares_v261;
create policy kombax_event_connection_participant_shares_deny_v261
  on public.kombax_event_connection_participant_shares_v261 for all
  using(false) with check(false);

create or replace function public.app_kombax_event_connection_can_v220(p_connection_id uuid,p_action text default 'read')
returns boolean
language plpgsql
stable security definer
set search_path to ''
as $function$
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

  -- All club roles that own the canonical private-event permission can operate their own connection.
  if public.app_puede_gestionar_eventos_v033(v_c.owner_club_id) then return true; end if;

  if exists(
    select 1 from public.kombax_event_organizer_permissions_v220 op
    where op.connection_id=v_c.id and op.perfil_id=v_uid and op.status='active'
      and (
        op.role_code='owner'
        or v_action='read'
        or (v_action='manage' and 'manage'=any(op.permissions))
        or (v_action='publish' and 'publish'=any(op.permissions))
        or (v_action='participants' and 'participants'=any(op.permissions))
        or (v_action='official_weigh_in' and 'official_weigh_in'=any(op.permissions))
        or (v_action='results' and 'results'=any(op.permissions))
      )
  ) then return true; end if;
  return false;
end
$function$;

revoke all on function public.app_kombax_event_connection_can_v220(uuid,text) from public,anon;
grant execute on function public.app_kombax_event_connection_can_v220(uuid,text) to authenticated;

create or replace function public.app_kombax_event_connections_v220(p_internal_event_id uuid default null,p_public_event_id uuid default null)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_c public.kombax_event_connections_v220%rowtype;
  v_policy public.kombax_event_publication_policies_v220%rowtype;
  v_internal public.eventos_competicion%rowtype;
  v_public public.kombax_eventos_publicos%rowtype;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_c from public.kombax_event_connections_v220 c
  where (p_internal_event_id is not null and c.internal_event_id=p_internal_event_id)
     or (p_public_event_id is not null and c.public_event_id=p_public_event_id)
  order by c.updated_at desc limit 1;
  if not found then return null; end if;
  if not public.app_kombax_event_connection_can_v220(v_c.id,'read')
     and not public.app_kombax_evento_puede_gestionar_v160(v_c.public_event_id) then return null; end if;
  select * into v_policy from public.kombax_event_publication_policies_v220 where connection_id=v_c.id;
  select * into v_internal from public.eventos_competicion where id=v_c.internal_event_id;
  select * into v_public from public.kombax_eventos_publicos where id=v_c.public_event_id;
  return jsonb_build_object(
    'id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status,
    'internal_event_id',v_c.internal_event_id,'public_event_id',v_c.public_event_id,
    'owner_club_id',v_c.owner_club_id,'connected_at',v_c.connected_at,'requested_at',v_c.requested_at,
    'authorized_at',v_c.authorized_at,'authorization_note',v_c.authorization_note,'updated_at',v_c.updated_at,
    'internal_event',jsonb_build_object('id',v_internal.id,'nombre',v_internal.nombre,'fecha',v_internal.fecha,'lugar',v_internal.lugar),
    'public_event',jsonb_build_object('id',v_public.id,'nombre',v_public.nombre,'slug',v_public.slug,'estado',v_public.estado),
    'policy',to_jsonb(v_policy)-'connection_id'-'updated_by'
  );
end
$function$;

revoke all on function public.app_kombax_event_connections_v220(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_event_connections_v220(uuid,uuid) to authenticated;

create or replace function public.app_kombax_event_connections_for_public_v261(p_public_event_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare v_rows jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_public_event_id is null then raise exception 'KOMBAX_PUBLIC_EVENT_ID_REQUIRED'; end if;
  if not public.app_kombax_evento_puede_gestionar_v160(p_public_event_id)
     and not public.app_kombax_es_platform_admin_v055() then
    raise exception 'KOMBAX_PUBLIC_EVENT_MANAGE_REQUIRED';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'status',c.status,'authorization_status',c.authorization_status,'owner_club_id',c.owner_club_id,
    'requested_at',c.requested_at,'authorized_at',c.authorized_at,'authorization_note',c.authorization_note,
    'internal_event',jsonb_build_object('id',i.id,'nombre',i.nombre,'fecha',i.fecha,'lugar',i.lugar),
    'club',jsonb_build_object('id',cl.id,'nombre',cl.nombre,'slug',cl.slug),
    'policy',to_jsonb(p)-'connection_id'-'updated_by',
    'shared_participants',(select count(*) from public.kombax_event_connection_participant_shares_v261 s where s.connection_id=c.id)
  ) order by c.requested_at desc),'[]'::jsonb) into v_rows
  from public.kombax_event_connections_v220 c
  join public.eventos_competicion i on i.id=c.internal_event_id
  join public.clubes cl on cl.id=c.owner_club_id
  left join public.kombax_event_publication_policies_v220 p on p.connection_id=c.id
  where c.public_event_id=p_public_event_id;
  return v_rows;
end
$function$;

revoke all on function public.app_kombax_event_connections_for_public_v261(uuid) from public,anon;
grant execute on function public.app_kombax_event_connections_for_public_v261(uuid) to authenticated;

create or replace function public.app_kombax_event_connection_participants_v261(p_connection_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  v_c public.kombax_event_connections_v220%rowtype;
  v_rows jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_c from public.kombax_event_connections_v220 where id=p_connection_id;
  if not found then raise exception 'KOMBAX_CONNECTION_NOT_FOUND'; end if;
  if not public.app_kombax_event_connection_can_v220(v_c.id,'read')
     and not public.app_kombax_evento_puede_gestionar_v160(v_c.public_event_id) then
    raise exception 'KOMBAX_CONNECTION_PERMISSION_REQUIRED';
  end if;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'share_id',s.internal_participant_id,'internal_participant_id',ep.id,'socio_id',ep.socio_id,
    'name',trim(concat_ws(' ',ep.nombre,ep.apellidos)),'club_name',coalesce(nullif(ep.club_origen,''),cl.nombre),
    'discipline',ep.disciplina_texto,'category',ep.categoria_texto,'event_weight_kg',ep.peso,'grade',ep.grado_texto,'age',ep.edad,
    'registration_status',ep.estado,
    'license',case when l.id is null then null else jsonb_build_object(
      'id',l.id,'number',l.license_number,'discipline',l.discipline,'category',l.category,'season',l.season,
      'status',l.status,'verification_status',l.verification_status,'valid_from',l.valid_from,'expires_at',l.expires_at
    ) end,
    'shared_at',s.shared_at,'updated_at',s.updated_at
  )) order by ep.nombre,ep.apellidos),'[]'::jsonb) into v_rows
  from public.kombax_event_connection_participant_shares_v261 s
  join public.evento_participantes ep on ep.id=s.internal_participant_id
  join public.clubes cl on cl.id=v_c.owner_club_id
  left join public.kombax_federation_licenses_v200 l on l.id=s.license_id
  where s.connection_id=v_c.id;
  return jsonb_build_object('connection_id',v_c.id,'authorization_status',v_c.authorization_status,'participants',v_rows);
end
$function$;

revoke all on function public.app_kombax_event_connection_participants_v261(uuid) from public,anon;
grant execute on function public.app_kombax_event_connection_participants_v261(uuid) to authenticated;

create or replace function public.app_kombax_event_connection_mutate_v220(p_operation text,p_payload jsonb default '{}'::jsonb,p_request_id text default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_op text:=lower(trim(coalesce(p_operation,'')));
  v_internal_id uuid:=nullif(p_payload->>'internal_event_id','')::uuid;
  v_public_id uuid:=nullif(p_payload->>'public_event_id','')::uuid;
  v_connection_id uuid:=nullif(p_payload->>'connection_id','')::uuid;
  v_internal public.eventos_competicion%rowtype;
  v_public public.kombax_eventos_publicos%rowtype;
  v_c public.kombax_event_connections_v220%rowtype;
  v_before jsonb;
  v_policy jsonb;
  v_projection jsonb;
  v_status text;
  v_decision text;
  v_note text;
  v_public_manager boolean:=false;
  v_shared integer:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if v_op='connect' then
    if v_internal_id is null or v_public_id is null then raise exception 'KOMBAX_EVENT_CONNECTION_IDS_REQUIRED'; end if;
    select * into v_internal from public.eventos_competicion where id=v_internal_id;
    if not found then raise exception 'KOMBAX_INTERNAL_EVENT_NOT_FOUND'; end if;
    if not public.app_puede_gestionar_eventos_v033(v_internal.club_id) then raise exception 'KOMBAX_INTERNAL_EVENT_MANAGE_REQUIRED'; end if;
    select * into v_public from public.kombax_eventos_publicos where id=v_public_id;
    if not found then raise exception 'KOMBAX_PUBLIC_EVENT_NOT_FOUND'; end if;
    v_public_manager:=public.app_kombax_evento_puede_gestionar_v160(v_public_id);
    if not v_public_manager and coalesce(v_public.estado,'borrador') in ('borrador','cancelado') then
      raise exception 'KOMBAX_PUBLIC_EVENT_NOT_CONNECTABLE';
    end if;

    select * into v_c from public.kombax_event_connections_v220
    where internal_event_id=v_internal_id and public_event_id=v_public_id limit 1;
    if found then
      -- A rejected/revoked club may explicitly request authorization again. Repeating an
      -- already-active/pending request remains a no-op, preserving idempotency.
      if v_c.authorization_status in ('rejected','revoked') then
        update public.kombax_event_connections_v220 set
          authorization_status=case when v_public_manager then 'approved' else 'pending' end,
          requested_by=v_uid,requested_at=now(),
          authorized_by=case when v_public_manager then v_uid else null end,
          authorized_at=case when v_public_manager then now() else null end,
          authorization_note=null,
          status=case when v_public_manager then 'connected' else 'paused' end,
          disconnected_at=null,updated_at=now()
        where id=v_c.id returning * into v_c;
        insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
          values(v_c.id,v_uid,case when v_public_manager then 'connect.reapproved' else 'connect.requested_again' end,'event_connection',v_c.id,to_jsonb(v_c));
        return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status,'re_requested',true,'request_id',p_request_id);
      end if;
      return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status,'idempotent',true,'request_id',p_request_id);
    end if;
    if exists(select 1 from public.kombax_event_connections_v220 where internal_event_id=v_internal_id) then
      raise exception 'KOMBAX_INTERNAL_EVENT_ALREADY_CONNECTED';
    end if;
    if exists(select 1 from public.kombax_event_connections_v220 where public_event_id=v_public_id and owner_club_id=v_internal.club_id) then
      raise exception 'KOMBAX_CLUB_ALREADY_CONNECTED_TO_PUBLIC_EVENT';
    end if;

    insert into public.kombax_event_connections_v220(
      internal_event_id,public_event_id,owner_club_id,status,connected_by,authorization_status,requested_by,requested_at,authorized_by,authorized_at
    ) values(
      v_internal_id,v_public_id,v_internal.club_id,case when v_public_manager then 'connected' else 'paused' end,v_uid,
      case when v_public_manager then 'approved' else 'pending' end,v_uid,now(),case when v_public_manager then v_uid else null end,case when v_public_manager then now() else null end
    ) returning * into v_c;
    insert into public.kombax_event_publication_policies_v220(connection_id,updated_by) values(v_c.id,v_uid)
      on conflict(connection_id) do nothing;
    insert into public.kombax_event_organizer_permissions_v220(connection_id,perfil_id,role_code,permissions,granted_by)
      values(v_c.id,v_uid,'owner',array['manage','publish','participants','official_weigh_in','results'],v_uid)
      on conflict(connection_id,perfil_id) do update set role_code='owner',permissions=excluded.permissions,status='active',revoked_at=null;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,case when v_public_manager then 'connect.approved' else 'connect.requested' end,'event_connection',v_c.id,to_jsonb(v_c));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status,'request_id',p_request_id);
  end if;

  if v_connection_id is null then raise exception 'KOMBAX_CONNECTION_ID_REQUIRED'; end if;
  select * into v_c from public.kombax_event_connections_v220 where id=v_connection_id;
  if not found then raise exception 'KOMBAX_CONNECTION_NOT_FOUND'; end if;

  if v_op='authorization.set' then
    if not public.app_kombax_evento_puede_gestionar_v160(v_c.public_event_id)
       and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_PUBLIC_EVENT_MANAGE_REQUIRED'; end if;
    v_decision:=lower(coalesce(nullif(trim(p_payload->>'decision'),''),'approved'));
    if v_decision not in ('approved','rejected','revoked') then raise exception 'KOMBAX_CONNECTION_AUTHORIZATION_INVALID'; end if;
    v_note:=nullif(left(trim(coalesce(p_payload->>'note','')),1000),'');
    v_before:=to_jsonb(v_c);
    update public.kombax_event_connections_v220 set
      authorization_status=v_decision,
      authorized_by=v_uid,
      authorized_at=now(),
      authorization_note=v_note,
      status=case when v_decision='approved' then 'connected' when v_decision='rejected' then 'disconnected' else 'paused' end,
      disconnected_at=case when v_decision='rejected' then now() else null end,
      updated_at=now()
    where id=v_c.id returning * into v_c;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,before_state,after_state)
      values(v_c.id,v_uid,'authorization.'||v_decision,'event_connection',v_c.id,v_before,to_jsonb(v_c));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status);
  end if;

  if v_op='participants.sync' then
    if v_c.authorization_status<>'approved' then raise exception 'KOMBAX_CONNECTION_APPROVAL_REQUIRED'; end if;
    if not public.app_puede_gestionar_eventos_v033(v_c.owner_club_id)
       and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_INTERNAL_EVENT_MANAGE_REQUIRED'; end if;
    insert into public.kombax_event_connection_participant_shares_v261(connection_id,internal_participant_id,license_id,shared_by,shared_at,updated_at)
    select v_c.id,ep.id,lic.id,v_uid,now(),now()
    from public.evento_participantes ep
    left join lateral(
      select l.id
      from public.kombax_federation_licenses_v200 l
      where ep.socio_id is not null
        and l.holder_club_member_id=ep.socio_id
        and (l.club_id is null or l.club_id=v_c.owner_club_id)
        and l.status='active' and l.verification_status='verified'
      order by (l.expires_at is null) desc,l.expires_at desc,l.updated_at desc
      limit 1
    ) lic on true
    where ep.evento_id=v_c.internal_event_id and ep.club_id=v_c.owner_club_id and ep.estado='confirmado'
    on conflict(connection_id,internal_participant_id) do update set
      license_id=excluded.license_id,shared_by=excluded.shared_by,updated_at=now();

    delete from public.kombax_event_connection_participant_shares_v261 s
    where s.connection_id=v_c.id
      and not exists(
        select 1 from public.evento_participantes ep
        where ep.id=s.internal_participant_id and ep.evento_id=v_c.internal_event_id and ep.club_id=v_c.owner_club_id and ep.estado='confirmado'
      );
    select count(*)::integer into v_shared from public.kombax_event_connection_participant_shares_v261 where connection_id=v_c.id;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,'participants.sync','event_participants',v_c.public_event_id,jsonb_build_object('shared',v_shared,'reference_only',true));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'shared_participants',v_shared,'reference_only',true);
  end if;

  if not public.app_kombax_event_connection_can_v220(v_c.id,case when v_op like 'policy.%' or v_op='projection.publish' then 'publish' else 'manage' end) then
    raise exception 'KOMBAX_CONNECTION_PERMISSION_REQUIRED';
  end if;

  if v_op='status.set' then
    v_status:=lower(coalesce(nullif(trim(p_payload->>'status'),''),'connected'));
    if v_status not in ('connected','paused','disconnected') then raise exception 'KOMBAX_CONNECTION_STATUS_INVALID'; end if;
    if v_status='connected' and v_c.authorization_status<>'approved' then raise exception 'KOMBAX_CONNECTION_APPROVAL_REQUIRED'; end if;
    v_before:=to_jsonb(v_c);
    update public.kombax_event_connections_v220 set status=v_status,disconnected_at=case when v_status='disconnected' then now() else null end,updated_at=now()
      where id=v_c.id returning * into v_c;
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,before_state,after_state)
      values(v_c.id,v_uid,'status.set','event_connection',v_c.id,v_before,to_jsonb(v_c));
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'status',v_c.status,'authorization_status',v_c.authorization_status);
  elsif v_op='policy.set' then
    if v_c.authorization_status<>'approved' then raise exception 'KOMBAX_CONNECTION_APPROVAL_REQUIRED'; end if;
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
    if v_c.authorization_status<>'approved' or v_c.status<>'connected' then raise exception 'KOMBAX_CONNECTION_APPROVAL_REQUIRED'; end if;
    select jsonb_strip_nulls(jsonb_build_object(
      'general',case when p.publish_general then jsonb_build_object('nombre',i.nombre,'descripcion',i.descripcion) end,
      'schedule',case when p.publish_schedule then jsonb_build_object('fecha',i.fecha,'hora_inicio',i.hora_inicio,'hora_fin',i.hora_fin) end,
      'location',case when p.publish_location then jsonb_build_object('lugar',i.lugar) end,
      'categories',case when p.publish_categories then jsonb_build_object('categoria',i.categoria_texto,'peso_min',i.peso_min,'peso_max',i.peso_max,'edad_min',i.edad_min,'edad_max',i.edad_max) end,
      'publish_participants',p.publish_participants,'publish_fight_card',p.publish_fight_card,'publish_official_weigh_in',p.publish_official_weigh_in,
      'publish_results',p.publish_results,'publish_album',p.publish_album,'publish_highlights',p.publish_highlights,
      'source_club_id',v_c.owner_club_id,'connection_id',v_c.id,'generated_at',now()
    )) into v_projection
    from public.eventos_competicion i join public.kombax_event_publication_policies_v220 p on p.connection_id=v_c.id
    where i.id=v_c.internal_event_id;
    insert into public.kombax_event_public_projection_v220(connection_id,projection,published_by)
      values(v_c.id,coalesce(v_projection,'{}'::jsonb),v_uid)
      on conflict(connection_id) do update set projection=excluded.projection,published_by=excluded.published_by,published_at=now(),updated_at=now();
    insert into public.kombax_event_connection_audit_v220(connection_id,actor_id,action,object_type,object_id,after_state)
      values(v_c.id,v_uid,'projection.publish','public_projection',v_c.public_event_id,v_projection);
    return jsonb_build_object('ok',true,'connection_id',v_c.id,'projection',v_projection);
  end if;
  raise exception 'KOMBAX_CONNECTION_OPERATION_INVALID';
end
$function$;

revoke all on function public.app_kombax_event_connection_mutate_v220(text,jsonb,text) from public,anon;
grant execute on function public.app_kombax_event_connection_mutate_v220(text,jsonb,text) to authenticated;

create or replace function public.app_kombax_event_public_projection_v220(p_public_event_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare v_count integer;v_first jsonb;v_rows jsonb;
begin
  select count(*),min(pp.projection::text)::jsonb into v_count,v_first
  from public.kombax_event_public_projection_v220 pp
  join public.kombax_event_connections_v220 c on c.id=pp.connection_id
  where c.public_event_id=p_public_event_id and c.status='connected' and c.authorization_status='approved';
  if coalesce(v_count,0)=0 then return '{}'::jsonb; end if;
  if v_count=1 then return coalesce(v_first,'{}'::jsonb); end if;
  select coalesce(jsonb_agg(jsonb_build_object('connection_id',c.id,'club_id',c.owner_club_id,'projection',pp.projection) order by c.updated_at desc),'[]'::jsonb)
    into v_rows
  from public.kombax_event_public_projection_v220 pp
  join public.kombax_event_connections_v220 c on c.id=pp.connection_id
  where c.public_event_id=p_public_event_id and c.status='connected' and c.authorization_status='approved';
  return jsonb_build_object('multiclub',true,'connections',v_rows);
end
$function$;

revoke all on function public.app_kombax_event_public_projection_v220(uuid) from public;
grant execute on function public.app_kombax_event_public_projection_v220(uuid) to anon,authenticated;

commit;
