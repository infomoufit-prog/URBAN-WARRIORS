select
 not has_function_privilege('authenticated','public.app_generar_sesiones_recurrentes(uuid,integer)','EXECUTE') as recurring_client_closed,
 has_function_privilege('service_role','public.app_generar_sesiones_recurrentes(uuid,integer)','EXECUTE') as recurring_service_open,
 not has_function_privilege('authenticated','public.app_kombax_codigo_validar_seguro_v086(text,text,text)','EXECUTE') as validator_helper_internal,
 not has_function_privilege('authenticated','public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text)','EXECUTE') as relation_helper_internal,
 not has_function_privilege('authenticated','public.app_kombax_social_avatar_path_v058(uuid)','EXECUTE') as avatar_helper_internal,
 not has_function_privilege('authenticated','public.app_multiclub_audit_v030()','EXECUTE') as old_audit_closed;
