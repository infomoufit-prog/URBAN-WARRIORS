-- KOMBAX 20.110 R60 · Migrations guide + customer history deletion hardening
-- Additive over R59. Does not deploy automatically.
-- Goals:
--  * Guide access is organization-only: Club operational roles or Federation direct profile.
--  * Deleting Assist/Migrations history removes content + staged Storage through the R60 Edge function.
--  * Usage/allowance/cost ledgers remain, so deleting content never restores quota.

begin;

-- -----------------------------------------------------------------------------
-- 1) Preserve usage ledger while allowing customer content/tickets to be deleted.
-- -----------------------------------------------------------------------------
alter table kombax_ai_ops.assistance_turns
  add column if not exists content_deleted_at timestamptz;

alter table kombax_ai_ops.assistance_turns
  drop constraint if exists assistance_turns_ticket_id_fkey;

alter table kombax_ai_ops.assistance_turns
  alter column ticket_id drop not null;

alter table kombax_ai_ops.assistance_turns
  add constraint assistance_turns_ticket_id_fkey
  foreign key(ticket_id) references kombax_customer_ops.tickets(ticket_id) on delete set null;

comment on column kombax_ai_ops.assistance_turns.content_deleted_at is
'R60: customer-visible content was deleted. Metering fields remain to preserve allowance/cost accounting; deleting history never restores quota.';

create table if not exists kombax_ai_ops.customer_content_deletions(
  deletion_id uuid primary key default gen_random_uuid(),
  tenant_ref text not null,
  user_ref uuid not null references auth.users(id) on delete restrict,
  scope text not null check(scope in('ASSIST','MIGRATION','MIXED')),
  tickets_deleted integer not null default 0 check(tickets_deleted>=0),
  chat_messages_deleted integer not null default 0 check(chat_messages_deleted>=0),
  migration_files_deleted integer not null default 0 check(migration_files_deleted>=0),
  migration_bytes_deleted bigint not null default 0 check(migration_bytes_deleted>=0),
  deleted_at timestamptz not null default now()
);
create index if not exists customer_content_deletions_tenant_time_idx
  on kombax_ai_ops.customer_content_deletions(tenant_ref,deleted_at desc);
create index if not exists customer_content_deletions_user_time_idx
  on kombax_ai_ops.customer_content_deletions(user_ref,deleted_at desc);
alter table kombax_ai_ops.customer_content_deletions enable row level security;
revoke all on kombax_ai_ops.customer_content_deletions from public,anon,authenticated,service_role;

-- -----------------------------------------------------------------------------
-- 2) Exact organization gate for the migration guide.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_org_guide_access_r60(p_tenant_ref text default null)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_allowed boolean:=false;
  v_kind text:=null;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  v_allowed:=kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref);
  if v_allowed then
    v_kind:=case when v_ctx.tenant_ref like 'club:%' then 'club' when v_ctx.tenant_ref like 'profile:%' then 'federacion' else null end;
  end if;
  return jsonb_build_object('allowed',v_allowed,'tenant_ref',v_ctx.tenant_ref,'organization_type',v_kind,'guide','KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf');
end $$;
revoke all on function public.app_kombax_org_guide_access_r60(text) from public,anon,service_role;
grant execute on function public.app_kombax_org_guide_access_r60(text) to authenticated;
comment on function public.app_kombax_org_guide_access_r60(text) is
'R60 organization-only guide gate. Club operational roles and Federation direct profile only; Member/Competitor/Brand/Professional/Media/Spectator are denied.';

-- -----------------------------------------------------------------------------
-- 3) Tenant-scoped ticket listing for Club/Federation. Prevents identity bleed
--    when the same global account owns more than one organization profile.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_customer_ops_tickets_r60(
  p_tenant_ref text default null,
  p_limit integer default 50
)
returns table(ticket_id text,status text,category text,priority text,module text,subject_redacted text,opened_at timestamptz,updated_at timestamptz,tenant_ref text)
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then
    raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501';
  end if;
  return query
  select t.ticket_id,t.status,t.category,t.priority,t.module,t.subject_redacted,t.opened_at,t.updated_at,t.tenant_ref
  from kombax_customer_ops.tickets t
  where t.user_ref=v_uid and t.tenant_ref=v_ctx.tenant_ref
  order by t.updated_at desc
  limit least(100,greatest(1,coalesce(p_limit,50)));
end $$;
revoke all on function public.app_kombax_customer_ops_tickets_r60(text,integer) from public,anon,service_role;
grant execute on function public.app_kombax_customer_ops_tickets_r60(text,integer) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) User-side deletion plan. Returns only owned ticket IDs and Storage paths.
--    Edge function removes Storage first, then calls the service-only finalizer.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_customer_history_delete_plan_r60(
  p_ticket_id text default null,
  p_mode text default null,
  p_tenant_ref text default null
)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_mode text:=lower(btrim(coalesce(p_mode,'')));
  v_ticket_ids text[]:='{}'::text[];
  v_paths text[]:='{}'::text[];
  v_count integer:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if v_mode not in ('','assist','migration') then raise exception 'KOMBAX_HISTORY_DELETE_MODE_INVALID'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then
    raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501';
  end if;

  select coalesce(array_agg(t.ticket_id order by t.updated_at desc),'{}'::text[])
    into v_ticket_ids
  from kombax_customer_ops.tickets t
  where t.user_ref=v_uid
    and t.tenant_ref=v_ctx.tenant_ref
    and (p_ticket_id is null or t.ticket_id=p_ticket_id)
    and (v_mode='' or (v_mode='migration' and t.category='MIGRATION') or (v_mode='assist' and t.category<>'MIGRATION'));

  v_count:=coalesce(cardinality(v_ticket_ids),0);
  if v_count=0 then
    return jsonb_build_object('ok',true,'tenant_ref',v_ctx.tenant_ref,'ticket_ids','[]'::jsonb,'storage_paths','[]'::jsonb,'tickets',0,'mode',coalesce(nullif(v_mode,''),'mixed'));
  end if;

  select coalesce(array_agg(f.storage_path order by f.created_at),'{}'::text[])
    into v_paths
  from kombax_customer_ops.migration_files f
  where f.user_ref=v_uid and f.ticket_id=any(v_ticket_ids);

  return jsonb_build_object(
    'ok',true,
    'tenant_ref',v_ctx.tenant_ref,
    'ticket_ids',to_jsonb(v_ticket_ids),
    'storage_paths',to_jsonb(v_paths),
    'tickets',v_count,
    'mode',coalesce(nullif(v_mode,''),'mixed')
  );
