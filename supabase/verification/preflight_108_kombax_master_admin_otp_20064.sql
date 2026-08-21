-- KOMBAX 20.064 / preflight 108. Ejecutar ANTES de aplicar la migración; no modifica datos.
select
  to_regclass('public.kombax_platform_admins') is not null as platform_admins_table,
  to_regclass('public.perfiles') is not null as perfiles_table,
  to_regprocedure('public.app_kombax_es_platform_admin_v055()') is not null as platform_helper,
  to_regprocedure('public.app_kombax_platform_context_v055()') is not null as platform_context,
  to_regprocedure('public.app_kombax_platform_admin_challenge_start_v108()') is not null as v108_already_present,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='pg_catalog' and p.proname='gen_random_uuid') as gen_random_uuid_available;

select count(*) as active_platform_admins from public.kombax_platform_admins where activo;
