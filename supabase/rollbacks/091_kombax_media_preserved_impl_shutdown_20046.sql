begin;
grant execute on function public.app_kombax_social_media_v053_pre_media_v085(uuid) to authenticated;
grant execute on function public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) to authenticated;
commit;
