-- R103: legacy allowances continue to count in shadow; credits control Assist and Migrations.
begin;
update kombax_ai_ops.assistance_cost_policies set
  max_turns_per_general_case=12,max_turns_per_migration_case=12,
  monthly_hard_cost=case plan when 'CLUB_BASIC' then 1.25 when 'CLUB_PREMIUM' then 2.50 else 5.00 end,
  first_month_hard_cost=case plan when 'CLUB_BASIC' then 5.00 when 'CLUB_PREMIUM' then 5.00 else 10.00 end,
  updated_at=now();
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
  v_pilot boolean:=false;
  v_platform_cost numeric:=0;
  v_platform_cap numeric:=18;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if v_msg='' then raise exception 'message_required' using errcode='22023'; end if;
  if v_req='' then raise exception 'client_request_id_required' using errcode='22023'; end if;

  select * into v_ticket
  from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=v_uid
  for update;
  if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;

  -- Unverified trials only accept curated, generic demo questions. No personal data reaches the AI transcript.
  if kombax_commercial.trial_safe_r97(v_ticket.tenant_ref) and exists (
    select 1 from kombax_commercial.trial_entities_r97 tr
    where v_ticket.tenant_ref='club:'||tr.club_id::text and tr.ends_at<=now()
  ) then return jsonb_build_object('ok',false,'reason','TRIAL_ENDED'); end if;
  if kombax_commercial.trial_safe_r97(v_ticket.tenant_ref) and v_msg not in (
    'Resume las funciones principales de KOMBAX para un club de demostración.',
    '¿Cómo puedo organizar grupos y horarios en KOMBAX?',
    'Explícame cómo funcionan las cuotas de demostración.',
    '¿Cómo reviso una migración de ejemplo antes de confirmar?'
  ) then
    return jsonb_build_object('ok',false,'reason','TRIAL_DEMO_ONLY');
  end if;
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
  select exists(select 1 from kombax_commercial.pilot_entities_r97 where tenant_ref=v_ctx.tenant_ref) and kombax_commercial.program_phase_r97()<>'PREPARATION' into v_pilot;
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;

  if v_ticket.category='MIGRATION' then
    v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id);
  elsif v_ticket.category='MANAGEMENT' then
    v_allowance:=kombax_ai_ops.reserve_management_for_ticket(v_uid,p_ticket_id);
  else
    v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,p_ticket_id);
  end if;
  if v_ticket.category not in ('MIGRATION','MANAGEMENT') and not v_pilot and not coalesce((v_allowance->>'available')::boolean,false) then
    return jsonb_build_object('ok',false,'reason',v_allowance->>'reason','allowance',v_allowance);
  end if;

  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  v_period_cap:=case when v_period.first_month_bonus>0 then v_policy.first_month_hard_cost else v_policy.monthly_hard_cost end;
  v_case_cap:=case when v_ticket.category='MIGRATION' then v_policy.migration_case_hard_cost else v_policy.general_case_hard_cost end;
  v_max_turns:=case when v_ticket.category in ('MIGRATION','MANAGEMENT') then 12 when v_pilot then 12 when v_ticket.category='MIGRATION' then v_policy.max_turns_per_migration_case else v_policy.max_turns_per_general_case end;

  -- Cost guard remains global across the three AI lines so an unexpected usage spike cannot run away.
  select coalesce(sum(t.estimated_cost),0) into v_period_cost
  from kombax_ai_ops.assistance_turns t
  where t.tenant_ref=v_ctx.tenant_ref
    and t.requested_at>=v_period.period_start and t.requested_at<v_period.period_end
    and t.status='COMPLETED';
  select coalesce(sum(t.estimated_cost),0),count(*) into v_case_cost,v_turns
  from kombax_ai_ops.assistance_turns t
  where t.ticket_id=p_ticket_id and t.status in('RESERVED','COMPLETED');

  if v_pilot then
    select coalesce(sum(t.estimated_cost),0) into v_platform_cost from kombax_ai_ops.assistance_turns t where t.status='COMPLETED' and t.requested_at>=date_trunc('month',now()) and t.requested_at<date_trunc('month',now())+interval '1 month';
    select coalesce((value::text)::numeric,18) into v_platform_cap from kombax_commercial.runtime_config_r64 where config_key='ai_platform_monthly_cost_cap';
    if v_platform_cost>=v_platform_cap then return jsonb_build_object('ok',false,'reason','AI_PLATFORM_BUDGET_GUARD'); end if;
  else
    if v_period_cost>=v_period_cap then return jsonb_build_object('ok',false,'reason','AI_MONTHLY_ECONOMY_GUARD'); end if;
    if v_case_cost>=v_case_cap then return jsonb_build_object('ok',false,'reason','AI_CASE_ECONOMY_GUARD'); end if;
  end if;
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
commit;