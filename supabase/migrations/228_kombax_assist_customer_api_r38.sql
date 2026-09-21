-- KOMBAX 20.101 R38 · Customer-safe Assist chat APIs
create or replace function public.app_kombax_assist_dashboard_v227(p_tenant_ref text default null)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ctx record; v_period kombax_ai_ops.assistance_periods%rowtype;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype; v_settings jsonb;
  v_remaining integer; v_migration_total integer; v_migration_used integer; v_valid_until timestamptz;
  v_docs bigint:=0; v_bytes bigint:=0; v_max_docs integer; v_max_mb numeric;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;
  v_settings:=v_ent.migration_allowance;
  v_remaining:=greatest(0,v_period.allowance_total-v_period.allowance_used);
  v_valid_until:=v_ctx.started_at+((v_settings->>'validity_days')::integer*interval '1 day');
  v_migration_total:=case when now()<v_ctx.started_at+interval '1 month' then (v_settings->>'first_month_cases')::integer else (v_settings->>'cases')::integer end;
  select count(*) into v_migration_used from kombax_ai_ops.migration_allowance_cases m
   where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  select coalesce(sum(m.documents),0),coalesce(sum(m.size_mb*1048576),0) into v_docs,v_bytes
   from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  v_max_docs:=coalesce((v_settings->>'max_documents_total')::integer,0); v_max_mb:=coalesce((v_settings->>'max_total_mb')::numeric,0);
  return jsonb_build_object(
    'plan',v_ctx.plan,
    'assistance',jsonb_build_object('total',v_period.allowance_total,'remaining',v_remaining,'used',v_period.allowance_used,'period_end',v_period.period_end),
    'migration',jsonb_build_object(
      'total',v_migration_total,'remaining',case when now()>v_valid_until then 0 else greatest(0,v_migration_total-v_migration_used) end,'used',v_migration_used,
      'valid_until',v_valid_until,'documents_used',v_docs,'documents_max',v_max_docs,'mb_used',round(v_bytes::numeric/1048576,2),'mb_max',v_max_mb,
      'file_types',v_settings->'file_types','case_continuity',true
    ),
    'message',v_remaining||' de '||v_period.allowance_total||' conversaciones de asistencia disponibles este mes.'
  );
end $$;

create or replace function public.app_kombax_assist_messages_v227(p_ticket_id text,p_limit integer default 80)
returns table(message_id uuid,role text,content_text text,created_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$ begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=auth.uid()) then raise exception 'ticket_not_found' using errcode='P0002'; end if;
  return query select m.message_id,m.role,m.content_text,m.created_at from kombax_customer_ops.assist_chat_messages m
   where m.ticket_id=p_ticket_id and m.user_ref=auth.uid() order by m.created_at asc limit least(120,greatest(1,coalesce(p_limit,80)));
end $$;

