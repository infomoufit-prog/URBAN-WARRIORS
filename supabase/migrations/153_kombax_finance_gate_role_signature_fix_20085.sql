-- KOMBAX RC13 build 20085 · Finance pilot gate role signature compatibility
-- Production patch after 148/149: use the existing VARIADIC role function correctly.
begin;

create or replace function public.app_finance_pilot_readiness_v148(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_q jsonb;v_flags jsonb;v_rules int;
  v_last public.finance_qa_shadow_runs;v_prev public.finance_qa_shadow_runs;
  v_ready boolean;v_live boolean;v_blocking int;
begin
  if (select auth.uid()) is null then raise exception 'AUTH_REQUIRED'; end if;
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria','economia')
          or coalesce(public.app_kombax_support_club_v140(p_club_id),false)) then
    raise exception 'FINANCE_ACCESS_DENIED';
  end if;
  v_q:=public.app_finance_v2_qa_status_v146(p_club_id);
  v_flags:=public.app_finance_v2_flags_v143(p_club_id);
  v_blocking:=coalesce((v_q#>>'{anomalies,blocking,total}')::int,0);
  select count(*)::int into v_rules from public.reglas_cobro r where r.club_id=p_club_id and r.activa;
  select * into v_last from public.finance_qa_shadow_runs where club_id=p_club_id and estado='ok' order by creado_en desc limit 1;
  select * into v_prev from public.finance_qa_shadow_runs where club_id=p_club_id and estado='ok' order by creado_en desc offset 1 limit 1;
  v_live:=private.finance_flag_v143(p_club_id,'finance_pilot_live_enabled');
  v_ready:=v_blocking=0
    and coalesce((v_q->>'approved')::boolean,false)
    and v_rules>0
    and v_last.id is not null and v_prev.id is not null
    and v_last.fecha_proceso=v_prev.fecha_proceso and v_last.fingerprint=v_prev.fingerprint
    and coalesce((v_flags->>'finance_v2_enabled')::boolean,false)
    and coalesce((v_flags->>'finance_dashboard_v2_enabled')::boolean,false);
  return jsonb_build_object(
    'ready',v_ready,'live',v_live,'active_rules',v_rules,'qa',v_q,'flags',v_flags,
    'blocking_anomalies',v_blocking,
    'two_equivalent_shadow_runs',v_last.id is not null and v_prev.id is not null
      and v_last.fecha_proceso=v_prev.fecha_proceso and v_last.fingerprint=v_prev.fingerprint,
    'last_shadow_fingerprint',v_last.fingerprint,'last_shadow_date',v_last.fecha_proceso,
    'requirements',jsonb_build_object(
      'finance_v2',coalesce((v_flags->>'finance_v2_enabled')::boolean,false),
      'dashboard_v2',coalesce((v_flags->>'finance_dashboard_v2_enabled')::boolean,false),
      'qa_approved',coalesce((v_q->>'approved')::boolean,false),
      'blocking_anomalies_zero',v_blocking=0,
      'active_rule',v_rules>0)
  );
end;
$$;
revoke all on function public.app_finance_pilot_readiness_v148(uuid) from public,anon;
grant execute on function public.app_finance_pilot_readiness_v148(uuid) to authenticated;

create or replace function public.app_mutate_v160_pre_security_149(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;
  v_ready jsonb;v_data jsonb;v_result jsonb;v_existing public.app_mutation_requests;v_backend_version text;
begin
  if p_operation not in ('finance.pilot.activar','finance.pilot.pausar') then
    return public.app_mutate_v160_pre_finance_final_148(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=coalesce(nullif(v_payload->>'club_id','')::uuid,nullif(current_setting('request.jwt.claim.club_id',true),'')::uuid);
  exception when others then v_club:=null; end;
  if v_club is null then raise exception 'CLUB_REQUIRED'; end if;
  if not (public.tiene_rol_club(v_club,'direccion') or coalesce(public.app_kombax_support_club_v140(v_club),false)) then
    raise exception 'DIRECCION_REQUIRED';
  end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
  end if;
  if p_operation='finance.pilot.activar' then
    if upper(btrim(coalesce(v_payload->>'confirmacion',''))) <> 'ACTIVAR RECURRENCIA' then raise exception 'FINANCE_PILOT_CONFIRMATION_REQUIRED'; end if;
    v_ready:=public.app_finance_pilot_readiness_v148(v_club);
    if coalesce((v_ready->>'ready')::boolean,false) is not true then raise exception 'FINANCE_PILOT_NOT_READY'; end if;
    insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
      values(v_club,'finance_recurring_enabled','true'::jsonb,'Recurrencia Finance Premium','direccion',now(),v_uid)
      on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now(),actualizado_por=v_uid;
    insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
      values(v_club,'finance_pilot_live_enabled','true'::jsonb,'Gate final de recurrencia real Finance Premium','direccion',now(),v_uid)
      on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now(),actualizado_por=v_uid;
    v_data:=jsonb_build_object('live',true,'recurring',true,'activated_at',now(),'readiness',v_ready);
  else
    update public.config_club set valor='false'::jsonb,actualizado_en=now(),actualizado_por=v_uid
      where club_id=v_club and clave in ('finance_pilot_live_enabled','finance_recurring_enabled');
    v_data:=jsonb_build_object('live',false,'recurring',false,'paused_at',now());
  end if;
  select backend_version into v_backend_version from public.app_runtime_meta where singleton=true;
  v_result:=jsonb_build_object('ok',true,'backend_version',coalesce(v_backend_version,'1.6.0'),'operation',p_operation,'request_id',p_request_id,'data',v_data);
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end;
$$;
revoke all on function public.app_mutate_v160_pre_security_149(text,jsonb,uuid) from public,anon,authenticated;

commit;
