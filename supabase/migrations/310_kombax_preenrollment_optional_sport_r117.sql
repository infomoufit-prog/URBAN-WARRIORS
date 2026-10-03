-- KOMBAX R117 build 20174 · approving a pre-enrollment does not require
-- discipline/group. Sport assignment can be completed later.

create or replace function public.app_aprobar_preinscripcion(p_preinscripcion_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public','auth'
as $$
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
  select * into p from public.preinscripciones where id=p_preinscripcion_id for update;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;

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
    order by s.creado_en desc limit 1;
    return v_socio;
  end if;

  if p.estado in ('rechazada','cancelada') then raise exception 'La solicitud está cerrada'; end if;

  if v_grupo_id is not null and v_disciplina_id is null then
    select g.disciplina_id into v_disciplina_id
    from public.grupos g
    where g.id=v_grupo_id and g.club_id=p.club_id and g.activo;
    if v_disciplina_id is null then raise exception 'El grupo no está disponible'; end if;
  end if;

  if v_disciplina_id is not null and not exists(
    select 1 from public.disciplinas d
    where d.id=v_disciplina_id and d.club_id=p.club_id and d.activa
  ) then
    raise exception 'La disciplina seleccionada no está disponible';
  end if;

  if v_grupo_id is not null then
    select g.plazas into v_plazas
    from public.grupos g
    where g.id=v_grupo_id and g.club_id=p.club_id
      and g.disciplina_id=v_disciplina_id and g.activo;
    if not found then raise exception 'El grupo no está disponible para la disciplina'; end if;

    select count(distinct sd.socio_id) into v_ocupacion
    from public.socio_disciplinas sd
    where sd.club_id=p.club_id and sd.grupo_id=v_grupo_id and sd.activa;

    if v_plazas is not null and v_ocupacion>=v_plazas then
      update public.preinscripciones
         set estado='lista_espera',revisada_por=auth.uid(),revisada_en=now(),
             observaciones=coalesce(observaciones,'Grupo completo: trasladada automáticamente a lista de espera.')
       where id=p.id;
      raise exception 'El grupo está completo. La solicitud se ha trasladado a lista de espera';
    end if;
  end if;

  if p.tarifa_id is not null and not exists(
    select 1 from public.tarifas where id=p.tarifa_id and club_id=p.club_id and activa
  ) then
    raise exception 'La tarifa seleccionada no está disponible';
  end if;

  if p.tipo_solicitud='adulto' then
    if p.solicitante_perfil_id is not null then
      select s.id into v_socio
      from public.socios s
      where s.club_id=p.club_id and s.perfil_id=p.solicitante_perfil_id
      order by s.creado_en desc limit 1;
    end if;

    if v_socio is null and v_email<>'' then
      select count(*) into v_email_count
      from public.socios s
      where s.club_id=p.club_id and lower(btrim(coalesce(s.email,'')))=v_email and s.estado<>'baja';
      if v_email_count>1 then raise exception 'KOMBAX_AMBIGUOUS_EXISTING_MEMBER_EMAIL'; end if;
      if v_email_count=1 then
        select s.id into v_socio
        from public.socios s
        where s.club_id=p.club_id and lower(btrim(coalesce(s.email,'')))=v_email and s.estado<>'baja'
        limit 1;
      end if;
    end if;

    if v_socio is null and p.fecha_nacimiento is not null then
      select count(*) into v_possible_count
      from public.socios s
      where s.club_id=p.club_id and s.perfil_id is null
        and coalesce(btrim(s.email),'')=''
        and lower(btrim(s.nombre))=lower(btrim(p.nombre))
        and lower(btrim(s.apellidos))=lower(btrim(p.apellidos))
        and s.fecha_nacimiento=p.fecha_nacimiento and s.estado<>'baja';
      if v_possible_count>0 then raise exception 'KOMBAX_POSSIBLE_IMPORTED_MEMBER_REVIEW_REQUIRED'; end if;
    end if;
  else
    select s.id into v_socio
    from public.socios s
    where s.club_id=p.club_id
      and lower(s.nombre)=lower(p.nombre)
      and lower(s.apellidos)=lower(p.apellidos)
      and s.fecha_nacimiento is not distinct from p.fecha_nacimiento
    order by s.creado_en desc limit 1;
  end if;

  if v_socio is null then
    insert into public.socios(
      club_id,perfil_id,nombre,apellidos,fecha_nacimiento,telefono,email,
      tutor_nombre,tarifa_id,estado,kombax_acceso_estado
    ) values(
      p.club_id,case when p.tipo_solicitud='adulto' then p.solicitante_perfil_id end,
      p.nombre,p.apellidos,p.fecha_nacimiento,nullif(p.telefono,''),
      case when p.tipo_solicitud='adulto' then nullif(v_email,'') else null end,
      case when p.tipo_solicitud='menor' then p.tutor_nombre end,
      p.tarifa_id,'activo',
      case when p.tipo_solicitud='adulto' and p.solicitante_perfil_id is not null then 'activo' else 'sin_activar' end
    ) returning id into v_socio;
  else
    update public.socios
       set nombre=p.nombre,apellidos=p.apellidos,fecha_nacimiento=p.fecha_nacimiento,
           telefono=coalesce(nullif(p.telefono,''),telefono),
           email=case when p.tipo_solicitud='adulto' then coalesce(nullif(v_email,''),email) else email end,
           tutor_nombre=case when p.tipo_solicitud='menor' then p.tutor_nombre else tutor_nombre end,
           tarifa_id=coalesce(p.tarifa_id,tarifa_id),estado='activo',actualizado_en=now()
     where id=v_socio;
  end if;

  if v_disciplina_id is not null then
    select sd.id into v_matricula
    from public.socio_disciplinas sd
    where sd.club_id=p.club_id and sd.socio_id=v_socio
      and sd.disciplina_id=v_disciplina_id
      and sd.grupo_id is not distinct from v_grupo_id
    order by sd.activa desc,sd.fecha_inicio desc,sd.id desc limit 1;

    if v_matricula is null then
      insert into public.socio_disciplinas(
        club_id,socio_id,disciplina_id,grupo_id,activa,fecha_inicio,fecha_fin
      ) values(p.club_id,v_socio,v_disciplina_id,v_grupo_id,true,current_date,null);
    else
      update public.socio_disciplinas
         set grupo_id=v_grupo_id,activa=true,fecha_fin=null
       where id=v_matricula;
    end if;
  end if;

  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(
      p.club_id,p.solicitante_perfil_id,v_socio,
      coalesce(p.parentesco,'Tutor/a responsable'),
      not exists(select 1 from public.tutores_socios where club_id=p.club_id and socio_id=v_socio and contacto_principal)
    )
    on conflict(club_id,tutor_perfil_id,socio_id)
    do update set parentesco=excluded.parentesco;
  end if;

  update public.preinscripciones
     set estado='aprobada',disciplina_id=v_disciplina_id,grupo_id=v_grupo_id,
         revisada_por=auth.uid(),revisada_en=now()
   where id=p.id;

  if p.solicitante_perfil_id is not null then
    insert into public.notificaciones(
      club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
    ) values(
      p.club_id,p.solicitante_perfil_id,'preinscripcion-'||p.id||'-aprobada',
      'inscripcion','Inscripción aprobada',p.nombre||' ya tiene el alta confirmada.','home',
      jsonb_build_object('preinscripcion_id',p.id,'socio_id',v_socio,'disciplina_id',v_disciplina_id,'grupo_id',v_grupo_id),
      auth.uid()
    )
    on conflict(club_id,perfil_id,clave)
    where clave is not null and perfil_id is not null
    do nothing;
  end if;

  return v_socio;
end;
$$;

comment on function public.app_aprobar_preinscripcion(uuid) is
'R117 pilot: permite aprobar y crear la ficha del alumno sin exigir disciplina ni grupo; la asignación deportiva es progresiva.';

notify pgrst,'reload schema';
