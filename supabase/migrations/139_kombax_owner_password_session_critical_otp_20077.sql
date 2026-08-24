-- KOMBAX RC13 build 20077 · Owner password session + critical OTP elevation
-- Normal hidden Owner console: exact Owner account + recent password -> 30 minute platform session.
-- OTP is retained only as a step-up control for exceptional destructive/security-critical operations.

begin;

create or replace function public.app_kombax_platform_admin_password_session_v139()
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_session_id text:=nullif(auth.jwt()->>'session_id','');
  v_expira timestamptz:=now()+interval '30 minutes';
  v_nivel text;
begin
  if v_uid is null or v_session_id is null then raise exception 'KOMBAX_ADMIN_AUTH_REQUIRED'; end if;

  select a.nivel into v_nivel
  from public.kombax_platform_admins a
  where a.perfil_id=v_uid and a.activo
  limit 1;
  if v_nivel is null then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;

  if not public.app_kombax_auth_method_recent_v108('password',600) then
    raise exception 'KOMBAX_ADMIN_PASSWORD_REQUIRED';
  end if;

  update public.kombax_platform_admin_sessions
     set terminado_en=coalesce(terminado_en,now())
   where perfil_id=v_uid and terminado_en is null;

  insert into public.kombax_platform_admin_sessions(perfil_id,auth_session_id,challenge_id,expira_en)
  values(v_uid,v_session_id,null,v_expira);

  insert into public.kombax_platform_privileged_audit(
    actor_perfil_id,auth_session_id,platform_session_id,entidad_tipo,entidad_id,accion,resultado,motivo,detalle
  )
  select v_uid,v_session_id,s.id,'platform',v_uid,'admin.session.password','success',
         'Acceso Owner mediante contraseña reciente',jsonb_build_object('auth_mode','password','expires_at',v_expira)
  from public.kombax_platform_admin_sessions s
  where s.perfil_id=v_uid and s.auth_session_id=v_session_id and s.terminado_en is null
  order by s.creado_en desc limit 1;

  return jsonb_build_object('authorized',true,'nivel',v_nivel,'expires_at',v_expira,'auth_mode','password');
end;
$$;
revoke all on function public.app_kombax_platform_admin_password_session_v139() from public,anon;
grant execute on function public.app_kombax_platform_admin_password_session_v139() to authenticated;

create or replace function public.app_kombax_platform_critical_authorized_v139()
returns boolean
language sql
stable
security definer
set search_path=public,auth
as $$
  select public.app_kombax_es_platform_admin_v055()
    and public.app_kombax_auth_method_recent_v108('otp',600);
$$;
revoke all on function public.app_kombax_platform_critical_authorized_v139() from public,anon,authenticated;
grant execute on function public.app_kombax_platform_critical_authorized_v139() to service_role;

-- Deep legacy delete gateway now requires a recent OTP step-up, not merely an open Owner session.
create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_destructive constant text[]:=array[
    'grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado',
    'disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado',
    'material.eliminar_forzado','publicacion.limpiar_antiguas'
  ];
