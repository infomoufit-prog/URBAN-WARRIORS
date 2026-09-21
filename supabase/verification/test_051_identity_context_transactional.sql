-- Ejecutar autenticado con una cuenta QA. No deja cambios permanentes.
begin;
select public.app_kombax_social_tipo_v051(id) as tipo from public.kombax_social_perfiles where sujeto_tipo='miembro' limit 1;
select * from public.app_kombax_social_mis_perfiles_v051(null) limit 20;
rollback;
