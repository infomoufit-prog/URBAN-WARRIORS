-- FIX17: direct profile uploader uses uid/profile_id/file (two folders).
-- Keep ownership and per-identity edit authorization. No subscription or verification bypass.
alter policy kombax_public_media_insert_v070 on storage.objects
with check (
 bucket_id='kombax-public-media'
 and array_length(storage.foldername(name),1)>=2
 and (storage.foldername(name))[1]=auth.uid()::text
 and public.app_kombax_puede_gestionar_perfil_v070(
   public.app_kombax_uuid_or_null_v070((storage.foldername(name))[2]),'edit')
);

