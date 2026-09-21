begin;
-- Test estructural reversible: los límites están en DB y no en UI únicamente.
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.perfiles_kombax_directos'::regclass and conname='perfiles_kombax_directos_workflow_estado_check') then raise exception '043 workflow constraint missing'; end if;
  if not exists(select 1 from pg_trigger where tgrelid='public.kombax_perfil_media'::regclass and tgname='kombax_media_guard_v043' and not tgisinternal) then raise exception '043 media guard missing'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_verification_docs_select_v043') then raise exception '043 private docs policy missing'; end if;
end $$;
rollback;
