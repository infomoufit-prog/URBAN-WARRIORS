select
  to_regprocedure('public.app_kombax_header_activity_v103()') is not null as header_activity_present,
  has_function_privilege('authenticated','public.app_kombax_header_activity_v103()','EXECUTE') as authenticated_execute,
  not has_function_privilege('anon','public.app_kombax_header_activity_v103()','EXECUTE') as anon_closed,
  position('security definer' in lower(pg_get_functiondef('public.app_kombax_header_activity_v103()'::regprocedure)))>0 as security_definer;