begin
  if p_operation=any(v_destructive)
     and not coalesce(public.app_kombax_platform_critical_authorized_v139(),false)
     and not public.app_kombax_force_delete_is_qa_v133(p_operation,coalesce(p_payload,'{}'::jsonb)) then
    raise exception 'KOMBAX_DESTRUCTIVE_DELETE_CRITICAL_OTP_REQUIRED';
  end if;
  return public.app_mutate_v160_pre_lifecycle_133(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Account deletion is exceptional: wrap both phases with critical OTP step-up.
do $migration$
begin
  if to_regprocedure('public.app_kombax_deletion_plan_v119_pre_critical_139(uuid)') is null then
    alter function public.app_kombax_deletion_plan_v119(uuid) rename to app_kombax_deletion_plan_v119_pre_critical_139;
  end if;
  if to_regprocedure('public.app_kombax_deletion_finalize_v119_pre_critical_139(uuid,boolean,integer)') is null then
    alter function public.app_kombax_deletion_finalize_v119(uuid,boolean,integer) rename to app_kombax_deletion_finalize_v119_pre_critical_139;
  end if;
end
$migration$;
revoke all on function public.app_kombax_deletion_plan_v119_pre_critical_139(uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_deletion_finalize_v119_pre_critical_139(uuid,boolean,integer) from public,anon,authenticated;

create or replace function public.app_kombax_deletion_plan_v119(p_solicitud_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_platform_critical_authorized_v139() then
    raise exception 'KOMBAX_CRITICAL_OTP_REQUIRED';
  end if;
  return public.app_kombax_deletion_plan_v119_pre_critical_139(p_solicitud_id);
end $$;
revoke all on function public.app_kombax_deletion_plan_v119(uuid) from public,anon;
grant execute on function public.app_kombax_deletion_plan_v119(uuid) to authenticated;

create or replace function public.app_kombax_deletion_finalize_v119(p_solicitud_id uuid,p_auth_anonymized boolean,p_storage_removed integer default 0)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_platform_critical_authorized_v139() then
    raise exception 'KOMBAX_CRITICAL_OTP_REQUIRED';
  end if;
  return public.app_kombax_deletion_finalize_v119_pre_critical_139(p_solicitud_id,p_auth_anonymized,p_storage_removed);
end $$;
revoke all on function public.app_kombax_deletion_finalize_v119(uuid,boolean,integer) from public,anon;
grant execute on function public.app_kombax_deletion_finalize_v119(uuid,boolean,integer) to authenticated;


-- Readiness now reflects the approved split: password for routine Owner console,
-- recent OTP only for critical/destructive elevation.
create or replace function public.app_kombax_pilot_readiness_status_v117()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','auth','storage'
as $$
declare
  v_manual jsonb;
  v_ready boolean;
  v_owner_password boolean;
  v_critical_otp boolean;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_object_agg(control,jsonb_build_object('verified',verificado,'evidence',evidencia,'verified_at',verificado_en)),'{}'::jsonb),bool_and(verificado)
    into v_manual,v_ready from public.kombax_pilot_readiness_v117;
  v_owner_password:=to_regprocedure('public.app_kombax_platform_admin_password_session_v139()') is not null
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_password_session_v139()','EXECUTE');
  v_critical_otp:=to_regprocedure('public.app_kombax_platform_admin_challenge_start_v108()') is not null
    and to_regprocedure('public.app_kombax_platform_admin_challenge_complete_v108(uuid)') is not null
    and to_regprocedure('public.app_kombax_platform_critical_authorized_v139()') is not null
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_challenge_start_v108()','EXECUTE')
    and has_function_privilege('authenticated','public.app_kombax_platform_admin_challenge_complete_v108(uuid)','EXECUTE');
  return jsonb_build_object(
    'build',20077,'pilot_ready',coalesce(v_ready,false),'manual',v_manual,
    'technical',jsonb_build_object(
      'rls_verifiers',to_regclass('public.kombax_verificadores_globales_v117') is not null,
      'private_docs_policy',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='kombax_verification_docs_select_v117'),
      'owner_password_console',v_owner_password,
      'owner_critical_otp',v_critical_otp,
      'owner_mfa',v_critical_otp,
      'owner_password_only_executable',v_owner_password,
      'privacy_deletion_owner_queue',to_regprocedure('public.app_kombax_deletion_queue_v119(text,integer)') is not null,
      'minor_guardian_consent',to_regclass('public.kombax_social_minor_consents_v121') is not null,
      'message_report_evidence',to_regclass('public.kombax_message_report_evidence_v122') is not null,
      'incident_capture',to_regprocedure('public.app_kombax_client_incident_report_v117(text,text,text,jsonb)') is not null
    )
  );
end $$;
revoke all on function public.app_kombax_pilot_readiness_status_v117() from public,anon;
grant execute on function public.app_kombax_pilot_readiness_status_v117() to authenticated;

notify pgrst,'reload schema';
commit;
