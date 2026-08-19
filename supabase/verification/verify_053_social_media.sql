select
  to_regclass('public.kombax_social_media') is not null as social_media_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_publicaciones' and column_name='social_media_id') as post_media_link_ok,
  to_regprocedure('public.app_kombax_social_media_v053(uuid)') is not null as media_list_ok,
  to_regprocedure('public.app_kombax_social_feed_v053(timestamptz,uuid,integer)') is not null as feed_ok,
  to_regprocedure('public.app_kombax_perfil_publico_v053(uuid)') is not null as public_profile_ok,
  to_regprocedure('public.app_kombax_social_mutate_v053(text,jsonb,uuid)') is not null as mutation_ok,
  pg_get_functiondef('public.app_kombax_social_mutate_v053(text,jsonb,uuid)'::regprocedure) like '%KOMBAX_POST_DAILY_LIMIT_3%' as limits_ok;
