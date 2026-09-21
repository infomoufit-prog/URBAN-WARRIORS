-- Verificación 068 · privacidad de Relaciones.
-- Debe devolver:
--   v068 authenticated=true/anon=false
--   históricos authenticated=false
--   y la definición pública debe eliminar la clave "relations".

select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'app_kombax_relaciones_v045','app_kombax_relaciones_v068',
    'app_kombax_perfil_publico_v052','app_kombax_perfil_publico_v053',
    'app_kombax_perfil_publico_v065','app_kombax_perfil_publico_v068'
  )
order by p.proname;

select
  position($needle$v - 'relations'$needle$ in pg_get_functiondef('public.app_kombax_perfil_publico_v068(uuid)'::regprocedure))>0 as public_profile_strips_relations,
  position('app_kombax_social_puede_actuar_v051(p_social_id)' in pg_get_functiondef('public.app_kombax_relaciones_v068(uuid)'::regprocedure))>0 as private_list_checks_identity_control,
  position('KOMBAX_RELATIONS_PRIVATE' in pg_get_functiondef('public.app_kombax_relaciones_v068(uuid)'::regprocedure))>0 as private_error_present;
