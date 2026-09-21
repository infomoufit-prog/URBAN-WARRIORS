begin;

-- KOMBAX RC13 build 20082 · Finance Premium 2.0 · QA profundo + Shadow gate
-- Additive hardening only. No historical payment/receipt/report rows are rewritten.

-- ---------------------------------------------------------------------------
-- 1) Explicit QA approval gate. It starts CLOSED for every club.
-- ---------------------------------------------------------------------------
insert into public.config_club(club_id,clave,valor,descripcion,editable_por)
select c.id,'finance_qa_shadow_approved','false'::jsonb,
       'Shadow QA financiero aprobado para permitir recurrencias reales','direccion'
from public.clubes c
on conflict(club_id,clave) do nothing;

create table if not exists public.finance_qa_shadow_runs (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  fecha_proceso date not null,
  fingerprint text not null,
  estado text not null check (estado in ('ok','warning','blocked','error')),
  reglas integer not null default 0 check (reglas>=0),
  cargos_simulados integer not null default 0 check (cargos_simulados>=0),
  importe_total numeric(14,2) not null default 0,
  bloqueos jsonb not null default '{}'::jsonb,
  advertencias jsonb not null default '{}'::jsonb,
  resultado jsonb not null default '{}'::jsonb,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now()
);
create index if not exists idx_finance_qa_shadow_runs_v146
  on public.finance_qa_shadow_runs(club_id,fecha_proceso desc,creado_en desc);

alter table public.finance_qa_shadow_runs enable row level security;
drop policy if exists finance_qa_shadow_runs_read_v146 on public.finance_qa_shadow_runs;
create policy finance_qa_shadow_runs_read_v146 on public.finance_qa_shadow_runs
  for select to authenticated
  using (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));
