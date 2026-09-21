-- Urban Warriors RC12 · desglose financiero y recibos de cuota/material.
-- Requiere 024, 025 y el sistema de recibos 016. Idempotente y no destructiva.

begin;

alter table public.recibos_cuota
  add column if not exists origen text not null default 'cuota',
  add column if not exists concepto text;

do $$ begin
  if not exists(
    select 1 from pg_constraint
    where conname='recibos_cuota_origen_valido'
      and conrelid='public.recibos_cuota'::regclass
  ) then
    alter table public.recibos_cuota
      add constraint recibos_cuota_origen_valido
      check(origen in ('cuota','material','otro')) not valid;
    alter table public.recibos_cuota validate constraint recibos_cuota_origen_valido;
  end if;
end $$;

create or replace function public.trg_clasificar_recibo_v031()
returns trigger
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_origen text;
  v_concepto text;
begin
  select coalesce(q.origen,'cuota'),coalesce(nullif(q.concepto_publico,''),q.concepto,'Cuota')
    into v_origen,v_concepto
  from public.cuotas q
  where q.club_id=new.club_id and q.id=new.cuota_id;

  new.origen:=coalesce(v_origen,'cuota');
  new.concepto:=coalesce(v_concepto,new.concepto,new.actividad,'Cuota');
  if new.origen='material' then
    new.actividad:=new.concepto;
  else
    new.actividad:=coalesce(nullif(new.actividad,''),new.concepto);
  end if;
  return new;
end;
$$;
revoke all on function public.trg_clasificar_recibo_v031() from public,anon,authenticated;

drop trigger if exists trg_clasificar_recibo_v031 on public.recibos_cuota;
create trigger trg_clasificar_recibo_v031
before insert or update of cuota_id on public.recibos_cuota
for each row execute function public.trg_clasificar_recibo_v031();

-- Corrige recibos históricos sin alterar su número, fecha, importe ni trazabilidad.
update public.recibos_cuota r
set origen=coalesce(q.origen,'cuota'),
    concepto=coalesce(nullif(q.concepto_publico,''),q.concepto,r.concepto,r.actividad,'Cuota'),
    actividad=case
      when q.origen='material' then coalesce(nullif(q.concepto_publico,''),q.concepto,r.actividad,'Material')
      else r.actividad
    end
from public.cuotas q
where q.club_id=r.club_id and q.id=r.cuota_id
  and (
    r.origen is distinct from coalesce(q.origen,'cuota')
    or r.concepto is distinct from coalesce(nullif(q.concepto_publico,''),q.concepto,r.concepto,r.actividad,'Cuota')
    or (q.origen='material' and r.actividad is distinct from coalesce(nullif(q.concepto_publico,''),q.concepto,r.actividad,'Material'))
  );

-- Amplía el estado de cuenta sin cambiar las columnas ya consumidas por RC11.
create or replace view public.v_estado_cuenta_socio
with (security_invoker=true) as
select
  q.club_id,
  q.socio_id,
  q.id as cuota_id,
  q.periodo,
  coalesce(nullif(q.concepto_publico,''),q.concepto) as concepto,
  q.importe,
  q.vencimiento,
  q.estado,
  coalesce(pa.pagado_validado,0)::numeric(10,2) as pagado_validado,
  greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(10,2) as saldo,
  pa.ultima_fecha_pago,
  rc.recibo_id,
  rc.recibo_numero,
  rc.recibo_anulado_en,
  coalesce(q.origen,'cuota') as origen,
  q.origen_id
from public.cuotas q
left join lateral (
  select
    coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(10,2) as pagado_validado,
    max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago
  from public.pagos p
  where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join lateral (
  select r.id recibo_id,r.numero recibo_numero,r.anulado_en recibo_anulado_en
  from public.recibos_cuota r
  where r.club_id=q.club_id and r.cuota_id=q.id
  limit 1
) rc on true;
grant select on public.v_estado_cuenta_socio to authenticated;

create or replace function public.app_finance_receipts_audit_v031()
returns table(control text,estado text,detalle text)
language sql
security definer
set search_path=public,auth
as $$
  select 'trigger de emisión',
    case when exists(select 1 from pg_trigger where tgname='trg_emitir_recibo_cuota_pagada' and not tgisinternal) then 'OK' else 'FALLO' end,
    'emite al pasar el cargo a pagada'
  union all
  select 'clasificación de recibo',
    case when exists(select 1 from pg_trigger where tgname='trg_clasificar_recibo_v031' and not tgisinternal) then 'OK' else 'FALLO' end,
    'cuota/material/otro'
  union all
  select 'pagadas sin recibo',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text
  from public.cuotas q
  where q.estado='pagada' and not exists(
    select 1 from public.recibos_cuota r where r.club_id=q.club_id and r.cuota_id=q.id
  )
  union all
  select 'material pagado sin recibo',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text
  from public.cuotas q
  where q.origen='material' and q.estado='pagada' and not exists(
    select 1 from public.recibos_cuota r where r.club_id=q.club_id and r.cuota_id=q.id
  )
  union all
  select 'recibos de material identificados',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text||' incorrectos'
  from public.recibos_cuota r join public.cuotas q on q.club_id=r.club_id and q.id=r.cuota_id
  where q.origen='material' and (r.origen<>'material' or r.concepto is null or r.actividad not like 'Material:%')
  union all
  select 'recibos antes de pago completo',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text
  from public.recibos_cuota r join public.cuotas q on q.club_id=r.club_id and q.id=r.cuota_id
  where q.estado<>'pagada' and r.anulado_en is null
  union all
  select 'recibo único por cargo',case when count(*)=0 then 'OK' else 'FALLO' end,count(*)::text||' duplicados'
  from (
    select club_id,cuota_id from public.recibos_cuota group by club_id,cuota_id having count(*)>1
  ) d;
$$;
revoke all on function public.app_finance_receipts_audit_v031() from public,anon,authenticated;
grant execute on function public.app_finance_receipts_audit_v031() to service_role,postgres;

notify pgrst,'reload schema';
commit;

select * from public.app_finance_receipts_audit_v031();
