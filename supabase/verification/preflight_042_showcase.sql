-- Solo lectura. Debe devolver PASS antes de ejecutar 042.
select '040_direct_profiles' control,case when to_regclass('public.perfiles_kombax_directos') is not null and to_regclass('public.kombax_entitlements') is not null then 'PASS' else 'FAIL' end resultado;
select '041_global_moderation' control,case when to_regprocedure('public.app_kombax_es_moderador_v041()') is not null then 'PASS' else 'FAIL' end resultado;
select 'mutation_governance' control,case when to_regclass('public.app_mutation_requests') is not null then 'PASS' else 'FAIL' end resultado;
select 'profiles' control,case when to_regclass('public.perfiles') is not null then 'PASS' else 'FAIL' end resultado;
