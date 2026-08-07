-- ============================================================================
-- URBAN WARRIORS 1.5.0 — FAMILIAS, MULTIDISCIPLINA/MULTIGRUPO Y PUSH
-- Aplicar después de 009_final_operational_v140.sql
-- ============================================================================

-- Una matrícula representa una combinación alumno + disciplina + grupo.
-- Permite varias disciplinas y también varios grupos dentro de la misma disciplina.
alter table public.socio_disciplinas
  drop constraint if exists socio_disciplinas_club_id_socio_id_disciplina_id_key;

drop index if exists public.socio_disciplinas_club_id_socio_id_disciplina_id_key;
create unique index if not exists uq_socio_disciplina_grupo_activa
  on public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id)
  where activa and grupo_id is not null;
create unique index if not exists uq_socio_disciplina_sin_grupo_activa
  on public.socio_disciplinas(club_id,socio_id,disciplina_id)
  where activa and grupo_id is null;
create index if not exists idx_socio_disciplinas_grupo_activa
  on public.socio_disciplinas(club_id,grupo_id,socio_id) where activa;

-- La aprobación ya no desactiva otras disciplinas ni otros grupos.
create or replace function public.app_aprobar_preinscripcion(p_preinscripcion_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth
as $$
declare
  p public.preinscripciones;
  v_socio uuid;
  v_ocupacion integer;
  v_plazas integer;
begin
  select * into p from public.preinscripciones where id=p_preinscripcion_id for update;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;
  if p.estado='aprobada' then
    select s.id into v_socio from public.socios s
      where s.club_id=p.club_id
        and ((p.tipo_solicitud='adulto' and s.perfil_id=p.solicitante_perfil_id)
          or (lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos)
              and s.fecha_nacimiento is not distinct from p.fecha_nacimiento))
      order by s.creado_en desc limit 1;
    return v_socio;
  end if;
  if p.estado in ('rechazada','cancelada') then raise exception 'La solicitud está cerrada'; end if;
  if p.disciplina_id is null or not exists(select 1 from public.disciplinas where id=p.disciplina_id and club_id=p.club_id and activa) then
    raise exception 'La solicitud necesita una disciplina activa';
  end if;
  if p.grupo_id is null then raise exception 'Asigna un grupo antes de aprobar'; end if;
  select plazas into v_plazas from public.grupos where id=p.grupo_id and club_id=p.club_id and disciplina_id=p.disciplina_id and activo;
  if not found then raise exception 'El grupo no está disponible para la disciplina'; end if;
  select count(distinct socio_id) into v_ocupacion from public.socio_disciplinas where club_id=p.club_id and grupo_id=p.grupo_id and activa;
  if v_plazas is not null and v_ocupacion>=v_plazas then
    update public.preinscripciones set estado='lista_espera',revisada_por=auth.uid(),revisada_en=now(),
      observaciones=coalesce(observaciones,'Grupo completo: trasladada automáticamente a lista de espera.') where id=p.id;
    raise exception 'El grupo está completo. La solicitud se ha trasladado a lista de espera';
  end if;
  if p.tarifa_id is not null and not exists(select 1 from public.tarifas where id=p.tarifa_id and club_id=p.club_id and activa) then
    raise exception 'La tarifa seleccionada no está disponible';
  end if;

  select s.id into v_socio from public.socios s
  where s.club_id=p.club_id
    and ((p.tipo_solicitud='adulto' and s.perfil_id=p.solicitante_perfil_id)
      or (p.tipo_solicitud='menor' and lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos)
          and s.fecha_nacimiento is not distinct from p.fecha_nacimiento))
  order by s.creado_en desc limit 1;

  if v_socio is null then
    insert into public.socios(club_id,perfil_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,tarifa_id,estado)
    values(p.club_id,case when p.tipo_solicitud='adulto' then p.solicitante_perfil_id end,
      p.nombre,p.apellidos,p.fecha_nacimiento,p.telefono,
      case when p.tipo_solicitud='adulto' then p.tutor_email end,
      case when p.tipo_solicitud='menor' then p.tutor_nombre end,p.tarifa_id,'activo')
    returning id into v_socio;
  else
    update public.socios set nombre=p.nombre,apellidos=p.apellidos,fecha_nacimiento=p.fecha_nacimiento,
      telefono=p.telefono,email=case when p.tipo_solicitud='adulto' then p.tutor_email else email end,
      tutor_nombre=case when p.tipo_solicitud='menor' then p.tutor_nombre else tutor_nombre end,
      tarifa_id=coalesce(p.tarifa_id,tarifa_id),estado='activo',actualizado_en=now() where id=v_socio;
  end if;

  insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,activa,fecha_inicio,fecha_fin)
  values(p.club_id,v_socio,p.disciplina_id,p.grupo_id,true,current_date,null)
  on conflict do nothing;

  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(p.club_id,p.solicitante_perfil_id,v_socio,coalesce(p.parentesco,'Tutor/a responsable'),
      not exists(select 1 from public.tutores_socios where club_id=p.club_id and socio_id=v_socio and contacto_principal))
    on conflict(club_id,tutor_perfil_id,socio_id) do update set parentesco=excluded.parentesco;
  end if;

  update public.preinscripciones set estado='aprobada',revisada_por=auth.uid(),revisada_en=now() where id=p.id;
  if p.solicitante_perfil_id is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p.club_id,p.solicitante_perfil_id,'preinscripcion-'||p.id||'-aprobada','inscripcion','Inscripción aprobada',
      p.nombre||' ya tiene la plaza confirmada.','home',jsonb_build_object('preinscripcion_id',p.id,'socio_id',v_socio,'disciplina_id',p.disciplina_id,'grupo_id',p.grupo_id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_socio;
end; $$;
revoke all on function public.app_aprobar_preinscripcion(uuid) from public;
grant execute on function public.app_aprobar_preinscripcion(uuid) to authenticated;

-- Solicitud adicional para un adulto ya inscrito o para cualquiera de sus menores.
create or replace function public.app_solicitar_nueva_matricula(
  p_socio_id uuid,
  p_disciplina_id uuid,
  p_grupo_id uuid,
  p_tarifa_id uuid default null
) returns uuid language plpgsql security definer set search_path=public,auth
as $$
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
end; $$;
revoke all on function public.app_solicitar_nueva_matricula(uuid,uuid,uuid,uuid) from public;
grant execute on function public.app_solicitar_nueva_matricula(uuid,uuid,uuid,uuid) to authenticated;

-- Diagnóstico final ampliado.
create or replace function public.app_diagnostico_v150(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,storage
as $$
begin
  if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo dirección puede ejecutar el diagnóstico'; end if;
  return jsonb_build_object(
    'club_activo',exists(select 1 from public.clubes where id=p_club_id and activo),
    'matriculas_activas',(select count(*) from public.socio_disciplinas where club_id=p_club_id and activa),
    'alumnos_multidisciplina',(select count(*) from (select socio_id from public.socio_disciplinas where club_id=p_club_id and activa group by socio_id having count(distinct disciplina_id)>1) x),
    'alumnos_multigrupo',(select count(*) from (select socio_id,disciplina_id from public.socio_disciplinas where club_id=p_club_id and activa group by socio_id,disciplina_id having count(distinct grupo_id)>1) x),
    'familias_con_varios_menores',(select count(*) from (select tutor_perfil_id from public.tutores_socios where club_id=p_club_id group by tutor_perfil_id having count(distinct socio_id)>1) x),
    'dispositivos_push_activos',(select count(*) from public.dispositivos_push where club_id=p_club_id and activo),
    'avisos_pendientes_push',(select count(*) from public.notificaciones where club_id=p_club_id and push_enviado_en is null),
    'config_avisos',exists(select 1 from public.configuracion_avisos_cuota where club_id=p_club_id and activo),
    'buckets_ok',jsonb_build_object(
      'public_media',exists(select 1 from storage.buckets where id='club-public-media'),
      'justificantes',exists(select 1 from storage.buckets where id='justificantes-pago'),
      'documentos',exists(select 1 from storage.buckets where id='member-documents'))
  );
end; $$;
revoke all on function public.app_diagnostico_v150(uuid) from public;
grant execute on function public.app_diagnostico_v150(uuid) to authenticated;
