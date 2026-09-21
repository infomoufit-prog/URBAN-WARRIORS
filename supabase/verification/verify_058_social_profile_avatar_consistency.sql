select '058.01 avatar helper' check_name,to_regprocedure('public.app_kombax_social_avatar_path_v058(uuid)') is not null ok
union all select '058.02 banner helper',to_regprocedure('public.app_kombax_social_banner_path_v058(uuid)') is not null
union all select '058.03 sync function',to_regprocedure('public.app_kombax_social_media_sync_profile_v058()') is not null
union all select '058.04 sync trigger',exists(select 1 from pg_trigger where tgname='kombax_social_media_sync_profile_v058' and not tgisinternal)
union all select '058.05 feed canonical avatar',position('app_kombax_social_avatar_path_v058' in pg_get_functiondef(to_regprocedure('public.app_kombax_social_feed_v053(timestamp with time zone,uuid,integer)')))>0
union all select '058.06 directory canonical avatar',position('app_kombax_social_avatar_path_v058' in pg_get_functiondef(to_regprocedure('public.app_kombax_social_directorio_v052(text,integer)')))>0
union all select '058.07 public profile canonical avatar',position('app_kombax_social_avatar_path_v058' in pg_get_functiondef(to_regprocedure('public.app_kombax_perfil_publico_v053(uuid)')))>0;
