CREATE OR REPLACE FUNCTION public.app_crear_preinscripcion(p_club_id uuid, p_tipo_solicitud text, p_nombre text, p_apellidos text, p_fecha_nacimiento date, p_tutor_nombre text, p_tutor_email text, p_telefono text, p_disciplina_id uuid, p_grupo_id uuid, p_tarifa_id uuid, p_parentesco text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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

  v_edad:=public.app_kombax_birth_date_validate_r117(p_fecha_nacimiento)::smallint;
  if p_tipo_solicitud='adulto' and v_edad<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
  if p_tipo_solicitud='menor' and v_edad>=16 then raise exception 'KOMBAX_ADULT_MUST_USE_ADULT_FLOW'; end if;

  v_is_manager:=public.tiene_rol_club(p_club_id,'direccion','secretaria');
  if not v_is_manager then
    v_solicitante:=v_uid;
  end if;

  select lower(coalesce(u.email,'')) into v_auth_email
  from auth.users u
  where u.id=v_uid and u.deleted_at is null;

  v_email:=lower(btrim(coalesce(p_tutor_email,'')));
  if not v_is_manager and v_email='' then
    v_email:=v_auth_email;
  end if;

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

  if v_disciplina is not null
     and not exists(select 1 from public.disciplinas d where d.id=v_disciplina and d.club_id=p_club_id and d.activa) then
    raise exception 'Disciplina no disponible';
  end if;
  if v_grupo is not null
     and not exists(select 1 from public.grupos g where g.id=v_grupo and g.club_id=p_club_id and g.activo and g.disciplina_id=v_disciplina) then
    raise exception 'Grupo no disponible';
  end if;
  if p_tarifa_id is not null
     and not exists(select 1 from public.tarifas t where t.id=p_tarifa_id and t.club_id=p_club_id and t.activa) then
    raise exception 'Tarifa no disponible';
  end if;

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
      where p.club_id=p_club_id
        and p.tipo_solicitud='adulto'
        and lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')))=v_email
        and p.estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')
    ) then
      raise exception 'KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT_EMAIL';
    end if;
  end if;

  if v_solicitante is not null
     and exists(
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
  )
  values(
    p_club_id,v_solicitante,p_tipo_solicitud,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,v_edad,
    case when p_tipo_solicitud='menor' then nullif(trim(coalesce(p_tutor_nombre,'')),'') end,
    nullif(v_email,''),nullif(v_email,''),coalesce(nullif(trim(coalesce(p_telefono,'')),''),''),
    v_disciplina,v_grupo,p_tarifa_id,nullif(trim(coalesce(p_parentesco,'')),''),
    'enviada',nullif(trim(coalesce(p_observaciones,'')),''),
    'pendiente_alta'
  )
  returning id into v_id;

  insert into public.notificaciones(
    club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    p_club_id,rol,'preinscripcion-'||v_id||'-'||rol::text,'inscripcion',
    'Nueva preinscripción',
    trim(p_nombre||' '||p_apellidos)||' ha enviado una solicitud.',
    'enrollments',
    jsonb_build_object(
      'preinscripcion_id',v_id,
      'self_service',v_solicitante is not null,
      'discipline_assigned',v_disciplina is not null,
      'group_assigned',v_grupo is not null
    ),
    v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave)
  where clave is not null and rol_destino is not null
  do nothing;

  return v_id;
end $function$
