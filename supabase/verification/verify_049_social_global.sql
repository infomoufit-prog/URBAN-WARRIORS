select exists(select 1 from information_schema.columns where table_schema='public' and table_name='perfiles_kombax_directos' and column_name='social_activo') as opt_in_ok,
       to_regclass('public.kombax_aceptaciones_globales') is not null as global_consent_ok,
       to_regprocedure('public.app_kombax_social_estado_v049(uuid)') is not null as status_ok,
       to_regprocedure('public.app_kombax_social_mutate_v049(text,jsonb,uuid)') is not null as mutation_ok;
