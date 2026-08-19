select
  to_regclass('public.kombax_social_publicaciones') is not null as posts_ok,
  to_regclass('public.kombax_perfil_media') is not null as media_043_ok,
  to_regprocedure('public.app_kombax_social_mutate_v041(text,jsonb,uuid)') is not null as social_041_ok;
