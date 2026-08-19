select
  to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null as identity_051_ok,
  to_regclass('public.perfiles_club_publicos') is not null as club_profiles_ok,
  to_regclass('public.kombax_relaciones') is not null as relations_ok,
  to_regclass('public.kombax_showcase_elementos') is not null as showcase_ok;
