-- Verificación 078
select to_regprocedure('public.app_kombax_media_mutate_v072(text,jsonb,uuid)') is not null as media, not has_function_privilege('authenticated','public.app_kombax_media_mutate_v043(text,jsonb,uuid)','EXECUTE') as old_media_closed;
