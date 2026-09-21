-- Verificación 073 · APIs públicas
select
 to_regprocedure('public.app_kombax_social_afiliacion_v072(uuid)') is not null as affiliation,
 to_regprocedure('public.app_kombax_social_feed_v072(timestamp with time zone,uuid,integer)') is not null as feed,
 to_regprocedure('public.app_kombax_social_directorio_v072(text,integer)') is not null as directory,
 to_regprocedure('public.app_kombax_perfil_publico_v072(uuid)') is not null as public_profile,
 to_regprocedure('public.app_kombax_mis_perfiles_v072()') is not null as my_profiles,
 to_regprocedure('public.app_kombax_album_v072(uuid)') is not null as album;
