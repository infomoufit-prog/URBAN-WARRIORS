begin;
drop policy if exists kombax_events_media_insert_v165 on storage.objects;drop policy if exists kombax_events_media_select_v165 on storage.objects;drop policy if exists kombax_events_media_delete_v165 on storage.objects;
drop function if exists public.app_kombax_eventos_mutate_v165(text,jsonb,uuid);drop function if exists public.app_kombax_evento_media_asset_v165(uuid);drop function if exists public.app_kombax_evento_media_v165(uuid);drop function if exists public.app_kombax_evento_media_public_path_v165(text);drop function if exists public.app_kombax_evento_storage_manage_v165(text);
drop table if exists public.kombax_evento_media;
-- El bucket se conserva si contiene objetos; limpieza física es operación explícita.
commit;
