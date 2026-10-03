-- KOMBAX R118 · Phase 3 · multifacet identity compatibility
-- Non-destructive: keeps R100 metadata and trigger names, removes exclusivity as authorization.

comment on table public.kombax_account_types_r100 is
'LEGACY R100 onboarding classification. Since R118 this value is not an authorization or identity exclusivity source. Use memberships, managed organizations, direct facets and entitlements.';

CREATE OR REPLACE FUNCTION public.app_kombax_account_type_lock_r100()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
declare
  v_uid uuid:=new.perfil_id;
  v_type text:=new.tipo;
  v_member boolean:=false;
  v_club_admin boolean:=false;
  v_intended text;
begin
  if v_uid is null then return new; end if;
  select exists(
    select 1 from public.miembros_club m
    where m.perfil_id=v_uid and m.activo and (m.rol='direccion' or m.coordinacion)
  ) into v_club_admin;
  select (
    exists(select 1 from public.miembros_club m where m.perfil_id=v_uid and m.activo and m.rol in ('alumno','familia'))
    or exists(select 1 from public.socios s where s.perfil_id=v_uid and s.estado='activo' and s.kombax_acceso_estado='activo')
    or exists(select 1 from public.identidades_sociales i where i.perfil_id=v_uid and i.estado='activa')
  ) into v_member;
  v_intended:=case
    when v_club_admin then 'club'
    when v_member then 'miembro'
    when v_type in ('club','miembro','competidor','marca','federacion','profesional','media') then v_type
    else 'miembro'
  end;
  insert into public.kombax_account_types_r100(user_id,account_type)
  values(v_uid,v_intended)
  on conflict(user_id) do nothing;
  -- R118: account_type is legacy onboarding metadata only. It must never block
  -- compatible personal facets or organization management.
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.app_kombax_account_identity_guard_r100()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
declare
  v_uid uuid:=new.perfil_id;
  v_type text:=new.tipo;
  v_identity uuid;