end $$;
revoke all on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Service-only finalizer. Content goes away; metering remains detached.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_customer_history_delete_finalize_r60(
  p_user_id uuid,
  p_ticket_ids text[]
)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_ids text[]:=coalesce(p_ticket_ids,'{}'::text[]);
  v_requested integer:=coalesce(cardinality(v_ids),0);
  v_owned integer:=0;
  v_messages integer:=0;
  v_files integer:=0;
  v_bytes bigint:=0;
  v_tickets integer:=0;
  v_scope text:='MIXED';
  v_tenant_ref text:=null;
  v_tenant_count integer:=0;
begin
  if p_user_id is null then raise exception 'KOMBAX_HISTORY_DELETE_USER_REQUIRED'; end if;
  if v_requested=0 then return jsonb_build_object('ok',true,'tickets_deleted',0,'chat_messages_deleted',0,'migration_files_deleted',0,'migration_bytes_deleted',0); end if;
  if v_requested>100 then raise exception 'KOMBAX_HISTORY_DELETE_BATCH_TOO_LARGE'; end if;

  select count(*),min(t.tenant_ref),count(distinct t.tenant_ref)
    into v_owned,v_tenant_ref,v_tenant_count
  from kombax_customer_ops.tickets t
  where t.user_ref=p_user_id and t.ticket_id=any(v_ids);
  if v_owned<>v_requested then raise exception 'KOMBAX_HISTORY_DELETE_OWNERSHIP_MISMATCH' using errcode='42501'; end if;
  if v_tenant_count<>1 or v_tenant_ref is null then raise exception 'KOMBAX_HISTORY_DELETE_TENANT_MISMATCH' using errcode='42501'; end if;

  select count(*) into v_messages from kombax_customer_ops.assist_chat_messages m where m.user_ref=p_user_id and m.ticket_id=any(v_ids);
  select count(*),coalesce(sum(f.size_bytes),0) into v_files,v_bytes from kombax_customer_ops.migration_files f where f.user_ref=p_user_id and f.ticket_id=any(v_ids);
  select case when bool_and(t.category='MIGRATION') then 'MIGRATION' when bool_and(t.category<>'MIGRATION') then 'ASSIST' else 'MIXED' end
    into v_scope from kombax_customer_ops.tickets t where t.user_ref=p_user_id and t.ticket_id=any(v_ids);

  -- Delete content/derived data first.
  delete from kombax_customer_ops.migration_file_analysis a where a.user_ref=p_user_id and a.ticket_id=any(v_ids);
  delete from kombax_customer_ops.assist_chat_messages m where m.user_ref=p_user_id and m.ticket_id=any(v_ids);
  delete from kombax_customer_ops.migration_files f where f.user_ref=p_user_id and f.ticket_id=any(v_ids);
  delete from kombax_customer_ops.email_outbox o where o.ticket_id=any(v_ids);
  delete from kombax_customer_ops.ticket_messages m where m.ticket_id=any(v_ids);

  -- Preserve metering/cost/allowance rows, but sever content references.
  update kombax_ai_ops.assistance_turns t
    set session_id=null,ticket_id=null,content_deleted_at=coalesce(content_deleted_at,now())
    where t.user_ref=p_user_id and t.ticket_id=any(v_ids);

  delete from kombax_customer_ops.guided_sessions s where s.user_ref=p_user_id and s.ticket_id=any(v_ids);
  delete from kombax_customer_ops.ticket_events e where e.ticket_id=any(v_ids);
  delete from kombax_customer_ops.tickets t where t.user_ref=p_user_id and t.ticket_id=any(v_ids);
  get diagnostics v_tickets=row_count;

  -- Minimal accounting/security audit only. Capture the exact tenant before deleting
  -- customer content; retain no filenames, messages, subjects or ticket IDs.
  insert into kombax_ai_ops.customer_content_deletions(
    tenant_ref,user_ref,scope,tickets_deleted,chat_messages_deleted,migration_files_deleted,migration_bytes_deleted
  ) values(
    v_tenant_ref,p_user_id,coalesce(v_scope,'MIXED'),v_tickets,v_messages,v_files,v_bytes
  );

  return jsonb_build_object('ok',true,'tickets_deleted',v_tickets,'chat_messages_deleted',v_messages,'migration_files_deleted',v_files,'migration_bytes_deleted',v_bytes,'allowance_preserved',true);
end $$;
revoke all on function public.app_kombax_customer_history_delete_finalize_r60(uuid,text[]) from public,anon,authenticated;
grant execute on function public.app_kombax_customer_history_delete_finalize_r60(uuid,text[]) to service_role;
comment on function public.app_kombax_customer_history_delete_finalize_r60(uuid,text[]) is
'R60 service-only finalizer. Deletes customer content/tickets after Storage cleanup while preserving assistance_periods, migration_allowance_cases, support metrics and detached assistance_turns.';

notify pgrst,'reload schema';
commit;
