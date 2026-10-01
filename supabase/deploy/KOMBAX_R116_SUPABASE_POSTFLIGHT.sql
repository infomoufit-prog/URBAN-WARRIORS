-- READ-ONLY. Expected: every installed column = true.
select
  to_regprocedure('public.app_kombax_owner_alerts_r114(integer)') is not null as owner_alerts_installed,
  to_regprocedure('public.app_kombax_owner_report_payload_r114(integer)') is not null as owner_report_payload_installed,
  to_regprocedure('public.app_kombax_member_membership_confirmed_r115(uuid)') is not null as member_authority_installed,
  to_regprocedure('public.app_kombax_social_estado_v124(uuid)') is not null as social_state_v124_installed,
  to_regprocedure('public.app_kombax_identity_mutate_v124(text,jsonb,uuid)') is not null as identity_mutate_v124_installed,
  exists(select 1 from pg_trigger where tgname='trg_kombax_owner_notify_verification_r114' and not tgisinternal) as owner_verification_trigger_installed,
  exists(select 1 from pg_trigger where tgname='trg_kombax_owner_notify_agent_r114' and not tgisinternal) as owner_agent_trigger_installed;
