-- 024_finance_annual_metrics.sql
-- Historial financiero anual y métricas derivadas, sin duplicar saldos ni borrar datos.

begin;

alter table public.cuotas
  add column if not exists origen text not null default 'cuota',
  add column if not exists origen_id uuid;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='cuotas_origen_valido' and conrelid='public.cuotas'::regclass
  ) then
    alter table public.cuotas add constraint cuotas_origen_valido
      check (origen in ('cuota','material','otro')) not valid;
    alter table public.cuotas validate constraint cuotas_origen_valido;
  end if;
end
$migration$;

create index if not exists idx_cuotas_club_periodo_origen_estado
  on public.cuotas(club_id,periodo desc,origen,estado);
create index if not exists idx_pagos_club_cuota_validacion
  on public.pagos(club_id,cuota_id,estado_validacion,fecha desc);

create or replace view public.v_finanzas_detalle
with (security_invoker=true) as
select
  q.club_id,
  q.id as cuota_id,
  q.socio_id,
  s.nombre as socio_nombre,
  s.apellidos as socio_apellidos,
  extract(year from q.periodo)::integer as anio,
  extract(month from q.periodo)::integer as mes,
  q.periodo,
  q.concepto,
  q.origen,
  q.origen_id,
  q.importe,
  q.vencimiento,
  q.estado,
  q.creado_en,
  coalesce(pa.pagado_validado,0)::numeric(12,2) as pagado_validado,
  greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(12,2) as saldo,
  pa.ultima_fecha_pago,
  pa.ultimo_metodo_pago,
  rc.id as recibo_id,
  rc.numero as recibo_numero,
  rc.anulado_en as recibo_anulado_en
from public.cuotas q
join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
left join lateral (
  select
    coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0) as pagado_validado,
    max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago,
    (array_agg(p.metodo order by p.fecha desc,p.creado_en desc)
      filter(where p.estado_validacion='validado'))[1] as ultimo_metodo_pago
  from public.pagos p
  where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join public.recibos_cuota rc
  on rc.club_id=q.club_id and rc.cuota_id=q.id;

create or replace view public.v_finanzas_metricas_mensuales
with (security_invoker=true) as
select
  club_id,
  anio,
  mes,
  sum(importe)::numeric(14,2) as total_generado,
  sum(least(pagado_validado,importe))::numeric(14,2) as total_cobrado,
  sum(saldo)::numeric(14,2) as total_pendiente,
  sum(case when estado='vencida' then saldo else 0 end)::numeric(14,2) as total_vencido,
  count(distinct socio_id) filter(where saldo>0) as alumnos_con_deuda,
  case when sum(importe)>0 then round(100*sum(least(pagado_validado,importe))/sum(importe),2) else 0 end as porcentaje_cobro
from public.v_finanzas_detalle
group by club_id,anio,mes;

create or replace view public.v_finanzas_metricas_anuales
with (security_invoker=true) as
select
  club_id,
  anio,
  sum(importe)::numeric(14,2) as total_generado,
  sum(least(pagado_validado,importe))::numeric(14,2) as total_cobrado,
  sum(saldo)::numeric(14,2) as total_pendiente,
  sum(case when estado='vencida' then saldo else 0 end)::numeric(14,2) as total_vencido,
  count(distinct socio_id) filter(where saldo>0) as alumnos_con_deuda,
  case when sum(importe)>0 then round(100*sum(least(pagado_validado,importe))/sum(importe),2) else 0 end as porcentaje_cobro
from public.v_finanzas_detalle
group by club_id,anio;

revoke all on public.v_finanzas_detalle,public.v_finanzas_metricas_mensuales,public.v_finanzas_metricas_anuales
  from public,anon;
grant select on public.v_finanzas_detalle,public.v_finanzas_metricas_mensuales,public.v_finanzas_metricas_anuales
  to authenticated;

commit;

select
  to_regclass('public.v_finanzas_detalle') is not null as detalle_ok,
  to_regclass('public.v_finanzas_metricas_mensuales') is not null as mensual_ok,
  to_regclass('public.v_finanzas_metricas_anuales') is not null as anual_ok;
