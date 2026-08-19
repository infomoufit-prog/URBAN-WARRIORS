select
  to_regprocedure('public.app_kombax_social_directorio_v052(text,integer)') is not null as directory_ok,
  to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null as public_profile_ok,
  pg_get_functiondef('public.app_kombax_social_directorio_v052(text,integer)'::regprocedure) like '%app_kombax_social_tipo_v051%' as member_type_resolver_ok,
  pg_get_functiondef('public.app_kombax_perfil_publico_v052(uuid)'::regprocedure) like '%kombax_club_media%' as club_album_ok,
  pg_get_functiondef('public.app_kombax_perfil_publico_v052(uuid)'::regprocedure) like '%kombax_showcase_elementos%' as showcase_embedded_ok;
