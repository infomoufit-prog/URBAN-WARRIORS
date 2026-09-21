-- PRECHECK 025 DE SOLO LECTURA.
-- Resultado requerido: todos los controles en OK y cero estados incompatibles.

select control, estado, detalle
from (
  select 1 orden,
    'gateway RC10'::text control,
    case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null
      then 'OK' else 'FALLO' end estado,
    coalesce(to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)')::text,'ausente') detalle

  union all
  select 2,
    'wrapper 025 ausente',
    case when to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is null
      then 'OK' else 'FALLO' end,
    'evita encadenar 025 dos veces'

  union all
  select 3,
    'tablas requeridas',
    case when to_regclass('public.material_catalogo') is not null
      and to_regclass('public.material_variantes') is not null
      and to_regclass('public.material_pedidos') is not null
      and to_regclass('public.material_entregas') is not null
      and to_regclass('public.cuotas') is not null
      then 'OK' else 'FALLO' end,
    'catálogo, variantes, pedidos, entregas y cuotas'

  union all
  select 4,
    'estados de pedidos compatibles',
    case when count(*) filter (
      where estado not in ('reservado','pendiente_validacion','preparado','validado','entregado','cancelado')
    )=0 then 'OK' else 'FALLO' end,
    count(*) filter (
      where estado not in ('reservado','pendiente_validacion','preparado','validado','entregado','cancelado')
    )::text||' incompatibles'
  from public.material_pedidos

  union all
  select 5,
    'stock no negativo',
    case when
      (select count(*) from public.material_catalogo where stock<0)=0
      and (select count(*) from public.material_variantes where stock<0)=0
      then 'OK' else 'FALLO' end,
    ((select count(*) from public.material_catalogo where stock<0)
      +(select count(*) from public.material_variantes where stock<0))::text||' registros'

  union all
  select 6,
    'FK financiera disponible',
    case when exists (
      select 1 from pg_constraint
      where conrelid='public.cuotas'::regclass
        and contype in ('p','u')
        and pg_get_constraintdef(oid)='UNIQUE (club_id, id)'
    ) then 'OK' else 'FALLO' end,
    'cuotas(club_id,id)'

  union all
  select 7,
    '024 completa',
    case when exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='cuotas' and column_name='origen_id'
    ) and to_regclass('public.v_finanzas_detalle') is not null
      then 'OK' else 'FALLO' end,
    'origen_id y vista financiera'
) checks
order by orden;
