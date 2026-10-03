-- KOMBAX R117 build 20174 · account/profile exist before club membership.
-- A user can request to join a club without already being a member. Club approval
-- creates/activates the private membership. Invitation codes remain an alternative,
-- not a prerequisite.

create or replace function public.app_crear_preinscripcion(
  p_club_id uuid,
  p_tipo_solicitud text,
  p_nombre text,
  p_apellidos text,
  p_fecha_nacimiento date,
  p_tutor_nombre text,
  p_tutor_email text,
  p_telefono text,
  p_disciplina_id uuid,
  p_grupo_id uuid,
  p_tarifa_id uuid,
  p_parentesco text default null,
  p_observaciones text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_id uuid;
  v_uid uuid:=auth.uid();
  v_solicitante uuid;
  v_edad smallint;
  v_email text;
  v_auth_email text;
  v_is_manager boolean:=false;
  v_disciplina uuid:=p_disciplina_id;
  v_grupo uuid:=p_grupo_id;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from public.clubes c where c.id=p_club_id and c.activo) then
    raise exception 'KOMBAX_CLUB_NOT_AVAILABLE';
  end if;
  if p_tipo_solicitud not in ('adulto','menor') then raise exception 'Tipo de solicitud no válido'; end if;
  if nullif(trim(coalesce(p_nombre,'')),'') is null
     or nullif(trim(coalesce(p_apellidos,'')),'') is null then
    raise exception 'Nombre y apellidos son obligatorios';
  end if;
  if p_fecha_nacimiento is null then raise exception 'KOMBAX_BIRTHDATE_REQUIRED_FOR_NEW_ENROLLMENT'; end if;

  v_edad:=extract(year from age(current_date,p_fecha_nacimiento))::smallint;
  if p_tipo_solicitud='adulto' and v_edad<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
  if p_tipo_solicitud='menor' and v_edad>=16 then raise exception 'KOMBAX_ADULT_MUST_USE_ADULT_FLOW'; end if;

  v_is_manager:=public.tiene_rol_club(p_club_id,'direccion','secretaria');
  if not v_is_manager then v_solicitante:=v_uid; end if;

  select lower(coalesce(u.email,'')) into v_auth_email
  from auth.users u where u.id=v_uid and u.deleted_at is null;

  v_email:=lower(btrim(coalesce(p_tutor_email,'')));
  if not v_is_manager and v_email='' then v_email:=v_auth_email; end if;

  if p_tipo_solicitud='menor' then
    if nullif(btrim(coalesce(p_tutor_nombre,'')),'') is null then
      raise exception 'KOMBAX_TUTOR_NAME_REQUIRED_FOR_NEW_MINOR';
    end if;
    if v_email='' or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception 'KOMBAX_TUTOR_EMAIL_REQUIRED_FOR_NEW_MINOR';
    end if;
  elsif not v_is_manager then
    if v_email='' or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception 'KOMBAX_ADULT_EMAIL_REQUIRED_FOR_NEW_ENROLLMENT';
    end if;
  elsif v_email<>'' and v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'KOMBAX_ADULT_EMAIL_INVALID';
  end if;

  if v_grupo is not null and v_disciplina is null then
    select g.disciplina_id into v_disciplina
    from public.grupos g
    where g.id=v_grupo and g.club_id=p_club_id and g.activo;
    if v_disciplina is null then raise exception 'Grupo no disponible'; end if;
  end if;

  if v_disciplina is not null and not exists(
    select 1 from public.disciplinas d
    where d.id=v_disciplina and d.club_id=p_club_id and d.activa
  ) then raise exception 'Disciplina no disponible'; end if;

  if v_grupo is not null and not exists(
    select 1 from public.grupos g
    where g.id=v_grupo and g.club_id=p_club_id and g.activo and g.disciplina_id=v_disciplina
  ) then raise exception 'Grupo no disponible'; end if;

  if p_tarifa_id is not null and not exists(
    select 1 from public.tarifas t
    where t.id=p_tarifa_id and t.club_id=p_club_id and t.activa
  ) then raise exception 'Tarifa no disponible'; end if;

  if p_tipo_solicitud='adulto' and v_email<>'' then
    if exists(
      select 1 from public.socios s
      where s.club_id=p_club_id
        and lower(btrim(coalesce(s.email,'')))=v_email
        and s.estado in ('activo','prealta','suspendido')
    ) then
      raise exception 'KOMBAX_EXISTING_MEMBER_EMAIL_USE_EXISTING_RECORD';
    end if;

    if exists(
      select 1 from public.preinscripciones p
      where p.club_id=p_club_id and p.tipo_solicitud='adulto'
        and lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')))=v_email
        and p.estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')
    ) then
      raise exception 'KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT_EMAIL';
    end if;
  end if;

  if v_solicitante is not null and exists(
    select 1 from public.preinscripciones p
    where p.club_id=p_club_id
      and p.solicitante_perfil_id=v_solicitante
      and p.tipo_solicitud=p_tipo_solicitud
      and lower(btrim(p.nombre))=lower(btrim(p_nombre))
      and lower(btrim(p.apellidos))=lower(btrim(p_apellidos))
      and p.fecha_nacimiento is not distinct from p_fecha_nacimiento
      and p.estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')
  ) then
    raise exception 'KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT';
  end if;

  insert into public.preinscripciones(
    club_id,solicitante_perfil_id,tipo_solicitud,nombre,apellidos,fecha_nacimiento,edad,
    tutor_nombre,tutor_email,email_acceso,telefono,disciplina_id,grupo_id,tarifa_id,parentesco,
    estado,observaciones,kombax_activacion_estado
  ) values(
    p_club_id,v_solicitante,p_tipo_solicitud,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,v_edad,
    case when p_tipo_solicitud='menor' then nullif(trim(coalesce(p_tutor_nombre,'')),'') end,
    nullif(v_email,''),nullif(v_email,''),coalesce(nullif(trim(coalesce(p_telefono,'')),''),''),
    v_disciplina,v_grupo,p_tarifa_id,nullif(trim(coalesce(p_parentesco,'')),''),
    'enviada',nullif(trim(coalesce(p_observaciones,'')),''),'pendiente_alta'
  ) returning id into v_id;

  insert into public.notificaciones(
    club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    p_club_id,rol,'preinscripcion-'||v_id||'-'||rol::text,'inscripcion',
    'Nueva preinscripción',trim(p_nombre||' '||p_apellidos)||' ha enviado una solicitud.',
    'enrollments',
    jsonb_build_object(
      'preinscripcion_id',v_id,
      'self_service',v_solicitante is not null,
      'discipline_assigned',v_disciplina is not null,
      'group_assigned',v_grupo is not null
    ),v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave)
  where clave is not null and rol_destino is not null
  do nothing;

  return v_id;
