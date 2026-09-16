-- R73 rollback is deliberately non-destructive for reputation/history.
begin;
revoke execute on function public.app_kombax_event_community_manage_r73(uuid,integer) from authenticated;
revoke execute on function public.app_kombax_event_reaction_set_r73(uuid,text) from authenticated;
revoke execute on function public.app_kombax_event_comment_upsert_r73(uuid,text,uuid,jsonb,text) from authenticated;
revoke execute on function public.app_kombax_event_community_r73(uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_showcase_seller_reviews_r73(uuid,integer) from authenticated;
revoke execute on function public.app_kombax_showcase_reviews_r73(uuid,text,integer) from anon,authenticated;
-- Keep event_comments.kind and event_reactions data to preserve audit/reputation history.
notify pgrst,'reload schema';
commit;
