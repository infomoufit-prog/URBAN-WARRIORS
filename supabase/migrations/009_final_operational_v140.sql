-- ============================================================================
-- URBAN WARRIORS 1.4.0 — CIERRE OPERATIVO
-- Aplicar después de 008_audit_operational_v131.sql
-- - La creación pública genera una PREINSCRIPCIÓN, no un socio prematuro.
-- - Aprobación transaccional con validación de grupo, tarifa y aforo.
-- - Lista de espera operativa y notificada.
-- - Diagnóstico técnico para dirección.
-- ============================================================================

-- El registro crea la cuenta, la pertenencia al club y la solicitud. El socio
-- nace únicamente cuando secretaría/dirección aprueba la preinscripción.
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
) returns jsonb
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_club_id uuid;
  v_rol public.rol_club;
  v_nombre text;
  v_apellidos text;
  v_fecha date;
  v_email text := coalesce(auth.jwt() ->> 'email', '');
  v_preinscripcion_id uuid;
begin
  if v_uid is null then raise exception 'Debes autenticarte antes de completar el registro'; end if;
  if p_tipo_cuenta not in ('adulto','tutor') then raise exception 'Tipo de cuenta no permitido'; end if;
  if nullif(trim(p_adulto_nombre),'') is null or nullif(trim(p_adulto_apellidos),'') is null then
    raise exception 'Nombre y apellidos del adulto son obligatorios';
  end if;
  if nullif(trim(p_telefono),'') is null then raise exception 'El teléfono es obligatorio'; end if;

  select id into v_club_id from public.clubes where slug=p_club_slug and activo limit 1;
  if v_club_id is null then raise exception 'Club no disponible'; end if;
  if p_disciplina_id is null then raise exception 'Selecciona una disciplina'; end if;
  if p_grupo_id is null then raise exception 'Selecciona un grupo'; end if;
  if not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=v_club_id and activa) then
    raise exception 'Disciplina no válida para este club';
  end if;
  if not exists(select 1 from public.grupos where id=p_grupo_id and club_id=v_club_id and disciplina_id=p_disciplina_id and activo) then
    raise exception 'Grupo no válido para la disciplina seleccionada';
  end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=v_club_id and activa) then
    raise exception 'Tarifa no válida para este club';
  end if;

  insert into public.perfiles(id,nombre,apellidos,telefono)
  values(v_uid,trim(p_adulto_nombre),trim(p_adulto_apellidos),trim(p_telefono))
  on conflict(id) do update set nombre=excluded.nombre,apellidos=excluded.apellidos,
    telefono=excluded.telefono,actualizado_en=now();

  v_rol := case when p_tipo_cuenta='adulto' then 'alumno'::public.rol_club else 'familia'::public.rol_club end;
  insert into public.miembros_club(club_id,perfil_id,rol,activo)
  values(v_club_id,v_uid,v_rol,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true;

  if p_tipo_cuenta='adulto' then
    v_nombre:=trim(p_adulto_nombre); v_apellidos:=trim(p_adulto_apellidos); v_fecha:=p_fecha_nacimiento_adulto;
  else
    if nullif(trim(p_menor_nombre),'') is null or nullif(trim(p_menor_apellidos),'') is null then
      raise exception 'Faltan los datos del menor';
    end if;
    v_nombre:=trim(p_menor_nombre); v_apellidos:=trim(p_menor_apellidos); v_fecha:=p_fecha_nacimiento_menor;
  end if;

  if exists(
    select 1 from public.preinscripciones
    where club_id=v_club_id and solicitante_perfil_id=v_uid
      and lower(nombre)=lower(v_nombre) and lower(apellidos)=lower(v_apellidos)
      and disciplina_id=p_disciplina_id and estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')
  ) then raise exception 'Ya existe una solicitud activa para esta persona y disciplina'; end if;

  insert into public.preinscripciones(
    club_id,solicitante_perfil_id,tipo_solicitud,nombre,apellidos,fecha_nacimiento,
    tutor_nombre,tutor_email,telefono,disciplina_id,grupo_id,tarifa_id,parentesco,estado
  ) values(
    v_club_id,v_uid,case when p_tipo_cuenta='adulto' then 'adulto' else 'menor' end,
    v_nombre,v_apellidos,v_fecha,
    case when p_tipo_cuenta='tutor' then concat_ws(' ',trim(p_adulto_nombre),trim(p_adulto_apellidos)) end,
    v_email,trim(p_telefono),p_disciplina_id,p_grupo_id,p_tarifa_id,
    case when p_tipo_cuenta='tutor' then 'Tutor/a responsable' end,'enviada'
  ) returning id into v_preinscripcion_id;

  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select v_club_id,rol,'preinscripcion-'||v_preinscripcion_id||'-'||rol::text,'inscripcion',
    'Nueva preinscripción',v_nombre||' '||v_apellidos||' ha enviado una solicitud.',
    'enrollments',jsonb_build_object('preinscripcion_id',v_preinscripcion_id),v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;

  return jsonb_build_object('club_id',v_club_id,'preinscripcion_id',v_preinscripcion_id,'rol',v_rol,'estado','enviada');
end; $$;
revoke all on function public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid) from public;
grant execute on function public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid) to authenticated;

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
    select sd.socio_id into v_socio from public.socio_disciplinas sd
      join public.socios s on s.id=sd.socio_id and s.club_id=sd.club_id
      where sd.club_id=p.club_id and sd.disciplina_id=p.disciplina_id
        and lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos)
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
  select count(*) into v_ocupacion from public.socio_disciplinas where club_id=p.club_id and grupo_id=p.grupo_id and activa;
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
      tarifa_id=p.tarifa_id,estado='activo',actualizado_en=now() where id=v_socio;
  end if;

  update public.socio_disciplinas set activa=false,fecha_fin=current_date
    where club_id=p.club_id and socio_id=v_socio and disciplina_id<>p.disciplina_id and activa;
  insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,activa,fecha_inicio,fecha_fin)
  values(p.club_id,v_socio,p.disciplina_id,p.grupo_id,true,current_date,null)
  on conflict(club_id,socio_id,disciplina_id) do update set grupo_id=excluded.grupo_id,activa=true,fecha_fin=null;

  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(p.club_id,p.solicitante_perfil_id,v_socio,coalesce(p.parentesco,'Tutor/a responsable'),true)
    on conflict(club_id,tutor_perfil_id,socio_id) do update set parentesco=excluded.parentesco,contacto_principal=true;
  end if;

  update public.preinscripciones set estado='aprobada',revisada_por=auth.uid(),revisada_en=now() where id=p.id;
  if p.solicitante_perfil_id is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p.club_id,p.solicitante_perfil_id,'preinscripcion-'||p.id||'-aprobada','inscripcion','Inscripción aprobada',
      p.nombre||' ya tiene la plaza confirmada.','home',jsonb_build_object('preinscripcion_id',p.id,'socio_id',v_socio),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_socio;
