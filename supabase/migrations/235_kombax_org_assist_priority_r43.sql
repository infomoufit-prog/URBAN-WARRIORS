-- KOMBAX 20.101 R43 · Organizational Assist/Migrations priority and AI spend guard
-- Purpose: expose/authorize AI-assisted support and migration only for organization contexts.
-- Active contexts in this freeze candidate:
--   * Club operational roles: direccion, coordinacion, secretaria, economia
--   * Direct profile: federacion
-- Brand is deliberately NOT enabled in R43; it can be activated later with its own entitlement.

create or replace function kombax_ai_ops.org_assist_access_allowed(p_uid uuid,p_tenant_ref text)
returns boolean
language plpgsql stable security definer set search_path=''
as $$
declare
  v_ref text:=btrim(coalesce(p_tenant_ref,''));
  v_id uuid;
begin
  if p_uid is null or v_ref='' then return false; end if;

  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then return false; end;
    return exists(
      select 1 from public.miembros_club mc
      where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo
        and mc.rol::text in ('direccion','coordinacion','secretaria','economia')
    );
  end if;

  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;
    return exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=v_id and d.perfil_id=p_uid and d.estado='activo' and d.tipo='federacion'
    );
  end if;

  return false;
end;
$$;

revoke all on function kombax_ai_ops.org_assist_access_allowed(uuid,text) from public,anon,authenticated,service_role;

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

  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('ok',false,'reason','ORG_ASSIST_ONLY');
  end if;

  if v_ticket.category<>'MIGRATION' and not exists(
    select 1 from kombax_customer_ops.guided_sessions s
    where s.ticket_id=p_ticket_id and s.user_ref=v_uid and s.status='ACTIVE' and s.expires_at>now()
  ) then
    return jsonb_build_object('ok',false,'reason','ASSIST_CHAT_NOT_ACTIVATED');
  end if;

  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  if v_ticket.category='MIGRATION' then v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id);
  else v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,p_ticket_id); end if;
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
  values(v_ctx.tenant_ref,v_uid,p_ticket_id,(select s.session_id from kombax_customer_ops.guided_sessions s where s.ticket_id=p_ticket_id and s.status='ACTIVE' and s.expires_at>now()),v_ticket.category,v_req)
  returning * into v_turn;
  insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text) values(p_ticket_id,v_uid,v_turn.turn_id,'USER',v_msg);
  update kombax_customer_ops.tickets set status='GUIDED_SESSION',updated_at=now() where ticket_id=p_ticket_id;
  return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',false,'category',v_ticket.category,'turns_remaining',greatest(0,v_max_turns-v_turns-1));
end $$;

revoke all on function public.app_kombax_assist_turn_reserve_v227(text,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) to authenticated;
comment on function public.app_kombax_assist_turn_reserve_v227(text,text,text) is 'R43 organization-only AI gate: Club operational roles and Federation direct profile only; standard Assist still requires an active guided session.';

-- Guard migration upload before any document can enter the AI-assisted migration path.
create or replace function public.app_kombax_migration_file_register_v228(p_ticket_id text,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();v_id uuid;v_path text:=btrim(coalesce(p_storage_path,''));v_name text:=left(btrim(coalesce(p_original_name,'')),255);v_mime text:=lower(btrim(coalesce(p_mime_type,'')));
  v_ticket kombax_customer_ops.tickets%rowtype;v_ctx record;v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;v_settings jsonb;v_case kombax_ai_ops.migration_allowance_cases%rowtype;v_allowance jsonb;
  v_max_docs integer;v_max_mb numeric;v_docs bigint;v_bytes numeric;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MIGRATION' for update;
  if not found then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ticket.tenant_ref) then raise exception 'KOMBAX_ORG_MIGRATION_ONLY' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id);
  if not coalesce((v_allowance->>'available')::boolean,false) then raise exception 'KOMBAX_MIGRATION_ALLOWANCE_EXHAUSTED'; end if;
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;v_settings:=v_ent.migration_allowance;
  v_max_docs:=coalesce((v_settings->>'max_documents_total')::integer,0);v_max_mb:=coalesce((v_settings->>'max_total_mb')::numeric,0);
  select * into strict v_case from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.contextual_case_key='ticket:'||p_ticket_id for update;
  select coalesce(sum(m.documents),0),coalesce(sum(m.size_mb),0) into v_docs,v_bytes from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_case.valid_until;
  if p_size_bytes is null or p_size_bytes<=0 or p_size_bytes>10485760 then raise exception 'KOMBAX_MIGRATION_FILE_SIZE_INVALID'; end if;
  if v_name='' then raise exception 'KOMBAX_MIGRATION_FILE_NAME_INVALID'; end if;
  if v_mime not in ('application/pdf','text/csv','application/csv','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/webp') then raise exception 'KOMBAX_MIGRATION_FILE_TYPE_INVALID'; end if;
  if v_path not like v_uid::text||'/'||p_ticket_id||'/%' then raise exception 'KOMBAX_MIGRATION_FILE_PATH_INVALID'; end if;
  if v_max_docs>0 and v_docs+1>v_max_docs then raise exception 'KOMBAX_MIGRATION_DOCUMENT_LIMIT'; end if;
  if v_max_mb>0 and v_bytes+(p_size_bytes::numeric/1048576)>v_max_mb then raise exception 'KOMBAX_MIGRATION_VOLUME_LIMIT'; end if;
  insert into kombax_customer_ops.migration_files(ticket_id,user_ref,original_name,mime_type,size_bytes,storage_path)
  values(p_ticket_id,v_uid,v_name,v_mime,p_size_bytes,v_path) returning file_id into v_id;
  update kombax_ai_ops.migration_allowance_cases set documents=documents+1,size_mb=size_mb+(p_size_bytes::numeric/1048576),file_types=(select array(select distinct x from unnest(file_types||array[upper(coalesce(nullif(split_part(v_name,'.',-1),''),'FILE'))]) x)),consumed_at=least(consumed_at,now()) where migration_case_id=v_case.migration_case_id;
  return jsonb_build_object('ok',true,'file_id',v_id,'ticket_id',p_ticket_id,'status','STAGED','documents_used',v_docs+1,'documents_max',v_max_docs,'mb_used',round(v_bytes+(p_size_bytes::numeric/1048576),2),'mb_max',v_max_mb);
end $$;

revoke all on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) from public,anon,service_role;
grant execute on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) to authenticated;
comment on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) is 'R43 organization-only migration upload gate.';

notify pgrst,'reload schema';