begin
  if v_uid is null then return new; end if;

  if tg_table_name='kombax_solicitudes_alta' and new.perfil_directo_id is not null then
    if not exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=new.perfil_directo_id
        and d.perfil_id=v_uid
        and d.tipo=v_type
    ) then
      raise exception 'KOMBAX_PROFILE_APPLICATION_MISMATCH';
    end if;
  end if;

  if tg_table_name='perfiles_kombax_directos'
     and v_type in ('competidor','profesional','espectador')
     and new.origen_identidad_social_id is null then
    select i.id into v_identity
    from public.identidades_sociales i
    where i.perfil_id=v_uid
    order by i.activada_en
    limit 1;
    if v_identity is not null then
      new.origen_identidad_social_id:=v_identity;
    end if;
  end if;

  -- R118 deliberately permits multiple compatible facets for the same account.
  -- Organization roles are governed separately by miembros_club/perfil managers.
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.app_kombax_identity_mutate_v124(p_operation text, p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_identity public.identidades_sociales;
  v_profile public.perfiles;
  v_social_id uuid;
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

  begin
    v_club:=nullif(p_payload->>'club_id','')::uuid;
  exception when others then
    v_club:=null;
  end;

  -- Editing one's Perfil Social never depends on club membership.
  if p_operation='kombax.identity.member.profile.update' then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  -- Confirmed memberships keep the established minor/guardian flow.
  if public.app_kombax_member_membership_confirmed_r115(v_club) then
    return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
  end if;

  -- If DOB is explicitly supplied, persist it in the canonical private account record.
  if nullif(p_payload->>'fecha_nacimiento','') is not null then
    begin
      perform public.app_kombax_account_birth_date_set_r117(
        (p_payload->>'fecha_nacimiento')::date
      );
    exception when others then
      raise exception 'KOMBAX_PROFILE_BIRTH_DATE_INVALID';
    end;
  end if;

  select a.fecha_nacimiento into v_dob
  from public.kombax_account_private_r117 a
  where a.perfil_id=v_uid;

  if v_dob is null then
    raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED';
  end if;

  v_age:=public.app_kombax_birth_date_validate_r117(v_dob);
  if v_age<16 then
    raise exception 'KOMBAX_MEMBER_INDEPENDENT_MIN_AGE_16';
  end if;

  select * into v_existing
  from public.app_mutation_requests
  where request_id=p_request_id;

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

  -- R118: preserve a legacy onboarding hint without making it an authorization gate.
  insert into public.kombax_account_types_r100(user_id,account_type)
  values(v_uid,'miembro')
  on conflict(user_id) do nothing;

  select * into v_profile
  from public.perfiles
  where id=v_uid;

  if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;

  select * into v_identity
  from public.identidades_sociales
  where perfil_id=v_uid
  for update;

  if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then
    raise exception 'KOMBAX_SOCIAL_REACTIVATION_REQUIRES_REVIEW';
  end if;

  select t.version into v_rules
  from public.textos_legales t
  where t.tipo='comunidad_general' and t.vigente
  order by t.creado_en desc
  limit 1;
  v_rules:=coalesce(v_rules,'1.2.0');

  v_name:=btrim(concat_ws(
    ' ',
    nullif(v_profile.nombre,''),
    nullif(v_profile.apellidos,'')
  ));
  if v_name='' then
    v_name:=split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1);
  end if;

  if v_identity.id is null then
    insert into public.identidades_sociales(
      perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,
      estado,version_normas,activada_en,actualizado_en
    )
    values(
      v_uid,null,null,'miembro',
      'miembro-'||replace(v_uid::text,'-',''),
      left(v_name,160),'activa',v_rules,now(),now()
    )
    returning * into v_identity;
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
  where sp.sujeto_tipo='miembro'
    and sp.identidad_social_id=v_identity.id;

  if v_social_id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_CREATED'; end if;

  insert into public.kombax_actor_audit(
    actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle
  )
  values(
    v_uid,v_social_id,null,
    'social.member.public_profile.activate',
    'social_profile',v_social_id,
    jsonb_build_object(
      'membership_confirmed',false,
      'publication_enabled',false,
      'album_enabled',true,
      'network_enabled',true,
      'profile_social_enabled',true,
      'source','self_service_no_club_r117'
    )
  );

  v_result:=jsonb_build_object(
    'ok',true,
    'operation',p_operation,
    'request_id',p_request_id,
    'data',jsonb_build_object(
      'identidad_social_id',v_identity.id,
      'social_profile_id',v_social_id,
      'status','activa',
      'membership_confirmed',false,
      'publication_enabled',false,
      'album_enabled',true,
      'network_enabled',true,
      'profile_social_enabled',true,
      'birth_date_reused',true,
      'rules_version',v_rules
    )
  );

  update public.app_mutation_requests
     set result=v_result,completed_at=now()
   where request_id=p_request_id;

  return v_result;

