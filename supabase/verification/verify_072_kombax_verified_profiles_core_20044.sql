-- Verificación 072 · núcleo
select
 to_regprocedure('public.app_kombax_application_validate_v072(uuid)') is not null as validator,
 to_regprocedure('public.app_kombax_social_switch_competitor_v072(uuid)') is not null as member_upgrade,
 to_regprocedure('public.app_kombax_social_puede_actuar_v051(uuid)') is not null as social_guard;
select count(*) filter(where sujeto_tipo='miembro' and verificado) as member_badges_must_be_0 from public.kombax_social_perfiles;
