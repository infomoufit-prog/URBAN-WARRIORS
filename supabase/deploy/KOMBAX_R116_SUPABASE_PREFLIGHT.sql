-- READ-ONLY. Expected: every *_dependency column = true.
select
  to_regclass('public.notificaciones') is not null as notificaciones_dependency,
  to_regclass('public.kombax_solicitudes_alta') is not null as solicitudes_dependency,
  to_regclass('kombax_owner_ai.agent_turns') is not null as owner_agents_dependency,
  to_regclass('public.socios') is not null as socios_dependency,
  to_regclass('public.miembros_club') is not null as miembros_dependency,
  to_regclass('public.identidades_sociales') is not null as identidades_dependency,
  to_regclass('public.kombax_social_perfiles') is not null as social_profiles_dependency,
  to_regclass('public.perfiles_kombax_directos') is not null as direct_profiles_dependency,
  to_regprocedure('public.app_kombax_es_platform_admin_v055()') is not null as owner_auth_dependency,
  to_regprocedure('public.app_kombax_metrics_platform_v133(integer)') is not null as metrics_dependency,
  to_regprocedure('public.app_kombax_social_estado_v123(uuid)') is not null as social_state_dependency,
  to_regprocedure('public.app_kombax_identity_mutate_v123(text,jsonb,uuid)') is not null as identity_mutate_dependency,
  to_regprocedure('public.app_kombax_social_puede_actuar_v051(uuid)') is not null as social_action_dependency,
  exists(select 1 from storage.buckets where id='kombax-reports') as reports_bucket_dependency;
