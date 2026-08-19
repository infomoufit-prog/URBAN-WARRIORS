select
  not has_function_privilege('authenticated','public.app_kombax_badge_tipo_v069(uuid)','EXECUTE') as badge_type_internal,
  not has_function_privilege('authenticated','public.app_kombax_badge_visible_v069(uuid)','EXECUTE') as badge_visible_internal,
  not has_function_privilege('authenticated','public.app_kombax_perfil_servicio_v071(uuid)','EXECUTE') as service_internal,
  not has_function_privilege('authenticated','public.app_kombax_perfil_servicio_activo_v071(uuid)','EXECUTE') as service_active_internal,
  not has_function_privilege('authenticated','public.app_kombax_plan_limite_v071(uuid,text)','EXECUTE') as plan_limit_internal;
