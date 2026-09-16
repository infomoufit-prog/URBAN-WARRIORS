-- Non-destructive rollback for 20.098. Keep additive columns/data; remove only the 20.098 RPC surface.
begin;
drop function if exists public.app_kombax_eventos_mutate_v173(text,jsonb,uuid);
drop function if exists public.app_kombax_evento_publico_slug_v173(text);
drop function if exists public.app_kombax_evento_publico_detalle_v173(uuid);
drop function if exists public.app_kombax_eventos_publicos_v173(text,text,text,integer);
drop function if exists public.app_kombax_evento_entradas_estado_v173(uuid);
drop function if exists public.app_kombax_evento_inscripciones_estado_v173(uuid);
commit;
