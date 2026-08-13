-- PRECHECK 029 DE SOLO LECTURA. Resultado requerido: 6/6 OK.
select control,estado,detalle from (
  select 1 orden,'028 activa'::text control,
    case when to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is not null
      and pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_media_028%' then 'OK' else 'FALLO' end estado,
    'metadatos dentro de la cadena'::text detalle
  union all
  select 2,'wrapper 029 ausente',
    case when to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is null then 'OK' else 'FALLO' end,
    'evita reutilizar un wrapper antiguo'
  union all
  select 3,'columnas 029 pendientes',
    case when count(*)=0 then 'OK' else 'FALLO' end,
    count(*)::text||' columnas ya existentes'
  from information_schema.columns
  where table_schema='public' and table_name='publicaciones_comunidad'
    and column_name in ('portada_automatica_path','portada_manual_path')
  union all
  select 4,'bucket privado',
    case when exists(select 1 from storage.buckets where id='community-media' and not public) then 'OK' else 'FALLO' end,
    'community-media'
  union all
  select 5,'coordinación disponible',
    case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='miembros_club' and column_name='coordinacion') then 'OK' else 'FALLO' end,
    'permiso para portada manual'
  union all
  select 6,'Storage organizado',
    case when exists(
      select 1
      from pg_policies
      where schemaname='storage'
        and tablename='objects'
        and cmd='INSERT'
        and policyname in (
          'community_media_write_rc10',
          'community_media_insert_rc10'
        )
    ) then 'OK' else 'FALLO' end,
    'paths club/perfil'
) checks order by orden;
