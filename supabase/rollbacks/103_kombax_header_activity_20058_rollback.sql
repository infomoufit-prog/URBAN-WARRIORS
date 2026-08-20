begin;
drop function if exists public.app_kombax_header_activity_v103();
notify pgrst,'reload schema';
commit;
