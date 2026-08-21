-- KOMBAX 20066 / verification 110. Solo lectura.
select
  to_regprocedure('public.app_kombax_platform_admin_password_complete_v110(uuid)') is not null as password_complete,
  has_function_privilege('anon','public.app_kombax_platform_admin_password_complete_v110(uuid)','EXECUTE') as anon_execute,
  has_function_privilege('authenticated','public.app_kombax_platform_admin_password_complete_v110(uuid)','EXECUTE') as authenticated_execute;

select pg_get_functiondef('public.app_kombax_platform_admin_password_complete_v110(uuid)'::regprocedure) as function_def;
