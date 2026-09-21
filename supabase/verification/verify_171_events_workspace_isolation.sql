select
  to_regprocedure('public.app_kombax_eventos_organizador_contexto_v171(uuid)') is not null as organizer_context_rpc,
  to_regprocedure('public.app_kombax_evento_contexto_gestion_v171(uuid,uuid)') is not null as context_manage_rpc,
  to_regprocedure('public.app_kombax_eventos_mutate_v171(text,jsonb,uuid)') is not null as mutate_rpc,
  not has_function_privilege('anon','public.app_kombax_eventos_mutate_v171(text,jsonb,uuid)','EXECUTE') as anon_mutate_blocked,
  has_function_privilege('authenticated','public.app_kombax_eventos_mutate_v171(text,jsonb,uuid)','EXECUTE') as auth_mutate_allowed;
