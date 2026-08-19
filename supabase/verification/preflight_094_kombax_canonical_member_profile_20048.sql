select
  to_regclass('public.identidades_sociales') is not null as identities_present,
  to_regclass('public.perfiles_deportivos') is not null as legacy_present,
  to_regprocedure('public.app_kombax_perfil_publico_v083(uuid)') is not null as public_profile_083_present,
  to_regprocedure('public.app_kombax_identity_mutate_v065(text,jsonb,uuid)') is not null as identity_065_present,
  to_regprocedure('public.app_kombax_social_switch_competitor_v072(uuid)') is not null as competitor_switch_present,
  not has_table_privilege('authenticated','public.perfiles_deportivos','SELECT') as legacy_direct_select_private;