end; $$;
revoke all on function public.app_aprobar_preinscripcion(uuid) from public;
grant execute on function public.app_aprobar_preinscripcion(uuid) to authenticated;

create or replace function public.app_lista_espera_preinscripcion(p_preinscripcion_id uuid,p_motivo text default null)
returns void language plpgsql security definer set search_path=public,auth
as $$
declare v_row public.preinscripciones;
begin
  select * into v_row from public.preinscripciones where id=p_preinscripcion_id for update;
  if v_row.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(v_row.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;
  if v_row.estado in ('aprobada','rechazada','cancelada') then raise exception 'La solicitud está cerrada'; end if;
  update public.preinscripciones set estado='lista_espera',observaciones=coalesce(nullif(trim(p_motivo),''),observaciones),
    revisada_por=auth.uid(),revisada_en=now() where id=v_row.id;
  if v_row.solicitante_perfil_id is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_row.club_id,v_row.solicitante_perfil_id,'preinscripcion-'||v_row.id||'-espera','inscripcion','Solicitud en lista de espera',
      coalesce(nullif(trim(p_motivo),''),'Te avisaremos cuando haya una plaza disponible.'),'home',jsonb_build_object('preinscripcion_id',v_row.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
end; $$;
revoke all on function public.app_lista_espera_preinscripcion(uuid,text) from public;
grant execute on function public.app_lista_espera_preinscripcion(uuid,text) to authenticated;

-- Diagnóstico legible por dirección. No modifica datos.
create or replace function public.app_diagnostico_final(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,storage
as $$
declare v_result jsonb;
begin
  if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo dirección puede ejecutar el diagnóstico'; end if;
  select jsonb_build_object(
    'club',exists(select 1 from public.clubes where id=p_club_id and activo),
    'disciplinas',(select count(*) from public.disciplinas where club_id=p_club_id),
    'grupos',(select count(*) from public.grupos where club_id=p_club_id),
    'horarios',(select count(*) from public.horarios_grupo where club_id=p_club_id),
    'socios',(select count(*) from public.socios where club_id=p_club_id),
    'preinscripciones',(select count(*) from public.preinscripciones where club_id=p_club_id),
    'tarifas',(select count(*) from public.tarifas where club_id=p_club_id),
    'cuotas',(select count(*) from public.cuotas where club_id=p_club_id),
    'config_avisos',exists(select 1 from public.configuracion_avisos_cuota where club_id=p_club_id),
    'bucket_public_media',exists(select 1 from storage.buckets where id='club-public-media'),
    'bucket_justificantes',exists(select 1 from storage.buckets where id='justificantes-pago'),
    'bucket_documentos',exists(select 1 from storage.buckets where id='member-documents')
  ) into v_result;
  return v_result;
end; $$;
revoke all on function public.app_diagnostico_final(uuid) from public;
grant execute on function public.app_diagnostico_final(uuid) to authenticated;
