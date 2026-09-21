-- Verificación 075
select to_regprocedure('public.app_kombax_social_feed_v072(timestamp with time zone,uuid,integer)') is not null as feed, to_regprocedure('public.app_kombax_social_directorio_v072(text,integer)') is not null as directory, to_regprocedure('public.app_kombax_perfil_publico_v072(uuid)') is not null as public_profile;
