-- Keep legacy entry points consistent with the current free Social feed.
-- Reading does not activate a public identity, publication, Commerce or Ticketing.
create or replace function public.app_kombax_social_acceso_v041() returns boolean
language sql stable security definer set search_path='' as $fn$
  select public.app_kombax_social_read_access_r117();
$fn$;
