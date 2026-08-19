-- Emergency rollback restores the exact 20.045 client function names from the preserved implementations.
begin;
revoke execute on function public.app_kombax_social_feed_v085(timestamptz,uuid,integer) from authenticated;
revoke execute on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_social_media_v085(uuid) from authenticated;

drop function if exists public.app_kombax_social_feed_v083(timestamptz,uuid,integer);
drop function if exists public.app_kombax_social_mutate_v083(text,jsonb,uuid);
drop function if exists public.app_kombax_social_media_v053(uuid);

alter function public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer) rename to app_kombax_social_feed_v083;
alter function public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid) rename to app_kombax_social_mutate_v083;
alter function public.app_kombax_social_media_v053_pre_media_v085(uuid) rename to app_kombax_social_media_v053;

grant execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_media_v053(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
