do $$ begin
 if to_regprocedure('public.app_kombax_eventos_mutate_v165(text,jsonb,uuid)') is null then raise exception 'PRECHECK_166: falta 165'; end if;
end $$;
