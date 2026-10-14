-- Phase 3 / R264: void only UNPAID administrative club fees.
-- Every cancellation is auditable. No actual payment, receipt or Stripe object is modified.
-- This is compatible with existing web clients: old readers still access the same views/columns.
begin;

create table if not exists public.kombax_fee_void_audit_r264 (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  club_id uuid not null references public.clubes(id) on delete restrict,
  cuota_id uuid not null references public.cuotas(id) on delete restrict,
  actor_id uuid not null,
  action text not null check (action='void_unpaid'),
  reason text not null check (char_length(btrim(reason)) between 8 and 500),
  previous_state public.estado_cuota not null,
  previous_amount numeric(10,2) not null,
  resulting_state public.estado_cuota not null,
  created_at timestamptz not null default now()
);
alter table public.kombax_fee_void_audit_r264 enable row level security;
revoke all on public.kombax_fee_void_audit_r264 from public,anon,authenticated;
create index if not exists idx_kombax_fee_void_audit_r264_club_fee
 on public.kombax_fee_void_audit_r264(club_id,cuota_id,created_at desc);

create or replace function public.app_kombax_fee_void_r264(
 p_club_id uuid,p_cuota_id uuid,p_reason text,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  v_actor uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason,''));
  v_fee public.cuotas%rowtype;
  v_previous public.kombax_fee_void_audit_r264%rowtype;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_club_id is null or p_cuota_id is null or p_request_id is null then
    raise exception 'FINANCE_VOID_PARAMETERS_REQUIRED';
  end if;
  if char_length(v_reason) not between 8 and 500 then
    raise exception 'FINANCE_VOID_REASON_REQUIRED';
  end if;
  -- Only Direction and Treasury can void. Monitor, Secretariat and member cannot.
  if coalesce(public.tiene_rol_club(p_club_id,'direccion','economia'),false) is not true then
    raise exception 'FINANCE_VOID_PERMISSION_DENIED';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,264));
  select * into v_previous
    from public.kombax_fee_void_audit_r264
   where request_id=p_request_id;
  if found then
    if v_previous.actor_id<>v_actor or v_previous.club_id<>p_club_id
       or v_previous.cuota_id<>p_cuota_id or v_previous.reason<>v_reason then
      raise exception 'FINANCE_VOID_REQUEST_ID_REUSED';
    end if;
    return jsonb_build_object('ok',true,'already_processed',true,'cuota_id',p_cuota_id,'estado','anulada');
  end if;

  select * into v_fee from public.cuotas
    where id=p_cuota_id and club_id=p_club_id for update;
  if v_fee.id is null then raise exception 'FINANCE_FEE_NOT_FOUND'; end if;
  if v_fee.origen is distinct from 'cuota' or v_fee.estado not in ('pendiente','vencida') then
    raise exception 'FINANCE_VOID_STATE_NOT_ALLOWED';
  end if;
  if v_fee.stripe_payment_intent_id is not null or v_fee.pagada_en is not null then
    raise exception 'FINANCE_VOID_PAYMENT_PROVIDER_REVIEW_REQUIRED';
  end if;
  -- Includes unvalidated payments: never void a fee with any payment attempt recorded.
  if exists(select 1 from public.pagos where cuota_id=v_fee.id and club_id=p_club_id)
    or exists(select 1 from public.recibos_cuota where cuota_id=v_fee.id and club_id=p_club_id) then
    raise exception 'FINANCE_VOID_LINKED_PAYMENT_OR_RECEIPT';
  end if;

  update public.cuotas set
    estado='anulada', avisos_pausados=true, avisos_pausados_hasta=null,
    avisos_pausados_por=v_actor, avisos_pausados_en=now(),
    motivo_pausa_avisos='Anulado por corrección administrativa (R264).',
    actualizado_en=now()
   where id=v_fee.id and club_id=p_club_id;
  insert into public.kombax_fee_void_audit_r264(
    request_id,club_id,cuota_id,actor_id,action,reason,previous_state,previous_amount,resulting_state
  ) values (p_request_id,p_club_id,p_cuota_id,v_actor,'void_unpaid',v_reason,v_fee.estado,v_fee.importe,'anulada');
  return jsonb_build_object('ok',true,'already_processed',false,'cuota_id',v_fee.id,'estado','anulada');
end $fn$;
revoke all on function public.app_kombax_fee_void_r264(uuid,uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_fee_void_r264(uuid,uuid,text,uuid) to authenticated;

-- Preserve the same public view interface while preventing false debt and inflated
-- collection metrics for voided fees. Original amounts remain in cuotas and audit.
create or replace view public.v_estado_cuenta_socio with (security_invoker=true) as
select q.club_id, q.socio_id, q.id as cuota_id, q.periodo,
  coalesce(nullif(q.concepto_publico,''),q.concepto) as concepto,
  (case when q.estado in ('anulada','cancelada') then 0::numeric else q.importe end)::numeric(10,2) as importe,
  q.vencimiento,q.estado,
  coalesce(pa.pagado_validado,0::numeric)::numeric(10,2) as pagado_validado,
  (case when q.estado in ('anulada','cancelada') then 0::numeric
   else greatest(q.importe-coalesce(pa.pagado_validado,0::numeric),0::numeric) end)::numeric(10,2) as saldo,
  pa.ultima_fecha_pago,rc.recibo_id,rc.recibo_numero,rc.recibo_anulado_en,
  coalesce(q.origen,'cuota') as origen,q.origen_id as referencia_id
from public.cuotas q
left join lateral (
 select coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0::numeric)::numeric(10,2) as pagado_validado,
        max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago
 from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join lateral (
 select r.id as recibo_id,r.numero as recibo_numero,r.anulado_en as recibo_anulado_en
 from public.recibos_cuota r where r.club_id=q.club_id and r.cuota_id=q.id limit 1
) rc on true;

create or replace view public.v_finanzas_detalle with (security_invoker=true) as
select q.club_id,q.id as cuota_id,q.socio_id,s.nombre as socio_nombre,s.apellidos as socio_apellidos,
 extract(year from q.periodo)::integer as anio,extract(month from q.periodo)::integer as mes,
 q.periodo,q.concepto,q.origen,q.origen_id,
 (case when q.estado in ('anulada','cancelada') then 0::numeric else q.importe end)::numeric(10,2) as importe,
 q.vencimiento,q.estado,q.creado_en,
 coalesce(pa.pagado_validado,0::numeric)::numeric(12,2) as pagado_validado,
 (case when q.estado in ('anulada','cancelada') then 0::numeric
   else greatest(q.importe-coalesce(pa.pagado_validado,0::numeric),0::numeric) end)::numeric(12,2) as saldo,
 pa.ultima_fecha_pago,pa.ultimo_metodo_pago,
 rc.id as recibo_id,rc.numero as recibo_numero,rc.anulado_en as recibo_anulado_en
from public.cuotas q
join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
left join lateral (
 select coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0::numeric) as pagado_validado,
        max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago,
        (array_agg(p.metodo order by p.fecha desc,p.creado_en desc)
          filter(where p.estado_validacion='validado'))[1] as ultimo_metodo_pago
 from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join public.recibos_cuota rc on rc.club_id=q.club_id and rc.cuota_id=q.id;

-- Guardrails for security_invoker financial reports retained.
commit;
