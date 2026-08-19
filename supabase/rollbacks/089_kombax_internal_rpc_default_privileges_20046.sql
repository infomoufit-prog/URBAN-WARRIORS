-- Rollback restores the default grants observed before 089 and the six helper RPC grants.
begin;
alter default privileges for role postgres in schema public grant select,insert,update,delete on tables to anon,authenticated,service_role;
alter default privileges for role postgres in schema public grant usage,select on sequences to anon,authenticated,service_role;
alter default privileges for role postgres in schema public grant execute on functions to anon,authenticated,service_role;

grant execute on function public.app_kombax_es_platform_admin_v055() to authenticated;
grant execute on function public.app_kombax_social_acceso_v041() to authenticated;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;
grant execute on function public.app_kombax_social_tipo_v051(uuid) to authenticated;
grant execute on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
