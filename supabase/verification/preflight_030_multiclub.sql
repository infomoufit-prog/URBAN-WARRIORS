-- PRECHECK 030 DE SOLO LECTURA.
-- Resultado obligatorio antes de pegar 030_multiclub_rls_performance.sql: 10/10 OK.
select control,estado,detalle from (
  select 1 orden,'gateway 029 activo'::text control,
    case when to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is not null
      and pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_video_029%' then 'OK' else 'FALLO' end estado,
    'vídeo dentro de la cadena activa'::text detalle
  union all
  select 2,'cadena 025-029 íntegra',
    case when to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is not null
      and to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is not null
      and pg_get_functiondef('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_media_028%'
      and pg_get_functiondef('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_material_025%' then 'OK' else 'FALLO' end,
    '029 → 028 → 025'
  union all
  select 3,'columnas vídeo',
    case when count(*)=2 then 'OK' else 'FALLO' end,
    count(*)::text||'/2 columnas'
  from information_schema.columns
  where table_schema='public' and table_name='publicaciones_comunidad'
    and column_name in ('portada_automatica_path','portada_manual_path')
  union all
  select 4,'bucket vídeo 50 MB',
    case when exists(
      select 1 from storage.buckets
      where id='community-media' and not public and file_size_limit=52428800
    ) then 'OK' else 'FALLO' end,
    'community-media privado'
  union all
  select 5,'tablas 030 disponibles',
    case when count(*)=15 then 'OK' else 'FALLO' end,
    count(*)::text||'/15 tablas'
  from information_schema.tables
  where table_schema='public' and table_type='BASE TABLE' and table_name=any(array[
    'perfiles','comunicaciones','publicaciones_comunidad','cuotas','pagos','recibos_cuota',
    'material_catalogo','material_variantes','material_pedidos','material_entregas',
    'dispositivos_push','preferencias_notificacion','notificaciones','notificaciones_lecturas',
    'configuracion_avisos_cuota'
  ])
  union all
  select 6,'columnas push',
    case when count(*)=6 then 'OK' else 'FALLO' end,
    count(*)::text||'/6 columnas'
  from information_schema.columns
  where table_schema='public' and (
    (table_name='dispositivos_push' and column_name in ('club_id','perfil_id','activo','ultimo_uso'))
    or (table_name='notificaciones' and column_name in ('push_enviado_en','push_intentos'))
  )
  union all
  select 7,'RLS base activo',
    case when count(*)=3 and bool_and(c.relrowsecurity) then 'OK' else 'FALLO' end,
    count(*)::text||'/3 tablas'
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in (
    'dispositivos_push','preferencias_notificacion','notificaciones_lecturas'
  )
  union all
  select 8,'auditor 030 pendiente',
    case when to_regprocedure('public.app_multiclub_audit_v030()') is null then 'OK' else 'FALLO' end,
    'evita mezclar una aplicación previa'
  union all
  select 9,'snapshot 030 pendiente',
    case when to_regclass('public.app_privilege_snapshot_v030') is null then 'OK' else 'FALLO' end,
    'se creará al aplicar 030'
  union all
  select 10,'índices 030 pendientes',
    case when count(*)=0 then 'OK' else 'FALLO' end,
    count(*)::text||' índices ya presentes'
  from pg_indexes where schemaname='public' and indexname=any(array[
    'idx_socios_club_nombre','idx_sesiones_club_fecha','idx_comunicaciones_club_feed',
    'idx_material_catalogo_club_activo','idx_material_variantes_club_material',
    'idx_dispositivos_push_club_activos','idx_notificaciones_club_feed',
    'idx_notificaciones_dispatch_pendiente','idx_notificaciones_lecturas_perfil',
    'idx_mutation_requests_club_created'
  ])
) checks order by orden;
