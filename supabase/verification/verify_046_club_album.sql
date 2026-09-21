select to_regclass('public.kombax_club_media') is not null as table_ok,
       to_regprocedure('public.app_kombax_club_album_v046(uuid)') is not null as read_rpc_ok,
       to_regprocedure('public.app_kombax_club_media_mutate_v046(text,jsonb,uuid)') is not null as mutate_rpc_ok;
select conname from pg_constraint where conrelid='public.kombax_club_media'::regclass and conname in ('kombax_club_video_duration_v046','kombax_club_media_mime_v046') order by conname;
