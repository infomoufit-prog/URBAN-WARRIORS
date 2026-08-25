-- KOMBAX RC13 build 20085 · Final finance readiness correctness fix
-- Corrects the anomaly JSON path used by the 148 readiness gate.
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

commit;
