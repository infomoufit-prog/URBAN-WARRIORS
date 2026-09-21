-- Preflight 043: no cambia datos.
select
  to_regclass('public.perfiles_kombax_directos') is not null as direct_profiles_ok,
  to_regclass('public.kombax_social_perfiles') is not null as social_profiles_ok,
  to_regclass('public.kombax_moderadores_globales') is not null as moderators_ok,
  exists(select 1 from storage.buckets where id='profile-media') as storage_baseline_ok;
