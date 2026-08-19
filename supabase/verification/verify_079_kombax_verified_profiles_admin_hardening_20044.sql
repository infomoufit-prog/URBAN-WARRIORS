-- Verificación 079
select to_regprocedure('public.app_kombax_platform_application_v072(uuid)') is not null as admin_app, to_regprocedure('public.app_kombax_platform_dashboard_v072()') is not null as dashboard, position('KOMBAX_OWNER_ROLE_IMMUTABLE' in pg_get_functiondef('public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid)'::regprocedure))>0 as owner_immutable;
