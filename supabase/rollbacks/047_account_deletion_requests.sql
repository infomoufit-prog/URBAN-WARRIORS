begin;
drop function if exists public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid);
drop function if exists public.app_kombax_solicitudes_eliminacion_v047();
drop table if exists public.kombax_solicitudes_eliminacion;
notify pgrst,'reload schema';
commit;
