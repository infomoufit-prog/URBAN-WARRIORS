begin;
revoke all on function public.app_kombax_social_mutate_v044(text,jsonb,uuid) from authenticated;
revoke all on function public.app_kombax_social_feed_v044(timestamptz,uuid,integer) from authenticated;
revoke all on function public.app_kombax_social_comentarios_v044(uuid,integer) from authenticated;
revoke all on function public.app_kombax_social_guardados_v044(integer) from authenticated;
update public.kombax_social_comentarios set estado='hidden' where estado='active';
notify pgrst,'reload schema';
commit;
