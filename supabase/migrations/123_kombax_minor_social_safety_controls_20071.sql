-- KOMBAX RC13 build 20071 · 123
-- Refuerza el control adulto 121: gestión reversible, estado explícito y
-- recordatorio de seguridad obligatorio para el menor antes de activar Social.
begin;

alter table public.kombax_social_minor_consents_v121
  add column if not exists safety_version text not null default '2026-08-23',
  add column if not exists minor_safety_ack_at timestamptz;

create or replace function public.app_kombax_social_minor_consent_status_v121()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_mine jsonb;v_approvals jsonb;v_managed jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'consent_id',c.id,'club_id',c.club_id,'socio_id',c.socio_id,'estado',c.estado,
    'tutor_profile_id',c.tutor_profile_id,'tutor_name',trim(concat_ws(' ',p.nombre,p.apellidos)),
    'solicitado_en',c.solicitado_en,'decidido_en',c.decidido_en,'revocado_en',c.revocado_en,
    'safety_version',c.safety_version,'minor_safety_ack_at',c.minor_safety_ack_at
  ) order by c.solicitado_en desc),'[]'::jsonb) into v_mine
  from public.kombax_social_minor_consents_v121 c
  join public.perfiles p on p.id=c.tutor_profile_id
  where c.minor_profile_id=v_uid;

  select coalesce(jsonb_agg(jsonb_build_object(
    'consent_id',c.id,'club_id',c.club_id,'socio_id',c.socio_id,'estado',c.estado,
    'minor_profile_id',c.minor_profile_id,'minor_name',trim(concat_ws(' ',s.nombre,s.apellidos)),
    'solicitado_en',c.solicitado_en,'decidido_en',c.decidido_en,'revocado_en',c.revocado_en,
    'safety_version',c.safety_version
  ) order by c.solicitado_en asc),'[]'::jsonb) into v_approvals
  from public.kombax_social_minor_consents_v121 c
  join public.socios s on s.id=c.socio_id
  where c.tutor_profile_id=v_uid and c.estado='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'consent_id',c.id,'club_id',c.club_id,'socio_id',c.socio_id,'estado',c.estado,
    'minor_profile_id',c.minor_profile_id,'minor_name',trim(concat_ws(' ',s.nombre,s.apellidos)),
    'solicitado_en',c.solicitado_en,'decidido_en',c.decidido_en,'revocado_en',c.revocado_en,
    'safety_version',c.safety_version
  ) order by c.actualizado_en desc),'[]'::jsonb) into v_managed
  from public.kombax_social_minor_consents_v121 c
  join public.socios s on s.id=c.socio_id
  where c.tutor_profile_id=v_uid and c.estado in ('approved','rejected','revoked');

  return jsonb_build_object('mine',v_mine,'approvals',v_approvals,'managed',v_managed);
end $$;
revoke all on function public.app_kombax_social_minor_consent_status_v121() from public,anon;
grant execute on function public.app_kombax_social_minor_consent_status_v121() to authenticated;

