select
  to_regclass('public.kombax_verificadores_globales_v117') is not null as verifier_table,
  to_regclass('public.kombax_pilot_readiness_v117') is not null as readiness_table,
  to_regclass('public.kombax_client_incidents_v117') is not null as incidents_table,
  to_regprocedure('public.app_kombax_es_verificador_v117()') is not null as verifier_gate,
  to_regprocedure('public.app_kombax_platform_profiles_v117(text,integer)') is not null as canonical_profile_search,
  exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_verification_docs_select_v117') as private_docs_select,
  not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_verification_docs_select_v043') as old_moderator_policy_removed;

select control,verificado,verificado_en from public.kombax_pilot_readiness_v117 order by control;
