select
  to_regclass('public.kombax_perfil_gestores') is not null as gestores_table,
  to_regclass('public.kombax_verificacion_eventos') is not null as verification_events_table,
  exists(select 1 from pg_indexes where schemaname='public' and indexname='uq_kombax_competidor_por_cuenta_v070') as competitor_unique,
  exists(select 1 from pg_indexes where schemaname='public' and indexname='uq_kombax_solicitud_directa_abierta_v070') as direct_application_unique;

select
  count(*) filter(where g.rol='owner' and g.estado='activo') = (select count(*) from public.perfiles_kombax_directos) as every_profile_has_owner_manager
from public.kombax_perfil_gestores g;

select
  has_function_privilege('authenticated','public.app_kombax_puede_gestionar_perfil_v070(uuid,text)','EXECUTE') as manager_guard_auth,
  not has_function_privilege('anon','public.app_kombax_puede_gestionar_perfil_v070(uuid,text)','EXECUTE') as manager_guard_no_anon;
