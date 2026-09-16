do $$ begin
 if to_regclass('public.idx_kombax_evento_combates_resultado_actualizado_por_v169') is null then raise exception 'VERIFY_169: result actor index'; end if;
 if to_regclass('public.idx_kombax_evento_media_creado_por_v169') is null then raise exception 'VERIFY_169: media creator index'; end if;
end $$;
