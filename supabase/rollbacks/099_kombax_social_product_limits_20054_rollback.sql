begin;
drop function if exists public.app_kombax_social_mutate_v099(text,jsonb,uuid);
drop function if exists public.app_kombax_social_profile_posts_v099(uuid,timestamptz,uuid,integer);
drop function if exists public.app_kombax_social_cupo_v099(uuid);
drop index if exists public.idx_kombax_actor_audit_social_publish_v099;
grant execute on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
