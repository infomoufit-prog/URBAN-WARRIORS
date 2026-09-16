do $$ begin
 if to_regprocedure('public.app_kombax_evento_publico_slug_v166(text)') is null then raise exception 'VERIFY_166: slug'; end if;
 if to_regprocedure('public.app_kombax_evento_historial_competidor_v166(uuid,integer)') is null then raise exception 'VERIFY_166: history'; end if;
 if has_table_privilege('anon','public.kombax_evento_media','select') or has_table_privilege('authenticated','public.kombax_evento_media','select') then raise exception 'VERIFY_166: direct media select exposed'; end if;
 if has_function_privilege('anon','public.app_kombax_eventos_mutate_v166(text,jsonb,uuid)','execute') then raise exception 'VERIFY_166: anon mutate'; end if;
end $$;
