-- VERIFY 050 · espera true en todas las columnas.
select
  to_regprocedure('public.app_kombax_moderation_queue_v050(integer)') is not null as queue_ok,
  to_regprocedure('public.app_kombax_social_mutate_v050(text,jsonb,uuid)') is not null as gateway_ok,
  exists(select 1 from pg_constraint where conrelid='public.kombax_social_reportes'::regclass and conname='kombax_social_reportes_objetivo_tipo_check' and pg_get_constraintdef(oid) ilike '%comentario%') as comment_reports_ok,
  exists(select 1 from pg_constraint where conrelid='public.kombax_social_moderacion'::regclass and conname='kombax_social_moderacion_objetivo_tipo_check' and pg_get_constraintdef(oid) ilike '%comentario%') as comment_moderation_log_ok;
