-- ============================================================================
-- URBAN WARRIORS 1.5.2 — INTEGRIDAD OPERATIVA FINAL
-- Ejecutar DESPUÉS de 010_family_multisport_firebase_final.sql
-- Esta migración incorpora y sustituye las correcciones del hotfix 011;
-- si 011 ya se ejecutó, 012 sigue siendo idempotente.
-- Objetivo: estabilizar TODAS las mutaciones críticas usadas por web/APK,
-- eliminar incompatibilidades introducidas por multideporte/multigrupo y
-- aportar un autotest transaccional del backend real.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. ESTRUCTURA MULTIGRUPO / ÍNDICES IDEMPOTENTES
-- ---------------------------------------------------------------------------
alter table public.socio_disciplinas
  drop constraint if exists socio_disciplinas_club_id_socio_id_disciplina_id_key;
drop index if exists public.socio_disciplinas_club_id_socio_id_disciplina_id_key;

-- Si una versión anterior dejó duplicadas exactamente la misma matrícula,
-- conservar una activa y cerrar las demás antes de endurecer el índice.
with ranked as (
  select id,row_number() over(
    partition by club_id,socio_id,disciplina_id,grupo_id
    order by fecha_inicio desc,id desc
  ) rn
  from public.socio_disciplinas
  where activa and grupo_id is not null
)
update public.socio_disciplinas sd
set activa=false,fecha_fin=coalesce(sd.fecha_fin,current_date)
from ranked r where sd.id=r.id and r.rn>1;
with ranked as (
  select id,row_number() over(
    partition by club_id,socio_id,disciplina_id
    order by fecha_inicio desc,id desc
  ) rn
  from public.socio_disciplinas
  where activa and grupo_id is null
)
update public.socio_disciplinas sd
set activa=false,fecha_fin=coalesce(sd.fecha_fin,current_date)
from ranked r where sd.id=r.id and r.rn>1;

create unique index if not exists uq_socio_disciplina_grupo_activa
  on public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id)
  where activa and grupo_id is not null;
create unique index if not exists uq_socio_disciplina_sin_grupo_activa
  on public.socio_disciplinas(club_id,socio_id,disciplina_id)
  where activa and grupo_id is null;
create index if not exists idx_socio_disciplinas_grupo_activa
  on public.socio_disciplinas(club_id,grupo_id,socio_id) where activa;

-- Idempotencia también para notificaciones compartidas por rol/audiencia.
-- Antes de crear los índices se conservan únicamente las filas más recientes
-- de posibles duplicados históricos, para que la migración nunca falle al
-- endurecer una base que ya lleva datos reales.
with ranked as (
  select id,row_number() over(partition by club_id,rol_destino,clave order by creado_en desc,id desc) rn
  from public.notificaciones
  where clave is not null and rol_destino is not null
)
delete from public.notificaciones n using ranked r where n.id=r.id and r.rn>1;
with ranked as (
  select id,row_number() over(partition by club_id,audiencia,clave order by creado_en desc,id desc) rn
  from public.notificaciones
  where clave is not null and audiencia is not null
)
delete from public.notificaciones n using ranked r where n.id=r.id and r.rn>1;
create unique index if not exists notificaciones_clave_rol_unica
  on public.notificaciones(club_id,rol_destino,clave)
  where clave is not null and rol_destino is not null;
create unique index if not exists notificaciones_clave_audiencia_unica
  on public.notificaciones(club_id,audiencia,clave)
  where clave is not null and audiencia is not null;


-- Limpieza compensatoria de justificantes: si el archivo se sube pero la
-- transacción de pago falla, el cliente autorizado puede borrar ese objeto.
drop policy if exists justificantes_borrar_autorizados on storage.objects;
create policy justificantes_borrar_autorizados on storage.objects
  for delete to authenticated using (
    bucket_id='justificantes-pago'
    and array_length(storage.foldername(name),1) >= 2
    and (
      public.puede_aportar_pago_socio(((storage.foldername(name))[2])::uuid)
      or public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria','economia')
    )
  );

-- Reafirmar las dos políticas de lectura que afectan directamente a la
-- experiencia de familias y publicaciones. Las políticas SELECT se combinan
-- con OR, así que el solicitante ve sus propias solicitudes sin ampliar la
-- gestión, y la audiencia de publicaciones se aplica también en PostgreSQL.
drop policy if exists preinscripciones_solicitante_lectura on public.preinscripciones;
create policy preinscripciones_solicitante_lectura on public.preinscripciones
  for select to authenticated using (solicitante_perfil_id=auth.uid());
drop policy if exists comunicaciones_lectura on public.comunicaciones;
create policy comunicaciones_lectura on public.comunicaciones
for select to authenticated
using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion')
  or (
    public.es_miembro_club(club_id)
    and (
      estado='publicada'
      or (estado='programada' and coalesce(programada_para,evento_fecha,now())<=now())
    )
    and (
      audiencia='todos'
      or (audiencia='familias' and public.tiene_rol_club(club_id,'familia','alumno'))
      or (audiencia='monitores' and public.tiene_rol_club(club_id,'monitor'))
    )
  )
);

