-- PRECHECK 028 DE SOLO LECTURA. Resultado requerido: 5/5 OK.
select control,estado,detalle from (
  select 1 orden,'027 aplicada'::text control,
    case when to_regclass('public.idx_comunidad_club_estado_cursor') is not null then 'OK' else 'FALLO' end estado,
    'índice de cursor'::text detalle
  union all
  select 2,'gateway 025 activo',
    case when pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
      like '%app_mutate_v160_pre_material_025%' then 'OK' else 'FALLO' end,
    'material permanece en la cadena'
  union all
  select 3,'wrapper 028 ausente',
    case when to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is null then 'OK' else 'FALLO' end,
    'evita reutilizar un wrapper antiguo'
  union all
  select 4,'tabla Comunidad',
    case when to_regclass('public.publicaciones_comunidad') is not null then 'OK' else 'FALLO' end,
    'destino de metadatos'
  union all
  select 5,'columnas 028 pendientes',
    case when count(*)=0 then 'OK' else 'FALLO' end,
    count(*)::text||' columnas ya existentes'
  from information_schema.columns
  where table_schema='public' and table_name='publicaciones_comunidad'
    and column_name in ('media_mime','media_width','media_height','media_size_bytes')
) checks order by orden;
