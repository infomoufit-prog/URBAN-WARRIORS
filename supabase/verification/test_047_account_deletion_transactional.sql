begin;
do $$ begin
  if to_regclass('public.kombax_solicitudes_eliminacion') is null then raise exception '047 table missing';end if;
  if to_regprocedure('public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid)') is null then raise exception '047 mutation missing';end if;
end $$;
rollback;
