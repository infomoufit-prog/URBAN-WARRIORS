CREATE OR REPLACE FUNCTION public.app_aprobar_preinscripcion(p_preinscripcion_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  p public.preinscripciones;
  v_socio uuid;
  v_ocupacion integer;
  v_plazas integer;
  v_email text;
  v_email_count integer:=0;
  v_possible_count integer:=0;
  v_disciplina_id uuid;
  v_grupo_id uuid;
  v_matricula uuid;
begin
  select * into p
  from public.preinscripciones
  where id=p_preinscripcion_id
  for update;

  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then
    raise exception 'No tienes permiso';
  end if;

  v_email:=lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')));
  v_disciplina_id:=p.disciplina_id;
  v_grupo_id:=p.grupo_id;

  if p.estado='aprobada' then
    select s.id into v_socio
    from public.socios s
    where s.club_id=p.club_id and (
      (p.tipo_solicitud='adulto' and p.solicitante_perfil_id is not null and s.perfil_id=p.solicitante_perfil_id)
      or (p.tipo_solicitud='adulto' and v_email<>'' and lower(btrim(coalesce(s.email,'')))=v_email)
      or (p.tipo_solicitud='menor' and lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos)
          and s.fecha_nacimiento is not distinct from p.fecha_nacimiento)
    )
    order by s.creado_en desc
    limit 1;
    return v_socio;
  end if;

  if p.estado in ('rechazada','cancelada') then
    raise exception 'La solicitud está cerrada';
  end if;

  -- Disciplina y grupo son opcionales para aprobar y registrar la ficha básica.
  -- Si hay grupo pero no disciplina, deducimos la disciplina del grupo.
  if v_grupo_id is not null and v_disciplina_id is null then
    select g.disciplina_id
      into v_disciplina_id
    from public.grupos g
    where g.id=v_grupo_id
      and g.club_id=p.club_id
      and g.activo;

    if v_disciplina_id is null then
      raise exception 'El grupo no está disponible';
    end if;
  end if;

  if v_disciplina_id is not null
     and not exists(
       select 1
       from public.disciplinas d
       where d.id=v_disciplina_id
         and d.club_id=p.club_id
         and d.activa
     ) then
    raise exception 'La disciplina seleccionada no está disponible';
  end if;

  if v_grupo_id is not null then
    select g.plazas
      into v_plazas
    from public.grupos g
    where g.id=v_grupo_id
      and g.club_id=p.club_id
      and g.disciplina_id=v_disciplina_id
      and g.activo;

    if not found then
      raise exception 'El grupo no está disponible para la disciplina';
    end if;

    select count(distinct sd.socio_id)
      into v_ocupacion
    from public.socio_disciplinas sd
    where sd.club_id=p.club_id
      and sd.grupo_id=v_grupo_id
      and sd.activa;

    if v_plazas is not null and v_ocupacion>=v_plazas then
      update public.preinscripciones
         set estado='lista_espera',
             revisada_por=auth.uid(),
             revisada_en=now(),
             observaciones=coalesce(observaciones,'Grupo completo: trasladada automáticamente a lista de espera.')
       where id=p.id;
      raise exception 'El grupo está completo. La solicitud se ha trasladado a lista de espera';
    end if;
  end if;

  if p.tarifa_id is not null
     and not exists(
       select 1
       from public.tarifas
       where id=p.tarifa_id and club_id=p.club_id and activa
     ) then
    raise exception 'La tarifa seleccionada no está disponible';
  end if;

  if p.tipo_solicitud='adulto' then
    if p.solicitante_perfil_id is not null then
      select s.id into v_socio
      from public.socios s
      where s.club_id=p.club_id
        and s.perfil_id=p.solicitante_perfil_id
      order by s.creado_en desc
      limit 1;
    end if;

    if v_socio is null and v_email<>'' then
      select count(*) into v_email_count
      from public.socios s
      where s.club_id=p.club_id
        and lower(btrim(coalesce(s.email,'')))=v_email
        and s.estado<>'baja';

      if v_email_count>1 then
        raise exception 'KOMBAX_AMBIGUOUS_EXISTING_MEMBER_EMAIL';
      end if;

      if v_email_count=1 then
        select s.id into v_socio
        from public.socios s
        where s.club_id=p.club_id
          and lower(btrim(coalesce(s.email,'')))=v_email
          and s.estado<>'baja'
        limit 1;
      end if;
    end if;

    if v_socio is null and p.fecha_nacimiento is not null then
      select count(*) into v_possible_count
      from public.socios s
      where s.club_id=p.club_id
        and s.perfil_id is null
        and coalesce(btrim(s.email),'')=''
        and lower(btrim(s.nombre))=lower(btrim(p.nombre))
        and lower(btrim(s.apellidos))=lower(btrim(p.apellidos))
        and s.fecha_nacimiento=p.fecha_nacimiento
        and s.estado<>'baja';

      if v_possible_count>0 then
        raise exception 'KOMBAX_POSSIBLE_IMPORTED_MEMBER_REVIEW_REQUIRED';
      end if;
    end if;
  else
    select s.id into v_socio
    from public.socios s
    where s.club_id=p.club_id
      and lower(s.nombre)=lower(p.nombre)
      and lower(s.apellidos)=lower(p.apellidos)
      and s.fecha_nacimiento is not distinct from p.fecha_nacimiento
    order by s.creado_en desc
    limit 1;
  end if;

  if v_socio is null then
    insert into public.socios(
      club_id,perfil_id,nombre,apellidos,fecha_nacimiento,telefono,email,
      tutor_nombre,tarifa_id,estado,kombax_acceso_estado
    )
    values(
      p.club_id,
      case when p.tipo_solicitud='adulto' then p.solicitante_perfil_id end,
      p.nombre,p.apellidos,p.fecha_nacimiento,p.telefono,
      case when p.tipo_solicitud='adulto' then nullif(v_email,'') else null end,
      case when p.tipo_solicitud='menor' then p.tutor_nombre end,
      p.tarifa_id,'activo',
      case when p.tipo_solicitud='adulto' and p.solicitante_perfil_id is not null
           then 'activo' else 'sin_activar' end
    )
    returning id into v_socio;
  else
    update public.socios
       set nombre=p.nombre,
           apellidos=p.apellidos,
           fecha_nacimiento=p.fecha_nacimiento,
           telefono=p.telefono,
           email=case when p.tipo_solicitud='adulto' then coalesce(nullif(v_email,''),email) else email end,
           tutor_nombre=case when p.tipo_solicitud='menor' then p.tutor_nombre else tutor_nombre end,
           tarifa_id=coalesce(p.tarifa_id,tarifa_id),
           estado='activo',
           actualizado_en=now()
     where id=v_socio;
  end if;

  -- Solo se crea matrícula deportiva cuando existe disciplina.
  if v_disciplina_id is not null then
    select sd.id into v_matricula
    from public.socio_disciplinas sd
    where sd.club_id=p.club_id
      and sd.socio_id=v_socio
      and sd.disciplina_id=v_disciplina_id
      and sd.grupo_id is not distinct from v_grupo_id
    order by sd.activa desc,sd.fecha_inicio desc,sd.id desc
    limit 1;

    if v_matricula is null then
      insert into public.socio_disciplinas(
        club_id,socio_id,disciplina_id,grupo_id,activa,fecha_inicio,fecha_fin
      )
      values(
        p.club_id,v_socio,v_disciplina_id,v_grupo_id,true,current_date,null
      );
    else
      update public.socio_disciplinas
         set grupo_id=v_grupo_id,
             activa=true,
             fecha_fin=null
       where id=v_matricula;
    end if;
  end if;

  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(
      club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal
    )
    values(
      p.club_id,p.solicitante_perfil_id,v_socio,
      coalesce(p.parentesco,'Tutor/a responsable'),
      not exists(
        select 1
        from public.tutores_socios
        where club_id=p.club_id and socio_id=v_socio and contacto_principal
      )
    )
    on conflict(club_id,tutor_perfil_id,socio_id)
    do update set parentesco=excluded.parentesco;
  end if;

  update public.preinscripciones
     set estado='aprobada',
         disciplina_id=v_disciplina_id,
         grupo_id=v_grupo_id,
         revisada_por=auth.uid(),
         revisada_en=now()
   where id=p.id;

  if p.solicitante_perfil_id is not null then
    insert into public.notificaciones(
      club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
    )
    values(
      p.club_id,p.solicitante_perfil_id,
      'preinscripcion-'||p.id||'-aprobada',
      'inscripcion','Inscripción aprobada',
      p.nombre||' ya tiene el alta confirmada.',
      'home',
      jsonb_build_object(
        'preinscripcion_id',p.id,
        'socio_id',v_socio,
        'disciplina_id',v_disciplina_id,
        'grupo_id',v_grupo_id
      ),
      auth.uid()
    )
    on conflict(club_id,perfil_id,clave)
    where clave is not null and perfil_id is not null
    do nothing;
  end if;

  return v_socio;
