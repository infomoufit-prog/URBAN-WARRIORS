-- KOMBAX RC13 build 20046 · 084 · Social legacy RPC shutdown
-- Security objective: after audience controls (083), older Social read/write RPCs must not remain
-- directly executable by client roles because they predate per-post audience enforcement.
begin;

-- Legacy feeds: direct client access could bypass audiencia introduced in 083.
revoke execute on function public.app_kombax_social_feed_v041(timestamptz,uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_social_feed_v044(timestamptz,uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_social_feed_v065(timestamptz,uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_social_feed_v072(timestamptz,uuid,integer) from anon,authenticated;

-- Legacy comments: v044 does not check 083 audience. v053 is kept internal only because v083 wraps it.
revoke execute on function public.app_kombax_social_comentarios_v044(uuid,integer) from anon,authenticated;
revoke execute on function public.app_kombax_social_comentarios_v053(uuid,integer) from anon,authenticated;

-- Legacy mutations: old gateways can create/interact with posts without the 083 audience gate.
-- They remain callable internally by SECURITY DEFINER wrappers owned by postgres.
revoke execute on function public.app_kombax_social_mutate_v041(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v044(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v049(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v050(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v053(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v065(text,jsonb,uuid) from anon,authenticated;
revoke execute on function public.app_kombax_social_mutate_v067(text,jsonb,uuid) from anon,authenticated;

-- Old public-profile contracts are obsolete in the runtime. 072 remains internal dependency of 083.
revoke execute on function public.app_kombax_perfil_publico_v068(uuid) from anon,authenticated;
revoke execute on function public.app_kombax_perfil_publico_v072(uuid) from anon,authenticated;

-- Current audience-aware client surface stays explicit.
revoke all on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) to authenticated;
revoke all on function public.app_kombax_social_comentarios_v083(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v083(uuid,integer) to authenticated;
revoke all on function public.app_kombax_social_guardados_v083(integer) from public,anon;
grant execute on function public.app_kombax_social_guardados_v083(integer) to authenticated;
revoke all on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) to authenticated;
revoke all on function public.app_kombax_perfil_publico_v083(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v083(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
