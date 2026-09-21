select
  to_regclass('public.kombax_social_perfiles') is not null as social_profiles_present,
  to_regclass('public.identidades_sociales') is not null as identities_present,
  to_regprocedure('public.app_kombax_social_avatar_url_v063(uuid)') is not null as avatar_helper_present,
  to_regprocedure('public.es_miembro_club(uuid)') is not null as membership_guard_present;
