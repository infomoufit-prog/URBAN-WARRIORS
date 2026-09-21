select
  not has_function_privilege('authenticated','public.app_kombax_contactos_v065()','EXECUTE') as contact_list_065_closed,
  not has_function_privilege('authenticated','public.app_kombax_contact_mensajes_v065(uuid)','EXECUTE') as contact_messages_065_closed,
  has_function_privilege('authenticated','public.app_kombax_contactos_v067()','EXECUTE') as contact_list_067_open,
  not has_function_privilege('authenticated','public.app_kombax_identity_mutate_v051(text,jsonb,uuid)','EXECUTE') as identity_051_closed,
  has_function_privilege('authenticated','public.app_kombax_identity_mutate_v065(text,jsonb,uuid)','EXECUTE') as identity_065_open,
  not has_function_privilege('authenticated','public.app_kombax_platform_dashboard_v055()','EXECUTE') as platform_055_closed,
  has_function_privilege('authenticated','public.app_kombax_platform_dashboard_v072()','EXECUTE') as platform_072_open,
  not has_function_privilege('anon','public.app_kombax_showcase_list_v042(text,text,timestamptz,uuid,integer)','EXECUTE') as showcase_042_anon_closed,
  has_function_privilege('anon','public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer)','EXECUTE') as showcase_054_public,
  not has_function_privilege('authenticated','public.app_kombax_social_directorio_v052(text,integer)','EXECUTE') as directory_052_closed,
  has_function_privilege('authenticated','public.app_kombax_social_directorio_v072(text,integer)','EXECUTE') as directory_072_open;
