-- KOMBAX RC13 build 20071
-- Readiness must report the effective security posture, not merely RPC existence.

create or replace function public.app_kombax_pilot_readiness_status_v117()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','auth','storage'
as $function$
declare
  v_manual jsonb;
  v_ready boolean;
  v_password_only_auth boolean;
  v_owner_mfa boolean;
begin
  if not public.app_kombax_es_platform_admin_v055() then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;

  select coalesce(
           jsonb_object_agg(control,jsonb_build_object(
             'verified',verificado,
             'evidence',evidencia,
             'verified_at',verificado_en
           )),
           '{}'::jsonb
         ),
         bool_and(verificado)
    into v_manual,v_ready
  from public.kombax_pilot_readiness_v117;

  v_password_only_auth :=
    to_regprocedure('public.app_kombax_platform_admin_password_complete_v110(uuid)') is not null
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_password_complete_v110(uuid)','EXECUTE');

  v_owner_mfa :=
    to_regprocedure('public.app_kombax_platform_admin_challenge_start_v108()') is not null
    and to_regprocedure('public.app_kombax_platform_admin_challenge_complete_v108(uuid)') is not null
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_challenge_start_v108()','EXECUTE')
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_challenge_complete_v108(uuid)','EXECUTE')
    and not v_password_only_auth;

  return jsonb_build_object(
    'build',20071,
    'pilot_ready',coalesce(v_ready,false),
    'manual',v_manual,
    'technical',jsonb_build_object(
      'rls_verifiers',to_regclass('public.kombax_verificadores_globales_v117') is not null,
      'private_docs_policy',exists(
        select 1 from pg_policies
        where schemaname='storage'
          and tablename='objects'
          and policyname='kombax_verification_docs_select_v117'
      ),
      'owner_mfa',v_owner_mfa,
      'owner_password_only_executable',v_password_only_auth,
      'privacy_deletion_owner_queue',to_regprocedure('public.app_kombax_deletion_queue_v119(text,integer)') is not null,
      'minor_guardian_consent',to_regclass('public.kombax_social_minor_consents_v121') is not null,
      'message_report_evidence',to_regclass('public.kombax_message_report_evidence_v122') is not null,
      'incident_capture',to_regprocedure('public.app_kombax_client_incident_report_v117(text,text,text,jsonb)') is not null
    )
  );
end
$function$;

revoke all on function public.app_kombax_pilot_readiness_status_v117() from public,anon;
grant execute on function public.app_kombax_pilot_readiness_status_v117() to authenticated;

comment on function public.app_kombax_pilot_readiness_status_v117() is
'KOMBAX 20071 readiness: reports effective Owner MFA posture and current hardening controls; password-only is true only if authenticated can execute it.';