end $$;

create or replace function public.registrar_cuenta_club(
  p_club_slug text,
  p_tipo_cuenta text,
  p_adulto_nombre text,
  p_adulto_apellidos text,
  p_telefono text,
  p_fecha_nacimiento_adulto date default null,
  p_menor_nombre text default null,
  p_menor_apellidos text default null,
  p_fecha_nacimiento_menor date default null,
  p_disciplina_id uuid default null,
  p_grupo_id uuid default null,
  p_tarifa_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_club_id uuid;
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_preinscripcion_id uuid;
  v_tipo text;
  v_target_nombre text;
  v_target_apellidos text;
  v_target_fecha date;
  v_tutor_nombre text;
  v_requested_role text;
  v_account_dob date;
  v_account_age integer;
begin
  if v_uid is null then raise exception 'Debes autenticarte antes de completar el registro'; end if;
  if p_tipo_cuenta not in ('adulto','tutor') then raise exception 'Tipo de cuenta no permitido'; end if;
  if nullif(trim(coalesce(p_adulto_nombre,'')),'') is null
     or nullif(trim(coalesce(p_adulto_apellidos,'')),'') is null then
    raise exception 'Nombre y apellidos del adulto son obligatorios';
  end if;

  select id into v_club_id
  from public.clubes where slug=p_club_slug and activo limit 1;
  if v_club_id is null then raise exception 'Club no disponible'; end if;

  select a.fecha_nacimiento into v_account_dob
  from public.kombax_account_private_r117 a
  where a.perfil_id=v_uid;
  v_account_dob:=coalesce(p_fecha_nacimiento_adulto,v_account_dob);
  if v_account_dob is null then raise exception 'KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED'; end if;
  v_account_age:=public.app_kombax_birth_date_validate_r117(v_account_dob);

  if p_tipo_cuenta='adulto' then
    if v_account_age<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
    v_tipo:='adulto';
    v_target_nombre:=trim(p_adulto_nombre);
    v_target_apellidos:=trim(p_adulto_apellidos);
    v_target_fecha:=v_account_dob;
    v_requested_role:='alumno';
  else
    if v_account_age<18 then raise exception 'KOMBAX_TUTOR_MIN_AGE_18'; end if;
    if nullif(trim(coalesce(p_menor_nombre,'')),'') is null
       or nullif(trim(coalesce(p_menor_apellidos,'')),'') is null
       or p_fecha_nacimiento_menor is null then
      raise exception 'Faltan los datos del menor';
    end if;
    if extract(year from age(current_date,p_fecha_nacimiento_menor))>=16 then
      raise exception 'KOMBAX_ADULT_MUST_USE_ADULT_FLOW';
    end if;
    v_tipo:='menor';
    v_target_nombre:=trim(p_menor_nombre);
    v_target_apellidos:=trim(p_menor_apellidos);
    v_target_fecha:=p_fecha_nacimiento_menor;
    v_tutor_nombre:=concat_ws(' ',trim(p_adulto_nombre),trim(p_adulto_apellidos));
    v_requested_role:='familia';
  end if;

  insert into public.perfiles(id,nombre,apellidos,telefono)
  values(v_uid,trim(p_adulto_nombre),trim(p_adulto_apellidos),nullif(trim(coalesce(p_telefono,'')),''))
  on conflict(id) do update
  set nombre=excluded.nombre,
      apellidos=excluded.apellidos,
      telefono=coalesce(excluded.telefono,public.perfiles.telefono),
      actualizado_en=now();

  -- Account/Profile Social exists before the private club membership.
  v_preinscripcion_id:=public.app_crear_preinscripcion(
    v_club_id,v_tipo,v_target_nombre,v_target_apellidos,v_target_fecha,
    coalesce(v_tutor_nombre,''),v_email,coalesce(p_telefono,''),
    p_disciplina_id,p_grupo_id,p_tarifa_id,
    case when v_tipo='menor' then 'Tutor/a responsable' else null end,
    'Alta iniciada desde cuenta KOMBAX; la membresía requiere confirmación del club.'
  );

  return jsonb_build_object(
    'club_id',v_club_id,
    'preinscripcion_id',v_preinscripcion_id,
    'rol_solicitado',v_requested_role,
    'estado','pendiente_club',
    'membership_created',false,
    'club_authorization_required',true,
    'invite_code_required',false,
    'profile_social_independent',true
  );
end $$;

create or replace function public.app_kombax_preinscripcion_aprobar_r59(p_preinscripcion_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  p public.preinscripciones;
  v_socio_id uuid;
  v_socio public.socios;
  v_email text;
  v_inv jsonb;
begin
  select * into p from public.preinscripciones where id=p_preinscripcion_id;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;

  v_email:=lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')));
  v_socio_id:=public.app_aprobar_preinscripcion(p_preinscripcion_id);
  select * into v_socio
  from public.socios where id=v_socio_id and club_id=p.club_id for update;

  -- Authenticated adult: Club approval is enough; no extra code is required.
  if p.tipo_solicitud='adulto' and v_socio.perfil_id is not null then
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(p.club_id,v_socio.perfil_id,'alumno',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;

    update public.socios
       set kombax_acceso_estado='activo',
           kombax_acceso_email=coalesce(nullif(v_email,''),email),
           kombax_acceso_modo='alumno',
           kombax_acceso_actualizado_en=now(),
           kombax_vinculado_en=coalesce(kombax_vinculado_en,now())
     where id=v_socio_id;

    update public.preinscripciones set kombax_activacion_estado='activa' where id=p.id;
    return jsonb_build_object(
      'ok',true,'socio_id',v_socio_id,'activation','already_linked',
      'email',v_email,'modo','alumno','invitation_required',false
    );
  end if;

  -- Authenticated parent/tutor: Club approval can directly authorize the family link.
  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(
      club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal
    ) values(
      p.club_id,p.solicitante_perfil_id,v_socio_id,
      coalesce(nullif(p.parentesco,''),'Tutor/a responsable'),true
    )
    on conflict(club_id,tutor_perfil_id,socio_id)
    do update set parentesco=excluded.parentesco,contacto_principal=true;

    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(p.club_id,p.solicitante_perfil_id,'familia',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;

    update public.socios
       set kombax_acceso_estado='activo',
           kombax_acceso_email=nullif(v_email,''),
           kombax_acceso_modo='tutor',
           kombax_acceso_actualizado_en=now(),
           kombax_vinculado_en=coalesce(kombax_vinculado_en,now())
     where id=v_socio_id;

    update public.preinscripciones
       set kombax_activacion_estado='activa',kombax_invitacion_id=null
     where id=p.id;

    return jsonb_build_object(
      'ok',true,'socio_id',v_socio_id,'activation','family_linked',
      'email',v_email,'modo','tutor','invitation_required',false
    );
  end if;

  -- Administrative record without account: invitation remains a valid route.
  if v_email='' then
    update public.preinscripciones
       set kombax_activacion_estado='pendiente_email'
     where id=p.id;
    return jsonb_build_object(
      'ok',true,'socio_id',v_socio_id,'activation','missing_email',
      'invitation_required',false
    );
  end if;

  v_inv:=public.app_kombax_alumno_invitar_r58(p.club_id,v_socio_id,v_email);
  update public.preinscripciones
     set kombax_activacion_estado='invitacion_pendiente',
         kombax_invitacion_id=(v_inv->>'id')::uuid,
         email_acceso=v_email
   where id=p.id;

  return jsonb_build_object(
    'ok',true,'socio_id',v_socio_id,'activation','invitation_pending',
    'email',v_email,'invitation_id',v_inv->>'id','codigo',v_inv->>'codigo',
    'modo',case when p.tipo_solicitud='menor' then 'tutor' else 'alumno' end,
    'invitation_required',true
  );
end $$;

notify pgrst,'reload schema';
