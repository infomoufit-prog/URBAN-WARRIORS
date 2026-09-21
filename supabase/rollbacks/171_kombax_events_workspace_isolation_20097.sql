begin;
drop function if exists public.app_kombax_eventos_mutate_v171(text,jsonb,uuid);
drop function if exists public.app_kombax_evento_contexto_gestion_v171(uuid,uuid);
drop function if exists public.app_kombax_eventos_organizador_contexto_v171(uuid);
notify pgrst,'reload schema';
commit;