revoke all on table public.finance_qa_shadow_runs from public,anon;
grant select on table public.finance_qa_shadow_runs to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Read-only invariant scanner. Blocking anomalies must be zero before pilot.
-- ---------------------------------------------------------------------------
create or replace function private.finance_qa_anomalies_v146(p_club uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_dup_rule integer:=0;
  v_dup_key integer:=0;
  v_overpaid integer:=0;
  v_view_mismatch integer:=0;
  v_receipt_early integer:=0;
  v_paid_no_receipt integer:=0;
  v_report_missing integer:=0;
  v_rules_no_target integer:=0;
  v_active_rules integer:=0;
  v_pending_validation integer:=0;
  v_block_total integer:=0;
begin
  select count(*) into v_dup_rule from (
    select 1 from public.cuotas
    where club_id=p_club and regla_cobro_id is not null and ciclo_clave is not null
    group by regla_cobro_id,socio_id,ciclo_clave having count(*)>1
  ) d;
  select count(*) into v_dup_key from (
    select 1 from public.cuotas
    where club_id=p_club and generacion_clave is not null
    group by generacion_clave having count(*)>1
  ) d;
  select count(*) into v_overpaid
  from public.cuotas q
  join lateral (
    select coalesce(sum(p.importe),0)::numeric paid
    from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id and p.estado_validacion='validado'
  ) x on true
  where q.club_id=p_club and x.paid>q.importe+0.01;
  select count(*) into v_view_mismatch
  from public.v_estado_cuenta_socio v
  join lateral (
    select coalesce(sum(p.importe),0)::numeric paid
    from public.pagos p where p.club_id=v.club_id and p.cuota_id=v.cuota_id and p.estado_validacion='validado'
  ) x on true
  where v.club_id=p_club and abs(coalesce(v.pagado_validado,0)-x.paid)>0.01;
  select count(*) into v_receipt_early
  from public.recibos_cuota r
  join public.v_estado_cuenta_socio v on v.club_id=r.club_id and v.cuota_id=r.cuota_id
  where r.club_id=p_club and r.anulado_en is null and coalesce(v.saldo,0)>0.01;
  select count(*) into v_paid_no_receipt
  from public.cuotas q
  where q.club_id=p_club and q.estado='pagada'
    and not exists(select 1 from public.recibos_cuota r where r.club_id=q.club_id and r.cuota_id=q.id and r.anulado_en is null);
  select count(*) into v_report_missing
  from public.informes_financieros r
  where r.club_id=p_club and r.archivo_path is not null
    and not exists(select 1 from storage.objects o where o.bucket_id='finance-reports' and o.name=r.archivo_path);
  select count(*) into v_active_rules from public.reglas_cobro r where r.club_id=p_club and r.activa;
  select count(*) into v_rules_no_target
  from public.reglas_cobro r
  where r.club_id=p_club and r.activa
    and not exists(select 1 from public.reglas_cobro_destinatarios d where d.club_id=r.club_id and d.regla_id=r.id);
  select count(*) into v_pending_validation from public.pagos p where p.club_id=p_club and p.estado_validacion='pendiente';

  v_block_total:=v_dup_rule+v_dup_key+v_overpaid+v_view_mismatch+v_receipt_early+v_paid_no_receipt+v_report_missing;
  return jsonb_build_object(
    'blocking',jsonb_build_object(
      'total',v_block_total,
      'duplicate_rule_student_cycle',v_dup_rule,
      'duplicate_generation_key',v_dup_key,
      'validated_overpayment',v_overpaid,
      'account_view_mismatch',v_view_mismatch,
      'receipt_before_full_payment',v_receipt_early,
      'paid_charge_without_active_receipt',v_paid_no_receipt,
      'report_file_missing',v_report_missing
    ),
    'warnings',jsonb_build_object(
      'active_rules',v_active_rules,
      'active_rules_without_target',v_rules_no_target,
      'payments_pending_validation',v_pending_validation
    )
  );
end
$$;
revoke all on function private.finance_qa_anomalies_v146(uuid) from public,anon,authenticated;

create or replace function public.app_finance_v2_qa_status_v146(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_a jsonb;
  v_runs jsonb;
  v_approved boolean;
begin
  if v_uid is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_QA_FORBIDDEN';
  end if;
  v_a:=private.finance_qa_anomalies_v146(p_club_id);
  v_approved:=private.finance_flag_v143(p_club_id,'finance_qa_shadow_approved');
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,'fecha_proceso',x.fecha_proceso,'fingerprint',x.fingerprint,'estado',x.estado,
    'reglas',x.reglas,'cargos_simulados',x.cargos_simulados,'importe_total',x.importe_total,'creado_en',x.creado_en
  ) order by x.creado_en desc),'[]'::jsonb)
  into v_runs
  from (select * from public.finance_qa_shadow_runs where club_id=p_club_id order by creado_en desc limit 8) x;
  return jsonb_build_object(
    'ok',true,'club_id',p_club_id,
    'flags',jsonb_build_object(
      'finance_v2_enabled',private.finance_flag_v143(p_club_id,'finance_v2_enabled'),
      'finance_dashboard_v2_enabled',private.finance_flag_v143(p_club_id,'finance_dashboard_v2_enabled'),
      'finance_reports_enabled',private.finance_flag_v143(p_club_id,'finance_reports_enabled'),
      'finance_recurring_enabled',private.finance_flag_v143(p_club_id,'finance_recurring_enabled'),
      'finance_qa_shadow_approved',v_approved
    ),
    'anomalies',v_a,'recent_shadow_runs',v_runs,
    'ready_for_shadow',coalesce((v_a#>>'{blocking,total}')::int,0)=0,
    'approved',v_approved
  );
end
$$;
revoke all on function public.app_finance_v2_qa_status_v146(uuid) from public,anon;
grant execute on function public.app_finance_v2_qa_status_v146(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Deterministic whole-club shadow run + fingerprint.
-- ---------------------------------------------------------------------------
create or replace function private.finance_qa_fingerprint_v146(p_club uuid,p_fecha date,p_result jsonb)
returns text
language sql
stable
security definer
set search_path=''
as $$
  select md5(concat_ws('|',
    coalesce((select jsonb_agg(to_jsonb(r) order by r.id)::text from (
      select id,nombre,concepto,categoria,importe,periodicidad,fecha_inicio,fecha_fin,dia_generacion,dia_vencimiento,zona_horaria,activa
      from public.reglas_cobro where club_id=p_club order by id
    ) r),'[]'),
    coalesce((select jsonb_agg(to_jsonb(d) order by d.id)::text from (
      select id,regla_id,tipo,socio_id,grupo_id,disciplina_id from public.reglas_cobro_destinatarios where club_id=p_club order by id
    ) d),'[]'),
    coalesce((select jsonb_agg(to_jsonb(e) order by e.id)::text from (
      select id,regla_id,socio_id,tipo,fecha_inicio,fecha_fin,ciclo_clave,bonificacion_porcentaje,bonificacion_importe,importe_personalizado,activa
      from public.reglas_cobro_excepciones where club_id=p_club order by id
    ) e),'[]'),
    coalesce((select jsonb_agg(to_jsonb(m) order by m.socio_id,m.id)::text from (
      select sd.id,sd.socio_id,sd.disciplina_id,sd.grupo_id,sd.fecha_inicio,sd.fecha_fin,sd.activa,s.estado
      from public.socio_disciplinas sd join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id
      where sd.club_id=p_club order by sd.socio_id,sd.id
    ) m),'[]'),
    coalesce(p_fecha::text,''),
    coalesce(p_result->>'reglas_procesadas','0'),
    coalesce(p_result->>'cargos_simulados','0'),
    coalesce(p_result->>'importe_total','0')
  ));
$$;
revoke all on function private.finance_qa_fingerprint_v146(uuid,date,jsonb) from public,anon,authenticated;

create or replace function private.finance_qa_shadow_run_v146(p_club uuid,p_fecha date,p_uid uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_result jsonb;
  v_anomalies jsonb;
  v_fp text;
  v_status text;
  v_id uuid;
  v_blocks int;
  v_warn_no_target int;
begin
  if p_uid is null or not public.tiene_rol_club(p_club,'direccion','economia') then raise exception 'FINANCE_QA_RUN_FORBIDDEN'; end if;
  v_anomalies:=private.finance_qa_anomalies_v146(p_club);
  v_blocks:=coalesce((v_anomalies#>>'{blocking,total}')::int,0);
  v_result:=public.procesar_cargos_recurrentes(coalesce(p_fecha,current_date),p_club,true,false);
  v_fp:=private.finance_qa_fingerprint_v146(p_club,coalesce(p_fecha,current_date),v_result);
  v_warn_no_target:=coalesce((v_anomalies#>>'{warnings,active_rules_without_target}')::int,0);
  v_status:=case when not coalesce((v_result->>'ok')::boolean,false) then 'error'
                 when v_blocks>0 then 'blocked'
                 when v_warn_no_target>0 then 'warning' else 'ok' end;
  insert into public.finance_qa_shadow_runs(
    club_id,fecha_proceso,fingerprint,estado,reglas,cargos_simulados,importe_total,bloqueos,advertencias,resultado,creado_por
  ) values(
    p_club,coalesce(p_fecha,current_date),v_fp,v_status,
    coalesce((v_result->>'reglas_procesadas')::int,0),coalesce((v_result->>'cargos_simulados')::int,0),
    coalesce((v_result->>'importe_total')::numeric,0),coalesce(v_anomalies->'blocking','{}'::jsonb),
    coalesce(v_anomalies->'warnings','{}'::jsonb),v_result-'preview',p_uid
  ) returning id into v_id;
  return jsonb_build_object('run_id',v_id,'estado',v_status,'fingerprint',v_fp,'resultado',v_result,'anomalies',v_anomalies);
exception when others then
  insert into public.finance_qa_shadow_runs(club_id,fecha_proceso,fingerprint,estado,resultado,creado_por)
  values(p_club,coalesce(p_fecha,current_date),md5(coalesce(sqlstate,'')||':'||coalesce(sqlerrm,'')),'error',jsonb_build_object('sqlstate',sqlstate,'error',left(sqlerrm,500)),p_uid);
  raise;
end
$$;
revoke all on function private.finance_qa_shadow_run_v146(uuid,date,uuid) from public,anon,authenticated;

create or replace function private.finance_qa_approve_v146(p_club uuid,p_uid uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare r1 public.finance_qa_shadow_runs;r2 public.finance_qa_shadow_runs;v_a jsonb;v_rules int;
begin
  if p_uid is null or not public.tiene_rol_club(p_club,'direccion') then raise exception 'FINANCE_QA_APPROVE_FORBIDDEN'; end if;
  select count(*) into v_rules from public.reglas_cobro where club_id=p_club and activa;
  if v_rules=0 then raise exception 'FINANCE_QA_NO_ACTIVE_RULES'; end if;
  select * into r1 from public.finance_qa_shadow_runs where club_id=p_club order by creado_en desc limit 1;
  select * into r2 from public.finance_qa_shadow_runs where club_id=p_club order by creado_en desc offset 1 limit 1;
  if r1.id is null or r2.id is null then raise exception 'FINANCE_QA_TWO_SHADOW_RUNS_REQUIRED'; end if;
  if r1.estado<>'ok' or r2.estado<>'ok' or r1.fecha_proceso<>r2.fecha_proceso or r1.fingerprint<>r2.fingerprint then
    raise exception 'FINANCE_QA_SHADOW_RUNS_NOT_EQUIVALENT';
  end if;
  if r1.creado_en<now()-interval '24 hours' then raise exception 'FINANCE_QA_SHADOW_RUN_EXPIRED'; end if;
  v_a:=private.finance_qa_anomalies_v146(p_club);
  if coalesce((v_a#>>'{blocking,total}')::int,0)>0 then raise exception 'FINANCE_QA_BLOCKING_ANOMALIES'; end if;
  insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
  values(p_club,'finance_qa_shadow_approved','true'::jsonb,'Shadow QA financiero aprobado','direccion',now(),p_uid)
  on conflict(club_id,clave) do update set valor='true'::jsonb,actualizado_en=now(),actualizado_por=p_uid;
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(p_club,p_uid,'FINANCE_QA_APPROVED','finance_qa',r1.id::text,jsonb_build_object('fingerprint',r1.fingerprint,'fecha_proceso',r1.fecha_proceso));
  return jsonb_build_object('approved',true,'run_id',r1.id,'fingerprint',r1.fingerprint,'fecha_proceso',r1.fecha_proceso);
end
$$;
revoke all on function private.finance_qa_approve_v146(uuid,uuid) from public,anon,authenticated;

create or replace function private.finance_qa_revoke_v146(p_club uuid,p_uid uuid,p_reason text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  if p_uid is null or not public.tiene_rol_club(p_club,'direccion') then raise exception 'FINANCE_QA_REVOKE_FORBIDDEN'; end if;
  update public.config_club set valor='false'::jsonb,actualizado_en=now(),actualizado_por=p_uid
  where club_id=p_club and clave='finance_qa_shadow_approved';
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(p_club,p_uid,'FINANCE_QA_REVOKED','finance_qa',p_club::text,jsonb_build_object('reason',coalesce(nullif(trim(p_reason),''),'manual')));
  return jsonb_build_object('approved',false);
end
$$;
revoke all on function private.finance_qa_revoke_v146(uuid,uuid,text) from public,anon,authenticated;

-- Configuration changes invalidate an earlier approval automatically.
create or replace function private.finance_qa_invalidate_v146()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_club uuid:=coalesce(new.club_id,old.club_id);
begin
  update public.config_club set valor='false'::jsonb,actualizado_en=now(),actualizado_por=auth.uid()
  where club_id=v_club and clave='finance_qa_shadow_approved' and valor='true'::jsonb;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;
revoke all on function private.finance_qa_invalidate_v146() from public,anon,authenticated;

drop trigger if exists trg_finance_qa_invalidate_rule_v146 on public.reglas_cobro;
create trigger trg_finance_qa_invalidate_rule_v146 after insert or update or delete on public.reglas_cobro
for each row execute function private.finance_qa_invalidate_v146();
drop trigger if exists trg_finance_qa_invalidate_target_v146 on public.reglas_cobro_destinatarios;
create trigger trg_finance_qa_invalidate_target_v146 after insert or update or delete on public.reglas_cobro_destinatarios
for each row execute function private.finance_qa_invalidate_v146();
drop trigger if exists trg_finance_qa_invalidate_exception_v146 on public.reglas_cobro_excepciones;
create trigger trg_finance_qa_invalidate_exception_v146 after insert or update or delete on public.reglas_cobro_excepciones
for each row execute function private.finance_qa_invalidate_v146();

-- ---------------------------------------------------------------------------
-- 4) Serialize real recurring runs and require QA approval.
-- Shadow remains unrestricted and read-only.
-- ---------------------------------------------------------------------------
do $engine$
begin
  if to_regprocedure('public.procesar_cargos_recurrentes_pre_qa_146(date,uuid,boolean,boolean)') is null then
    alter function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean)
      rename to procesar_cargos_recurrentes_pre_qa_146;
  end if;
end
$engine$;
revoke all on function public.procesar_cargos_recurrentes_pre_qa_146(date,uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.procesar_cargos_recurrentes_pre_qa_146(date,uuid,boolean,boolean) to service_role;

create or replace function public.procesar_cargos_recurrentes(
  p_fecha date default current_date,
  p_club_id uuid default null,
  p_shadow boolean default true,
  p_forzar_ciclo_actual boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_service boolean:=coalesce(auth.jwt()->>'role',current_setting('request.jwt.claim.role',true),'')='service_role';v_locked boolean;
begin
  if p_club_id is null then raise exception 'FINANCE_V2_CLUB_REQUIRED'; end if;
  if not p_shadow then
    if not private.finance_flag_v143(p_club_id,'finance_qa_shadow_approved') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_qa_shadow_approved=false','club_id',p_club_id);
    end if;
    v_locked:=pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('kombax-finance-real:'||p_club_id::text,0));
    if not v_locked then return jsonb_build_object('ok',true,'busy',true,'reason','finance_real_run_in_progress','club_id',p_club_id); end if;
  end if;
  if not v_service and (v_uid is null or not public.tiene_rol_club(p_club_id,'direccion','economia')) then raise exception 'FINANCE_V2_PROCESS_FORBIDDEN'; end if;
  return public.procesar_cargos_recurrentes_pre_qa_146(p_fecha,p_club_id,p_shadow,p_forzar_ciclo_actual);
end
$$;
revoke all on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) from public,anon;
grant execute on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) to authenticated,service_role;

-- ---------------------------------------------------------------------------
-- 5) Gateway QA actions + recurring flag guard, preserving request idempotency.
-- ---------------------------------------------------------------------------
do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_qa_146(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_qa_146;
  end if;
end
$gateway$;
revoke all on function public.app_mutate_v160_pre_finance_qa_146(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;
  v_existing public.app_mutation_requests;v_data jsonb;v_result jsonb;v_backend_version text;
begin
  if p_operation not in ('finance.qa.shadow.run','finance.qa.aprobar','finance.qa.revocar') then
    if p_operation='finance.flag.establecer'
       and v_payload->>'clave'='finance_recurring_enabled'
       and coalesce((v_payload->>'valor')::boolean,false)=true then
      begin v_club:=nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
      if not private.finance_flag_v143(v_club,'finance_qa_shadow_approved') then raise exception 'FINANCE_QA_APPROVAL_REQUIRED_BEFORE_RECURRING'; end if;
    end if;
    return public.app_mutate_v160_pre_finance_qa_146(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','economia') then raise exception 'FINANCE_QA_MUTATION_FORBIDDEN'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='finance.qa.shadow.run' then
    v_data:=private.finance_qa_shadow_run_v146(v_club,coalesce(nullif(v_payload->>'fecha','')::date,current_date),v_uid);
  elsif p_operation='finance.qa.aprobar' then
    v_data:=private.finance_qa_approve_v146(v_club,v_uid);
  elsif p_operation='finance.qa.revocar' then
    v_data:=private.finance_qa_revoke_v146(v_club,v_uid,v_payload->>'motivo');
  end if;

  select backend_version into v_backend_version from public.app_runtime_meta where singleton=true;
  v_result:=jsonb_build_object('ok',true,'backend_version',coalesce(v_backend_version,'1.6.0'),'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Runtime contract extension only; RC13 version/epoch remain unchanged.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_qa_146(uuid)') is null then
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_qa_146;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_qa_146(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_base jsonb;v_op text;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_qa_146(p_club_id);
  foreach v_op in array array['finance.qa.shadow.run','finance.qa.aprobar','finance.qa.revocar'] loop
    if not (coalesce(v_base->'operations','[]'::jsonb) @> jsonb_build_array(v_op)) then
      v_base:=jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array(v_op),true);
    end if;
  end loop;
  return v_base;
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Self-audit: installation must remain safe by default.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.finance_qa_shadow_runs') is null then raise exception 'FINANCE_QA_146_TABLE_MISSING'; end if;
  if to_regprocedure('public.app_finance_v2_qa_status_v146(uuid)') is null then raise exception 'FINANCE_QA_146_STATUS_MISSING'; end if;
  if to_regprocedure('public.procesar_cargos_recurrentes_pre_qa_146(date,uuid,boolean,boolean)') is null then raise exception 'FINANCE_QA_146_ENGINE_WRAPPER_MISSING'; end if;
  if exists(select 1 from public.config_club where clave='finance_qa_shadow_approved' and valor='true'::jsonb) then
    raise exception 'FINANCE_QA_146_MUST_START_CLOSED';
  end if;
end
$$;

commit;