create or replace function public.app_kombax_social_minor_consent_mutate_v121(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_existing public.app_mutation_requests;v_result jsonb;v_club uuid;v_socio public.socios;v_tutor uuid;v_id uuid;v_state text;v_consent public.kombax_social_minor_consents_v121;v_age integer;v_social uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation not in ('kombax.social.minor.consent.request','kombax.social.minor.consent.decide') then raise exception 'KOMBAX_MINOR_CONSENT_OPERATION_INVALID';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,nullif(p_payload->>'club_id','')::uuid,p_operation);
  end if;

  if p_operation='kombax.social.minor.consent.request' then
    begin v_club:=(p_payload->>'club_id')::uuid;exception when others then raise exception 'KOMBAX_CLUB_ID_INVALID';end;
    select * into v_socio from public.socios where club_id=v_club and perfil_id=v_uid and estado='activo' order by creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_SOCIAL_AGE_VERIFICATION_REQUIRED';end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
    if v_age>=18 then raise exception 'KOMBAX_MINOR_CONSENT_NOT_REQUIRED';end if;
    select t.tutor_perfil_id into v_tutor from public.tutores_socios t where t.club_id=v_club and t.socio_id=v_socio.id and t.contacto_principal order by t.id limit 1;
    if v_tutor is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_LINK_REQUIRED';end if;
    insert into public.kombax_social_minor_consents_v121(club_id,socio_id,minor_profile_id,tutor_profile_id,estado,rules_version,safety_version,solicitado_en,decidido_en,revocado_en,minor_safety_ack_at,actualizado_en)
    values(v_club,v_socio.id,v_uid,v_tutor,'pending','1.3','2026-08-23',now(),null,null,null,now())
    on conflict(club_id,socio_id,tutor_profile_id) do update set minor_profile_id=excluded.minor_profile_id,estado='pending',rules_version='1.3',safety_version='2026-08-23',solicitado_en=now(),decidido_en=null,revocado_en=null,minor_safety_ack_at=null,actualizado_en=now()
    returning * into v_consent;
    v_result:=jsonb_build_object('consent_id',v_consent.id,'estado',v_consent.estado,'tutor_profile_id',v_tutor);
  else
    begin v_id:=(p_payload->>'consent_id')::uuid;exception when others then raise exception 'KOMBAX_MINOR_CONSENT_ID_INVALID';end;
    v_state:=lower(coalesce(p_payload->>'estado',''));
    if v_state not in ('approved','rejected','revoked') then raise exception 'KOMBAX_MINOR_CONSENT_STATE_INVALID';end if;
    select * into v_consent from public.kombax_social_minor_consents_v121 where id=v_id for update;
    if v_consent.id is null or v_consent.tutor_profile_id<>v_uid then raise exception 'KOMBAX_MINOR_CONSENT_FORBIDDEN';end if;
    if not exists(select 1 from public.tutores_socios t where t.club_id=v_consent.club_id and t.socio_id=v_consent.socio_id and t.tutor_perfil_id=v_uid) then raise exception 'KOMBAX_MINOR_CONSENT_RELATION_REQUIRED';end if;
    update public.kombax_social_minor_consents_v121
       set estado=v_state,decidido_en=case when v_state in ('approved','rejected') then now() else decidido_en end,
           revocado_en=case when v_state='revoked' then now() else null end,
           minor_safety_ack_at=case when v_state='approved' then null else minor_safety_ack_at end,
           actualizado_en=now()
     where id=v_id returning * into v_consent;

    select sp.id into v_social
    from public.identidades_sociales i join public.kombax_social_perfiles sp on sp.identidad_social_id=i.id
    where i.perfil_id=v_consent.minor_profile_id limit 1;

    if v_state='revoked' then
      update public.identidades_sociales set estado='suspendida',suspendida_en=now(),suspension_motivo='guardian_revoked_v123',actualizado_en=now()
      where perfil_id=v_consent.minor_profile_id and estado='activa';
      update public.kombax_social_perfiles set estado='limitado',visible=false,publicar_habilitado=false,contacto_habilitado=false,actualizado_en=now()
      where id=v_social;
      update public.perfiles_kombax_directos set social_activo=false,social_activado_en=null,actualizado_en=now()
      where perfil_id=v_consent.minor_profile_id and fecha_nacimiento_verificada is not null and extract(year from age(current_date,fecha_nacimiento_verificada))<18;
    end if;
    v_result:=jsonb_build_object('consent_id',v_consent.id,'estado',v_consent.estado,'social_profile_id',v_social);
  end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_social_minor_consent_mutate_v121(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_minor_consent_mutate_v121(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_social_estado_v123(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_uid uuid:=auth.uid();v_socio public.socios;v_age integer;v_consent public.kombax_social_minor_consents_v121;v_identity public.identidades_sociales;v_direct public.perfiles_kombax_directos;
begin
  v:=public.app_kombax_social_estado_v065(p_club_id);
  if v_uid is null then return v;end if;
  select * into v_socio from public.socios s where s.perfil_id=v_uid and s.estado='activo' and s.fecha_nacimiento is not null and (p_club_id is null or s.club_id=p_club_id) order by s.creado_en desc limit 1;
  if v_socio.id is not null then
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
    if v_age<18 then
      select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.club_id=v_socio.club_id order by c.actualizado_en desc limit 1;
      select * into v_identity from public.identidades_sociales where perfil_id=v_uid limit 1;
      if v_consent.estado='approved' and v_consent.revocado_en is null then
        if v_identity.estado='suspendida' and v_identity.suspension_motivo='guardian_revoked_v123' then
          return v||jsonb_build_object('status','inactiva','eligible',true,'minor',true,'age',v_age,'guardian_required',true,'guardian_approved',true,'safety_reminder_required',true,'reason','Tu tutor ha vuelto a autorizar KOMBAX Social. Revisa el recordatorio de seguridad para reactivar tu perfil.');
        end if;
        return v||jsonb_build_object('minor',true,'age',v_age,'guardian_required',true,'guardian_approved',true,'safety_reminder_required',true);
      end if;
      return v||jsonb_build_object('status','inactiva','eligible',false,'minor',true,'age',v_age,'guardian_required',true,'guardian_approved',false,'guardian_state',coalesce(v_consent.estado,'none'),'safety_reminder_required',false,
        'reason',case when v_consent.estado='pending' then 'La autorización del tutor está pendiente.' when v_consent.estado='rejected' then 'El tutor no ha autorizado KOMBAX Social.' when v_consent.estado='revoked' then 'El tutor ha desactivado KOMBAX Social.' else 'Para usar KOMBAX Social siendo menor de 18 años, un padre, madre o tutor vinculado debe autorizarlo.' end);
    end if;
  end if;

  if coalesce(v->>'scope','')='global' and nullif(v->>'direct_profile_id','') is not null then
    select * into v_direct from public.perfiles_kombax_directos where id=(v->>'direct_profile_id')::uuid and perfil_id=v_uid;
    if v_direct.id is not null and v_direct.fecha_nacimiento_verificada is not null and v_direct.fecha_nacimiento_verificada>current_date-interval '18 years' then
      select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.estado='approved' and c.revocado_en is null order by c.actualizado_en desc limit 1;
      if v_consent.id is null then return v||jsonb_build_object('status','inactiva','eligible',false,'minor',true,'guardian_required',true,'guardian_approved',false,'safety_reminder_required',false,'reason','La activación Social de un Competidor menor de 18 años requiere autorización de un tutor vinculado al club.');end if;
      return v||jsonb_build_object('minor',true,'guardian_required',true,'guardian_approved',true,'safety_reminder_required',true);
    end if;
  end if;
  return v||jsonb_build_object('minor',false,'guardian_required',false,'guardian_approved',true,'safety_reminder_required',false);
end $$;
revoke all on function public.app_kombax_social_estado_v123(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v123(uuid) to authenticated;

create or replace function public.app_kombax_identity_mutate_v123(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_socio public.socios;v_age integer;v_club uuid;v_consent public.kombax_social_minor_consents_v121;v_identity public.identidades_sociales;v_result jsonb;
begin
  if p_operation='kombax.identity.member.activate' then
    begin v_club:=nullif(p_payload->>'club_id','')::uuid;exception when others then v_club:=null;end;
    select * into v_socio from public.socios where perfil_id=v_uid and estado='activo' and fecha_nacimiento is not null and (v_club is null or club_id=v_club) order by creado_en desc limit 1;
    if v_socio.id is not null then
      v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;
      if v_age<18 then
        select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.club_id=v_socio.club_id and c.estado='approved' and c.revocado_en is null order by c.actualizado_en desc limit 1;
        if v_consent.id is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';end if;
        if coalesce((p_payload->>'acepta_seguridad_menor')::boolean,false) is not true then raise exception 'KOMBAX_MINOR_SOCIAL_SAFETY_REMINDER_REQUIRED';end if;
        select * into v_identity from public.identidades_sociales where perfil_id=v_uid for update;
        if v_identity.estado='suspendida' and v_identity.suspension_motivo='guardian_revoked_v123' then
          update public.identidades_sociales set estado='activa',suspendida_en=null,suspension_motivo=null,actualizado_en=now() where id=v_identity.id;
        end if;
      end if;
    end if;
  end if;
  v_result:=public.app_kombax_identity_mutate_v094(p_operation,p_payload,p_request_id);
  if p_operation='kombax.identity.member.activate' and v_consent.id is not null then
    update public.kombax_social_minor_consents_v121 set minor_safety_ack_at=now(),safety_version='2026-08-23',actualizado_en=now() where id=v_consent.id;
  end if;
  return v_result;
end $$;
revoke all on function public.app_kombax_identity_mutate_v123(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v123(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_social_mutate_v123(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_direct public.perfiles_kombax_directos;v_consent public.kombax_social_minor_consents_v121;v_result jsonb;
begin
  if p_operation='kombax.social.direct.activate' then
    begin select * into v_direct from public.perfiles_kombax_directos where id=(p_payload->>'perfil_directo_id')::uuid and perfil_id=v_uid;exception when others then v_direct.id:=null;end;
    if v_direct.id is not null and v_direct.fecha_nacimiento_verificada is not null and v_direct.fecha_nacimiento_verificada>current_date-interval '18 years' then
      select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.estado='approved' and c.revocado_en is null order by c.actualizado_en desc limit 1;
      if v_consent.id is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';end if;
      if coalesce((p_payload->>'acepta_seguridad_menor')::boolean,false) is not true then raise exception 'KOMBAX_MINOR_SOCIAL_SAFETY_REMINDER_REQUIRED';end if;
    end if;
  end if;
  v_result:=public.app_kombax_social_mutate_v099(p_operation,p_payload,p_request_id);
  if p_operation='kombax.social.direct.activate' and v_consent.id is not null then update public.kombax_social_minor_consents_v121 set minor_safety_ack_at=now(),safety_version='2026-08-23',actualizado_en=now() where id=v_consent.id;end if;
  return v_result;
end $$;
revoke all on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
