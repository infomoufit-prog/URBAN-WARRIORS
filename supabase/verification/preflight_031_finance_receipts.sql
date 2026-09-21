-- Solo lectura. Ejecutar antes de 031_finance_receipts_breakdown.sql.
select control,estado,detalle from (
  select 1 orden,'recibos base'::text control,
    case when to_regclass('public.recibos_cuota') is not null
      and to_regprocedure('public.emitir_recibo_cuota(uuid)') is not null then 'OK' else 'FALLO' end estado,
    'tabla y emisor disponibles'::text detalle
  union all
  select 2,'trigger de emisión',
    case when exists(select 1 from pg_trigger where tgname='trg_emitir_recibo_cuota_pagada' and not tgisinternal) then 'OK' else 'FALLO' end,
    'cargo pagado → recibo'
  union all
  select 3,'origen financiero',
    case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='cuotas' and column_name='origen') then 'OK' else 'FALLO' end,
    'cuota/material/otro'
  union all
  select 4,'cargo de material',
    case when exists(select 1 from public.cuotas where origen='material') then 'OK' else 'OK' end,
    count(*)::text||' cargos de material existentes'
  from public.cuotas where origen='material'
  union all
  select 5,'031 pendiente',
    case when to_regprocedure('public.app_finance_receipts_audit_v031()') is null then 'OK' else 'FALLO' end,
    'evita mezclar una ejecución anterior'
) checks order by orden;
