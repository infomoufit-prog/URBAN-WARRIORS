-- Verificación 074 · mutaciones
select
 to_regprocedure('public.app_kombax_perfil_mutate_v072(text,jsonb,uuid)') is not null as mutator_v072,
 has_function_privilege('authenticated','public.app_kombax_perfil_mutate_v072(text,jsonb,uuid)','EXECUTE') as new_mutator_open,
 not has_function_privilege('authenticated','public.app_kombax_perfil_mutate_v043(text,jsonb,uuid)','EXECUTE') as old_mutator_closed,
 not has_function_privilege('anon','public.app_kombax_perfil_mutate_v072(text,jsonb,uuid)','EXECUTE') as anon_closed;
