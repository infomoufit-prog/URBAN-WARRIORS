begin;

create table if not exists public.kombax_support_authorizations_v194 (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('club','direct_profile','account')),
  subject_id uuid not null,
  requested_by uuid not null references public.perfiles(id),
  ticket_ref text null check (ticket_ref is null or char_length(ticket_ref) <= 120),
  scopes text[] not null default array['support.read']::text[],
  code_hash text not null unique check (code_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'active' check (status in ('active','claimed','revoked','expired')),
  expires_at timestamptz not null,
  claimed_at timestamptz null,
  claimed_by text null check (claimed_by is null or char_length(claimed_by) <= 120),
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create index if not exists kombax_support_authorizations_subject_v194_idx
  on public.kombax_support_authorizations_v194(subject_type, subject_id, created_at desc);
create index if not exists kombax_support_authorizations_active_v194_idx
  on public.kombax_support_authorizations_v194(status, expires_at)
  where status in ('active','claimed');

create table if not exists public.kombax_support_access_audit_v194 (
  id bigint generated always as identity primary key,
  authorization_id uuid null references public.kombax_support_authorizations_v194(id) on delete set null,
  subject_type text not null check (subject_type in ('club','direct_profile','account','platform')),
  subject_id uuid null,
  actor_type text not null check (actor_type in ('customer','ai_support','platform_admin','system')),
  actor_profile_id uuid null references public.perfiles(id),
  action text not null check (char_length(action) between 3 and 120),
  detail jsonb not null default '{}'::jsonb check (jsonb_typeof(detail)='object'),
  created_at timestamptz not null default now()
);
create index if not exists kombax_support_access_audit_subject_v194_idx
  on public.kombax_support_access_audit_v194(subject_type, subject_id, created_at desc);

alter table public.kombax_support_authorizations_v194 enable row level security;
alter table public.kombax_support_access_audit_v194 enable row level security;

revoke all on public.kombax_support_authorizations_v194 from anon, authenticated;
revoke all on public.kombax_support_access_audit_v194 from anon, authenticated;

do $$ begin
  if exists (select 1 from pg_roles where rolname='service_role') then
    grant select, insert, update on public.kombax_support_authorizations_v194 to service_role;
    grant select, insert on public.kombax_support_access_audit_v194 to service_role;
  end if;
end $$;

create or replace function public.app_kombax_support_can_manage_subject_v194(
  p_subject_type text,
  p_subject_id uuid,
  p_actor uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when p_actor is null or p_subject_id is null then false
    when exists (
      select 1 from public.kombax_platform_admins pa
      where pa.perfil_id=p_actor and pa.activo=true
    ) then true
    when p_subject_type='account' then p_subject_id=p_actor
    when p_subject_type='club' then exists (
      select 1 from public.miembros_club mc
      where mc.club_id=p_subject_id and mc.perfil_id=p_actor and mc.activo=true
        and (mc.rol='direccion' or mc.coordinacion=true)
    )
    when p_subject_type='direct_profile' then exists (
      select 1 from public.perfiles_kombax_directos pd
      where pd.id=p_subject_id and pd.perfil_id=p_actor
    ) or exists (
      select 1 from public.kombax_perfil_gestores pg
      where pg.perfil_directo_id=p_subject_id and pg.perfil_id=p_actor
        and pg.estado='activo' and pg.rol in ('owner','admin')
    )
    else false
  end;
$$;
revoke all on function public.app_kombax_support_can_manage_subject_v194(text,uuid,uuid) from public, anon, authenticated;

create or replace function public.app_kombax_support_authorizations_v194(
  p_subject_type text,
  p_subject_id uuid,
  p_limit integer default 25
) returns table(
  id uuid, subject_type text, subject_id uuid, requested_by uuid,
  ticket_ref text, scopes text[], status text, expires_at timestamptz,
  claimed_at timestamptz, claimed_by text, revoked_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.app_kombax_support_can_manage_subject_v194(p_subject_type,p_subject_id,auth.uid()) then
    raise exception 'SUPPORT_SUBJECT_FORBIDDEN';
  end if;
  return query
  select a.id,a.subject_type,a.subject_id,a.requested_by,a.ticket_ref,a.scopes,
         case when a.status in ('active','claimed') and a.expires_at<=now() then 'expired' else a.status end,
         a.expires_at,a.claimed_at,a.claimed_by,a.revoked_at,a.created_at
  from public.kombax_support_authorizations_v194 a
  where a.subject_type=p_subject_type and a.subject_id=p_subject_id
  order by a.created_at desc
  limit least(100,greatest(1,coalesce(p_limit,25)));
end;
$$;
revoke all on function public.app_kombax_support_authorizations_v194(text,uuid,integer) from public, anon;
grant execute on function public.app_kombax_support_authorizations_v194(text,uuid,integer) to authenticated;

create or replace function public.app_kombax_support_authorization_mutate_v194(
  p_operation text,
  p_payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_subject_type text := nullif(trim(p_payload->>'subject_type'),'');
  v_subject_id uuid := nullif(p_payload->>'subject_id','')::uuid;
  v_id uuid;
  v_minutes integer;
  v_ticket text;
  v_scopes text[];
  v_code text;
  v_hash text;
  v_row public.kombax_support_authorizations_v194%rowtype;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;

  if p_operation='support.authorization.create' then
    if not public.app_kombax_support_can_manage_subject_v194(v_subject_type,v_subject_id,v_actor) then
      raise exception 'SUPPORT_SUBJECT_FORBIDDEN';
    end if;
    v_minutes := least(1440,greatest(15,coalesce((p_payload->>'duration_minutes')::integer,120)));
    v_ticket := nullif(left(trim(coalesce(p_payload->>'ticket_ref','')),120),'');
    select coalesce(array_agg(distinct s),array['support.read']::text[]) into v_scopes
      from jsonb_array_elements_text(coalesce(p_payload->'scopes','["support.read"]'::jsonb)) s
      where s in ('support.read','support.write','finance.read','documents.read','minors.read');
    if cardinality(v_scopes)=0 then v_scopes:=array['support.read']::text[]; end if;
    v_code := lpad((floor(random()*1000000))::integer::text,6,'0');
    v_hash := encode(digest(v_code,'sha256'),'hex');
    while exists(select 1 from public.kombax_support_authorizations_v194 where code_hash=v_hash and expires_at>now()) loop
      v_code := lpad((floor(random()*1000000))::integer::text,6,'0');
      v_hash := encode(digest(v_code,'sha256'),'hex');
    end loop;
    insert into public.kombax_support_authorizations_v194(subject_type,subject_id,requested_by,ticket_ref,scopes,code_hash,expires_at)
      values(v_subject_type,v_subject_id,v_actor,v_ticket,v_scopes,v_hash,now()+make_interval(mins=>v_minutes))
      returning * into v_row;
    insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,actor_profile_id,action,detail)
      values(v_row.id,v_subject_type,v_subject_id,'customer',v_actor,'support.authorization.created',jsonb_build_object('scopes',v_scopes,'expires_at',v_row.expires_at,'ticket_ref',v_ticket));
    return jsonb_build_object('id',v_row.id,'code',v_code,'expires_at',v_row.expires_at,'scopes',v_scopes,'ticket_ref',v_ticket,'status','active');
  elsif p_operation='support.authorization.revoke' then
    v_id := nullif(p_payload->>'authorization_id','')::uuid;
    select * into v_row from public.kombax_support_authorizations_v194 where id=v_id for update;
    if not found then raise exception 'SUPPORT_AUTHORIZATION_NOT_FOUND'; end if;
    if not public.app_kombax_support_can_manage_subject_v194(v_row.subject_type,v_row.subject_id,v_actor) then
      raise exception 'SUPPORT_SUBJECT_FORBIDDEN';
    end if;
    update public.kombax_support_authorizations_v194
       set status='revoked',revoked_at=now(),updated_at=now()
     where id=v_id and status in ('active','claimed');
    insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,actor_profile_id,action,detail)
      values(v_id,v_row.subject_type,v_row.subject_id,'customer',v_actor,'support.authorization.revoked','{}');
    return jsonb_build_object('id',v_id,'status','revoked');
  else
    raise exception 'SUPPORT_OPERATION_INVALID';
  end if;
end;
$$;
revoke all on function public.app_kombax_support_authorization_mutate_v194(text,jsonb) from public, anon;
grant execute on function public.app_kombax_support_authorization_mutate_v194(text,jsonb) to authenticated;

create or replace function public.app_kombax_support_authorization_claim_v194(
  p_code text,
  p_ticket_ref text default null,
  p_agent_label text default 'KOMBAX AI Support'
) returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_role text := coalesce(current_setting('request.jwt.claim.role',true),'');
  v_hash text := encode(digest(trim(coalesce(p_code,'')),'sha256'),'hex');
  v_row public.kombax_support_authorizations_v194%rowtype;
begin
  if v_role <> 'service_role' then raise exception 'SUPPORT_SERVICE_ROLE_REQUIRED'; end if;
  select * into v_row from public.kombax_support_authorizations_v194
   where code_hash=v_hash and status='active' and expires_at>now()
   for update;
  if not found then raise exception 'SUPPORT_CODE_INVALID_OR_EXPIRED'; end if;
  if v_row.ticket_ref is not null and coalesce(trim(p_ticket_ref),'')<>v_row.ticket_ref then
    raise exception 'SUPPORT_TICKET_MISMATCH';
  end if;
  update public.kombax_support_authorizations_v194
     set status='claimed',claimed_at=now(),claimed_by=left(coalesce(nullif(trim(p_agent_label),''),'KOMBAX AI Support'),120),updated_at=now()
   where id=v_row.id;
  insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,action,detail)
    values(v_row.id,v_row.subject_type,v_row.subject_id,'ai_support','support.authorization.claimed',jsonb_build_object('agent',left(coalesce(p_agent_label,'KOMBAX AI Support'),120),'ticket_ref',p_ticket_ref));
  return jsonb_build_object('authorization_id',v_row.id,'subject_type',v_row.subject_type,'subject_id',v_row.subject_id,'scopes',v_row.scopes,'expires_at',v_row.expires_at,'ticket_ref',v_row.ticket_ref);
end;
$$;
revoke all on function public.app_kombax_support_authorization_claim_v194(text,text,text) from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname='service_role') then
    grant execute on function public.app_kombax_support_authorization_claim_v194(text,text,text) to service_role;
  end if;
