-- R118 Phase 5/9 rollback: keep functions but remove client access.
revoke execute on function public.app_kombax_discovery_search_r118(jsonb) from authenticated;
revoke execute on function public.app_kombax_discovery_public_profile_r118(uuid) from authenticated;
revoke execute on function public.app_kombax_person_facets_r118(uuid) from authenticated;
