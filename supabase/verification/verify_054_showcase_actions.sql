select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_showcase_elementos' and column_name='cta_tipo') as cta_ok,
  to_regclass('public.kombax_showcase_guardados') is not null as saved_ok,
  to_regprocedure('public.app_kombax_showcase_list_v054(text,text,timestamp with time zone,uuid,integer)') is not null as list_ok,
  to_regprocedure('public.app_kombax_showcase_guardados_v054(integer)') is not null as saved_rpc_ok,
  to_regprocedure('public.app_kombax_showcase_mis_elementos_v054(uuid)') is not null as manage_rpc_ok,
  to_regprocedure('public.app_kombax_showcase_mutate_v054(text,jsonb,uuid)') is not null as mutate_ok,
  exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_showcase_media_insert_v054') as upload_policy_ok,
  exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_showcase_media_delete_v054') as delete_policy_ok;
