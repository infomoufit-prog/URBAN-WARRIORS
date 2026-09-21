select to_regprocedure('public.app_kombax_showcase_ensure_brand_v048(uuid)') is not null as ensure_brand_ok,
       to_regprocedure('public.app_kombax_showcase_mis_espacios_v048(uuid)') is not null as spaces_ok,
       to_regprocedure('public.app_kombax_showcase_mutate_v048(text,jsonb,uuid)') is not null as mutate_ok;
