-- KOMBAX build 20028 · 056 · contrato técnico de release, visible solo para Administración KOMBAX.
begin;
create or replace function public.app_kombax_release_contract_v056()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return jsonb_build_object(
    'ok',true,'build',20030,
    'identity_context',to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null,
    'public_profiles',to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null,
    'social_media',to_regprocedure('public.app_kombax_social_mutate_v053(text,jsonb,uuid)') is not null,
    'showcase_actions',to_regprocedure('public.app_kombax_showcase_mutate_v054(text,jsonb,uuid)') is not null,
    'platform_admin',to_regprocedure('public.app_kombax_platform_dashboard_v055()') is not null,
    'tables',jsonb_build_object(
      'social_media',to_regclass('public.kombax_social_media') is not null,
      'showcase_saved',to_regclass('public.kombax_showcase_guardados') is not null,
      'team_permissions',to_regclass('public.kombax_club_team_permissions') is not null,
      'actor_audit',to_regclass('public.kombax_actor_audit') is not null,
      'platform_admins',to_regclass('public.kombax_platform_admins') is not null
    )
  );
end $$;
revoke all on function public.app_kombax_release_contract_v056() from public,anon;
grant execute on function public.app_kombax_release_contract_v056() to authenticated;
notify pgrst,'reload schema';commit;
