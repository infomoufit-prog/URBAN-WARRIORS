select
  to_regclass('public.kombax_social_minor_consents_v121') is not null as table_ok,
  to_regprocedure('public.app_kombax_social_minor_consent_status_v121()') is not null as status_rpc_ok,
  to_regprocedure('public.app_kombax_social_minor_consent_mutate_v121(text,jsonb,uuid)') is not null as mutate_rpc_ok,
  exists(select 1 from pg_trigger where tgrelid='public.identidades_sociales'::regclass and tgname='trg_kombax_minor_social_consent_guard_v121') as member_guard_ok,
  exists(select 1 from pg_trigger where tgrelid='public.perfiles_kombax_directos'::regclass and tgname='trg_kombax_minor_direct_social_consent_guard_v121') as direct_guard_ok,
  not has_function_privilege('anon','public.app_kombax_social_minor_consent_status_v121()','EXECUTE') as anon_denied;
