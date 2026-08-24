begin;

-- Build 20072: el Verificador global puede revisar documentación de verificación,
-- pero no modificarla ni eliminarla. La eliminación ordinaria corresponde al
-- propietario del documento; los procesos de privacidad usan service_role.
drop policy if exists kombax_verification_docs_delete_v117 on storage.objects;
create policy kombax_verification_docs_delete_v128
on storage.objects
for delete
to authenticated
using (
  bucket_id='kombax-verification-docs'
  and array_length(storage.foldername(name),1)>=1
  and (storage.foldername(name))[1]=(auth.uid())::text
);

-- Mantener la lectura del Verificador separada y explícita.
drop policy if exists kombax_verification_docs_select_v117 on storage.objects;
create policy kombax_verification_docs_select_v128
on storage.objects
for select
to authenticated
using (
  bucket_id='kombax-verification-docs'
  and (
    (storage.foldername(name))[1]=(auth.uid())::text
    or public.app_kombax_es_verificador_v117()
  )
);

notify pgrst,'reload schema';
commit;
