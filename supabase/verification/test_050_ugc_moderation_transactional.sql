begin;
-- Prueba de contrato estructural sin crear UGC persistente.
do $$
begin
  if to_regprocedure('public.app_kombax_social_mutate_v050(text,jsonb,uuid)') is null then raise exception 'TEST_050_GATEWAY_MISSING';end if;
  if to_regprocedure('public.app_kombax_moderation_queue_v050(integer)') is null then raise exception 'TEST_050_QUEUE_MISSING';end if;
  if not exists(select 1 from pg_constraint where conrelid='public.kombax_social_reportes'::regclass and conname='kombax_social_reportes_objetivo_tipo_check' and pg_get_constraintdef(oid) ilike '%comentario%') then raise exception 'TEST_050_COMMENT_REPORT_MISSING';end if;
end $$;
rollback;
