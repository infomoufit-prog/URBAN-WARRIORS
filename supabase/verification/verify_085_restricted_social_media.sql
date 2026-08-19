select
  exists(select 1 from storage.buckets where id='kombax-restricted-media' and public=false) as private_bucket,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_media' and column_name='storage_bucket') as media_bucket_column,
  to_regprocedure('public.app_kombax_social_media_v085(uuid)') is not null as media_085,
  to_regprocedure('public.app_kombax_social_feed_v085(timestamptz,uuid,integer)') is not null as feed_085,
  to_regprocedure('public.app_kombax_social_mutate_v085(text,jsonb,uuid)') is not null as mutate_085,
  has_function_privilege('authenticated','public.app_kombax_social_media_v053(uuid)','EXECUTE') as compat_media_053,
  has_function_privilege('authenticated','public.app_kombax_social_feed_v083(timestamptz,uuid,integer)','EXECUTE') as compat_feed_083,
  has_function_privilege('authenticated','public.app_kombax_social_mutate_v083(text,jsonb,uuid)','EXECUTE') as compat_mutate_083,
  position('app_kombax_social_mutate_v085' in pg_get_functiondef('public.app_kombax_social_mutate_v083(text,jsonb,uuid)'::regprocedure))>0 as mutate_083_hardened_wrapper,
  position('case when f.media_bucket=''kombax-public-media'' then f.media_path else null end' in lower(pg_get_functiondef('public.app_kombax_social_feed_v083(timestamptz,uuid,integer)'::regprocedure)))>0 as feed_083_hides_private_path,
  not has_table_privilege('anon','public.kombax_social_media','SELECT') as media_table_anon_private;
