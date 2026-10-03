-- KOMBAX R117 build 20174 · canonical Perfil Social for independent Member/Practitioner.
-- Uses the private canonical DOB already collected at account creation. Club membership
-- is not required for the Perfil Social/album/network, but feed publication remains off
-- until the Club confirms membership.

create or replace function public.app_kombax_identity_mutate_v124(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_identity public.identidades_sociales;
  v_profile public.perfiles;
  v_social_id uuid;
  v_locked text;
  v_name text;
  v_rules text:='1.2.0';
  v_result jsonb;
  v_dob date;
  v_age integer;
begin
  if p_operation not in ('kombax.identity.member.activate','kombax.identity.member.profile.update') then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  begin v_club:=nullif(p_payload->>'club_id','')::uuid;
  exception when others then v_club:=null; end;

  if p_operation='kombax.identity.member.profile.update' then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  if public.app_kombax_member_membership_confirmed_r115(v_club) then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  if nullif(p_payload->>'fecha_nacimiento','') is not null then
    begin
      perform public.app_kombax_account_birth_date_set_r117((p_payload->>'fecha_nacimiento')::date);
    exception when others then
      raise exception 'KOMBAX_PROFILE_BIRTH_DATE_INVALID';
    end;
  end if;

  select a.fecha_nacimiento into v_dob
  from public.kombax_account_private_r117 a
  where a.perfil_id=v_uid;
  if v_dob is null then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED'; end if;

  v_age:=public.app_kombax_birth_date_validate_r117(v_dob);
  if v_age<16 then raise exception 'KOMBAX_MEMBER_INDEPENDENT_MIN_AGE_16'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,p_operation);
  end if;

  if coalesce((p_payload->>'acepta_normas')::boolean,false) is not true
     or coalesce((p_payload->>'acepta_privacidad')::boolean,false) is not true then
    raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';
  end if;

  select account_type into v_locked
  from public.kombax_account_types_r100
  where user_id=v_uid for update;

  if v_locked is null then
    insert into public.kombax_account_types_r100(user_id,account_type)
    values(v_uid,'miembro') on conflict(user_id) do nothing;
  elsif v_locked not in ('miembro','competidor') then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;

  select * into v_profile from public.perfiles where id=v_uid;
  if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;

  select * into v_identity
  from public.identidades_sociales where perfil_id=v_uid for update;
  if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then
    raise exception 'KOMBAX_SOCIAL_REACTIVATION_REQUIRES_REVIEW';
  end if;

  select t.version into v_rules
  from public.textos_legales t
  where t.tipo='comunidad_general' and t.vigente
  order by t.creado_en desc limit 1;
  v_rules:=coalesce(v_rules,'1.2.0');

  v_name:=btrim(concat_ws(' ',nullif(v_profile.nombre,''),nullif(v_profile.apellidos,'')));
  if v_name='' then v_name:=split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1); end if;

  if v_identity.id is null then
    insert into public.identidades_sociales(
      perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,
      estado,version_normas,activada_en,actualizado_en
    ) values(
      v_uid,null,null,'miembro','miembro-'||replace(v_uid::text,'-',''),
      left(v_name,160),'activa',v_rules,now(),now()
    ) returning * into v_identity;
  else
    update public.identidades_sociales
       set nombre_publico=left(v_name,160),
           version_normas=coalesce(version_normas,v_rules),
           actualizado_en=now()
     where id=v_identity.id
     returning * into v_identity;
  end if;

  select sp.id into v_social_id
  from public.kombax_social_perfiles sp
  where sp.sujeto_tipo='miembro' and sp.identidad_social_id=v_identity.id;
  if v_social_id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_CREATED'; end if;

  insert into public.kombax_actor_audit(
    actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle
  ) values(
    v_uid,v_social_id,null,'social.member.public_profile.activate','social_profile',v_social_id,
    jsonb_build_object(
      'membership_confirmed',false,'publication_enabled',false,'album_enabled',true,
      'network_enabled',true,'profile_social_enabled',true,'source','self_service_no_club_r117'
    )
  );

  v_result:=jsonb_build_object(
    'ok',true,'operation',p_operation,'request_id',p_request_id,
    'data',jsonb_build_object(
      'identidad_social_id',v_identity.id,'social_profile_id',v_social_id,
      'status','activa','membership_confirmed',false,'publication_enabled',false,
      'album_enabled',true,'network_enabled',true,'profile_social_enabled',true,
      'birth_date_reused',true,'rules_version',v_rules
    )
  );

  update public.app_mutation_requests
     set result=v_result,completed_at=now()
   where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;

notify pgrst,'reload schema';
