do $$ begin
 if to_regprocedure('public.app_kombax_eventos_mutate_v164(text,jsonb,uuid)') is null then raise exception 'PRECHECK_165: falta 164'; end if;
 if to_regclass('storage.objects') is null then raise exception 'PRECHECK_165: Storage no disponible'; end if;
end $$;