end $$;

create or replace function public.app_kombax_support_authorization_validate_v194(
  p_authorization_id uuid,
  p_required_scope text default 'support.read'
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_role text := coalesce(current_setting('request.jwt.claim.role',true),'');
  v_row public.kombax_support_authorizations_v194%rowtype;
begin
  if v_role <> 'service_role' then raise exception 'SUPPORT_SERVICE_ROLE_REQUIRED'; end if;
  select * into v_row from public.kombax_support_authorizations_v194
   where id=p_authorization_id and status='claimed' and expires_at>now() and revoked_at is null;
  if not found then raise exception 'SUPPORT_AUTHORIZATION_INACTIVE'; end if;
  if not (p_required_scope = any(v_row.scopes)) then raise exception 'SUPPORT_SCOPE_FORBIDDEN'; end if;
  return jsonb_build_object('authorization_id',v_row.id,'subject_type',v_row.subject_type,'subject_id',v_row.subject_id,'scopes',v_row.scopes,'expires_at',v_row.expires_at,'ticket_ref',v_row.ticket_ref,'valid',true);
end;
$$;
revoke all on function public.app_kombax_support_authorization_validate_v194(uuid,text) from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname='service_role') then
    grant execute on function public.app_kombax_support_authorization_validate_v194(uuid,text) to service_role;
  end if;
end $$;

comment on table public.kombax_support_authorizations_v194 is 'R26 customer-authorized, time-limited, scoped support grants. Codes are stored only as SHA-256 hashes.';
comment on table public.kombax_support_access_audit_v194 is 'R26 auditable support authorization lifecycle. Existing Owner privileged access remains governed by platform admin/session audit.';

commit;
