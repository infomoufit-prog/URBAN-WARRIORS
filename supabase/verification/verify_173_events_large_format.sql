select
  to_regprocedure('public.app_kombax_eventos_publicos_v173(text,text,text,integer)') is not null as list_v173,
  to_regprocedure('public.app_kombax_evento_publico_detalle_v173(uuid)') is not null as detail_v173,
  to_regprocedure('public.app_kombax_evento_publico_slug_v173(text)') is not null as slug_v173,
  to_regprocedure('public.app_kombax_eventos_mutate_v173(text,jsonb,uuid)') is not null as mutate_v173,
  has_function_privilege('anon','public.app_kombax_eventos_mutate_v173(text,jsonb,uuid)','execute') as anon_can_mutate,
  has_function_privilege('authenticated','public.app_kombax_eventos_mutate_v173(text,jsonb,uuid)','execute') as auth_can_mutate,
  has_table_privilege('anon','public.kombax_eventos_publicos','select') as anon_direct_select,
  has_table_privilege('authenticated','public.kombax_eventos_publicos','select') as auth_direct_select;
