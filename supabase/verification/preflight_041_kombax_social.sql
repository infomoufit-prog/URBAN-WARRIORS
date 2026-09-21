-- Solo lectura. Debe devolver PASS antes de ejecutar 041.
select '040_gateway' control,case when to_regprocedure('public.app_mis_contextos_kombax_v040()') is not null then 'PASS' else 'FAIL' end resultado;
select '036_identity' control,case when to_regclass('public.identidades_sociales') is not null and to_regprocedure('public.app_comunidad_general_estado_v036(uuid)') is not null then 'PASS' else 'FAIL' end resultado;
select '032_sports' control,case when to_regclass('public.perfiles_deportivos') is not null then 'PASS' else 'FAIL' end resultado;
select 'mutation_governance' control,case when to_regclass('public.app_mutation_requests') is not null then 'PASS' else 'FAIL' end resultado;
select 'required_sources' control,case when to_regclass('public.clubes') is not null and to_regclass('public.socios') is not null and to_regclass('public.perfiles_kombax_directos') is not null then 'PASS' else 'FAIL' end resultado;