end;
$function$;

CREATE OR REPLACE FUNCTION public.app_desactivar_matricula(p_matricula_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v public.socio_disciplinas;
begin
  select * into v from public.socio_disciplinas where id=p_matricula_id for update;
  if v.id is null then raise exception 'Matrícula no encontrada'; end if;
  if not public.tiene_rol_club(v.club_id,'direccion','secretaria') then raise exception 'No tienes permiso para modificar matrículas'; end if;
  update public.socio_disciplinas set activa=false,fecha_fin=coalesce(fecha_fin,current_date) where id=v.id;
  return v.id;
end; $function$;

CREATE OR REPLACE FUNCTION public.app_solicitar_nueva_matricula(p_socio_id uuid, p_disciplina_id uuid, p_grupo_id uuid, p_tarifa_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_socio public.socios; v_id uuid; v_uid uuid:=auth.uid();
begin
  select * into v_socio from public.socios where id=p_socio_id;
  if v_socio.id is null then raise exception 'Alumno no encontrado'; end if;
  if not public.puede_ver_socio(v_socio.id) then raise exception 'No tienes permiso sobre este alumno'; end if;
  if not exists(select 1 from public.grupos where id=p_grupo_id and club_id=v_socio.club_id and disciplina_id=p_disciplina_id and activo) then
    raise exception 'El grupo no pertenece a la disciplina o no está activo';
  end if;
  if exists(select 1 from public.socio_disciplinas where club_id=v_socio.club_id and socio_id=v_socio.id and disciplina_id=p_disciplina_id and grupo_id=p_grupo_id and activa) then
    raise exception 'El alumno ya está inscrito en ese grupo';
  end if;
  if exists(select 1 from public.preinscripciones where club_id=v_socio.club_id and solicitante_perfil_id=v_uid
      and lower(nombre)=lower(v_socio.nombre) and lower(apellidos)=lower(v_socio.apellidos)
      and disciplina_id=p_disciplina_id and grupo_id=p_grupo_id and estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')) then
    raise exception 'Ya existe una solicitud activa para ese grupo';
  end if;
  insert into public.preinscripciones(club_id,solicitante_perfil_id,tipo_solicitud,nombre,apellidos,fecha_nacimiento,
    telefono,disciplina_id,grupo_id,tarifa_id,estado)
  values(v_socio.club_id,v_uid,case when v_socio.perfil_id=v_uid then 'adulto' else 'menor' end,
    v_socio.nombre,v_socio.apellidos,v_socio.fecha_nacimiento,v_socio.telefono,p_disciplina_id,p_grupo_id,p_tarifa_id,'enviada')
  returning id into v_id;
  return v_id;
end; $function$;
