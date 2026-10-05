-- Atomic multiple enrollments. Parent requests keep club approval and target an exact existing pupil.
begin;
alter table public.preinscripciones add column if not exists target_socio_id_r120 uuid references public.socios(id);
create index if not exists preinscripcion_target_member_r120 on public.preinscripciones(target_socio_id_r120) where target_socio_id_r120 is not null;
create table public.kombax_member_batch_requests_r120(request_id uuid primary key,actor_id uuid not null,operation text not null,payload jsonb not null,response jsonb not null);
alter table public.kombax_member_batch_requests_r120 enable row level security;
revoke all on public.kombax_member_batch_requests_r120 from public,anon,authenticated;

create function public.app_kombax_member_batch_mutate_r120(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare club uuid;sid uuid;member jsonb;links jsonb;link jsonb;d uuid;g uuid;grade uuid;request uuid;ids jsonb:='[]'::jsonb;old public.kombax_member_batch_requests_r120%rowtype;out jsonb;rec public.socios%rowtype;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null or p_payload is null then raise exception 'REQUEST_REQUIRED';end if;
 club:=(p_payload->>'club_id')::uuid;member:=coalesce(p_payload->'member','{}'::jsonb);links:=coalesce(p_payload->'enrollments','[]'::jsonb);
 sid:=coalesce(nullif(member->>'id','')::uuid,nullif(p_payload->>'socio_id','')::uuid);
 if p_operation not in ('member.save.batch','enrollment.request.batch') then raise exception 'MEMBER_OPERATION_UNKNOWN';end if;
 if jsonb_typeof(links)<>'array' or jsonb_array_length(links)>100 then raise exception 'ENROLLMENT_SELECTION_INVALID';end if;
 if p_operation='member.save.batch' then
  if not public.tiene_rol_club(club,'direccion','secretaria') then raise exception 'MEMBER_ADMIN_REQUIRED';end if;
 elsif sid is null or not exists(select 1 from public.socios s where s.id=sid and s.club_id=club and s.estado<>'baja' and
    (s.perfil_id=auth.uid() or exists(select 1 from public.tutores_socios t where t.club_id=s.club_id and t.socio_id=s.id and t.tutor_perfil_id=auth.uid()))) then raise exception 'MEMBER_OR_AUTHORIZED_TUTOR_REQUIRED';end if;
 if sid is not null then
  select * into rec from public.socios where id=sid and club_id=club for update;
  if rec.id is null then raise exception 'MEMBER_CONTEXT_MISMATCH';end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,121));
 select * into old from public.kombax_member_batch_requests_r120 where request_id=p_request_id;
 if found then
  if old.actor_id<>auth.uid() or old.operation<>p_operation or old.payload<>p_payload then raise exception 'REQUEST_ID_REUSED';end if;
  return old.response;
 end if;
 if p_operation='member.save.batch' then
  sid:=public.app_guardar_socio(club,sid,member->>'nombre',member->>'apellidos',nullif(member->>'fecha_nacimiento','')::date,
   member->>'telefono',member->>'email',member->>'tutor_nombre',null,null,null,member->>'grado_texto',nullif(member->>'tarifa_id','')::uuid,
   coalesce(nullif(member->>'estado',''),'activo'),member->>'contacto_emergencia',member->>'telefono_emergencia',member->>'notas_internas');
 end if;
 -- Lock groups in deterministic order. Capacity checks and all writes are atomic.
 perform 1 from public.grupos where id in (select nullif(x->>'grupo_id','')::uuid from jsonb_array_elements(links) x) order by id for update;
 for link in select value from jsonb_array_elements(links) loop
  d:=nullif(link->>'disciplina_id','')::uuid;g:=nullif(link->>'grupo_id','')::uuid;grade:=nullif(link->>'grado_id','')::uuid;
  if d is null or not exists(select 1 from public.disciplinas where id=d and club_id=club and activa) then raise exception 'MEMBER_DISCIPLINE_INVALID';end if;
  if g is not null and not exists(select 1 from public.grupos where id=g and club_id=club and disciplina_id=d and activo) then raise exception 'MEMBER_GROUP_DISCIPLINE_MISMATCH';end if;
  if grade is not null and not exists(select 1 from public.grados where id=grade and club_id=club and disciplina_id=d and activo) then raise exception 'MEMBER_GRADE_DISCIPLINE_MISMATCH';end if;
  if p_operation='member.save.batch' then
   -- Add a link; never deactivate another discipline or group. Preserve its existing grade.
   if not exists(select 1 from public.socio_disciplinas where club_id=club and socio_id=sid and disciplina_id=d and grupo_id is not distinct from g and activa) then
    if g is not null and exists(select 1 from public.grupos q where q.id=g and q.plazas is not null and
      (select count(distinct sd.socio_id) from public.socio_disciplinas sd where sd.club_id=club and sd.grupo_id=g and sd.activa)>=q.plazas) then raise exception 'MEMBER_GROUP_FULL';end if;
    insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,grado_id,activa,fecha_inicio) values(club,sid,d,g,grade,true,current_date);
   end if;
  else
   if g is null then raise exception 'MEMBER_GROUP_REQUIRED';end if;
   request:=public.app_solicitar_nueva_matricula(sid,d,g,nullif(p_payload->>'tarifa_id','')::uuid);
   ids:=ids||jsonb_build_array(request);
  end if;
 end loop;
 out:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('socio_id',sid,'request_ids',ids,'selected',jsonb_array_length(links)));
 insert into public.kombax_member_batch_requests_r120 values(p_request_id,auth.uid(),p_operation,p_payload,out);
 return out;
end $$;
revoke all on function public.app_kombax_member_batch_mutate_r120(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_member_batch_mutate_r120(text,jsonb,uuid) to authenticated;
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

  if p.target_socio_id_r120 is not null then
    select s.id into v_socio from public.socios s where s.id=p.target_socio_id_r120 and s.club_id=p.club_id;
    if v_socio is null then raise exception 'MEMBER_CONTEXT_MISMATCH';end if;
    if p.estado='aprobada' then return v_socio;end if;
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
    if v_socio is null and p.solicitante_perfil_id is not null then
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
  elsif v_socio is null then
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

  if p.target_socio_id_r120 is null and p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
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
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v_socio from public.socios where id=p_socio_id;
  if v_socio.id is null then raise exception 'Alumno no encontrado'; end if;
  if not (coalesce(v_socio.perfil_id=v_uid,false) or public.tiene_rol_club(v_socio.club_id,'direccion','secretaria') or exists(select 1 from public.tutores_socios t where t.club_id=v_socio.club_id and t.socio_id=v_socio.id and t.tutor_perfil_id=v_uid)) then raise exception 'MEMBER_OR_AUTHORIZED_TUTOR_REQUIRED';end if;
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
    telefono,disciplina_id,grupo_id,tarifa_id,estado,target_socio_id_r120)
  values(v_socio.club_id,v_uid,case when v_socio.fecha_nacimiento is not null and v_socio.fecha_nacimiento>current_date-interval '16 years' then 'menor' else 'adulto' end,
    v_socio.nombre,v_socio.apellidos,v_socio.fecha_nacimiento,v_socio.telefono,p_disciplina_id,p_grupo_id,p_tarifa_id,'enviada',v_socio.id)
  returning id into v_id;
  return v_id;
end; $function$;


commit;