exception when others then
  delete from public.app_mutation_requests
   where request_id=p_request_id and result is null;
  raise;
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_pilot_club_activate_r110(p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_email text;
  v_email_confirmed timestamptz;
  v_profile public.perfiles;
  v_type text;
  v_name text:=btrim(coalesce(v_payload->>'nombre_publico',''));
  v_phone text:=btrim(coalesce(v_payload->>'telefono',''));
  v_location text:=btrim(coalesce(v_payload->>'ubicacion',''));
  v_disciplines jsonb:=case
    when jsonb_typeof(coalesce(v_payload->'disciplinas','[]'::jsonb))='array'
      then coalesce(v_payload->'disciplinas','[]'::jsonb)
    else '[]'::jsonb
  end;
  v_public jsonb;
  v_verify jsonb;
  v_club uuid;
  v_application uuid;
  v_open timestamptz;
  v_close timestamptz;
  v_pilot_end timestamptz;
  v_slots integer:=4;
  v_used integer:=0;
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_manager_name text;
  v_open_application uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing
  from public.app_mutation_requests
  where request_id=p_request_id;

  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid
       or v_existing.operation<>'kombax.pilot.club.activate.r110' then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,'kombax.pilot.club.activate.r110');
  end if;

  select lower(coalesce(u.email,'')),u.email_confirmed_at
    into v_email,v_email_confirmed
  from auth.users u
  where u.id=v_uid and u.deleted_at is null;

  if v_email='' or v_email_confirmed is null then
    raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED';
  end if;

  select * into v_profile
  from public.perfiles p
  where p.id=v_uid;

  if v_profile.id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;

  -- R118: account_type is a legacy onboarding hint. A person may manage a Club
  -- while retaining Member/Competitor/Professional facets.
  select account_type into v_type
  from public.kombax_account_types_r100
  where user_id=v_uid;

  if v_type is null then
    insert into public.kombax_account_types_r100(user_id,account_type)
    values(v_uid,'club')
    on conflict(user_id) do nothing;
    v_type:='club';
  end if;

  select trim(both '"' from value::text)::timestamptz into v_open
  from kombax_commercial.runtime_config_r64
  where config_key='pilot_registration_open_at';

  select trim(both '"' from value::text)::timestamptz into v_close
  from kombax_commercial.runtime_config_r64
  where config_key='pilot_registration_close_at';

  select trim(both '"' from value::text)::timestamptz into v_pilot_end
  from kombax_commercial.runtime_config_r64
  where config_key='pilot_end_at';

  if v_open is null or v_close is null or now()<v_open or now()>=v_close then
    raise exception 'KOMBAX_PILOT_REGISTRATION_CLOSED';
  end if;

  -- Alta progresiva: para crear el Club Piloto solo son imprescindibles
  -- la cuenta confirmada, el nombre del club y la declaración.
  if char_length(v_name)<2 or char_length(v_name)>160 then
    raise exception 'KOMBAX_CLUB_NAME_INVALID';
  end if;

  if coalesce((v_payload->>'declaration')::boolean,false) is not true then
    raise exception 'KOMBAX_DECLARATION_REQUIRED';
  end if;

  -- Si se informa teléfono, se valida. No es obligatorio para crear el club.
  if v_phone<>'' and char_length(regexp_replace(v_phone,'[^0-9+]','','g'))<6 then
    raise exception 'KOMBAX_CLUB_PHONE_INVALID';
  end if;

  select m.club_id into v_club
  from public.miembros_club m
  join public.clubes c on c.id=m.club_id
  where m.perfil_id=v_uid
    and m.activo
    and (m.rol='direccion' or m.coordinacion)
  order by m.creado_en
  limit 1;

  if v_club is not null then
    if exists(
      select 1
      from kombax_commercial.pilot_entities_r97 p
      where p.subject_type='club' and p.subject_id=v_club
    ) then
      select application_id into v_application
      from kombax_commercial.pilot_club_activations_r110
      where club_id=v_club;

      v_result:=jsonb_build_object(
        'ok',true,
        'reused',true,
        'club_id',v_club,
        'application_id',v_application,
        'plan_code','premium',
        'document_verification_required',false,
        'approval_required',false,
        'founder_eligible',true,
        'invite_code_required',false,
        'registration_mode','open',
        'progressive_profile_completion',true
      );

      update public.app_mutation_requests
      set club_id=v_club,result=v_result,completed_at=now()
      where request_id=p_request_id;

      return v_result;
    end if;

    raise exception 'KOMBAX_ACCOUNT_ALREADY_MANAGES_CLUB';
  end if;

  perform pg_advisory_xact_lock(hashtext('kombax-pilot-club-slots'));

  select greatest(0,least(4,coalesce(value::text::integer,4))) into v_slots
  from kombax_commercial.runtime_config_r64
  where config_key='pilot_club_slots';

  v_slots:=coalesce(v_slots,4);

  select count(*) into v_used
  from kombax_commercial.pilot_entities_r97
  where subject_type='club';

  if v_used>=v_slots then raise exception 'KOMBAX_PILOT_CLUB_SLOTS_FULL'; end if;

  select s.id into v_open_application
  from public.kombax_solicitudes_alta s
  where s.perfil_id=v_uid
    and s.tipo='club'
    and s.estado in ('draft','submitted','under_review','needs_information')
  order by s.creado_en desc
  limit 1;

  if v_open_application is not null then
    update public.kombax_solicitudes_alta
       set estado='withdrawn',
           motivo_revision='Sustituida por alta directa Club Piloto R117',
           actualizado_en=now()
     where id=v_open_application;
  end if;

  v_manager_name:=btrim(concat_ws(
    ' ',
    nullif(v_profile.nombre,''),
    nullif(v_profile.apellidos,'')
  ));
  if v_manager_name='' then v_manager_name:=split_part(v_email,'@',1); end if;

  v_public:=jsonb_build_object(
    'ubicacion',nullif(v_location,''),
    'ciudad',left(nullif(btrim(coalesce(v_payload->>'ciudad','')),''),120),
    'provincia',left(nullif(btrim(coalesce(v_payload->>'provincia','')),''),120),
    'pais',left(coalesce(nullif(btrim(v_payload->>'pais'),''),'España'),120),
    'disciplinas',v_disciplines,
    'lema',left(nullif(btrim(coalesce(v_payload->>'lema','')),''),180),
    'descripcion',left(nullif(btrim(coalesce(v_payload->>'descripcion','')),''),1600),
    'web_publica',nullif(btrim(coalesce(v_payload->>'web_publica','')),''),
    'instagram',left(nullif(btrim(coalesce(v_payload->>'instagram','')),''),180)
  );

  v_verify:=jsonb_build_object(
    'pilot_activation',true,
    'verification_source','pilot_program_open_progressive_r117',
    'registration_mode','open',
    'invite_code_required',false,
    'approval_required',false,
    'document_bypass',true,
    'nombre_legal',v_name,
    'email_oficial',v_email,
    'telefono',nullif(v_phone,''),
    'responsable',v_manager_name,
    'rol_responsable','direccion',
    'evidencia','pilot_program_open_self_service_r117'
  );

  v_club:=public.app_kombax_create_pilot_club_core_r117(
    v_uid,v_name,v_public,v_verify,v_uid
  );

  insert into public.kombax_solicitudes_alta(
    perfil_id,tipo,perfil_directo_id,club_id,nombre_publico,
    datos_publicos,datos_verificacion,estado,
    schema_version,declaracion_aceptada,declaracion_en,requisitos_version,
    enviado_en,revisado_por,revisado_en,motivo_revision
  )
  values(
    v_uid,'club',null,v_club,v_name,
    v_public,v_verify,'verified',
    6,true,now(),'pilot-open-progressive-r117',
    now(),null,null,
    'Alta directa Club Piloto; sin código, documentación ni aprobación previa.'
  )
  returning id into v_application;

  insert into public.kombax_verificacion_eventos(
    solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle
  )
  values(
    v_application,null,v_uid,'verified',
    jsonb_build_object(
      'club_id',v_club,
      'source','pilot_program_open_progressive_r117',
      'invite_code_required',false,
      'approval_required',false,
      'document_verification_required',false,
      'progressive_profile_completion',true
    )
  );

  insert into kombax_commercial.pilot_entities_r97(
    subject_type,subject_id,enrolled_by,founder_eligible,notes
  )
  values(
    'club',v_club,v_uid,true,
    'Alta directa y progresiva Club Piloto R117; continuidad como Club fundador'
  )
  on conflict(subject_type,subject_id)
  do update set
    founder_eligible=true,
    notes=excluded.notes;

  insert into kombax_commercial.plan_benefits_r97(
    subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by
  )
  values(
    'club',v_club,'PILOT_ACCESS','premium',now(),v_pilot_end,
    'pilot_open_progressive_r117',v_uid
  )
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;

  insert into kombax_commercial.pilot_club_activations_r110(
    club_id,manager_profile_id,application_id,activated_at,
    activation_source,activation_status,founder_eligible
  )
  values(
    v_club,v_uid,v_application,now(),
    'pilot_open_progressive_r117','active',true
  )
  on conflict(club_id)
  do update set
    application_id=excluded.application_id,
    manager_profile_id=excluded.manager_profile_id,
    activation_source=excluded.activation_source,
    activation_status='active',
    founder_eligible=true;

  insert into public.kombax_actor_audit(
    actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle
  )
  values(
    v_uid,v_club,'kombax.pilot.club.activate.r110','club',v_club,
    jsonb_build_object(
      'application_id',v_application,
      'plan_code','premium',
      'registration_mode','open',
      'invite_code_required',false,
      'approval_required',false,
      'document_verification_required',false,
      'progressive_profile_completion',true
    )
  );

  v_result:=jsonb_build_object(
    'ok',true,
    'reused',false,
    'club_id',v_club,
    'application_id',v_application,
    'plan_code','premium',
    'pilot_end_at',v_pilot_end,
    'registration_mode','open',
    'invite_code_required',false,
    'approval_required',false,
    'document_verification_required',false,
    'founder_eligible',true,
    'member_linking_ready',true,
    'club_persists_after_pilot',true,
    'progressive_profile_completion',true
  );

  update public.app_mutation_requests
     set club_id=v_club,result=v_result,completed_at=now()
   where request_id=p_request_id;

  return v_result;

