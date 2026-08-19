-- Emergency rollback only. Re-opening these RPCs reintroduces pre-083 audience bypass risk.
begin;
grant execute on function public.app_kombax_social_feed_v041(timestamptz,uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_feed_v044(timestamptz,uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_comentarios_v044(uuid,integer) to authenticated;
grant execute on function public.app_kombax_social_mutate_v041(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_mutate_v044(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_mutate_v049(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_mutate_v050(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_mutate_v053(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_social_mutate_v065(text,jsonb,uuid) to authenticated;
grant execute on function public.app_kombax_perfil_publico_v068(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
