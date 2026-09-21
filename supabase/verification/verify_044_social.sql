select
  to_regclass('public.kombax_social_comentarios') is not null as comments_ok,
  to_regclass('public.kombax_social_guardados') is not null as saves_ok,
  to_regprocedure('public.app_kombax_social_feed_v044(timestamp with time zone,uuid,integer)') is not null as feed_ok,
  to_regprocedure('public.app_kombax_social_comentarios_v044(uuid,integer)') is not null as comments_rpc_ok,
  to_regprocedure('public.app_kombax_social_mutate_v044(text,jsonb,uuid)') is not null as mutate_ok;
