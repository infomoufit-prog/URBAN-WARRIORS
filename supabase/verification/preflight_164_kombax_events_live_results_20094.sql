do $$ begin
 if to_regclass('public.kombax_evento_combates_publicos') is null then raise exception 'PRECHECK_164: falta 161'; end if;
 if to_regprocedure('public.app_kombax_eventos_mutate_v162(text,jsonb,uuid)') is null then raise exception 'PRECHECK_164: falta 162'; end if;
end $$;
