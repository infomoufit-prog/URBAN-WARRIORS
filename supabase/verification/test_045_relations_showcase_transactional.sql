begin;
do $$ begin
  if not exists(select 1 from pg_indexes where schemaname='public' and indexname='uq_kombax_relacion_abierta_v045') then raise exception '045 relation uniqueness missing';end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.kombax_showcase_marcas'::regclass and tgname='showcase_provider_guard_v045' and not tgisinternal) then raise exception '045 provider guard missing';end if;
end $$;
rollback;
