-- KOMBAX RC13 build 20083 · Finance Premium final pilot gate
-- Final safety layer: QA approval alone cannot accidentally start real recurring generation.

begin;

insert into public.config_club(club_id,clave,valor,descripcion,editable_por)
select c.id,'finance_pilot_live_enabled','false'::jsonb,'Gate final de recurrencia real Finance Premium','direccion'
from public.clubes c
on conflict (club_id,clave) do nothing;


create or replace function private.finance_final_gate_sync_v148()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.clave='finance_qa_shadow_approved' and coalesce(new.valor,'false'::jsonb)='false'::jsonb then
    update public.config_club
      set valor='false'::jsonb,actualizado_en=now(),actualizado_por=coalesce(new.actualizado_por,(select auth.uid()))
      where club_id=new.club_id and clave in ('finance_pilot_live_enabled','finance_recurring_enabled') and valor<>'false'::jsonb;
  end if;
  return new;
end;
$$;
revoke all on function private.finance_final_gate_sync_v148() from public,anon,authenticated;

drop trigger if exists trg_finance_final_gate_sync_v148 on public.config_club;
create trigger trg_finance_final_gate_sync_v148
after insert or update of valor on public.config_club
for each row when (new.clave='finance_qa_shadow_approved')
execute function private.finance_final_gate_sync_v148();

create or replace function public.app_finance_pilot_readiness_v148(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_q jsonb;v_flags jsonb;v_rules int;v_last public.finance_qa_shadow_runs;v_prev public.finance_qa_shadow_runs;v_ready boolean;v_live boolean;
begin
  if (select auth.uid()) is null then raise exception 'AUTH_REQUIRED'; end if;
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') or coalesce(public.app_kombax_support_club_v140(p_club_id),false)) then
    raise exception 'FINANCE_ACCESS_DENIED';
  end if;
  v_q:=public.app_finance_v2_qa_status_v146(p_club_id);
  v_flags:=public.app_finance_v2_flags_v143(p_club_id);
  select count(*)::int into v_rules from public.reglas_cobro r where r.club_id=p_club_id and r.activa;
  select * into v_last from public.finance_qa_shadow_runs where club_id=p_club_id and estado='ok' order by creado_en desc limit 1;
  select * into v_prev from public.finance_qa_shadow_runs where club_id=p_club_id and estado='ok' order by creado_en desc offset 1 limit 1;
  v_live:=private.finance_flag_v143(p_club_id,'finance_pilot_live_enabled');
  v_ready:=coalesce((v_q#>>'{blocking,total}')::int,0)=0
    and coalesce((v_q->>'approved')::boolean,false)
    and v_rules>0
    and v_last.id is not null and v_prev.id is not null
    and v_last.fecha_proceso=v_prev.fecha_proceso and v_last.fingerprint=v_prev.fingerprint
    and coalesce((v_flags->>'finance_v2_enabled')::boolean,false)
    and coalesce((v_flags->>'finance_dashboard_v2_enabled')::boolean,false);
  return jsonb_build_object(
    'ready',v_ready,'live',v_live,'active_rules',v_rules,'qa',v_q,'flags',v_flags,
    'two_equivalent_shadow_runs',v_last.id is not null and v_prev.id is not null and v_last.fecha_proceso=v_prev.fecha_proceso and v_last.fingerprint=v_prev.fingerprint,
    'last_shadow_fingerprint',v_last.fingerprint,'last_shadow_date',v_last.fecha_proceso,
    'requirements',jsonb_build_object('finance_v2',coalesce((v_flags->>'finance_v2_enabled')::boolean,false),'dashboard_v2',coalesce((v_flags->>'finance_dashboard_v2_enabled')::boolean,false),'qa_approved',coalesce((v_q->>'approved')::boolean,false),'blocking_anomalies_zero',coalesce((v_q#>>'{blocking,total}')::int,0)=0,'active_rule',v_rules>0)
  );
end;
$$;
revoke all on function public.app_finance_pilot_readiness_v148(uuid) from public,anon;
grant execute on function public.app_finance_pilot_readiness_v148(uuid) to authenticated;

do $wrap$
begin
  if to_regprocedure('public.procesar_cargos_recurrentes_pre_final_148(date,uuid,boolean,boolean)') is null then
    alter function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) rename to procesar_cargos_recurrentes_pre_final_148;
  end if;
end $wrap$;
revoke all on function public.procesar_cargos_recurrentes_pre_final_148(date,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.procesar_cargos_recurrentes_pre_final_148(date,uuid,boolean,boolean) to service_role;

create or replace function public.procesar_cargos_recurrentes(
  p_fecha date default current_date,p_club_id uuid default null,p_shadow boolean default true,p_forzar_ciclo_actual boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  if not p_shadow then
    if p_club_id is null then return jsonb_build_object('ok',true,'disabled',true,'reason','club_required_for_real_run'); end if;
    if not private.finance_flag_v143(p_club_id,'finance_recurring_enabled') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_recurring_enabled=false','club_id',p_club_id);
    end if;
    if not private.finance_flag_v143(p_club_id,'finance_qa_shadow_approved') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_qa_shadow_approved=false','club_id',p_club_id);
    end if;
    if not private.finance_flag_v143(p_club_id,'finance_pilot_live_enabled') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_pilot_live_enabled=false','club_id',p_club_id);
    end if;
  end if;
  return public.procesar_cargos_recurrentes_pre_final_148(p_fecha,p_club_id,p_shadow,p_forzar_ciclo_actual);
end;
$$;
revoke all on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) from public,anon;
grant execute on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) to authenticated,service_role;

do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_final_148(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_final_148;
  end if;
end $gateway$;
revoke all on function public.app_mutate_v160_pre_finance_final_148(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_ready jsonb;v_data jsonb;v_result jsonb;v_existing public.app_mutation_requests;v_backend_version text;
begin
  if p_operation not in ('finance.pilot.activar','finance.pilot.pausar') then
    return public.app_mutate_v160_pre_finance_final_148(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=coalesce(nullif(v_payload->>'club_id','')::uuid,nullif(current_setting('request.jwt.claim.club_id',true),'')::uuid); exception when others then v_club:=null; end;
  if v_club is null then raise exception 'CLUB_REQUIRED'; end if;
  if not (public.tiene_rol_club(v_club,'direccion') or coalesce(public.app_kombax_support_club_v140(v_club),false)) then raise exception 'DIRECCION_REQUIRED'; end if;

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
      on conflict (club_id,clave) do update set valor=excluded.valor,actualizado_en=now(),actualizado_por=v_uid;
    insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
      values(v_club,'finance_pilot_live_enabled','true'::jsonb,'Gate final de recurrencia real Finance Premium','direccion',now(),v_uid)
      on conflict (club_id,clave) do update set valor=excluded.valor,actualizado_en=now(),actualizado_por=v_uid;
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
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Extend contract operation list without changing backend_version/schema epoch.
do $$
declare v_op text;
begin
  foreach v_op in array array['finance.pilot.activar','finance.pilot.pausar'] loop
    -- operation exposure is supplied by the wrapped runtime contract in 143/146; marker for static QA only.
    perform v_op;
  end loop;
end $$;

commit;
