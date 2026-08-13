-- AUDITORÍA FINAL 023-030 DE SOLO LECTURA.
-- No aprueba pruebas funcionales: confirma únicamente estructura y cadena SQL.
-- Resultado requerido antes de Edge Functions y APK: 10/10 OK.
select control,estado,detalle from (
  select 1 orden,'023 gateway RC10'::text control,
    case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null
      then 'OK' else 'FALLO' end estado,
    'puerta única disponible'::text detalle
  union all
  select 2,'024 finanzas',
    case when to_regclass('public.v_finanzas_detalle') is not null
      and to_regclass('public.v_finanzas_metricas_mensuales') is not null
      and to_regclass('public.v_finanzas_metricas_anuales') is not null
      then 'OK' else 'FALLO' end,
    'detalle + mensual + anual'
  union all
  select 3,'025 material',
    case when to_regprocedure('public.app_validar_retirada_material_v025(uuid)') is not null
      and to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is not null
      then 'OK' else 'FALLO' end,
    'validación y rollback'
  union all
  select 4,'026 avisos',
    case when to_regprocedure('public.procesar_avisos_cobro(date,uuid)') is not null
      and pg_get_functiondef('public.procesar_avisos_cobro(date,uuid)'::regprocedure)
        like '%Material pendiente%'
      then 'OK' else 'FALLO' end,
    'motor común cuota + material'
  union all
  select 5,'027 Comunidad',
    case when to_regclass('public.idx_comunidad_club_estado_cursor') is not null
      then 'OK' else 'FALLO' end,
    'índice cursor'
  union all
  select 6,'028 imágenes',
    case when to_regprocedure('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)') is not null
      and exists(
        select 1 from information_schema.columns
        where table_schema='public' and table_name='publicaciones_comunidad'
          and column_name='media_width'
      ) then 'OK' else 'FALLO' end,
    'metadatos multimedia'
  union all
  select 7,'029 vídeos',
    case when to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is not null
      and exists(
        select 1 from storage.buckets
        where id='community-media' and not public and file_size_limit=52428800
      ) then 'OK' else 'FALLO' end,
    'portadas + 50 MB'
  union all
  select 8,'030 multiclub',
    case when to_regprocedure('public.app_multiclub_audit_v030()') is not null
      and not exists(
        select 1 from public.app_multiclub_audit_v030()
        where not has_club_id or not rls_enabled or not tenant_index
      )
      then 'OK' else 'FALLO' end,
    'club_id + RLS'
  union all
  select 9,'cadena gateway',
    case when pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_video_029%'
      and pg_get_functiondef('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_media_028%'
      and pg_get_functiondef('public.app_mutate_v160_pre_media_028(text,jsonb,uuid)'::regprocedure)
        like '%app_mutate_v160_pre_material_025%'
      then 'OK' else 'FALLO' end,
    '029 → 028 → 025 → RC10'
  union all
  select 10,'escritura directa cerrada',
    case when not exists(select 1 from public.app_multiclub_audit_v030() where direct_client_dml)
      then 'OK' else 'FALLO' end,
    'frontend escribe por gateway'
) checks order by orden;
