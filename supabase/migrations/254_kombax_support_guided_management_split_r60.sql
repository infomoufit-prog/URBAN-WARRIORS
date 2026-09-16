-- KOMBAX R60 final pilot · Support guided chat + Management Assist split
-- Corrective/additive migration after 253.
-- Goals:
--   * Preserve the historical KOMBAX Support guided-chat gate and human-review path.
--   * Keep KOMBAX Assist MANAGEMENT as a new self-service management line.
--   * Keep Migrations as its own direct specialized line.
--   * Separate MANAGEMENT monthly conversation counters from guided Support counters.
--   * Keep one global AI economy guard per tenant while exposing no token/cost internals.
--   * Split history deletion modes so clearing Management Assist never deletes Support cases.

create or replace function kombax_ai_ops.reserve_management_for_ticket(p_uid uuid,p_ticket_id text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_ctx record;
  v_period kombax_ai_ops.assistance_periods%rowtype;
  v_existing kombax_ai_ops.assistance_cases%rowtype;
  v_used integer:=0;
  v_key text;
begin
  select * into v_ticket
  from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=p_uid and t.category='MANAGEMENT'
  for update;
  if not found then raise exception 'management_ticket_not_found' using errcode='P0002'; end if;

  if not kombax_ai_ops.org_assist_access_allowed(p_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('available',false,'consumed',false,'reason','ORG_ASSIST_ONLY');
  end if;

  select * into v_ctx from kombax_ai_ops.resolve_context(p_uid,v_ticket.tenant_ref);
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  select * into v_period from kombax_ai_ops.assistance_periods p where p.period_id=v_period.period_id for update;
  v_key:='management:'||p_ticket_id||':'||v_period.period_start::text;

  select * into v_existing
  from kombax_ai_ops.assistance_cases c
  where c.tenant_ref=v_ctx.tenant_ref
    and c.period_id=v_period.period_id
    and (c.idempotency_key=v_key or c.contextual_case_key='management-ticket:'||p_ticket_id)
  limit 1;
  if found then
    select count(*) into v_used
    from kombax_ai_ops.assistance_cases c
    where c.tenant_ref=v_ctx.tenant_ref and c.period_id=v_period.period_id
      and c.channel='CHAT' and c.contextual_case_key like 'management-ticket:%';
    return jsonb_build_object(
      'available',true,'consumed',false,'reason','EXISTING_MANAGEMENT_CASE',
      'allowance_total',v_period.allowance_total,
      'allowance_remaining',greatest(0,v_period.allowance_total-v_used),
      'period_end',v_period.period_end
    );
  end if;

  select count(*) into v_used
  from kombax_ai_ops.assistance_cases c
  where c.tenant_ref=v_ctx.tenant_ref and c.period_id=v_period.period_id
    and c.channel='CHAT' and c.contextual_case_key like 'management-ticket:%';

  if v_used>=v_period.allowance_total then
    return jsonb_build_object(
      'available',false,'consumed',false,'reason','MONTHLY_ALLOWANCE_EXHAUSTED',
      'allowance_total',v_period.allowance_total,'allowance_remaining',0,'period_end',v_period.period_end
    );
  end if;

  insert into kombax_ai_ops.assistance_cases(
    period_id,tenant_ref,user_ref,contextual_case_key,ticket_id,channel,idempotency_key
  ) values(
    v_period.period_id,v_ctx.tenant_ref,p_uid,'management-ticket:'||p_ticket_id,p_ticket_id,'CHAT',v_key
  );

  v_used:=v_used+1;
  return jsonb_build_object(
    'available',true,'consumed',true,'reason','NEW_MANAGEMENT_CASE',
    'allowance_total',v_period.allowance_total,
    'allowance_remaining',greatest(0,v_period.allowance_total-v_used),
    'period_end',v_period.period_end
  );
end;
$function$;

revoke all on function kombax_ai_ops.reserve_management_for_ticket(uuid,text) from public,anon,authenticated,service_role;

create or replace function public.app_kombax_assist_turn_reserve_v227(p_ticket_id text,p_message text,p_client_request_id text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_ctx record;
  v_period kombax_ai_ops.assistance_periods%rowtype;
  v_policy kombax_ai_ops.assistance_cost_policies%rowtype;
  v_allowance jsonb;
  v_turn kombax_ai_ops.assistance_turns%rowtype;
  v_msg text:=left(btrim(coalesce(p_message,'')),4000);
  v_req text:=left(btrim(coalesce(p_client_request_id,'')),120);
  v_turns integer;
  v_period_cost numeric:=0;
  v_case_cost numeric:=0;
  v_period_cap numeric;
  v_case_cap numeric;
  v_max_turns integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if v_msg='' then raise exception 'message_required' using errcode='22023'; end if;
  if v_req='' then raise exception 'client_request_id_required' using errcode='22023'; end if;

  select * into v_ticket
  from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=v_uid
  for update;
  if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;

  -- MANAGEMENT is the new self-service management line and requires an authorized org identity.
  if v_ticket.category='MANAGEMENT' and not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('ok',false,'reason','ORG_ASSIST_ONLY');
  end if;

  -- MIGRATION is direct but remains restricted to Club/Federation.
  if v_ticket.category='MIGRATION' and not kombax_ai_ops.migration_access_allowed(v_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('ok',false,'reason','MIGRATION_ORG_ACCESS_REQUIRED');
  end if;

  -- Every historical/support category keeps the R38 support-side activation gate.
  if v_ticket.category not in ('MIGRATION','MANAGEMENT') and not exists(
    select 1 from kombax_customer_ops.guided_sessions s
    where s.ticket_id=p_ticket_id and s.user_ref=v_uid and s.status='ACTIVE' and s.expires_at>now()
  ) then
    return jsonb_build_object('ok',false,'reason','ASSIST_CHAT_NOT_ACTIVATED');
  end if;

  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;

  if v_ticket.category='MIGRATION' then
    v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id);
  elsif v_ticket.category='MANAGEMENT' then
    v_allowance:=kombax_ai_ops.reserve_management_for_ticket(v_uid,p_ticket_id);
  else
    v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,p_ticket_id);
  end if;
  if not coalesce((v_allowance->>'available')::boolean,false) then
    return jsonb_build_object('ok',false,'reason',v_allowance->>'reason','allowance',v_allowance);
  end if;

  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  v_period_cap:=case when v_period.first_month_bonus>0 then v_policy.first_month_hard_cost else v_policy.monthly_hard_cost end;
  v_case_cap:=case when v_ticket.category='MIGRATION' then v_policy.migration_case_hard_cost else v_policy.general_case_hard_cost end;
  v_max_turns:=case when v_ticket.category='MIGRATION' then v_policy.max_turns_per_migration_case else v_policy.max_turns_per_general_case end;

  -- Cost guard remains global across the three AI lines so an unexpected usage spike cannot run away.
  select coalesce(sum(t.estimated_cost),0) into v_period_cost
  from kombax_ai_ops.assistance_turns t
  where t.tenant_ref=v_ctx.tenant_ref
    and t.requested_at>=v_period.period_start and t.requested_at<v_period.period_end
    and t.status='COMPLETED';
  select coalesce(sum(t.estimated_cost),0),count(*) into v_case_cost,v_turns
  from kombax_ai_ops.assistance_turns t
  where t.ticket_id=p_ticket_id and t.status in('RESERVED','COMPLETED');

  if v_period_cost>=v_period_cap then return jsonb_build_object('ok',false,'reason','AI_MONTHLY_ECONOMY_GUARD'); end if;
  if v_case_cost>=v_case_cap then return jsonb_build_object('ok',false,'reason','AI_CASE_ECONOMY_GUARD'); end if;
  if v_turns>=v_max_turns then return jsonb_build_object('ok',false,'reason','CASE_TURN_LIMIT','turns_remaining',0); end if;

  select * into v_turn
  from kombax_ai_ops.assistance_turns t
  where t.tenant_ref=v_ctx.tenant_ref and t.client_request_id=v_req;
  if found then
    return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',true,'category',v_turn.category,'turns_remaining',greatest(0,v_max_turns-v_turns),'allowance',v_allowance);
  end if;

  insert into kombax_ai_ops.assistance_turns(tenant_ref,user_ref,ticket_id,session_id,category,client_request_id)
  values(
    v_ctx.tenant_ref,v_uid,p_ticket_id,
    case when v_ticket.category in ('MIGRATION','MANAGEMENT') then null else (
      select s.session_id from kombax_customer_ops.guided_sessions s
      where s.ticket_id=p_ticket_id and s.status='ACTIVE' and s.expires_at>now()
    ) end,
    v_ticket.category,v_req
  ) returning * into v_turn;

  insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text)
  values(p_ticket_id,v_uid,v_turn.turn_id,'USER',v_msg);

  -- Preserve the support session status. MANAGEMENT/MIGRATION use the existing ticket state machine without implying human activation.
  if v_ticket.category not in ('MIGRATION','MANAGEMENT') then
    update kombax_customer_ops.tickets set status='GUIDED_SESSION',updated_at=now() where ticket_id=p_ticket_id;
  else
    update kombax_customer_ops.tickets set updated_at=now() where ticket_id=p_ticket_id;
  end if;

  return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',false,'category',v_ticket.category,'turns_remaining',greatest(0,v_max_turns-v_turns-1),'allowance',v_allowance);
end;
$function$;

revoke all on function public.app_kombax_assist_turn_reserve_v227(text,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) to authenticated;
comment on function public.app_kombax_assist_turn_reserve_v227(text,text,text)
is 'R60 final pilot: Support categories require an active support-side guided session; MANAGEMENT and MIGRATION are separate direct lines with independent case allowances.';

create or replace function public.app_kombax_assist_dashboard_v227(p_tenant_ref text default null::text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_period kombax_ai_ops.assistance_periods%rowtype;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;
  v_policy kombax_ai_ops.assistance_cost_policies%rowtype;
  v_settings jsonb;
  v_management_used integer:=0;
  v_management_remaining integer:=0;
  v_migration_total integer;
  v_migration_used integer;
  v_valid_until timestamptz;
  v_docs bigint:=0;
  v_bytes bigint:=0;
  v_max_docs integer;
  v_max_mb numeric;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then
    raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501';
  end if;

  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;

  select count(*) into v_management_used
  from kombax_ai_ops.assistance_cases c
  where c.tenant_ref=v_ctx.tenant_ref and c.period_id=v_period.period_id
    and c.channel='CHAT' and c.contextual_case_key like 'management-ticket:%';
  v_management_remaining:=greatest(0,v_period.allowance_total-v_management_used);

  v_settings:=v_ent.migration_allowance;
  v_valid_until:=v_ctx.started_at+((v_settings->>'validity_days')::integer*interval '1 day');
  v_migration_total:=case when now()<v_ctx.started_at+interval '1 month' then (v_settings->>'first_month_cases')::integer else (v_settings->>'cases')::integer end;
  select count(*) into v_migration_used
  from kombax_ai_ops.migration_allowance_cases m
  where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  select coalesce(sum(m.documents),0),coalesce(sum(m.size_mb*1048576),0) into v_docs,v_bytes
  from kombax_ai_ops.migration_allowance_cases m
  where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  v_max_docs:=coalesce((v_settings->>'max_documents_total')::integer,0);
  v_max_mb:=coalesce((v_settings->>'max_total_mb')::numeric,0);

  return jsonb_build_object(
    'plan',v_ctx.plan,
    'assistance',jsonb_build_object(
      'total',v_period.allowance_total,
      'remaining',v_management_remaining,
      'used',v_management_used,
      'period_end',v_period.period_end,
      'messages_per_conversation',v_policy.max_turns_per_general_case
    ),
    'migration',jsonb_build_object(
      'total',v_migration_total,
      'remaining',case when now()>v_valid_until then 0 else greatest(0,v_migration_total-v_migration_used) end,
      'used',v_migration_used,
      'valid_until',v_valid_until,
      'documents_used',v_docs,
      'documents_max',v_max_docs,
      'mb_used',round(v_bytes::numeric/1048576,2),
      'mb_max',v_max_mb,
      'file_types',v_settings->'file_types',
      'case_continuity',true,
      'messages_per_conversation',v_policy.max_turns_per_migration_case
    ),
    'support',jsonb_build_object(
      'guided_chat_requires_activation',true,
      'human_review_available',true,
      'messages_per_guided_conversation',v_policy.max_turns_per_general_case
    ),
    'message',v_management_remaining||' de '||v_period.allowance_total||' conversaciones de KOMBAX Assist disponibles este mes · '||v_policy.max_turns_per_general_case||' mensajes por conversación.'
  );
end;
$function$;

revoke all on function public.app_kombax_assist_dashboard_v227(text) from public,anon,service_role;
grant execute on function public.app_kombax_assist_dashboard_v227(text) to authenticated;

create or replace function public.app_kombax_support_guided_status_r60(p_ticket_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_session kombax_customer_ops.guided_sessions%rowtype;
  v_ctx record;
  v_policy kombax_ai_ops.assistance_cost_policies%rowtype;
  v_turns integer:=0;
  v_active boolean:=false;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_ticket
  from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category not in ('MIGRATION','MANAGEMENT');
  if not found then raise exception 'support_ticket_not_found' using errcode='P0002'; end if;

  select * into v_session
  from kombax_customer_ops.guided_sessions s
  where s.ticket_id=p_ticket_id and s.user_ref=v_uid and s.status='ACTIVE' and s.expires_at>now()
  order by s.started_at desc limit 1;
  v_active:=found;

  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  select count(*) into v_turns
  from kombax_ai_ops.assistance_turns t
  where t.ticket_id=p_ticket_id and t.status in ('RESERVED','COMPLETED');

  return jsonb_build_object(
    'ticket_id',p_ticket_id,
    'active',v_active,
    'expires_at',case when v_active then v_session.expires_at else null end,
    'messages_used',v_turns,
    'messages_per_conversation',v_policy.max_turns_per_general_case,
    'messages_remaining',greatest(0,v_policy.max_turns_per_general_case-v_turns),
    'human_review_available',true,
    'activation_owner','KOMBAX_SUPPORT'
  );
end;
$function$;

revoke all on function public.app_kombax_support_guided_status_r60(text) from public,anon,service_role;
grant execute on function public.app_kombax_support_guided_status_r60(text) to authenticated;
comment on function public.app_kombax_support_guided_status_r60(text)
is 'Customer-safe status for the formal Support guided-chat line. Activation remains controlled by KOMBAX Support.';

-- Split content-deletion targeting. Legacy `assist` remains accepted for backwards compatibility.
create or replace function public.app_kombax_customer_history_delete_plan_r60(
  p_ticket_id text default null,
  p_mode text default null,
  p_tenant_ref text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_mode text:=lower(btrim(coalesce(p_mode,'')));
  v_ticket_ids text[]:='{}'::text[];
  v_paths text[]:='{}'::text[];
  v_count integer:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if v_mode not in ('','assist','management','support','migration') then raise exception 'KOMBAX_HISTORY_DELETE_MODE_INVALID'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then
    raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501';
  end if;

  select coalesce(array_agg(t.ticket_id order by t.updated_at desc),'{}'::text[]) into v_ticket_ids
  from kombax_customer_ops.tickets t
  where t.user_ref=v_uid
    and t.tenant_ref=v_ctx.tenant_ref
    and (p_ticket_id is null or t.ticket_id=p_ticket_id)
    and (
      v_mode=''
      or (v_mode='migration' and t.category='MIGRATION')
      or (v_mode='management' and t.category='MANAGEMENT')
      or (v_mode='support' and t.category not in ('MIGRATION','MANAGEMENT'))
      or (v_mode='assist' and t.category<>'MIGRATION')
    );

  v_count:=coalesce(cardinality(v_ticket_ids),0);
  if v_count=0 then
    return jsonb_build_object('ok',true,'tenant_ref',v_ctx.tenant_ref,'ticket_ids','[]'::jsonb,'storage_paths','[]'::jsonb,'tickets',0,'mode',coalesce(nullif(v_mode,''),'mixed'));
  end if;

  select coalesce(array_agg(f.storage_path order by f.created_at),'{}'::text[]) into v_paths
  from kombax_customer_ops.migration_files f
  where f.user_ref=v_uid and f.ticket_id=any(v_ticket_ids);

  return jsonb_build_object(
    'ok',true,'tenant_ref',v_ctx.tenant_ref,'ticket_ids',to_jsonb(v_ticket_ids),
    'storage_paths',to_jsonb(v_paths),'tickets',v_count,'mode',coalesce(nullif(v_mode,''),'mixed')
  );
end;
$function$;

revoke all on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) to authenticated;

notify pgrst,'reload schema';