exception when others then
  delete from public.app_mutation_requests
  where request_id=p_request_id and result is null;
  raise;
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_social_estado_v124(p_club_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v jsonb;
  v_uid uuid:=auth.uid();
  v_confirmed boolean:=false;
  v_identity public.identidades_sociales;
begin
  v:=public.app_kombax_social_estado_v123(p_club_id);
  if v_uid is null then return v; end if;

  select * into v_identity
  from public.identidades_sociales
  where perfil_id=v_uid
  limit 1;

  if v_identity.id is not null then
    v_confirmed:=public.app_kombax_member_membership_confirmed_r115(p_club_id);
    return v||jsonb_build_object(
      'scope','member',
      'status',case when v_identity.estado='activa' then 'activa' else 'inactiva' end,
      'eligible',v_identity.estado='activa',
      'membership_confirmed',v_confirmed,
      'publication_enabled',v_confirmed and v_identity.estado='activa',
      'album_enabled',v_identity.estado='activa',
      'profile_enabled',v_identity.estado='activa',
      'reason',case
        when v_identity.estado<>'activa' then 'Tu perfil público está suspendido o cerrado.'
        when v_confirmed then 'Tu perfil público está activo y tu club ha confirmado la membresía.'
        else 'Tu perfil público está activo. Podrás publicar en KOMBAX Social cuando un club confirme tu membresía.'
      end
    );
  end if;

  if exists(select 1 from public.perfiles p where p.id=v_uid) then
    return v||jsonb_build_object(
      'scope','person',
      'status','inactiva',
      'eligible',true,
      'membership_confirmed',false,
      'publication_enabled',false,
      'album_enabled',true,
      'profile_enabled',true,
      'reason','Tu cuenta KOMBAX puede activar un único Perfil Social personal. Las facetas Competidor y Profesional se añaden sobre esta misma identidad.'
    );
  end if;

  return v;
end $function$
;

-- Attach existing personal facets to the canonical social identity when one already exists.
update public.perfiles_kombax_directos d
set origen_identidad_social_id=i.id,
    actualizado_en=now()
from public.identidades_sociales i
where i.perfil_id=d.perfil_id
  and d.tipo in ('competidor','profesional','espectador')
  and d.origen_identidad_social_id is null;

-- Contract assertions.
do $$
begin
  if position('KOMBAX_ACCOUNT_TYPE_IMMUTABLE' in pg_get_functiondef('public.app_kombax_account_type_lock_r100()'::regprocedure))>0 then
    raise exception 'R118_ASSERT_ACCOUNT_LOCK_STILL_BLOCKING';
  end if;
  if position('KOMBAX_PILOT_CLUB_ACCOUNT_REQUIRED' in pg_get_functiondef('public.app_kombax_pilot_club_activate_r110(jsonb,uuid)'::regprocedure))>0 then
    raise exception 'R118_ASSERT_PILOT_CLUB_STILL_ACCOUNT_TYPE_BLOCKED';
  end if;
  if position('KOMBAX_MEMBER_ONLY_COMPETITOR' in pg_get_functiondef('public.app_kombax_account_identity_guard_r100()'::regprocedure))>0 then
    raise exception 'R118_ASSERT_IDENTITY_GUARD_STILL_EXCLUSIVE';
  end if;
end $$;
