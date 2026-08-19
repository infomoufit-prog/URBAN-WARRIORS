-- KOMBAX 20.046 / 089
-- Structural hardening: internal helpers/triggers are not client RPCs and future
-- public-schema objects are deny-by-default until a migration grants them explicitly.
begin;

-- Prevent accidental future Data API exposure. Every new public object must opt in.
alter default privileges for role postgres in schema public
  revoke select,insert,update,delete on tables from anon,authenticated,service_role;
alter default privileges for role postgres in schema public
  revoke usage,select on sequences from anon,authenticated,service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public,anon,authenticated,service_role;

-- Trigger functions remain attached and executable by PostgreSQL, but cannot be RPCs.
do $$
declare r record;
begin
  for r in
    select n.nspname,p.proname
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prorettype='pg_catalog.trigger'::regtype
  loop
    execute format('revoke execute on function %I.%I() from public,anon,authenticated',r.nspname,r.proname);
  end loop;
end $$;

-- These helpers are used only from SECURITY DEFINER endpoints, never by RLS/storage
-- policies and never directly by the 20.046 frontend. Keep them internal.
revoke execute on function public.app_kombax_es_platform_admin_v055() from public,anon,authenticated;
revoke execute on function public.app_kombax_social_acceso_v041() from public,anon,authenticated;
revoke execute on function public.app_kombax_social_contactable_v041(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_social_tipo_v051(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) from public,anon,authenticated;

grant execute on function public.app_kombax_es_platform_admin_v055() to service_role;
grant execute on function public.app_kombax_social_acceso_v041() to service_role;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to service_role;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to service_role;
grant execute on function public.app_kombax_social_tipo_v051(uuid) to service_role;
grant execute on function public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text) to service_role;

notify pgrst,'reload schema';
commit;
