select
  has_function_privilege('anon','public.app_kombax_registro_catalogo_publico_v087(text)','EXECUTE') as anon_registration_catalog,
  has_function_privilege('authenticated','public.app_kombax_mis_perfiles_v072()','EXECUTE') as auth_profiles_072,
  not has_function_privilege('authenticated','public.app_kombax_mis_perfiles_v043()','EXECUTE') as old_profiles_closed,
  not has_function_privilege('authenticated','public.app_kombax_mis_solicitudes_v043()','EXECUTE') as old_applications_closed,
  not has_function_privilege('anon','public.app_diagnostico_v150(uuid)','EXECUTE') as old_diag_150_anon_closed,
  not has_function_privilege('authenticated','public.app_diagnostico_v150(uuid)','EXECUTE') as old_diag_150_auth_closed,
  not has_function_privilege('anon','public.actualizar_grado_actual()','EXECUTE') as trigger_rpc_closed,
  not has_function_privilege('anon','public.tiene_rol_club(uuid,rol_club[])','EXECUTE') as role_helper_anon_closed,
  has_function_privilege('authenticated','public.tiene_rol_club(uuid,rol_club[])','EXECUTE') as role_helper_auth_ok,
  not has_table_privilege('anon','public.socios','SELECT') as socios_anon_closed,
  not has_table_privilege('anon','public.pagos','SELECT') as pagos_anon_closed,
  has_table_privilege('anon','public.clubes','SELECT') as transitional_clubes_read,
  not has_table_privilege('anon','public.textos_legales','INSERT') as legal_anon_write_closed;

select policyname,roles,cmd,qual
from pg_policies
where schemaname='public' and tablename='club_ambitos_trabajo' and policyname='ambitos_lectura_v057';

select
  exists(select 1 from pg_policies where schemaname='public' and tablename='club_ambitos_trabajo' and policyname='ambitos_lectura_v057' and qual like '%ae.club_id = club_ambitos_trabajo.club_id%') as work_scope_tautology_fixed,
  exists(select 1 from pg_policies where schemaname='public' and tablename='registros_acceso_clase' and policyname='accesos_registro_usuario' and roles='{authenticated}' and with_check like '%s.club_id = registros_acceso_clase.club_id%') as access_log_tautology_fixed;
