select
  to_regclass('public.kombax_solicitudes_alta') is not null as applications_ok,
  to_regclass('public.kombax_verificacion_documentos') is not null as verification_docs_ok,
  to_regclass('public.kombax_perfil_media') is not null as album_ok,
  exists(select 1 from storage.buckets where id='kombax-public-media' and public) as public_media_bucket_ok,
  exists(select 1 from storage.buckets where id='kombax-verification-docs' and not public) as private_verification_bucket_ok,
  to_regprocedure('public.app_kombax_mis_perfiles_v043()') is not null as profiles_rpc_ok,
  to_regprocedure('public.app_kombax_perfil_mutate_v043(text,jsonb,uuid)') is not null as profile_mutation_ok,
  to_regprocedure('public.app_kombax_media_mutate_v043(text,jsonb,uuid)') is not null as media_mutation_ok;
