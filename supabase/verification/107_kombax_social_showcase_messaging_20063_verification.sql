-- Verificación 107 · ejecutar después de migrar.
select
  to_regprocedure('public.app_kombax_social_network_mutate_v107(text,jsonb,uuid)') is not null as network_v107,
  to_regprocedure('public.app_kombax_contactos_v107()') is not null as contacts_v107,
  to_regprocedure('public.app_kombax_header_activity_v107()') is not null as header_activity_v107,
  to_regprocedure('public.app_kombax_header_summary_v107(uuid)') is not null as header_summary_v107,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_contactos' and column_name='canal') as channel_column,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_contactos' and column_name='showcase_elemento_id') as showcase_item_column,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_contactos' and column_name='showcase_producto_nombre') as showcase_name_snapshot,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_contactos' and column_name='showcase_producto_imagen_url') as showcase_image_snapshot,
  to_regclass('public.uq_kombax_contact_social_pair_open_v107') is not null as social_open_index,
  to_regclass('public.uq_kombax_contact_showcase_pair_item_open_v107') is not null as showcase_open_index,
  has_function_privilege('authenticated','public.app_kombax_social_network_mutate_v107(text,jsonb,uuid)','EXECUTE') as authenticated_network,
  not has_function_privilege('anon','public.app_kombax_social_network_mutate_v107(text,jsonb,uuid)','EXECUTE') as anon_network_closed,
  position('coalesce(c.canal,''social'')=''social''' in pg_get_functiondef('public.app_kombax_social_network_mutate_v104(text,jsonb,uuid)'::regprocedure))>0 as legacy_v104_social_only,
  position('coalesce(c.canal,''social'')=''social''' in pg_get_functiondef('public.app_kombax_contactos_v106()'::regprocedure))>0 as legacy_v106_contacts_social_only,
  position('coalesce(c.canal,''social'')=''social''' in pg_get_functiondef('public.app_kombax_header_activity_v106()'::regprocedure))>0 as legacy_v106_header_social_only;
