select
  to_regclass('public.kombax_eventos_publicos') is not null as events_exists,
  to_regprocedure('public.app_kombax_eventos_mutate_v171(text,jsonb,uuid)') is not null as workspace_gateway_exists,
  to_regprocedure('public.app_kombax_evento_publico_slug_v166(text)') is not null as public_slug_exists;
