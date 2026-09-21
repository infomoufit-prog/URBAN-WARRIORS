select
  to_regclass('public.kombax_platform_admins') is not null as admins_ok,
  to_regprocedure('public.app_kombax_es_platform_admin_v055()') is not null as auth_ok,
  to_regprocedure('public.app_kombax_platform_context_v055()') is not null as context_ok,
  to_regprocedure('public.app_kombax_platform_dashboard_v055()') is not null as dashboard_ok,
  to_regprocedure('public.app_kombax_platform_profiles_v055(text,integer)') is not null as profiles_search_ok,
  to_regprocedure('public.app_kombax_platform_club_v055(uuid)') is not null as club_ok,
  to_regprocedure('public.app_kombax_platform_mutate_v055(text,jsonb,uuid)') is not null as mutate_ok,
  pg_get_functiondef('public.app_kombax_es_moderador_v041()'::regprocedure) like '%app_kombax_es_platform_admin_v055%' as platform_moderation_ok,
  pg_get_functiondef('public.app_kombax_platform_dashboard_v055()'::regprocedure) like '%pendiente%en_revision%' as current_report_states_ok;
