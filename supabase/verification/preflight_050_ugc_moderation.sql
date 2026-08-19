-- PRE-FLIGHT 050 · no modifica datos.
select
  to_regclass('public.kombax_social_reportes') is not null as reportes_ok,
  to_regclass('public.kombax_social_comentarios') is not null as comentarios_ok,
  to_regclass('public.kombax_social_moderacion') is not null as moderacion_ok,
  to_regprocedure('public.app_kombax_social_mutate_v049(text,jsonb,uuid)') is not null as gateway_049_ok,
  to_regprocedure('public.app_kombax_es_moderador_v041()') is not null as moderador_ok;
