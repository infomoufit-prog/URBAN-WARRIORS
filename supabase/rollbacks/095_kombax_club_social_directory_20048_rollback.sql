begin;
drop function if exists public.app_kombax_club_social_directory_v095(uuid,text,integer);
notify pgrst,'reload schema';
commit;
