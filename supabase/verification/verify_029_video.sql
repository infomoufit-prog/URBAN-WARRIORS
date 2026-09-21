-- VERIFICACIÓN 029 DE SOLO LECTURA. Resultado requerido: 7/7 OK.
select control,estado,detalle from (
  select 1 orden,'wrapper rollback'::text control,
    case when to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is not null
      then 'OK' else 'FALLO' end estado,
    'app_mutate_v160_pre_video_029'::text detalle
  union all
  select 2,'gateway 029 activo',
    case when pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
      like '%app_mutate_v160_pre_video_029%' then 'OK' else 'FALLO' end,
    'delegación segura'
  union all
  select 3,'columnas de portada',
    case when count(*)=2 then 'OK' else 'FALLO' end,
    count(*)::text||'/2'
  from information_schema.columns
  where table_schema='public' and table_name='publicaciones_comunidad'
    and column_name in ('portada_automatica_path','portada_manual_path')
  union all
  select 4,'bucket 50 MB privado',
    case when exists(
      select 1 from storage.buckets
      where id='community-media' and not public and file_size_limit=52428800
    ) then 'OK' else 'FALLO' end,
    'community-media'
  union all
  select 5,'MIME vídeo e imagen',
    case when exists(
      select 1 from storage.buckets b where b.id='community-media'
        and b.allowed_mime_types @> array[
          'image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'
        ]::text[]
    ) then 'OK' else 'FALLO' end,
    '6 tipos admitidos'
  union all
  select 6,'cadena 029-028',
    case when pg_get_functiondef('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)'::regprocedure)
      like '%app_mutate_v160_pre_media_028%' then 'OK' else 'FALLO' end,
    'conserva metadatos de imagen'
  union all
  select 7,'gateway solo authenticated',
    case when has_function_privilege('authenticated','public.app_mutate_v160(text,jsonb,uuid)','EXECUTE')
      and not has_function_privilege('anon','public.app_mutate_v160(text,jsonb,uuid)','EXECUTE')
      then 'OK' else 'FALLO' end,
    'permiso de ejecución'
) checks order by orden;