-- ---------------------------------------------------------------------------
-- 1. GRUPOS + HORARIOS: transaccional, validado e idempotente en edición.
-- ---------------------------------------------------------------------------
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
  if nullif(trim(coalesce(p_nombre,'')),'') is null then raise exception 'El nombre del grupo es obligatorio'; end if;
  if p_plazas is not null and p_plazas < 1 then raise exception 'Las plazas deben ser mayores que cero'; end if;
  if p_edad_min is not null and p_edad_min < 0 then raise exception 'La edad mínima no puede ser negativa'; end if;
  if p_edad_max is not null and p_edad_max < 0 then raise exception 'La edad máxima no puede ser negativa'; end if;
  if p_edad_min is not null and p_edad_max is not null and p_edad_min > p_edad_max then
    raise exception 'La edad mínima no puede superar la máxima';
  end if;
  if jsonb_typeof(coalesce(p_horarios,'[]'::jsonb)) <> 'array' then raise exception 'Formato de horarios no válido'; end if;

  -- Validar antes de tocar horarios existentes.
  for v_h in select value from jsonb_array_elements(coalesce(p_horarios,'[]'::jsonb)) loop
    if nullif(v_h->>'dia_semana','') is null or nullif(v_h->>'hora_inicio','') is null or nullif(v_h->>'hora_fin','') is null then
      raise exception 'Todos los horarios deben tener día, inicio y fin';
    end if;
    begin
      v_dia := (v_h->>'dia_semana')::smallint;
      v_inicio := (v_h->>'hora_inicio')::time;
      v_fin := (v_h->>'hora_fin')::time;
    exception when others then
      raise exception 'Hay un horario con día u hora no válidos';
    end;
    if v_dia not between 1 and 7 then raise exception 'El día del horario debe estar entre 1 y 7'; end if;
    if v_fin <= v_inicio then raise exception 'La hora de fin debe ser posterior a la hora de inicio'; end if;
  end loop;

  -- Detectar solapes dentro del JSON recibido antes de escribir.
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_horarios,'[]'::jsonb)) with ordinality a(value,ord)
    join jsonb_array_elements(coalesce(p_horarios,'[]'::jsonb)) with ordinality b(value,ord)
      on a.ord < b.ord
     and (a.value->>'dia_semana') = (b.value->>'dia_semana')
     and (a.value->>'hora_inicio')::time < (b.value->>'hora_fin')::time
     and (a.value->>'hora_fin')::time > (b.value->>'hora_inicio')::time
  ) then raise exception 'Hay horarios solapados para el mismo grupo'; end if;

  if p_id is null then
    if exists(select 1 from public.grupos where club_id=p_club_id and lower(nombre)=lower(trim(p_nombre))) then
      raise exception 'Ya existe un grupo con ese nombre';
    end if;
    insert into public.grupos(club_id,disciplina_id,nombre,monitor_nombre,sala,edad_min,edad_max,plazas,activo)
    values(p_club_id,p_disciplina_id,trim(p_nombre),nullif(trim(coalesce(p_monitor_nombre,'')),''),
      nullif(trim(coalesce(p_sala,'')),''),p_edad_min,p_edad_max,p_plazas,coalesce(p_activo,true))
    returning id into v_id;
  else
    if exists(select 1 from public.grupos where club_id=p_club_id and id<>p_id and lower(nombre)=lower(trim(p_nombre))) then
      raise exception 'Ya existe otro grupo con ese nombre';
    end if;
    if p_plazas is not null and (select count(distinct socio_id) from public.socio_disciplinas where club_id=p_club_id and grupo_id=p_id and activa) > p_plazas then
      raise exception 'No puedes reducir las plazas por debajo del número de alumnos matriculados';
    end if;
    update public.grupos set disciplina_id=p_disciplina_id,nombre=trim(p_nombre),
      monitor_nombre=nullif(trim(coalesce(p_monitor_nombre,'')),''),sala=nullif(trim(coalesce(p_sala,'')),''),
      edad_min=p_edad_min,edad_max=p_edad_max,plazas=p_plazas,activo=coalesce(p_activo,true)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Grupo no encontrado'; end if;
  end if;

  delete from public.horarios_grupo where club_id=p_club_id and grupo_id=v_id;
  for v_h in select value from jsonb_array_elements(coalesce(p_horarios,'[]'::jsonb)) loop
    insert into public.horarios_grupo(club_id,grupo_id,dia_semana,hora_inicio,hora_fin)
    values(p_club_id,v_id,(v_h->>'dia_semana')::smallint,(v_h->>'hora_inicio')::time,(v_h->>'hora_fin')::time);
  end loop;
  return v_id;
end; $$;
revoke all on function public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb) from public;
grant execute on function public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. ALUMNOS: conserva matrículas previas y usa alumno+disciplina+grupo.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_socio(
  p_club_id uuid,p_id uuid,p_nombre text,p_apellidos text,p_fecha_nacimiento date,
  p_telefono text,p_email text,p_tutor_nombre text,p_disciplina_id uuid,p_grupo_id uuid,
  p_grado_id uuid,p_grado_texto text,p_tarifa_id uuid,p_estado text default 'activo',
  p_contacto_emergencia text default '',p_telefono_emergencia text default '',p_notas_internas text default ''
) returns uuid
language plpgsql security definer set search_path=public,auth
as $$
declare v_id uuid; v_matricula uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para gestionar alumnos'; end if;
  if nullif(trim(coalesce(p_nombre,'')),'') is null or nullif(trim(coalesce(p_apellidos,'')),'') is null then raise exception 'Nombre y apellidos son obligatorios'; end if;
  if p_estado not in ('prealta','activo','baja','suspendido') then raise exception 'Estado de alumno no válido'; end if;
  if p_disciplina_id is null or p_grupo_id is null then raise exception 'Selecciona una disciplina y un grupo'; end if;
  if not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id and activa) then raise exception 'Disciplina no válida o inactiva'; end if;
  if not exists(select 1 from public.grupos where id=p_grupo_id and club_id=p_club_id and disciplina_id=p_disciplina_id and activo) then raise exception 'El grupo no pertenece a la disciplina o está inactivo'; end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=p_club_id and activa) then raise exception 'Tarifa no válida o inactiva'; end if;
  if p_grado_id is not null and not exists(select 1 from public.grados where id=p_grado_id and club_id=p_club_id and disciplina_id=p_disciplina_id and activo) then raise exception 'El grado no pertenece a la disciplina o está inactivo'; end if;

  if p_id is null then
    insert into public.socios(club_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,grado_texto,tarifa_id,estado,contacto_emergencia,telefono_emergencia,notas_internas)
    values(p_club_id,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,nullif(trim(coalesce(p_telefono,'')),''),
      lower(nullif(trim(coalesce(p_email,'')),'')),nullif(trim(coalesce(p_tutor_nombre,'')),''),
      nullif(trim(coalesce(p_grado_texto,'')),''),p_tarifa_id,p_estado,
      nullif(trim(coalesce(p_contacto_emergencia,'')),''),nullif(trim(coalesce(p_telefono_emergencia,'')),''),
      nullif(trim(coalesce(p_notas_internas,'')),'')) returning id into v_id;
  else
    update public.socios set nombre=trim(p_nombre),apellidos=trim(p_apellidos),fecha_nacimiento=p_fecha_nacimiento,
      telefono=nullif(trim(coalesce(p_telefono,'')),''),email=lower(nullif(trim(coalesce(p_email,'')),'')),
      tutor_nombre=nullif(trim(coalesce(p_tutor_nombre,'')),''),grado_texto=nullif(trim(coalesce(p_grado_texto,'')),''),
      tarifa_id=p_tarifa_id,estado=p_estado,contacto_emergencia=nullif(trim(coalesce(p_contacto_emergencia,'')),''),
      telefono_emergencia=nullif(trim(coalesce(p_telefono_emergencia,'')),''),notas_internas=nullif(trim(coalesce(p_notas_internas,'')),''),
      actualizado_en=now() where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Alumno no encontrado'; end if;
  end if;

  if not exists(select 1 from public.socio_disciplinas where club_id=p_club_id and socio_id=v_id and disciplina_id=p_disciplina_id and grupo_id=p_grupo_id and activa)
     and exists(
       select 1 from public.grupos g
       where g.id=p_grupo_id and g.club_id=p_club_id and g.plazas is not null
         and (select count(distinct sd.socio_id) from public.socio_disciplinas sd where sd.club_id=p_club_id and sd.grupo_id=p_grupo_id and sd.activa) >= g.plazas
     ) then
    raise exception 'No quedan plazas disponibles en el grupo seleccionado';
  end if;

  select id into v_matricula from public.socio_disciplinas
   where club_id=p_club_id and socio_id=v_id and disciplina_id=p_disciplina_id and grupo_id=p_grupo_id
   order by activa desc,fecha_inicio desc limit 1;
  if v_matricula is null then
    insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,grado_id,activa,fecha_inicio,fecha_fin)
    values(p_club_id,v_id,p_disciplina_id,p_grupo_id,p_grado_id,true,current_date,null);
  else
    update public.socio_disciplinas set grado_id=p_grado_id,activa=true,fecha_fin=null where id=v_matricula;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) from public;
