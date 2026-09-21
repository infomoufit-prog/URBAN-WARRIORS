begin;
-- Test estructural reversible: la tabla y límites existen; E2E real debe ejecutarse autenticado con un club QA.
do $$ begin
  if to_regclass('public.kombax_club_media') is null then raise exception '046 table missing';end if;
  if to_regprocedure('public.app_kombax_club_album_v046(uuid)') is null then raise exception '046 read rpc missing';end if;
  if to_regprocedure('public.app_kombax_club_media_mutate_v046(text,jsonb,uuid)') is null then raise exception '046 mutate rpc missing';end if;
end $$;
rollback;
