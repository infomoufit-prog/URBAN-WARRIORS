-- PRECHECK 026 DE SOLO LECTURA.
-- Resultado requerido: todos los controles en OK.

select control,estado,detalle from (
  select 1 orden,'025 activa'::text control,
    case when to_regprocedure('public.app_validar_retirada_material_v025(uuid)') is not null
      and to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is not null
      then 'OK' else 'FALLO' end estado,
    'validador y rollback del gateway'::text detalle

  union all
  select 2,'motor RC10 activo',
    case when to_regprocedure('public.procesar_avisos_cobro(date,uuid)') is not null
      then 'OK' else 'FALLO' end,
    coalesce(to_regprocedure('public.procesar_avisos_cobro(date,uuid)')::text,'ausente')

  union all
  select 3,'wrapper 026 ausente',
    case when to_regprocedure('public.procesar_avisos_cobro_pre_material_026(date,uuid)') is null
      then 'OK' else 'FALLO' end,
    'evita instalar 026 dos veces'

  union all
  select 4,'configuraciones de cinco días',
    case when count(*) filter(where cardinality(dias_aviso)<>5)=0 then 'OK' else 'FALLO' end,
    count(*) filter(where cardinality(dias_aviso)<>5)::text||' configuraciones incompatibles'
  from public.configuracion_avisos_cuota

  union all
  select 5,'días válidos 1–28',
    case when count(*)=0 then 'OK' else 'FALLO' end,
    count(*)::text||' configuraciones incompatibles'
  from public.configuracion_avisos_cuota c
  where exists(select 1 from unnest(c.dias_aviso) d where d<1 or d>28)

  union all
  select 6,'historial idempotente',
    case when exists(
      select 1 from pg_constraint
      where conrelid='public.historial_avisos_cuota'::regclass
        and contype='u'
        and pg_get_constraintdef(oid) like 'UNIQUE (club_id, cuota_id, perfil_id, aviso_numero, canal)%'
    ) then 'OK' else 'FALLO' end,
    'una fila por cargo, perfil, aviso y canal'

  union all
  select 7,'columnas financieras 026',
    case when exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='cuotas' and column_name='concepto_publico'
    ) and exists(
      select 1 from information_schema.columns
      where table_schema='public' and table_name='cuotas' and column_name='origen'
    ) then 'OK' else 'FALLO' end,
    'concepto_publico y origen'
) checks order by orden;
