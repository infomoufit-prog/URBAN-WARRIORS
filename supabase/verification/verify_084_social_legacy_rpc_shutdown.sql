select
  not has_function_privilege('authenticated','public.app_kombax_social_feed_v041(timestamptz,uuid,integer)','EXECUTE') as feed_041_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_feed_v044(timestamptz,uuid,integer)','EXECUTE') as feed_044_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_feed_v053(timestamptz,uuid,integer)','EXECUTE') as feed_053_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_comentarios_v044(uuid,integer)','EXECUTE') as comments_044_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_mutate_v053(text,jsonb,uuid)','EXECUTE') as mutate_053_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_mutate_v065(text,jsonb,uuid)','EXECUTE') as mutate_065_closed,
  not has_function_privilege('authenticated','public.app_kombax_perfil_publico_v068(uuid)','EXECUTE') as profile_068_closed,
  has_function_privilege('authenticated','public.app_kombax_social_feed_v083(timestamptz,uuid,integer)','EXECUTE') as feed_083_open,
  has_function_privilege('authenticated','public.app_kombax_social_comentarios_v083(uuid,integer)','EXECUTE') as comments_083_open,
  has_function_privilege('authenticated','public.app_kombax_social_mutate_v083(text,jsonb,uuid)','EXECUTE') as mutate_083_open,
  has_function_privilege('authenticated','public.app_kombax_perfil_publico_v083(uuid)','EXECUTE') as profile_083_open;
