-- PRECHECK de solo lectura antes de aplicar 024–030.
-- Resultado esperado: gateway/meta OK y todas las migraciones 024–030 PENDIENTE.
select control,estado,detalle from (
  select 1 orden,'gateway RC10 activo'::text control,
    case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end estado,
    coalesce((select mutation_endpoint||' · '||backend_version||' · epoch '||schema_epoch from public.app_runtime_meta where singleton),'sin metadata') detalle
  union all
  select 2,'024 finanzas',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='cuotas' and column_name='origen') then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'columna cuotas.origen'
  union all
  select 3,'025 material',case when to_regprocedure('public.app_validar_retirada_material_v025(uuid)') is not null then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'validador material'
  union all
  select 4,'026 avisos',case when pg_get_functiondef(to_regprocedure('public.procesar_avisos_cobro(date,uuid)')) like '%Material pendiente%' then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'motor común'
  union all
  select 5,'027 Comunidad',case when to_regclass('public.idx_comunidad_club_estado_cursor') is not null then 'APLICADA' else 'PENDIENTE' end,'índice cursor'
  union all
  select 6,'028 imágenes',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='publicaciones_comunidad' and column_name='media_size_bytes') then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'metadatos multimedia'
  union all
  select 7,'029 vídeos',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='publicaciones_comunidad' and column_name='portada_automatica_path') then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'paths de portada'
  union all
  select 8,'030 multiclub',case when to_regprocedure('public.app_multiclub_audit_v030()') is not null then 'APLICADA/PARCIAL' else 'PENDIENTE' end,'diagnóstico tenant'
) checks order by orden;
