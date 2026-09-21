begin;
do $$ begin
 if to_regprocedure('public.app_kombax_showcase_mutate_v048(text,jsonb,uuid)') is null then raise exception '048 mutation missing';end if;
end $$;
rollback;
