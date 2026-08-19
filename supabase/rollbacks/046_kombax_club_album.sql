begin;
drop policy if exists kombax_club_media_insert_v046 on storage.objects;
drop function if exists public.app_kombax_club_media_mutate_v046(text,jsonb,uuid);
drop function if exists public.app_kombax_club_album_v046(uuid);
drop trigger if exists kombax_club_media_guard_v046 on public.kombax_club_media;
drop function if exists public.app_kombax_club_media_guard_v046();
drop table if exists public.kombax_club_media;
notify pgrst,'reload schema';
commit;
