-- Verificación 075 · administración/hardening
select
 to_regprocedure('public.app_kombax_media_mutate_v072(text,jsonb,uuid)') is not null as media_v072,
 to_regprocedure('public.app_kombax_platform_application_v072(uuid)') is not null as admin_application,
 to_regprocedure('public.app_kombax_platform_dashboard_v072()') is not null as dashboard,
 to_regprocedure('public.app_kombax_platform_profiles_v072(text,integer)') is not null as profiles,
 position('KOMBAX_OWNER_ROLE_IMMUTABLE' in pg_get_functiondef('public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid)'::regprocedure))>0 as owner_role_immutable;
select
 not has_function_privilege('authenticated','public.app_kombax_media_mutate_v043(text,jsonb,uuid)','EXECUTE') as old_media_closed,
 not has_function_privilege('authenticated','public.app_kombax_social_feed_v065(timestamp with time zone,uuid,integer)','EXECUTE') as old_feed_closed,
 not has_function_privilege('authenticated','public.app_kombax_social_directorio_v065(text,integer)','EXECUTE') as old_directory_closed;
