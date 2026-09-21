select
  to_regprocedure('public.app_kombax_social_puede_actuar_v051(uuid)') is not null as identity_051_ok,
  to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null as profile_052_ok,
  exists(select 1 from storage.buckets where id='kombax-public-media' and public) as public_media_bucket_ok;
