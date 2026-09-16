select
  not has_function_privilege('anon','public.app_kombax_evento_inscripciones_estado_v173(uuid)','execute') as anon_registration_helper_blocked,
  not has_function_privilege('authenticated','public.app_kombax_evento_inscripciones_estado_v173(uuid)','execute') as auth_registration_helper_blocked,
  not has_function_privilege('anon','public.app_kombax_evento_entradas_estado_v173(uuid)','execute') as anon_ticket_helper_blocked,
  not has_function_privilege('authenticated','public.app_kombax_evento_entradas_estado_v173(uuid)','execute') as auth_ticket_helper_blocked,
  has_function_privilege('service_role','public.app_kombax_evento_inscripciones_estado_v173(uuid)','execute') as service_registration_helper,
  has_function_privilege('service_role','public.app_kombax_evento_entradas_estado_v173(uuid)','execute') as service_ticket_helper,
  has_function_privilege('anon','public.app_kombax_eventos_publicos_v173(text,text,text,integer)','execute') as anon_public_reader,
  has_function_privilege('anon','public.app_kombax_evento_publico_detalle_v173(uuid)','execute') as anon_public_detail,
  has_function_privilege('anon','public.app_kombax_evento_publico_slug_v173(text)','execute') as anon_public_slug;
