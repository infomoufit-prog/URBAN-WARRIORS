-- KOMBAX 20.046 / 091
-- The 085 transition renamed three legacy implementations before recreating
-- hardened compatibility wrappers. Renaming preserves ACLs, so explicitly make
-- the preserved implementations internal-only.
begin;
revoke all on function public.app_kombax_social_media_v053_pre_media_v085(uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer) from public,anon,authenticated;
revoke all on function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_social_media_v053_pre_media_v085(uuid) to service_role;
grant execute on function public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer) to service_role;
grant execute on function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) to service_role;
notify pgrst,'reload schema';
commit;
