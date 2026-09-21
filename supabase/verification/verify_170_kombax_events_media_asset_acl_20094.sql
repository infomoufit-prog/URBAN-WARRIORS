do $$ begin
 if has_function_privilege('anon','public.app_kombax_evento_media_asset_v165(uuid)','execute') then raise exception 'VERIFY_170: anon exposed'; end if;
 if has_function_privilege('authenticated','public.app_kombax_evento_media_asset_v165(uuid)','execute') then raise exception 'VERIFY_170: authenticated exposed'; end if;
 if not has_function_privilege('service_role','public.app_kombax_evento_media_asset_v165(uuid)','execute') then raise exception 'VERIFY_170: service_role missing'; end if;
end $$;
