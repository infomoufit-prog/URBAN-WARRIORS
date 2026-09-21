select
  to_regclass('public.kombax_relaciones') is not null as relations_ok,
  to_regprocedure('public.app_kombax_relacion_mutate_v045(text,jsonb,uuid)') is not null as relation_mutate_ok,
  to_regprocedure('public.app_kombax_showcase_mis_espacios_v045(uuid)') is not null as spaces_ok,
  to_regprocedure('public.app_kombax_showcase_puede_gestionar_v045(uuid)') is not null as provider_auth_ok,
  exists(select 1 from pg_trigger where tgrelid='public.kombax_showcase_elementos'::regclass and tgname='showcase_item_guard_v045' and not tgisinternal) as limits_guard_ok;
