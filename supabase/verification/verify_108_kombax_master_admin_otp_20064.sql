-- KOMBAX 20.064 / verification 108. Solo lectura.
select
  to_regclass('public.kombax_platform_admin_challenges') is not null as challenges_table,
  to_regclass('public.kombax_platform_admin_sessions') is not null as sessions_table,
  to_regprocedure('public.app_kombax_platform_admin_challenge_start_v108()') is not null as challenge_start,
  to_regprocedure('public.app_kombax_platform_admin_challenge_complete_v108(uuid)') is not null as challenge_complete,
  to_regprocedure('public.app_kombax_platform_admin_session_end_v108()') is not null as session_end,
  to_regprocedure('public.app_kombax_platform_context_v055()') is not null as platform_context;

select
  c.relname,
  c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('kombax_platform_admin_challenges','kombax_platform_admin_sessions')
order by c.relname;

select p.proname,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
  'app_kombax_platform_admin_challenge_start_v108',
  'app_kombax_platform_admin_challenge_complete_v108',
  'app_kombax_platform_admin_session_end_v108',
  'app_kombax_platform_context_v055',
  'app_kombax_es_platform_admin_v055',
  'app_kombax_auth_method_recent_v108'
)
order by p.proname;
