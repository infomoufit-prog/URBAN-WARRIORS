-- KOMBAX 20.046 / 088
-- Retire client access to superseded RPC versions. Newer wrappers remain callable
-- and can still invoke legacy implementation functions internally as function owner.
begin;

-- Contact 067 adds participant-copy deletion semantics. 065 must not bypass it.
revoke execute on function public.app_kombax_contactos_v065() from anon, authenticated;
revoke execute on function public.app_kombax_contact_mensajes_v065(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_contact_mark_read_v065(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_social_network_mutate_v065(text,jsonb,uuid) from anon, authenticated;
grant execute on function public.app_kombax_contactos_v067() to authenticated;
grant execute on function public.app_kombax_contact_mensajes_v067(uuid) to authenticated;
grant execute on function public.app_kombax_contact_mark_read_v067(uuid) to authenticated;
grant execute on function public.app_kombax_social_network_mutate_v067(text,jsonb,uuid) to authenticated;

-- Verified-profile and identity wrappers.
revoke execute on function public.app_kombax_album_v043(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_identity_mutate_v051(text,jsonb,uuid) from anon, authenticated;
grant execute on function public.app_kombax_album_v072(uuid) to authenticated;
grant execute on function public.app_kombax_identity_mutate_v065(text,jsonb,uuid) to authenticated;

-- Platform admin current dashboard/profile projection is 072.
revoke execute on function public.app_kombax_platform_dashboard_v055() from anon, authenticated;
revoke execute on function public.app_kombax_platform_profiles_v055(text,integer) from anon, authenticated;
grant execute on function public.app_kombax_platform_dashboard_v072() to authenticated;
grant execute on function public.app_kombax_platform_profiles_v072(text,integer) to authenticated;

-- Diagnostics: v166 is the only current diagnostic runtime contract.
revoke execute on function public.app_diagnostico_persistencia_v161() from anon, authenticated;
revoke execute on function public.app_diagnostico_final_v162() from anon, authenticated;
revoke execute on function public.app_diagnostico_final_v163() from anon, authenticated;
revoke execute on function public.app_diagnostico_final_v164() from anon, authenticated;
revoke execute on function public.app_diagnostico_final_v165() from anon, authenticated;
grant execute on function public.app_diagnostico_final_v166() to authenticated;

-- Showcase current list/mutation/management projections.
revoke execute on function public.app_kombax_showcase_list_v042(text,text,timestamptz,uuid,integer) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_mis_elementos_v042(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_mis_espacios_v045(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_mutate_v042(text,jsonb,uuid) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_mutate_v048(text,jsonb,uuid) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_mutate_v054(text,jsonb,uuid) from anon, authenticated;
revoke execute on function public.app_kombax_showcase_puede_gestionar_v042(uuid) from anon, authenticated;
grant execute on function public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer) to anon, authenticated;
grant execute on function public.app_kombax_showcase_mis_elementos_v054(uuid) to authenticated;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;
grant execute on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) to authenticated;

-- Social directory/status/self-projection current client versions.
revoke execute on function public.app_kombax_social_directorio_v041(text,integer) from anon, authenticated;
revoke execute on function public.app_kombax_social_directorio_v044(text,integer) from anon, authenticated;
revoke execute on function public.app_kombax_social_directorio_v052(text,integer) from anon, authenticated;
revoke execute on function public.app_kombax_social_estado_v041(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_social_estado_v049(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_social_estado_v051(uuid) from anon, authenticated;
revoke execute on function public.app_kombax_social_mis_perfiles_v041() from anon, authenticated;
revoke execute on function public.app_kombax_social_mis_perfiles_v044() from anon, authenticated;
revoke execute on function public.app_kombax_social_tipo_v045(uuid) from anon, authenticated;
grant execute on function public.app_kombax_social_directorio_v072(text,integer) to authenticated;
grant execute on function public.app_kombax_social_estado_v065(uuid) to authenticated;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;
grant execute on function public.app_kombax_social_tipo_v051(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
