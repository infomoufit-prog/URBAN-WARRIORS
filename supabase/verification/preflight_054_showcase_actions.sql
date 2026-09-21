select
  to_regclass('public.kombax_showcase_elementos') is not null as showcase_ok,
  to_regprocedure('public.app_kombax_showcase_mutate_v048(text,jsonb,uuid)') is not null as mutation_048_ok,
  to_regclass('public.kombax_actor_audit') is not null as audit_051_ok;
