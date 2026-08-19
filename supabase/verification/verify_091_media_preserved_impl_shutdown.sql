select
 not has_function_privilege('anon','public.app_kombax_social_media_v053_pre_media_v085(uuid)','EXECUTE')
 and not has_function_privilege('authenticated','public.app_kombax_social_media_v053_pre_media_v085(uuid)','EXECUTE') as media_impl_internal,
 not has_function_privilege('anon','public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer)','EXECUTE')
 and not has_function_privilege('authenticated','public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer)','EXECUTE') as feed_impl_internal,
 not has_function_privilege('anon','public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid)','EXECUTE')
 and not has_function_privilege('authenticated','public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid)','EXECUTE') as mutate_impl_internal;
