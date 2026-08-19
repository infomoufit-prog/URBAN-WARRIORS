select
  to_regclass('public.kombax_social_perfiles') is not null as social_profiles_ok,
  to_regclass('public.identidades_sociales') is not null as member_identity_ok,
  to_regclass('public.miembros_club') is not null as memberships_ok,
  to_regprocedure('public.app_kombax_social_mutate_v050(text,jsonb,uuid)') is not null as social_050_ok;
