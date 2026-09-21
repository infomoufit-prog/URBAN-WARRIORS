-- KOMBAX 20.064 / rollback 108.
-- Recupera el modelo 055 previo (platform admin activo = autorizado) y retira los endpoints 108.
begin;

create or replace function public.app_kombax_es_platform_admin_v055()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(select 1 from public.kombax_platform_admins a where a.perfil_id=auth.uid() and a.activo);
$$;
revoke all on function public.app_kombax_es_platform_admin_v055() from public,anon,authenticated;
grant execute on function public.app_kombax_es_platform_admin_v055() to service_role;

create or replace function public.app_kombax_platform_context_v055()
returns jsonb language sql stable security definer set search_path=public,auth as $$
  select case when public.app_kombax_es_platform_admin_v055() then
    jsonb_build_object('authorized',true,'nivel',(select nivel from public.kombax_platform_admins where perfil_id=auth.uid() and activo limit 1))
  else jsonb_build_object('authorized',false) end;
$$;
revoke all on function public.app_kombax_platform_context_v055() from public,anon;
grant execute on function public.app_kombax_platform_context_v055() to authenticated;

drop function if exists public.app_kombax_platform_admin_session_end_v108();
drop function if exists public.app_kombax_platform_admin_challenge_complete_v108(uuid);
drop function if exists public.app_kombax_platform_admin_challenge_start_v108();
drop function if exists public.app_kombax_auth_method_recent_v108(text,integer);
drop table if exists public.kombax_platform_admin_sessions;
drop table if exists public.kombax_platform_admin_challenges;
notify pgrst,'reload schema';
commit;
