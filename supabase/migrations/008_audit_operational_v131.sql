-- ============================================================================
-- URBAN WARRIORS · v1.3.1
-- Auditoría operativa y endurecimiento de altas, grupos y horarios.
-- Ejecutar después de 007_operational_v130.sql.
-- ============================================================================

create or replace function public.app_guardar_grupo(
  p_club_id uuid,
  p_id uuid,
  p_disciplina_id uuid,
  p_nombre text,
  p_monitor_nombre text,
  p_sala text,
  p_edad_min smallint,
  p_edad_max smallint,
  p_plazas integer,
  p_activo boolean,
  p_horarios jsonb default '[]'::jsonb
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare
  v_id uuid;
  v_h jsonb;
  v_dia smallint;
  v_inicio time;
  v_fin time;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then
    raise exception 'No tienes permiso para gestionar grupos';
  end if;
  if not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id and activa) then
    raise exception 'Selecciona una disciplina activa del club';
  end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre del grupo es obligatorio'; end if;
  if coalesce(p_plazas,0) < 1 then raise exception 'Las plazas deben ser mayores que cero'; end if;
  if p_edad_min is not null and p_edad_max is not null and p_edad_min > p_edad_max then
    raise exception 'La edad mínima no puede superar la máxima';
  end if;

  if p_id is null then
    insert into public.grupos(club_id,disciplina_id,nombre,monitor_nombre,sala,edad_min,edad_max,plazas,activo)
    values(p_club_id,p_disciplina_id,trim(p_nombre),nullif(trim(p_monitor_nombre),''),nullif(trim(p_sala),''),p_edad_min,p_edad_max,p_plazas,coalesce(p_activo,true))
    returning id into v_id;
  else
    update public.grupos set disciplina_id=p_disciplina_id,nombre=trim(p_nombre),monitor_nombre=nullif(trim(p_monitor_nombre),''),
      sala=nullif(trim(p_sala),''),edad_min=p_edad_min,edad_max=p_edad_max,plazas=p_plazas,activo=coalesce(p_activo,true)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Grupo no encontrado'; end if;
  end if;

  delete from public.horarios_grupo where club_id=p_club_id and grupo_id=v_id;
  for v_h in select * from jsonb_array_elements(coalesce(p_horarios,'[]'::jsonb)) loop
    if nullif(v_h->>'dia_semana','') is null
       or nullif(v_h->>'hora_inicio','') is null
       or nullif(v_h->>'hora_fin','') is null then
      continue;
    end if;
    v_dia := (v_h->>'dia_semana')::smallint;
    v_inicio := (v_h->>'hora_inicio')::time;
    v_fin := (v_h->>'hora_fin')::time;
    if v_dia < 1 or v_dia > 7 then raise exception 'El día del horario debe estar entre 1 y 7'; end if;
    if v_fin <= v_inicio then raise exception 'La hora de fin debe ser posterior a la hora de inicio'; end if;
    if exists(
      select 1 from public.horarios_grupo
      where club_id=p_club_id and grupo_id=v_id and dia_semana=v_dia
        and hora_inicio < v_fin and hora_fin > v_inicio
    ) then raise exception 'Hay horarios solapados para el mismo grupo'; end if;
    insert into public.horarios_grupo(club_id,grupo_id,dia_semana,hora_inicio,hora_fin)
    values(p_club_id,v_id,v_dia,v_inicio,v_fin);
  end loop;
  return v_id;
end; $$;
revoke all on function public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb) from public;
grant execute on function public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb) to authenticated;

