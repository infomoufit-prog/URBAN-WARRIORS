select
  not has_function_privilege('authenticated','public.app_kombax_es_platform_admin_v055()','EXECUTE') as admin_helper_internal,
  not has_function_privilege('authenticated','public.app_kombax_social_acceso_v041()','EXECUTE') as social_access_internal,
  not has_function_privilege('authenticated','public.app_kombax_social_contactable_v041(uuid)','EXECUTE') as contactable_internal,
  not has_function_privilege('authenticated','public.app_kombax_social_puede_publicar_v041(uuid)','EXECUTE') as publish_helper_internal,
  not has_function_privilege('authenticated','public.app_kombax_social_tipo_v051(uuid)','EXECUTE') as social_type_internal,
  not has_function_privilege('authenticated','public.app_kombax_contact_reason_allowed_v044(uuid,uuid,text)','EXECUTE') as reason_helper_internal,
  not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prorettype='pg_catalog.trigger'::regtype
      and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'))
  ) as trigger_rpcs_closed,
  not exists(
    select 1 from pg_default_acl d join pg_namespace n on n.oid=d.defaclnamespace
    where pg_get_userbyid(d.defaclrole)='postgres' and n.nspname='public' and d.defaclobjtype in ('r','f','S')
      and (
        coalesce(array_to_string(d.defaclacl,','),'') like '%anon=%'
        or coalesce(array_to_string(d.defaclacl,','),'') like '%authenticated=%'
        or coalesce(array_to_string(d.defaclacl,','),'') like '%service_role=%'
      )
  ) as future_objects_deny_by_default;
