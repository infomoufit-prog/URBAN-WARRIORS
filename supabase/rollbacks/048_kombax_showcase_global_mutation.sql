begin;
drop function if exists public.app_kombax_showcase_mutate_v048(text,jsonb,uuid);
drop function if exists public.app_kombax_showcase_mis_espacios_v048(uuid);
drop function if exists public.app_kombax_showcase_ensure_brand_v048(uuid);
notify pgrst,'reload schema';
commit;
