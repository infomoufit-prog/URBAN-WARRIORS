do $$ begin
 if to_regprocedure('public.app_kombax_eventos_mutate_v166(text,jsonb,uuid)') is null then raise exception 'VERIFY_168: gateway missing'; end if;
 if has_function_privilege('anon','public.app_kombax_eventos_mutate_v166(text,jsonb,uuid)','execute') then raise exception 'VERIFY_168: anon execute'; end if;
end $$;