create or replace function public.app_guardar_socio(
  p_club_id uuid,
  p_id uuid,
  p_nombre text,
  p_apellidos text,
  p_fecha_nacimiento date,
  p_telefono text,
  p_email text,
  p_tutor_nombre text,
  p_disciplina_id uuid,
  p_grupo_id uuid,
  p_grado_id uuid,
  p_grado_texto text,
  p_tarifa_id uuid,
  p_estado text default 'activo',
  p_contacto_emergencia text default '',
  p_telefono_emergencia text default '',
  p_notas_internas text default ''
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then
    raise exception 'No tienes permiso para gestionar alumnos';
  end if;
  if nullif(trim(p_nombre),'') is null or nullif(trim(p_apellidos),'') is null then
    raise exception 'Nombre y apellidos son obligatorios';
  end if;
  if p_estado not in ('prealta','activo','baja','suspendido') then raise exception 'Estado de alumno no válido'; end if;
  if p_disciplina_id is null or p_grupo_id is null then
    raise exception 'Selecciona una disciplina y un grupo para el alta directa';
  end if;
  if not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id and activa) then
    raise exception 'Disciplina no válida o inactiva';
  end if;
  if not exists(select 1 from public.grupos where id=p_grupo_id and club_id=p_club_id and disciplina_id=p_disciplina_id and activo) then
    raise exception 'El grupo no pertenece a la disciplina o está inactivo';
  end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=p_club_id and activa) then
    raise exception 'Tarifa no válida o inactiva';
  end if;
  if p_grado_id is not null and not exists(select 1 from public.grados where id=p_grado_id and club_id=p_club_id and disciplina_id=p_disciplina_id and activo) then
    raise exception 'El grado no pertenece a la disciplina o está inactivo';
  end if;

  if p_id is null then
    insert into public.socios(club_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,grado_texto,tarifa_id,estado,contacto_emergencia,telefono_emergencia,notas_internas)
    values(p_club_id,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,nullif(trim(p_telefono),''),lower(nullif(trim(p_email),'')),nullif(trim(p_tutor_nombre),''),nullif(trim(p_grado_texto),''),p_tarifa_id,p_estado,nullif(trim(p_contacto_emergencia),''),nullif(trim(p_telefono_emergencia),''),nullif(trim(p_notas_internas),''))
    returning id into v_id;
  else
    update public.socios set nombre=trim(p_nombre),apellidos=trim(p_apellidos),fecha_nacimiento=p_fecha_nacimiento,
      telefono=nullif(trim(p_telefono),''),email=lower(nullif(trim(p_email),'')),tutor_nombre=nullif(trim(p_tutor_nombre),''),
      grado_texto=nullif(trim(p_grado_texto),''),tarifa_id=p_tarifa_id,estado=p_estado,
      contacto_emergencia=nullif(trim(p_contacto_emergencia),''),telefono_emergencia=nullif(trim(p_telefono_emergencia),''),
      notas_internas=nullif(trim(p_notas_internas),''),actualizado_en=now()
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Alumno no encontrado'; end if;
  end if;

  update public.socio_disciplinas set activa=false,fecha_fin=current_date
   where club_id=p_club_id and socio_id=v_id and disciplina_id<>p_disciplina_id and activa;
  insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,grado_id,activa,fecha_inicio,fecha_fin)
  values(p_club_id,v_id,p_disciplina_id,p_grupo_id,p_grado_id,true,current_date,null)
  on conflict(club_id,socio_id,disciplina_id) do update set
    grupo_id=excluded.grupo_id,grado_id=excluded.grado_id,activa=true,fecha_fin=null;
  return v_id;
end; $$;
revoke all on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) from public;
grant execute on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) to authenticated;

-- Resumen legible para verificar que la instalación tiene todos los objetos mínimos.
create or replace function public.app_auditoria_operativa(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth
as $$
begin
  if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo dirección puede ejecutar la auditoría'; end if;
  return jsonb_build_object(
    'club', exists(select 1 from public.clubes where id=p_club_id),
    'disciplinas', (select count(*) from public.disciplinas where club_id=p_club_id),
    'grupos', (select count(*) from public.grupos where club_id=p_club_id),
    'horarios', (select count(*) from public.horarios_grupo where club_id=p_club_id),
    'socios', (select count(*) from public.socios where club_id=p_club_id),
    'preinscripciones', (select count(*) from public.preinscripciones where club_id=p_club_id),
    'tarifas', (select count(*) from public.tarifas where club_id=p_club_id),
    'cuotas', (select count(*) from public.cuotas where club_id=p_club_id),
    'pagos', (select count(*) from public.pagos where club_id=p_club_id),
    'publicaciones', (select count(*) from public.comunicaciones where club_id=p_club_id),
    'material', (select count(*) from public.material_catalogo where club_id=p_club_id),
    'notificaciones', (select count(*) from public.notificaciones where club_id=p_club_id),
    'bucket_medios', exists(select 1 from storage.buckets where id='club-public-media'),
    'bucket_justificantes', exists(select 1 from storage.buckets where id='justificantes-pago'),
    'bucket_documentos', exists(select 1 from storage.buckets where id='member-documents')
  );
end; $$;
revoke all on function public.app_auditoria_operativa(uuid) from public;
grant execute on function public.app_auditoria_operativa(uuid) to authenticated;
