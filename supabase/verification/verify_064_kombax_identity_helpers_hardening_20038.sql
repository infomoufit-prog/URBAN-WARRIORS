-- Verificación build 20038 · helpers 063 no expuestos directamente.
select p.proname,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('app_kombax_social_avatar_url_v063','app_kombax_social_banner_url_v063')
order by p.proname;
