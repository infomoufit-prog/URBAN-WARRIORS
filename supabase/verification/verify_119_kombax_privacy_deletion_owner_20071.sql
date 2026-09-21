-- Verify KOMBAX RC13 build 20071 · migration 119
select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_solicitudes_eliminacion' and column_name='ejecucion_iniciada_en') as deletion_started_column_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_solicitudes_eliminacion' and column_name='anonimizado_en') as anonymized_column_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_solicitudes_eliminacion' and column_name='ejecucion_resumen') as deletion_summary_column_ok,
  to_regprocedure('public.app_kombax_deletion_queue_v119(text,integer)') is not null as queue_rpc_ok,
  to_regprocedure('public.app_kombax_deletion_plan_v119(uuid)') is not null as plan_rpc_ok,
  to_regprocedure('public.app_kombax_deletion_finalize_v119(uuid,boolean,integer)') is not null as finalize_rpc_ok,
  not has_function_privilege('anon','public.app_kombax_deletion_queue_v119(text,integer)','EXECUTE') as queue_anon_denied,
  has_function_privilege('authenticated','public.app_kombax_deletion_queue_v119(text,integer)','EXECUTE') as queue_auth_rpc_available,
  position('app_kombax_es_platform_admin_v055' in pg_get_functiondef('public.app_kombax_deletion_queue_v119(text,integer)'::regprocedure))>0 as queue_owner_guard_ok,
  position('app_kombax_es_platform_admin_v055' in pg_get_functiondef('public.app_kombax_deletion_plan_v119(uuid)'::regprocedure))>0 as plan_owner_guard_ok,
  position('app_kombax_es_platform_admin_v055' in pg_get_functiondef('public.app_kombax_deletion_finalize_v119(uuid,boolean,integer)'::regprocedure))>0 as finalize_owner_guard_ok,
  position('app_kombax_es_moderador_v041' in pg_get_functiondef('public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid)'::regprocedure))=0 as moderator_not_authorized_for_privacy,
  position('PLATFORM_ADMIN_REQUIRED' in pg_get_functiondef('public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid)'::regprocedure))>0 as privacy_owner_required;
