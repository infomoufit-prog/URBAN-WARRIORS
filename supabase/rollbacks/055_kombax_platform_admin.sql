begin;
-- Restablece el contrato de moderación de 041 antes de retirar la autorización global.
create or replace function public.app_kombax_es_moderador_v041()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.kombax_moderadores_globales m where m.perfil_id=auth.uid() and m.activo);
$$;
revoke all on function public.app_kombax_es_moderador_v041() from public,anon;
grant execute on function public.app_kombax_es_moderador_v041() to authenticated;

drop function if exists public.app_kombax_platform_mutate_v055(text,jsonb,uuid);
drop function if exists public.app_kombax_platform_club_v055(uuid);
drop function if exists public.app_kombax_platform_profiles_v055(text,integer);
drop function if exists public.app_kombax_platform_dashboard_v055();
drop function if exists public.app_kombax_platform_context_v055();
drop function if exists public.app_kombax_es_platform_admin_v055();
drop table if exists public.kombax_platform_admins;
notify pgrst,'reload schema';
commit;
