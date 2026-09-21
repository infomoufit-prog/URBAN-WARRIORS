begin;
select
  public.app_kombax_es_platform_admin_v055() in (true,false) as platform_admin_auth_callable,
  to_regprocedure('public.app_kombax_platform_profiles_v055(text,integer)') is not null as profiles_search_callable,
  pg_get_functiondef('public.app_kombax_es_moderador_v041()'::regprocedure) like '%app_kombax_es_platform_admin_v055%' as platform_admin_moderation_integrated;
rollback;