grant execute on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. GRADUACIONES: compatible con varias matrículas de la misma disciplina.
-- El trigger actualizar_grado_actual actualiza TODAS las matrículas activas
-- de esa disciplina, por lo que el grado sigue siendo deportivo, no de grupo.
-- ---------------------------------------------------------------------------
create or replace function public.app_registrar_graduacion(
  p_club_id uuid,p_socio_id uuid,p_disciplina_id uuid,p_grado_id uuid,
  p_fecha date,p_examinador text,p_nota text
) returns uuid
language plpgsql security definer set search_path=public,auth
as $$
declare v_id uuid; v_anterior uuid; v_perfil uuid; v_alumno text; v_grado text;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para registrar graduaciones'; end if;
  if not exists(select 1 from public.socios where club_id=p_club_id and id=p_socio_id) then raise exception 'Alumno no válido'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa) then raise exception 'El alumno no tiene matrícula activa en esa disciplina'; end if;
  if not exists(select 1 from public.grados where club_id=p_club_id and id=p_grado_id and disciplina_id=p_disciplina_id and activo) then raise exception 'El grado no pertenece a la disciplina'; end if;
  select grado_id into v_anterior from public.socio_disciplinas
   where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa
   order by fecha_inicio desc,id desc limit 1;
  insert into public.graduaciones(club_id,socio_id,disciplina_id,grado_id,grado_anterior_id,fecha,examinador,nota,registrado_por)
  values(p_club_id,p_socio_id,p_disciplina_id,p_grado_id,v_anterior,coalesce(p_fecha,current_date),
    nullif(trim(coalesce(p_examinador,'')),''),nullif(trim(coalesce(p_nota,'')),''),auth.uid()) returning id into v_id;
  -- El trigger trg_grado_actual actualiza las matrículas activas.
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos),g.nombre
    into v_perfil,v_alumno,v_grado
  from public.socios s join public.grados g on g.id=p_grado_id and g.club_id=s.club_id
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=p_socio_id and s.club_id=p_club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p_club_id,v_perfil,'graduacion-'||v_id,'graduacion','Nuevo grado registrado',v_alumno||' ha alcanzado '||v_grado||'.','profile',
      jsonb_build_object('graduacion_id',v_id,'socio_id',p_socio_id,'disciplina_id',p_disciplina_id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) from public;
grant execute on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. PUBLICACIONES: guardado + notificación transaccional e idempotente.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_comunicacion(
  p_club_id uuid,p_id uuid,p_tipo text,p_titulo text,p_cuerpo text,
  p_audiencia text,p_estado text,p_evento_fecha timestamptz,p_ubicacion text,p_imagen_url text
) returns uuid
language plpgsql security definer set search_path=public,auth
as $$
declare v_id uuid; v_notificada timestamptz;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','comunicacion') then raise exception 'No tienes permiso para gestionar publicaciones'; end if;
  if p_tipo not in ('noticia','evento','clase','cartel') then raise exception 'Tipo de publicación no válido'; end if;
  if p_estado not in ('borrador','programada','publicada','archivada') then raise exception 'Estado no válido'; end if;
  if p_audiencia not in ('todos','familias','monitores') then raise exception 'Audiencia no válida'; end if;
  if nullif(trim(coalesce(p_titulo,'')),'') is null or nullif(trim(coalesce(p_cuerpo,'')),'') is null then raise exception 'Título y texto son obligatorios'; end if;
  if p_estado='programada' and p_evento_fecha is null then raise exception 'Indica la fecha de publicación programada'; end if;

  if p_id is null then
    insert into public.comunicaciones(club_id,tipo,titulo,cuerpo,audiencia,estado,evento_fecha,ubicacion,imagen_url,programada_para,publicada_en,creada_por)
    values(p_club_id,p_tipo,trim(p_titulo),trim(p_cuerpo),p_audiencia,p_estado,p_evento_fecha,
      nullif(trim(coalesce(p_ubicacion,'')),''),nullif(trim(coalesce(p_imagen_url,'')),''),
      case when p_estado='programada' then p_evento_fecha else null end,
      case when p_estado='publicada' then now() else null end,auth.uid())
    returning id,notificada_en into v_id,v_notificada;
  else
    update public.comunicaciones set tipo=p_tipo,titulo=trim(p_titulo),cuerpo=trim(p_cuerpo),audiencia=p_audiencia,estado=p_estado,
      evento_fecha=p_evento_fecha,ubicacion=nullif(trim(coalesce(p_ubicacion,'')),''),imagen_url=nullif(trim(coalesce(p_imagen_url,'')),''),
      programada_para=case when p_estado='programada' then p_evento_fecha else null end,
      publicada_en=case when p_estado='publicada' then coalesce(publicada_en,now()) else publicada_en end
    where id=p_id and club_id=p_club_id returning id,notificada_en into v_id,v_notificada;
    if v_id is null then raise exception 'Publicación no encontrada'; end if;
  end if;

  if p_estado='publicada' and v_notificada is null then
    if p_audiencia='todos' then
      insert into public.notificaciones(club_id,audiencia,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values(p_club_id,'todos','comunicacion-'||v_id||'-todos',case when p_tipo='evento' then 'evento' else 'comunicacion' end,
        trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid())
      on conflict(club_id,audiencia,clave) where clave is not null and audiencia is not null do nothing;
    elsif p_audiencia='monitores' then
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values(p_club_id,'monitor','comunicacion-'||v_id||'-monitor',case when p_tipo='evento' then 'evento' else 'comunicacion' end,
        trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid())
      on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
    else
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values
      (p_club_id,'familia','comunicacion-'||v_id||'-familia',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid()),
      (p_club_id,'alumno','comunicacion-'||v_id||'-alumno',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid())
      on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
    end if;
    update public.comunicaciones set notificada_en=now() where id=v_id;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) from public;
