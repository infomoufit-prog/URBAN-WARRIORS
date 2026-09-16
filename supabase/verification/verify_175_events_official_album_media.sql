select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_evento_media' and column_name='momento') as has_momento,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_evento_media' and column_name='duration_seconds') as has_duration,
  has_function_privilege('anon','public.app_kombax_evento_media_v175(uuid,uuid)','EXECUTE') as anon_album_reader,
  has_function_privilege('authenticated','public.app_kombax_evento_media_v175(uuid,uuid)','EXECUTE') as auth_album_reader,
  not has_function_privilege('anon','public.app_kombax_evento_media_cuota_v175(uuid,uuid)','EXECUTE') as anon_quota_blocked,
  has_function_privilege('authenticated','public.app_kombax_evento_media_cuota_v175(uuid,uuid)','EXECUTE') as auth_quota_reader,
  not has_function_privilege('anon','public.app_kombax_eventos_mutate_v175(text,jsonb,uuid)','EXECUTE') as anon_mutate_blocked,
  has_function_privilege('authenticated','public.app_kombax_eventos_mutate_v175(text,jsonb,uuid)','EXECUTE') as auth_mutate,
  (select file_size_limit from storage.buckets where id='kombax-events-media') as bucket_limit;
