-- Verificación 077
select to_regprocedure('public.app_kombax_perfil_mutate_v072(text,jsonb,uuid)') is not null as mutator, not has_function_privilege('authenticated','public.app_kombax_perfil_mutate_v043(text,jsonb,uuid)','EXECUTE') as old_closed;
