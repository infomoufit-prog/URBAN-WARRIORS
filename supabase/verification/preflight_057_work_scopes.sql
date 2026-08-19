-- KOMBAX build 20030 · preflight 057
select
  to_regprocedure('public.app_kombax_release_contract_v056()') is not null as release_056_ok,
  to_regclass('public.miembros_club') is not null as memberships_ok,
  to_regclass('public.socios') is not null as students_ok,
  to_regclass('public.grupos') is not null as groups_ok,
  to_regclass('public.reservas_sesion') is not null as reservations_ok,
  to_regclass('public.series_sesiones') is not null as session_series_ok,
  to_regclass('storage.objects') is not null as storage_ok,
  to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null as gateway_ok,
  to_regprocedure('public.app_kombax_puede_gestionar_ambitos_v057(uuid)') is null as not_applied_yet;
