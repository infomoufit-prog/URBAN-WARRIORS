select to_regclass('public.kombax_evento_interes') is not null as interest_table,
       to_regclass('public.kombax_evento_social_links') is not null as social_bridge_table,
       to_regprocedure('public.app_kombax_evento_publico_slug_v162(text)') is not null as public_slug_rpc,
       to_regprocedure('public.app_kombax_eventos_mutate_v162(text,jsonb,uuid)') is not null as mutation_rpc;
select c.relname,c.relrowsecurity,
       has_table_privilege('anon',c.oid,'select') as anon_select,
       has_table_privilege('authenticated',c.oid,'select') as authenticated_select
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('kombax_evento_interes','kombax_evento_social_links') order by c.relname;
