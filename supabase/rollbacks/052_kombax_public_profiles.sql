begin;
drop function if exists public.app_kombax_perfil_publico_v052(uuid);
drop function if exists public.app_kombax_social_directorio_v052(text,integer);
notify pgrst,'reload schema';
commit;
