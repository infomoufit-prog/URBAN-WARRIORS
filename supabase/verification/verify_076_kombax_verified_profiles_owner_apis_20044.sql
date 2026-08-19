-- Verificación 076
select to_regprocedure('public.app_kombax_mis_perfiles_v072()') is not null as my_profiles, to_regprocedure('public.app_kombax_mis_solicitudes_v072()') is not null as my_apps, to_regprocedure('public.app_kombax_album_v072(uuid)') is not null as album;
