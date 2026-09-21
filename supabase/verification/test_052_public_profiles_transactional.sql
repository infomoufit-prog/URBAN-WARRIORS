begin;
select * from public.app_kombax_social_directorio_v052('',10);
select public.app_kombax_perfil_publico_v052(id) from public.kombax_social_perfiles where visible and estado='activo' limit 1;
rollback;
