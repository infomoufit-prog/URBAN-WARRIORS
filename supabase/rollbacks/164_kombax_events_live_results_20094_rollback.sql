begin;
drop function if exists public.app_kombax_eventos_mutate_v164(text,jsonb,uuid);
drop function if exists public.app_kombax_evento_resultados_v164(uuid);
drop function if exists public.app_kombax_eventos_live_v164(integer);
drop function if exists public.app_kombax_evento_estado_temporal_v164(uuid);
drop index if exists public.idx_kombax_evento_combates_resultado_v164;
alter table public.kombax_evento_combates_publicos drop constraint if exists kombax_evento_combate_resultado_estado_ck,drop constraint if exists kombax_evento_combate_resultado_notas_ck,drop column if exists resultado_estado,drop column if exists resultado_publicado_en,drop column if exists resultado_actualizado_por,drop column if exists resultado_notas_publicas;
commit;
