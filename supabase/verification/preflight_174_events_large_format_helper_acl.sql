select
  to_regprocedure('public.app_kombax_evento_inscripciones_estado_v173(uuid)') is not null as registration_helper_exists,
  to_regprocedure('public.app_kombax_evento_entradas_estado_v173(uuid)') is not null as ticket_helper_exists,
  to_regprocedure('public.app_kombax_eventos_publicos_v173(text,text,text,integer)') is not null as public_reader_exists;
