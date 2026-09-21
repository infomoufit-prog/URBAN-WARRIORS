-- Verificación 074
select to_regprocedure('public.app_kombax_social_puede_actuar_v051(uuid)') is not null as act_guard, to_regprocedure('public.app_kombax_social_afiliacion_v072(uuid)') is not null as affiliation;
