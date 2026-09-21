do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_evento_combates_publicos' and column_name='resultado_estado') then raise exception 'VERIFY_164: resultado_estado'; end if;
 if to_regprocedure('public.app_kombax_eventos_live_v164(integer)') is null then raise exception 'VERIFY_164: live rpc'; end if;
 if to_regprocedure('public.app_kombax_eventos_mutate_v164(text,jsonb,uuid)') is null then raise exception 'VERIFY_164: mutate'; end if;
end $$;
