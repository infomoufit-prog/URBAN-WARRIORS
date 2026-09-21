select
  to_regclass('public.kombax_social_perfiles') is not null as social_ok,
  to_regclass('public.kombax_showcase_marcas') is not null as showcase_ok,
  to_regprocedure('public.app_kombax_showcase_puede_gestionar_v042(uuid)') is not null as showcase_auth_042_ok;
