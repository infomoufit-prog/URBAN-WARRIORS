-- Prueba de estructura reversible. No crea usuarios ni contenido persistente.
begin;
do $test$
begin
  if to_regclass('public.kombax_social_perfiles') is null then raise exception '041_TEST: falta perfiles'; end if;
  if to_regclass('public.kombax_social_publicaciones') is null then raise exception '041_TEST: falta feed'; end if;
  if to_regclass('public.kombax_social_contactos') is null then raise exception '041_TEST: falta contacto estructurado'; end if;
  if to_regprocedure('public.app_kombax_social_mutate_v041(text,jsonb,uuid)') is null then raise exception '041_TEST: falta gateway'; end if;
  if has_table_privilege('authenticated','public.kombax_social_contactos','SELECT') then raise exception '041_TEST: contacto expuesto directamente'; end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('kombax_social_mensajes','kombax_social_conversaciones','kombax_social_seguidores')) then raise exception '041_TEST: se creó una función social excluida'; end if;
end
$test$;
select '041_TRANSACTIONAL_STRUCTURE' resultado,'PASS' estado;
rollback;
