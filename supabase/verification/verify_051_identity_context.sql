select
  to_regclass('public.kombax_club_team_permissions') is not null as team_permissions_ok,
  to_regclass('public.kombax_actor_audit') is not null as actor_audit_ok,
  to_regprocedure('public.app_kombax_social_tipo_v051(uuid)') is not null as identity_type_ok,
  to_regprocedure('public.app_kombax_social_puede_actuar_v051(uuid)') is not null as act_as_ok,
  to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null as my_identities_ok,
  to_regprocedure('public.app_kombax_social_estado_v051(uuid)') is not null as status_ok,
  to_regprocedure('public.app_kombax_identity_mutate_v051(text,jsonb,uuid)') is not null as mutation_ok,
  pg_get_functiondef('public.app_kombax_social_tipo_v051(uuid)'::regprocedure) like '%when sp.sujeto_tipo=''miembro'' then ''miembro''%' as member_not_competitor_ok;

select to_regprocedure('public.app_kombax_club_team_v051(uuid)') is not null as team_rpc_ok;