grant execute on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. VARIANTES DE MATERIAL: evita depender de INSERT/UPDATE directo desde UI.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_variante_material(
  p_club_id uuid,p_id uuid,p_material_id uuid,p_talla text,p_color text,p_referencia text,p_stock integer,p_activa boolean
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'No tienes permiso para gestionar variantes'; end if;
  if not exists(select 1 from public.material_catalogo where id=p_material_id and club_id=p_club_id) then raise exception 'Material no encontrado'; end if;
  if coalesce(p_stock,0)<0 then raise exception 'El stock no puede ser negativo'; end if;
  if nullif(trim(coalesce(p_talla,'')),'') is null and nullif(trim(coalesce(p_color,'')),'') is null and nullif(trim(coalesce(p_referencia,'')),'') is null then
    raise exception 'Indica talla, color o referencia de la variante';
  end if;
  if p_id is null then
    insert into public.material_variantes(club_id,material_id,talla,color,referencia,stock,activa)
    values(p_club_id,p_material_id,nullif(trim(coalesce(p_talla,'')),''),nullif(trim(coalesce(p_color,'')),''),nullif(trim(coalesce(p_referencia,'')),''),coalesce(p_stock,0),coalesce(p_activa,true))
    returning id into v_id;
  else
    update public.material_variantes set material_id=p_material_id,talla=nullif(trim(coalesce(p_talla,'')),''),
      color=nullif(trim(coalesce(p_color,'')),''),referencia=nullif(trim(coalesce(p_referencia,'')),''),stock=coalesce(p_stock,0),activa=coalesce(p_activa,true)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Variante no encontrada'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_variante_material(uuid,uuid,uuid,text,text,text,integer,boolean) from public;
grant execute on function public.app_guardar_variante_material(uuid,uuid,uuid,text,text,text,integer,boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. ASISTENCIA Y CHECK-IN: operaciones atómicas y compatibles con familias.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_asistencia(
  p_sesion_id uuid,p_socio_id uuid,p_estado public.estado_asistencia,p_observacion text default null
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_id uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if not (public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria') or public.monitor_asignado_a_grupo(v_sesion.grupo_id)) then
    raise exception 'No tienes permiso para pasar asistencia';
  end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then
    raise exception 'El alumno no está matriculado en este grupo';
  end if;
  select id into v_id from public.asistencias where club_id=v_sesion.club_id and sesion_id=p_sesion_id and socio_id=p_socio_id limit 1;
  if v_id is null then
    insert into public.asistencias(club_id,sesion_id,socio_id,estado,observacion,registrado_por)
    values(v_sesion.club_id,p_sesion_id,p_socio_id,p_estado,nullif(trim(coalesce(p_observacion,'')),''),auth.uid()) returning id into v_id;
  else
    update public.asistencias set estado=p_estado,observacion=nullif(trim(coalesce(p_observacion,'')),''),registrado_por=auth.uid(),registrado_en=now() where id=v_id;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) from public;
grant execute on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) to authenticated;

create or replace function public.app_registrar_checkin(
  p_sesion_id uuid,p_socio_id uuid,p_codigo text,p_metodo text default 'codigo'
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_acceso uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id for update;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if v_sesion.estado='cancelada' then raise exception 'La sesión está cancelada'; end if;
  if v_sesion.fecha<>current_date then raise exception 'El check-in solo está disponible el día de la sesión'; end if;
  if not public.puede_aportar_pago_socio(p_socio_id) and not public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria','monitor') then raise exception 'No tienes acceso a este alumno'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then raise exception 'El alumno no está matriculado en este grupo'; end if;
  if nullif(v_sesion.codigo_acceso,'') is not null and upper(trim(coalesce(p_codigo,'')))<>upper(trim(v_sesion.codigo_acceso)) then raise exception 'El código de acceso no es correcto'; end if;
  if p_metodo not in ('codigo','qr','manual','nfc') then raise exception 'Método de acceso no válido'; end if;
  insert into public.registros_acceso_clase(club_id,sesion_id,socio_id,metodo,resultado,registrado_por)
  values(v_sesion.club_id,v_sesion.id,p_socio_id,p_metodo,'permitido',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set resultado='permitido',registrado_en=now(),registrado_por=auth.uid()
  returning id into v_acceso;
  insert into public.asistencias(club_id,sesion_id,socio_id,estado,registrado_por)
  values(v_sesion.club_id,v_sesion.id,p_socio_id,'presente',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set estado='presente',registrado_por=auth.uid(),registrado_en=now();
  return v_acceso;
end; $$;
revoke all on function public.app_registrar_checkin(uuid,uuid,text,text) from public;
grant execute on function public.app_registrar_checkin(uuid,uuid,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. SEGUIMIENTO: escritura servidor para evitar divergencias RLS/UI.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_seguimiento(
  p_club_id uuid,p_socio_id uuid,p_tipo text,p_nota text,p_visibilidad public.visibilidad_seguimiento,p_fecha date default current_date
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.socios where id=p_socio_id and club_id=p_club_id) then raise exception 'Alumno no encontrado'; end if;
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria') or public.monitor_puede_ver_socio(p_socio_id)) then raise exception 'No tienes permiso para registrar seguimiento'; end if;
  if nullif(trim(coalesce(p_tipo,'')),'') is null or nullif(trim(coalesce(p_nota,'')),'') is null then raise exception 'Tipo y nota son obligatorios'; end if;
  insert into public.seguimiento(club_id,socio_id,tipo,nota,visibilidad,registrado_por,fecha)
  values(p_club_id,p_socio_id,trim(p_tipo),trim(p_nota),coalesce(p_visibilidad,'equipo'::public.visibilidad_seguimiento),auth.uid(),coalesce(p_fecha,current_date))
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) from public;
grant execute on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. DOCUMENTOS: registro transaccional tras subida a Storage.
-- ---------------------------------------------------------------------------
create or replace function public.app_registrar_documento(
  p_club_id uuid,p_socio_id uuid,p_nombre text,p_tipo text,p_storage_path text,p_mime_type text,p_tamano_bytes bigint,p_visible_familia boolean
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.socios where id=p_socio_id and club_id=p_club_id) then raise exception 'Alumno no encontrado'; end if;
  if not (public.puede_aportar_pago_socio(p_socio_id) or public.tiene_rol_club(p_club_id,'direccion','secretaria')) then raise exception 'No tienes permiso para guardar documentos de este alumno'; end if;
  if nullif(trim(coalesce(p_nombre,'')),'') is null or nullif(trim(coalesce(p_storage_path,'')),'') is null then raise exception 'Nombre y archivo son obligatorios'; end if;
  insert into public.documentos_socios(club_id,socio_id,nombre,tipo,storage_path,mime_type,tamano_bytes,visible_familia,subido_por)
  values(p_club_id,p_socio_id,trim(p_nombre),coalesce(nullif(trim(coalesce(p_tipo,'')),''),'otro'),trim(p_storage_path),
    nullif(trim(coalesce(p_mime_type,'')),''),p_tamano_bytes,coalesce(p_visible_familia,true),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.app_registrar_documento(uuid,uuid,text,text,text,text,bigint,boolean) from public;
grant execute on function public.app_registrar_documento(uuid,uuid,text,text,text,text,bigint,boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. CONFIGURACIÓN DE AVISOS: validación única de servidor.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_config_avisos(
  p_club_id uuid,p_dias_aviso smallint[],p_hora_envio time,p_canal_app boolean,p_canal_push boolean,
  p_canal_email boolean,p_agrupar_por_familia boolean,p_marcar_vencida_dia smallint,p_zona_horaria text,p_activo boolean
) returns uuid language plpgsql security definer set search_path=public,auth as $$
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'No tienes permiso para configurar avisos'; end if;
  if cardinality(p_dias_aviso)<>5 then raise exception 'Deben configurarse exactamente cinco avisos'; end if;
  if exists(select 1 from unnest(p_dias_aviso) x where x<1 or x>28) then raise exception 'Los días de aviso deben estar entre 1 y 28'; end if;
  if (select count(distinct x) from unnest(p_dias_aviso) x)<>5 then raise exception 'Los cinco días de aviso deben ser distintos'; end if;
  if p_marcar_vencida_dia not between 1 and 28 then raise exception 'El día de vencimiento debe estar entre 1 y 28'; end if;
  insert into public.configuracion_avisos_cuota(club_id,activo,dias_aviso,hora_envio,zona_horaria,canal_app,canal_push,canal_email,agrupar_por_familia,marcar_vencida_dia,actualizado_por,actualizado_en)
  values(p_club_id,coalesce(p_activo,true),p_dias_aviso,coalesce(p_hora_envio,'10:00'),coalesce(nullif(trim(coalesce(p_zona_horaria,'')),''),'Europe/Madrid'),
    coalesce(p_canal_app,true),coalesce(p_canal_push,true),coalesce(p_canal_email,false),coalesce(p_agrupar_por_familia,true),p_marcar_vencida_dia,auth.uid(),now())
  on conflict(club_id) do update set activo=excluded.activo,dias_aviso=excluded.dias_aviso,hora_envio=excluded.hora_envio,zona_horaria=excluded.zona_horaria,
    canal_app=excluded.canal_app,canal_push=excluded.canal_push,canal_email=excluded.canal_email,agrupar_por_familia=excluded.agrupar_por_familia,
    marcar_vencida_dia=excluded.marcar_vencida_dia,actualizado_por=auth.uid(),actualizado_en=now();
  return p_club_id;
end; $$;
revoke all on function public.app_guardar_config_avisos(uuid,smallint[],time,boolean,boolean,boolean,boolean,smallint,text,boolean) from public;
grant execute on function public.app_guardar_config_avisos(uuid,smallint[],time,boolean,boolean,boolean,boolean,smallint,text,boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. PERFIL Y MATRÍCULAS: mutaciones explícitas de servidor.
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_perfil_propio(
  p_nombre text,p_apellidos text,p_telefono text
) returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Sesión no válida'; end if;
  if nullif(trim(coalesce(p_nombre,'')),'') is null then raise exception 'El nombre es obligatorio'; end if;
  update public.perfiles set nombre=trim(p_nombre),apellidos=nullif(trim(coalesce(p_apellidos,'')),''),
    telefono=nullif(trim(coalesce(p_telefono,'')),''),actualizado_en=now()
  where id=v_uid;
  if not found then raise exception 'Perfil no encontrado'; end if;
  return v_uid;
end; $$;
revoke all on function public.app_guardar_perfil_propio(text,text,text) from public;
grant execute on function public.app_guardar_perfil_propio(text,text,text) to authenticated;

create or replace function public.app_desactivar_matricula(p_matricula_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v public.socio_disciplinas;
begin
  select * into v from public.socio_disciplinas where id=p_matricula_id for update;
  if v.id is null then raise exception 'Matrícula no encontrada'; end if;
  if not public.tiene_rol_club(v.club_id,'direccion','secretaria') then raise exception 'No tienes permiso para modificar matrículas'; end if;
  update public.socio_disciplinas set activa=false,fecha_fin=coalesce(fecha_fin,current_date) where id=v.id;
  return v.id;
end; $$;
revoke all on function public.app_desactivar_matricula(uuid) from public;
grant execute on function public.app_desactivar_matricula(uuid) to authenticated;

-- Pago comunicado por familia/alumno: evita duplicados/overpayment y pausa
-- avisos únicamente mientras el justificante está pendiente de revisión.
create or replace function public.comunicar_pago_cuota(
  p_cuota_id uuid,p_importe numeric,p_fecha date,p_metodo text,
  p_referencia text default null,p_justificante_path text default null,p_observaciones text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas; v_pago public.pagos; v_pagado numeric; v_restante numeric;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.puede_aportar_pago_socio(v_cuota.socio_id) then raise exception 'Sin acceso a esta cuota'; end if;
  if v_cuota.estado in ('pagada','anulada','exenta') then raise exception 'La cuota ya no admite comunicación de pago'; end if;
  if coalesce(p_importe,0)<=0 then raise exception 'El importe debe ser mayor que cero'; end if;
  if p_metodo not in ('transferencia','bizum','efectivo','tarjeta','otro') then raise exception 'Método de pago no válido'; end if;
  if exists(select 1 from public.pagos where cuota_id=v_cuota.id and estado_validacion='pendiente') then
    raise exception 'Ya existe un pago pendiente de validar para esta cuota';
  end if;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_restante:=greatest(v_cuota.importe-v_pagado,0);
  if p_importe>v_restante+0.005 then raise exception 'El importe supera el saldo pendiente de la cuota'; end if;
  insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,justificante_url,estado_validacion,observaciones,comunicado_por,comunicado_en)
  values(v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,
    nullif(trim(coalesce(p_referencia,'')),''),nullif(trim(coalesce(p_justificante_path,'')),''),'pendiente',
    nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),now()) returning * into v_pago;
  update public.cuotas set estado='pendiente_validacion',pago_comunicado_en=now(),avisos_pausados=true,
    motivo_pausa_avisos='Pago comunicado por el usuario',avisos_pausados_hasta=null,avisos_pausados_por=auth.uid(),avisos_pausados_en=now(),actualizado_en=now()
  where id=v_cuota.id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select v_cuota.club_id,rol,'pago-pendiente-'||v_pago.id||'-'||rol::text,'cuota','Justificante pendiente de validar',
    'Un usuario ha comunicado el pago de una mensualidad.','fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid()
  from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
  return v_pago;
end; $$;
revoke all on function public.comunicar_pago_cuota(uuid,numeric,date,text,text,text,text) from public;
grant execute on function public.comunicar_pago_cuota(uuid,numeric,date,text,text,text,text) to authenticated;

create or replace function public.validar_pago_cuota(
  p_pago_id uuid,p_decision text,p_motivo text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_pago public.pagos; v_cuota public.cuotas; v_pagado numeric; v_otros numeric; v_perfil uuid; v_nombre text; v_pagada boolean;
begin
  select * into v_pago from public.pagos where id=p_pago_id for update;
  if v_pago.id is null then raise exception 'Pago no encontrado'; end if;
  if not public.tiene_rol_club(v_pago.club_id,'direccion','secretaria','economia') then raise exception 'Sin permisos'; end if;
  if p_decision not in ('validado','rechazado') then raise exception 'Decisión no válida'; end if;
  if p_decision='rechazado' and nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Indica el motivo del rechazo'; end if;
  if v_pago.estado_validacion=p_decision then return v_pago; end if;
  if v_pago.estado_validacion='validado' and p_decision='rechazado' then raise exception 'Un pago validado no puede rechazarse desde esta operación'; end if;
  select * into v_cuota from public.cuotas where id=v_pago.cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if p_decision='validado' then
    select coalesce(sum(importe),0) into v_otros from public.pagos where cuota_id=v_cuota.id and id<>v_pago.id and estado_validacion='validado';
    if v_otros+v_pago.importe>v_cuota.importe+0.005 then raise exception 'La validación superaría el importe total de la cuota'; end if;
  end if;
  update public.pagos set estado_validacion=p_decision,
    validado_por=case when p_decision='validado' then auth.uid() else null end,
    validado_en=case when p_decision='validado' then now() else null end,
    motivo_rechazo=case when p_decision='rechazado' then trim(p_motivo) else null end,
    rechazado_en=case when p_decision='rechazado' then now() else null end
  where id=p_pago_id returning * into v_pago;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_pagada:=v_pagado>=v_cuota.importe-0.005;
  update public.cuotas set
    estado=case when v_pagada then 'pagada'::public.estado_cuota when v_pagado>0 then 'parcialmente_pagada'::public.estado_cuota else 'pendiente'::public.estado_cuota end,
    avisos_pausados=v_pagada,avisos_pausados_hasta=null,
    motivo_pausa_avisos=case when v_pagada then 'Pago validado' else null end,
    avisos_pausados_por=case when v_pagada then auth.uid() else null end,
    avisos_pausados_en=case when v_pagada then now() else null end,actualizado_en=now()
  where id=v_cuota.id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos) into v_perfil,v_nombre
  from public.socios s
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=v_pago.socio_id and s.club_id=v_pago.club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_pago.club_id,v_perfil,'pago-'||v_pago.id||'-'||p_decision,'cuota',
      case when p_decision='validado' then 'Pago validado' else 'Justificante no validado' end,
      case when p_decision='validado' then v_nombre||': el pago ha sido registrado correctamente.' else v_nombre||': no se ha podido validar el justificante. '||trim(p_motivo) end,
      'fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_pago;
end; $$;
revoke all on function public.validar_pago_cuota(uuid,text,text) from public;
grant execute on function public.validar_pago_cuota(uuid,text,text) to authenticated;

-- El cobro administrativo también notifica al titular/tutor desde la misma
-- transacción. Así la UI no necesita un segundo INSERT que pueda fallar.
create or replace function public.registrar_cobro_cuota(
  p_cuota_id uuid,p_importe numeric,p_fecha date,p_metodo text,
  p_referencia text default null,p_observaciones text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas; v_pago public.pagos; v_pagado numeric; v_previo numeric; v_restante numeric; v_perfil uuid; v_nombre text; v_pagada boolean;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.tiene_rol_club(v_cuota.club_id,'direccion','secretaria','economia') then raise exception 'Sin permisos para registrar cobros'; end if;
  if coalesce(p_importe,0)<=0 then raise exception 'El importe debe ser mayor que cero'; end if;
  if p_metodo not in ('transferencia','bizum','efectivo','tarjeta','otro') then raise exception 'Método de pago no válido'; end if;
  if v_cuota.estado in ('pagada','anulada','exenta') then raise exception 'La cuota no admite cobros'; end if;
  select coalesce(sum(importe),0) into v_previo from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_restante:=greatest(v_cuota.importe-v_previo,0);
  if p_importe>v_restante+0.005 then raise exception 'El importe supera el saldo pendiente de la cuota'; end if;
  insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_por,validado_en,observaciones,comunicado_por,comunicado_en)
  values(v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,
    nullif(trim(coalesce(p_referencia,'')),''),'validado',auth.uid(),now(),nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),now())
  returning * into v_pago;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_pagada:=v_pagado>=v_cuota.importe-0.005;
  update public.cuotas set estado=case when v_pagada then 'pagada'::public.estado_cuota else 'parcialmente_pagada'::public.estado_cuota end,
    avisos_pausados=v_pagada,motivo_pausa_avisos=case when v_pagada then 'Cobro registrado' else null end,avisos_pausados_hasta=null,
    avisos_pausados_por=case when v_pagada then auth.uid() else null end,avisos_pausados_en=case when v_pagada then now() else null end,actualizado_en=now() where id=v_cuota.id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos) into v_perfil,v_nombre
  from public.socios s
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=v_cuota.socio_id and s.club_id=v_cuota.club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_cuota.club_id,v_perfil,'pago-'||v_pago.id||'-validado','cuota','Pago registrado',
      v_nombre||': el cobro ha sido registrado correctamente.','fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_pago;
end; $$;
revoke all on function public.registrar_cobro_cuota(uuid,numeric,date,text,text,text) from public;
grant execute on function public.registrar_cobro_cuota(uuid,numeric,date,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. DIAGNÓSTICO NO DESTRUCTIVO DEL BACKEND DESPLEGADO.
-- ---------------------------------------------------------------------------
create or replace function public.app_diagnostico_integridad_v152(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,storage as $$
begin
  if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo dirección puede ejecutar el diagnóstico'; end if;
  return jsonb_build_object(
    'ok',
      exists(select 1 from public.clubes where id=p_club_id and activo)
      and exists(select 1 from pg_proc where proname='app_guardar_grupo')
      and exists(select 1 from pg_proc where proname='app_guardar_socio')
      and exists(select 1 from pg_proc where proname='app_guardar_comunicacion')
      and exists(select 1 from pg_proc where proname='app_registrar_checkin')
      and exists(select 1 from pg_proc where proname='app_guardar_asistencia')
      and exists(select 1 from pg_proc where proname='app_guardar_variante_material')
      and exists(select 1 from pg_proc where proname='app_aprobar_preinscripcion')
      and exists(select 1 from pg_proc where proname='app_solicitar_nueva_matricula')
      and exists(select 1 from storage.buckets where id='club-public-media')
      and exists(select 1 from storage.buckets where id='justificantes-pago')
      and exists(select 1 from storage.buckets where id='member-documents')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert')
      and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete'),
    'club_activo',exists(select 1 from public.clubes where id=p_club_id and activo),
    'direccion_activa',exists(select 1 from public.miembros_club where club_id=p_club_id and rol='direccion' and activo),
    'indice_multigrupo',exists(select 1 from pg_indexes where schemaname='public' and indexname='uq_socio_disciplina_grupo_activa'),
    'rpc_grupos',exists(select 1 from pg_proc where proname='app_guardar_grupo'),
    'rpc_alumnos',exists(select 1 from pg_proc where proname='app_guardar_socio'),
    'rpc_publicaciones',exists(select 1 from pg_proc where proname='app_guardar_comunicacion'),
    'rpc_graduaciones',exists(select 1 from pg_proc where proname='app_registrar_graduacion'),
    'rpc_asistencia',exists(select 1 from pg_proc where proname='app_guardar_asistencia'),
    'rpc_checkin',exists(select 1 from pg_proc where proname='app_registrar_checkin'),
    'rpc_perfil',exists(select 1 from pg_proc where proname='app_guardar_perfil_propio'),
    'rpc_desactivar_matricula',exists(select 1 from pg_proc where proname='app_desactivar_matricula'),
    'rpc_material_variantes',exists(select 1 from pg_proc where proname='app_guardar_variante_material'),
    'rpc_aprobar_preinscripcion',exists(select 1 from pg_proc where proname='app_aprobar_preinscripcion'),
    'rpc_nueva_matricula',exists(select 1 from pg_proc where proname='app_solicitar_nueva_matricula'),
    'rpc_documentos',exists(select 1 from pg_proc where proname='app_registrar_documento'),
    'rpc_avisos',exists(select 1 from pg_proc where proname='app_guardar_config_avisos'),
    'bucket_public_media',exists(select 1 from storage.buckets where id='club-public-media'),
    'bucket_justificantes',exists(select 1 from storage.buckets where id='justificantes-pago'),
    'bucket_documentos',exists(select 1 from storage.buckets where id='member-documents'),
    'policy_public_media_insert',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert'),
    'policy_public_media_delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete'),
    'policy_justificantes_insert',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios'),
    'policy_justificantes_delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados'),
    'policy_documentos_insert',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert'),
    'policy_documentos_delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete')
  );
end; $$;
revoke all on function public.app_diagnostico_integridad_v152(uuid) from public;
grant execute on function public.app_diagnostico_integridad_v152(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 12. AUTOTEST TRANSACCIONAL DEL BACKEND REAL.
-- Se ejecuta desde SQL Editor. Crea datos temporales, prueba RPCs críticas y
-- los elimina. Si cualquier operación falla, PostgreSQL revierte todo el call.
-- ---------------------------------------------------------------------------
create or replace function public.app_autotest_operativo_v152(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_direction uuid;
  v_tag text := 'UW-AUTOTEST-'||substr(replace(gen_random_uuid()::text,'-',''),1,10);
  v_disc uuid; v_grade uuid; v_group uuid; v_group2 uuid; v_tariff uuid; v_member uuid; v_grad uuid; v_enrollment2 uuid;
  v_session uuid; v_material uuid; v_variant uuid; v_order uuid; v_comm uuid;
  v_pre_reject uuid; v_pre_approve uuid; v_approved_member uuid;
  v_fee uuid; v_fee2 uuid; v_payment uuid; v_payment2 uuid; v_notification uuid; v_access uuid; v_doc uuid;
  v_tracking uuid; v_attendance uuid;
  v_old_sub text;
begin
  select perfil_id into v_direction from public.miembros_club
   where club_id=p_club_id and rol='direccion' and activo order by creado_en limit 1;
  if v_direction is null then raise exception 'No existe un usuario de Dirección activo para ejecutar el autotest'; end if;
  if not exists(select 1 from storage.buckets where id='club-public-media') then raise exception 'AUTOTEST: falta bucket club-public-media'; end if;
  if not exists(select 1 from storage.buckets where id='justificantes-pago') then raise exception 'AUTOTEST: falta bucket justificantes-pago'; end if;
  if not exists(select 1 from storage.buckets where id='member-documents') then raise exception 'AUTOTEST: falta bucket member-documents'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert') then raise exception 'AUTOTEST: falta policy de subida de publicaciones'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete') then raise exception 'AUTOTEST: falta policy de borrado compensatorio de publicaciones'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios') then raise exception 'AUTOTEST: falta policy de subida de justificantes'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados') then raise exception 'AUTOTEST: falta policy de borrado compensatorio de justificantes'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert') then raise exception 'AUTOTEST: falta policy de subida de documentos'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete') then raise exception 'AUTOTEST: falta policy de borrado de documentos'; end if;
  v_old_sub := current_setting('request.jwt.claim.sub',true);
  perform set_config('request.jwt.claim.sub',v_direction::text,true);

  -- Catálogos y grupo/horarios.
  v_disc := public.app_guardar_disciplina(p_club_id,null,v_tag||'-DISC','Prueba temporal','#ffffff',true,999);
  v_grade := public.app_guardar_grado(p_club_id,null,v_disc,v_tag||'-GRADO',999,'#ffffff',0,true);
  v_group := public.app_guardar_grupo(p_club_id,null,v_disc,v_tag||'-GRUPO','Autotest','Sala test',16,60,20,true,
    '[{"dia_semana":2,"hora_inicio":"18:00","hora_fin":"19:00"},{"dia_semana":4,"hora_inicio":"18:00","hora_fin":"19:00"}]'::jsonb);
  if (select count(*) from public.horarios_grupo where grupo_id=v_group)<>2 then raise exception 'AUTOTEST: horarios no guardados'; end if;
  v_group2 := public.app_guardar_grupo(p_club_id,null,v_disc,v_tag||'-GRUPO-2','Autotest','Sala test',16,60,20,true,'[]'::jsonb);
  v_tariff := public.app_guardar_tarifa(p_club_id,null,v_tag||'-TARIFA','Prueba temporal',1,0,'mensual',true);

  -- Alumno + multigrupo + baja de una matrícula + graduación.
  v_member := public.app_guardar_socio(p_club_id,null,'Autotest','Alumno',date '2000-01-01','600000000',v_tag||'@invalid.local','',v_disc,v_group,null,'',v_tariff,'activo','','','Temporal');
  if not exists(select 1 from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and grupo_id=v_group and activa) then raise exception 'AUTOTEST: matrícula no guardada'; end if;
  perform public.app_guardar_socio(p_club_id,v_member,'Autotest','Alumno',date '2000-01-01','600000000',v_tag||'@invalid.local','',v_disc,v_group2,null,'',v_tariff,'activo','','','Temporal');
  if (select count(*) from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and activa)<>2 then raise exception 'AUTOTEST: multigrupo no conservó ambas matrículas'; end if;
  select id into v_enrollment2 from public.socio_disciplinas where socio_id=v_member and grupo_id=v_group2 and activa limit 1;
  perform public.app_desactivar_matricula(v_enrollment2);
  if exists(select 1 from public.socio_disciplinas where id=v_enrollment2 and activa) or not exists(select 1 from public.socio_disciplinas where socio_id=v_member and grupo_id=v_group and activa) then raise exception 'AUTOTEST: baja de matrícula afectó a otras matrículas'; end if;
  v_grad := public.app_registrar_graduacion(p_club_id,v_member,v_disc,v_grade,current_date,'Autotest','Temporal');
  if not exists(select 1 from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and grado_id=v_grade and activa) then raise exception 'AUTOTEST: graduación no aplicada'; end if;

  -- Sesión + asistencia servidor.
  v_session := public.app_guardar_sesion(p_club_id,null,v_group,current_date,'18:00','19:00','Autotest','programada','Temporal',v_tag);
  insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
  values(p_club_id,v_direction,v_member,'Autotest',true) on conflict(club_id,tutor_perfil_id,socio_id) do nothing;
  v_access := public.app_registrar_checkin(v_session,v_member,v_tag,'codigo');
  if not exists(select 1 from public.registros_acceso_clase where id=v_access and resultado='permitido') then raise exception 'AUTOTEST: check-in no guardado'; end if;
  v_attendance := public.app_guardar_asistencia(v_session,v_member,'presente','Temporal');
  if not exists(select 1 from public.asistencias where id=v_attendance and estado='presente') then raise exception 'AUTOTEST: asistencia no guardada'; end if;

  -- Publicación inmediata y notificación.
  v_comm := public.app_guardar_comunicacion(p_club_id,null,'noticia',v_tag||'-PUBLICACION','Contenido temporal','todos','publicada',null,'','');
  if not exists(select 1 from public.comunicaciones where id=v_comm and estado='publicada' and notificada_en is not null) then raise exception 'AUTOTEST: publicación no guardada/notificada'; end if;

  -- Material + variante + pedido.
  v_material := public.app_guardar_material(p_club_id,null,v_disc,v_tag||'-MATERIAL','test','Temporal','',1,2,false,v_tag,true);
  v_variant := public.app_guardar_variante_material(p_club_id,null,v_material,'M','',v_tag,2,true);
  v_order := public.app_solicitar_material(v_member,v_material,v_variant,1,'Temporal');
  if not exists(select 1 from public.material_pedidos where id=v_order and estado='reservado') then raise exception 'AUTOTEST: pedido de material no guardado'; end if;

  -- Seguimiento.
  v_tracking := public.app_guardar_seguimiento(p_club_id,v_member,'tecnico','Temporal','equipo',current_date);
  if not exists(select 1 from public.seguimiento where id=v_tracking) then raise exception 'AUTOTEST: seguimiento no guardado'; end if;

  -- Preinscripción: rechazo y aprobación.
  v_pre_reject := public.app_crear_preinscripcion(p_club_id,'menor','Autotest','Rechazo',date '2012-01-01','Tutor Autotest',v_tag||'@invalid.local','600000001',v_disc,v_group,v_tariff,'Tutor','Temporal');
  perform public.app_rechazar_preinscripcion(v_pre_reject,'Autotest');
  if not exists(select 1 from public.preinscripciones where id=v_pre_reject and estado='rechazada') then raise exception 'AUTOTEST: rechazo no aplicado'; end if;
  v_pre_approve := public.app_crear_preinscripcion(p_club_id,'menor','Autotest','Aprobacion',date '2011-01-01','Tutor Autotest',v_tag||'@invalid.local','600000002',v_disc,v_group,v_tariff,'Tutor','Temporal');
  v_approved_member := public.app_aprobar_preinscripcion(v_pre_approve);
  if v_approved_member is null or not exists(select 1 from public.preinscripciones where id=v_pre_approve and estado='aprobada') then raise exception 'AUTOTEST: aprobación no aplicada'; end if;

  -- Cuota + pago comunicado + validación, y cobro administrativo.
  insert into public.cuotas(club_id,socio_id,tarifa_id,periodo,concepto,importe,vencimiento)
  values(p_club_id,v_member,v_tariff,date_trunc('month',current_date)::date,v_tag||'-CUOTA-USUARIO',1,current_date+7) returning id into v_fee;
  v_payment := (public.comunicar_pago_cuota(v_fee,1,current_date,'bizum',v_tag,'test/path.pdf','Temporal')).id;
  if not exists(select 1 from public.cuotas where id=v_fee and estado='pendiente_validacion' and avisos_pausados) then raise exception 'AUTOTEST: pago comunicado no pausó avisos'; end if;
  perform public.validar_pago_cuota(v_payment,'validado',null);
  if not exists(select 1 from public.cuotas where id=v_fee and estado='pagada') then raise exception 'AUTOTEST: validación de pago no actualizó cuota'; end if;
  insert into public.cuotas(club_id,socio_id,tarifa_id,periodo,concepto,importe,vencimiento)
  values(p_club_id,v_member,v_tariff,date_trunc('month',current_date)::date,v_tag||'-CUOTA-ADMIN',1,current_date+7) returning id into v_fee2;
  v_payment2 := (public.registrar_cobro_cuota(v_fee2,1,current_date,'efectivo',v_tag,'Temporal')).id;
  if not exists(select 1 from public.cuotas where id=v_fee2 and estado='pagada') then raise exception 'AUTOTEST: cobro administrativo no actualizó cuota'; end if;

  -- Notificación y lectura.
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,creada_por)
  values(p_club_id,v_direction,v_tag||'-NOTIF','sistema','Autotest','Temporal','notifications',v_direction) returning id into v_notification;
  perform public.app_marcar_notificacion_leida(v_notification);
  if not exists(select 1 from public.notificaciones_lecturas where notificacion_id=v_notification and perfil_id=v_direction) then raise exception 'AUTOTEST: notificación no marcada como leída'; end if;

  -- Documento (solo metadato; Storage binario se comprueba con bucket/policy).
  v_doc := public.app_registrar_documento(p_club_id,v_member,v_tag||'.pdf','otro',p_club_id||'/'||v_member||'/'||v_tag||'.pdf','application/pdf',1,true);
  if not exists(select 1 from public.documentos_socios where id=v_doc) then raise exception 'AUTOTEST: documento no registrado'; end if;

  -- Limpieza explícita del caso exitoso. En caso de error, toda la llamada se revierte.
  delete from public.notificaciones_lecturas where notificacion_id=v_notification;
  delete from public.notificaciones where id=v_notification
     or clave in ('comunicacion-'||v_comm||'-todos','pedido-material-'||v_order||'-direccion','pedido-material-'||v_order||'-secretaria','pedido-material-'||v_order||'-economia')
     or clave like 'preinscripcion-'||v_pre_reject||'-%' or clave like 'preinscripcion-'||v_pre_approve||'-%'
     or clave like 'pago-pendiente-'||v_payment||'-%'
     or clave like 'pago-'||v_payment||'-%'
     or clave like 'pago-'||v_payment2||'-%'
     or clave='graduacion-'||v_grad;
  delete from public.documentos_socios where id=v_doc;
  delete from public.pagos where id in (v_payment,v_payment2);
  delete from public.cuotas where id in (v_fee,v_fee2);
  delete from public.preinscripciones where id in (v_pre_reject,v_pre_approve);
  delete from public.seguimiento where id=v_tracking;
  delete from public.material_pedidos where id=v_order;
  delete from public.material_variantes where id=v_variant;
  delete from public.material_catalogo where id=v_material;
  delete from public.asistencias where id=v_attendance;
  delete from public.registros_acceso_clase where sesion_id=v_session and socio_id=v_member;
  delete from public.sesiones_entrenamiento where id=v_session;
  delete from public.graduaciones where id=v_grad;
  delete from public.socio_disciplinas where socio_id in (v_member,v_approved_member);
  delete from public.tutores_socios where socio_id in (v_member,v_approved_member);
  delete from public.socios where id in (v_member,v_approved_member);
  delete from public.comunicaciones where id=v_comm;
  delete from public.horarios_grupo where grupo_id=v_group;
  delete from public.grupos where id in (v_group,v_group2);
  delete from public.grados where id=v_grade;
  delete from public.disciplinas where id=v_disc;
  delete from public.tarifas where id=v_tariff;

  if v_old_sub is not null then perform set_config('request.jwt.claim.sub',v_old_sub,true); end if;
  return jsonb_build_object(
    'ok',true,
    'version','1.5.2',
    'probado',jsonb_build_array('disciplina','grado','grupo','dos_horarios','alumno','matricula','multigrupo','baja_matricula','graduacion','sesion','checkin','asistencia','publicacion','notificacion_publicacion','material','variante','pedido_material','seguimiento','preinscripcion_rechazo','preinscripcion_aprobacion','cuota','pago_comunicado','validacion_pago','cobro_admin','notificacion_lectura','documento_metadato'),
    'storage',jsonb_build_object(
      'club-public-media',exists(select 1 from storage.buckets where id='club-public-media'),
      'justificantes-pago',exists(select 1 from storage.buckets where id='justificantes-pago'),
      'member-documents',exists(select 1 from storage.buckets where id='member-documents'),
      'public-media-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete'),
      'justificantes-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados'),
      'documentos-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete')
    )
  );
end; $$;
revoke all on function public.app_autotest_operativo_v152(uuid) from public,anon,authenticated;
grant execute on function public.app_autotest_operativo_v152(uuid) to service_role,postgres;

notify pgrst, 'reload schema';
