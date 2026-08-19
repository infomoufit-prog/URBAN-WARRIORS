begin;
do $$ begin
 if to_regclass('public.kombax_aceptaciones_globales') is null then raise exception '049 consent missing';end if;
 if to_regprocedure('public.app_kombax_social_mutate_v049(text,jsonb,uuid)') is null then raise exception '049 mutation missing';end if;
end $$;
rollback;
