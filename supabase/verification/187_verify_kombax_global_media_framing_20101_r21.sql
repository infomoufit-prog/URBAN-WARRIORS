select table_name,column_name,data_type from information_schema.columns
where table_schema='public' and (
 (table_name='kombax_evento_participantes_publicos' and column_name='media_presentation') or
 (table_name='kombax_evento_media' and column_name='media_presentation') or
 (table_name='kombax_social_media' and column_name='media_presentation') or
 (table_name='kombax_perfil_media' and column_name='media_presentation') or
 (table_name='kombax_club_media' and column_name='media_presentation') or
 (table_name='publicaciones_comunidad' and column_name='media_presentation') or
 (table_name='kombax_showcase_elementos' and column_name='imagen_presentacion') or
 (table_name='material_catalogo' and column_name='media_presentation') or
 (table_name='comunicaciones' and column_name='media_presentation')
) order by table_name;
select proname,prosecdef from pg_proc where pronamespace='public'::regnamespace and proname in ('app_kombax_media_presentation_normalize_v187','app_kombax_media_presentation_set_v187','app_kombax_media_presentations_v187') order by proname;
