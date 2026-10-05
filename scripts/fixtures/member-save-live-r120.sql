CREATE OR REPLACE FUNCTION public.app_guardar_socio(p_club_id uuid, p_id uuid, p_nombre text, p_apellidos text, p_fecha_nacimiento date, p_telefono text, p_email text, p_tutor_nombre text, p_disciplina_id uuid, p_grupo_id uuid, p_grado_id uuid, p_grado_texto text, p_tarifa_id uuid, p_estado text DEFAULT 'activo'::text, p_contacto_emergencia text DEFAULT ''::text, p_telefono_emergencia text DEFAULT ''::text, p_notas_internas text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_id uuid;
  v_matricula uuid;
  v_disciplina_id uuid:=p_disciplina_id;
  v_grupo_id uuid:=p_grupo_id;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then
    raise exception 'No tienes permiso para gestionar alumnos';
  end if;

  if nullif(trim(coalesce(p_nombre,'')),'') is null
     or nullif(trim(coalesce(p_apellidos,'')),'') is null then
    raise exception 'Nombre y apellidos son obligatorios';
  end if;

  if p_estado not in ('prealta','activo','baja','suspendido') then
    raise exception 'Estado de alumno no válido';
  end if;

  if v_grupo_id is not null and v_disciplina_id is null then
    select g.disciplina_id
      into v_disciplina_id
    from public.grupos g
    where g.id=v_grupo_id
      and g.club_id=p_club_id
      and g.activo;

    if v_disciplina_id is null then
      raise exception 'Grupo no válido o inactivo';
    end if;
  end if;

  if p_grado_id is not null and v_disciplina_id is null then
    select g.disciplina_id
      into v_disciplina_id
    from public.grados g
    where g.id=p_grado_id
      and g.club_id=p_club_id
      and g.activo;

    if v_disciplina_id is null then
      raise exception 'Grado no válido o inactivo';
    end if;
  end if;

  if v_disciplina_id is not null
     and not exists(
       select 1
       from public.disciplinas d
       where d.id=v_disciplina_id
         and d.club_id=p_club_id
         and d.activa
     ) then
    raise exception 'Disciplina no válida o inactiva';
  end if;

  if v_grupo_id is not null
     and not exists(
       select 1
       from public.grupos g
       where g.id=v_grupo_id
         and g.club_id=p_club_id
         and g.disciplina_id=v_disciplina_id
         and g.activo
     ) then
    raise exception 'El grupo no pertenece a la disciplina o está inactivo';
  end if;

  if p_tarifa_id is not null
     and not exists(
       select 1
       from public.tarifas t
       where t.id=p_tarifa_id
         and t.club_id=p_club_id
         and t.activa
     ) then
    raise exception 'Tarifa no válida o inactiva';
  end if;

  if p_grado_id is not null
     and (
       v_disciplina_id is null
       or not exists(
         select 1
         from public.grados g
         where g.id=p_grado_id
           and g.club_id=p_club_id
           and g.disciplina_id=v_disciplina_id
           and g.activo
       )
     ) then
    raise exception 'El grado no pertenece a la disciplina o está inactivo';
  end if;

  if p_id is null then
    insert into public.socios(
      club_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,
      grado_texto,tarifa_id,estado,contacto_emergencia,telefono_emergencia,notas_internas
    )
    values(
      p_club_id,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,
      nullif(trim(coalesce(p_telefono,'')),''),
      lower(nullif(trim(coalesce(p_email,'')),'')),
      nullif(trim(coalesce(p_tutor_nombre,'')),''),
      nullif(trim(coalesce(p_grado_texto,'')),''),
      p_tarifa_id,p_estado,
      nullif(trim(coalesce(p_contacto_emergencia,'')),''),
      nullif(trim(coalesce(p_telefono_emergencia,'')),''),
      nullif(trim(coalesce(p_notas_internas,'')),'')
    )
    returning id into v_id;
  else
    update public.socios
       set nombre=trim(p_nombre),
           apellidos=trim(p_apellidos),
           fecha_nacimiento=p_fecha_nacimiento,
           telefono=nullif(trim(coalesce(p_telefono,'')),''),
           email=lower(nullif(trim(coalesce(p_email,'')),'')),
           tutor_nombre=nullif(trim(coalesce(p_tutor_nombre,'')),''),
           grado_texto=nullif(trim(coalesce(p_grado_texto,'')),''),
           tarifa_id=p_tarifa_id,
           estado=p_estado,
           contacto_emergencia=nullif(trim(coalesce(p_contacto_emergencia,'')),''),
           telefono_emergencia=nullif(trim(coalesce(p_telefono_emergencia,'')),''),
           notas_internas=nullif(trim(coalesce(p_notas_internas,'')),''),
           actualizado_en=now()
     where id=p_id and club_id=p_club_id
     returning id into v_id;

    if v_id is null then
      raise exception 'Alumno no encontrado';
    end if;
  end if;

  if v_disciplina_id is null then
    return v_id;
  end if;

  if v_grupo_id is not null
     and not exists(
       select 1
       from public.socio_disciplinas sd
       where sd.club_id=p_club_id
         and sd.socio_id=v_id
         and sd.disciplina_id=v_disciplina_id
         and sd.grupo_id=v_grupo_id
         and sd.activa
     )
     and exists(
       select 1
       from public.grupos g
       where g.id=v_grupo_id
         and g.club_id=p_club_id
         and g.plazas is not null
         and (
           select count(distinct sd.socio_id)
           from public.socio_disciplinas sd
           where sd.club_id=p_club_id
             and sd.grupo_id=v_grupo_id
             and sd.activa
         ) >= g.plazas
     ) then
    raise exception 'No quedan plazas disponibles en el grupo seleccionado';
  end if;

  select sd.id
    into v_matricula
  from public.socio_disciplinas sd
  where sd.club_id=p_club_id
    and sd.socio_id=v_id
    and sd.disciplina_id=v_disciplina_id
    and sd.grupo_id is not distinct from v_grupo_id
  order by sd.activa desc,sd.fecha_inicio desc,sd.id desc
  limit 1;

  if v_matricula is null then
    insert into public.socio_disciplinas(
      club_id,socio_id,disciplina_id,grupo_id,grado_id,activa,fecha_inicio,fecha_fin
    )
    values(
      p_club_id,v_id,v_disciplina_id,v_grupo_id,p_grado_id,true,current_date,null
    );
  else
    update public.socio_disciplinas
       set grupo_id=v_grupo_id,
           grado_id=p_grado_id,
           activa=true,
           fecha_fin=null
     where id=v_matricula;
  end if;

  return v_id;
end;
$function$