create or replace function public.app_kombax_assist_turn_reserve_v227(p_ticket_id text,p_message text,p_client_request_id text)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ticket kombax_customer_ops.tickets%rowtype; v_ctx record; v_period kombax_ai_ops.assistance_periods%rowtype;
  v_policy kombax_ai_ops.assistance_cost_policies%rowtype; v_allowance jsonb; v_turn kombax_ai_ops.assistance_turns%rowtype;
  v_msg text:=left(btrim(coalesce(p_message,'')),4000); v_req text:=left(btrim(coalesce(p_client_request_id,'')),120);
  v_turns integer; v_period_cost numeric:=0; v_case_cost numeric:=0; v_period_cap numeric; v_case_cap numeric; v_max_turns integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if v_msg='' then raise exception 'message_required' using errcode='22023'; end if;
  if v_req='' then raise exception 'client_request_id_required' using errcode='22023'; end if;
  select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid for update;
  if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  if v_ticket.category='MIGRATION' then v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id); else v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,p_ticket_id); end if;
  if not coalesce((v_allowance->>'available')::boolean,false) then return jsonb_build_object('ok',false,'reason',v_allowance->>'reason','allowance',v_allowance); end if;
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  v_period_cap:=case when v_period.first_month_bonus>0 then v_policy.first_month_hard_cost else v_policy.monthly_hard_cost end;
  v_case_cap:=case when v_ticket.category='MIGRATION' then v_policy.migration_case_hard_cost else v_policy.general_case_hard_cost end;
  v_max_turns:=case when v_ticket.category='MIGRATION' then v_policy.max_turns_per_migration_case else v_policy.max_turns_per_general_case end;
  select coalesce(sum(t.estimated_cost),0) into v_period_cost from kombax_ai_ops.assistance_turns t where t.tenant_ref=v_ctx.tenant_ref and t.requested_at>=v_period.period_start and t.requested_at<v_period.period_end and t.status='COMPLETED';
  select coalesce(sum(t.estimated_cost),0),count(*) into v_case_cost,v_turns from kombax_ai_ops.assistance_turns t where t.ticket_id=p_ticket_id and t.status in('RESERVED','COMPLETED');
  if v_period_cost>=v_period_cap then return jsonb_build_object('ok',false,'reason','AI_MONTHLY_ECONOMY_GUARD'); end if;
  if v_case_cost>=v_case_cap then return jsonb_build_object('ok',false,'reason','AI_CASE_ECONOMY_GUARD'); end if;
  if v_turns>=v_max_turns then return jsonb_build_object('ok',false,'reason','CASE_TURN_LIMIT','turns_remaining',0); end if;
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.tenant_ref=v_ctx.tenant_ref and t.client_request_id=v_req;
  if found then return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',true,'category',v_turn.category,'turns_remaining',greatest(0,v_max_turns-v_turns)); end if;
  insert into kombax_ai_ops.assistance_turns(tenant_ref,user_ref,ticket_id,session_id,category,client_request_id)
  values(v_ctx.tenant_ref,v_uid,p_ticket_id,(select s.session_id from kombax_customer_ops.guided_sessions s where s.ticket_id=p_ticket_id),v_ticket.category,v_req)
  returning * into v_turn;
  insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text) values(p_ticket_id,v_uid,v_turn.turn_id,'USER',v_msg);
  update kombax_customer_ops.tickets set status='GUIDED_SESSION',updated_at=now() where ticket_id=p_ticket_id;
  return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',false,'category',v_ticket.category,'turns_remaining',greatest(0,v_max_turns-v_turns-1));
end $$;

create or replace function public.app_kombax_assist_turn_context_v227(p_turn_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_turn kombax_ai_ops.assistance_turns%rowtype; v_ctx record; v_policy kombax_ai_ops.assistance_cost_policies%rowtype; v_out jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id and t.user_ref=auth.uid();
  if not found then raise exception 'turn_not_found' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(auth.uid(),v_turn.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  select jsonb_build_object(
    'turn_id',v_turn.turn_id,'ticket_id',v_turn.ticket_id,'category',v_turn.category,
    'max_output_tokens',v_policy.max_output_tokens,'max_files_per_batch',v_policy.max_files_per_batch,
    'max_visual_files_per_batch',v_policy.max_visual_files_per_batch,'max_batch_mb',v_policy.max_batch_mb,'image_detail',v_policy.image_detail
  ) into v_out;
  return v_out;
end $$;

revoke all on function public.app_kombax_assist_dashboard_v227(text) from public,anon,service_role;
revoke all on function public.app_kombax_assist_messages_v227(text,integer) from public,anon,service_role;
revoke all on function public.app_kombax_assist_turn_reserve_v227(text,text,text) from public,anon,service_role;
revoke all on function public.app_kombax_assist_turn_context_v227(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_assist_dashboard_v227(text) to authenticated;
grant execute on function public.app_kombax_assist_messages_v227(text,integer) to authenticated;
grant execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) to authenticated;
grant execute on function public.app_kombax_assist_turn_context_v227(uuid) to authenticated;
comment on function public.app_kombax_assist_dashboard_v227(text) is 'Customer-safe KOMBAX Assist allowance view. Does not expose models, tokens, cost, or routing.';
notify pgrst,'reload schema';
