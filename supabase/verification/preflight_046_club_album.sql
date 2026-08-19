-- PRECHECK 046: no muta datos.
select to_regclass('public.perfiles_club_publicos') is not null as perfiles_club_ok,
       to_regclass('public.app_mutation_requests') is not null as mutation_requests_ok,
       exists(select 1 from storage.buckets where id='kombax-public-media') as public_media_bucket_ok;
