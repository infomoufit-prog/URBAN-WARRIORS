select
  to_regclass('public.perfiles') is not null as profiles_ok,
  to_regclass('public.miembros_club') is not null as memberships_ok,
  to_regclass('public.kombax_actor_audit') is not null as audit_051_ok,
  to_regclass('public.kombax_solicitudes_alta') is not null as verification_043_ok,
  to_regclass('public.kombax_social_reportes') is not null as reports_ok,
  to_regclass('public.kombax_relaciones') is not null as relations_045_ok,
  to_regclass('public.kombax_showcase_elementos') is not null as showcase_ok,
  to_regprocedure('public.app_kombax_social_tipo_v051(uuid)') is not null as identity_051_ok,
  to_regprocedure('public.app_kombax_es_moderador_v041()') is not null as moderation_ok;
