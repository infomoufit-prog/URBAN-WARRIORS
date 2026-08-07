-- ============================================================================
-- URBAN WARRIORS · VERSIÓN 1.3.0 OPERATIVA
-- Operaciones transaccionales, invitaciones, documentos y soporte de app.
-- Aplicar DESPUÉS de 006_production_runtime_fixes.sql.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. INVITACIONES PARA PERSONAL DEL CLUB
-- ---------------------------------------------------------------------------
create table if not exists public.invitaciones_club (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  email text not null,
  rol public.rol_club not null,
  token uuid not null default gen_random_uuid() unique,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','aceptada','revocada','caducada')),
  invitado_por uuid not null references public.perfiles(id),
  aceptado_por uuid references public.perfiles(id),
  expira_en timestamptz not null default (now() + interval '7 days'),
  creado_en timestamptz not null default now(),
  aceptado_en timestamptz,
  check (rol in ('direccion','secretaria','economia','comunicacion','monitor'))
);
create unique index if not exists invitaciones_pendientes_email_club
  on public.invitaciones_club(club_id, lower(email))
  where estado = 'pendiente';
create index if not exists invitaciones_token on public.invitaciones_club(token);

alter table public.invitaciones_club enable row level security;
drop policy if exists invitaciones_lectura on public.invitaciones_club;
create policy invitaciones_lectura on public.invitaciones_club for select to authenticated
using (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or (lower(email) = lower(coalesce(auth.jwt()->>'email','')) and estado='pendiente')
);
drop policy if exists invitaciones_gestion on public.invitaciones_club;
create policy invitaciones_gestion on public.invitaciones_club for all to authenticated
using (public.tiene_rol_club(club_id,'direccion'))
with check (public.tiene_rol_club(club_id,'direccion'));

create or replace function public.crear_invitacion_club(
  p_club_id uuid,
  p_email text,
  p_rol public.rol_club
) returns public.invitaciones_club
language plpgsql security definer set search_path = public, auth
as $$
declare v_row public.invitaciones_club;
begin
  if not public.tiene_rol_club(p_club_id,'direccion') then
    raise exception 'Solo dirección puede invitar personal';
  end if;
  if p_rol not in ('direccion','secretaria','economia','comunicacion','monitor') then
    raise exception 'Rol de invitación no permitido';
  end if;
  if nullif(trim(p_email),'') is null then raise exception 'El correo es obligatorio'; end if;

  update public.invitaciones_club
     set estado='revocada'
   where club_id=p_club_id and lower(email)=lower(trim(p_email)) and estado='pendiente';

  insert into public.invitaciones_club(club_id,email,rol,invitado_por)
  values (p_club_id,lower(trim(p_email)),p_rol,auth.uid())
  returning * into v_row;
  return v_row;
end; $$;
revoke all on function public.crear_invitacion_club(uuid,text,public.rol_club) from public;
grant execute on function public.crear_invitacion_club(uuid,text,public.rol_club) to authenticated;

create or replace function public.aceptar_invitacion_club(p_token uuid)
returns jsonb language plpgsql security definer set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt()->>'email',''));
  v_inv public.invitaciones_club;
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_inv from public.invitaciones_club
   where token=p_token and estado='pendiente' for update;
  if v_inv.id is null then raise exception 'Invitación no válida'; end if;
  if v_inv.expira_en < now() then
    update public.invitaciones_club set estado='caducada' where id=v_inv.id;
    raise exception 'La invitación ha caducado';
  end if;
  if lower(v_inv.email) <> v_email then raise exception 'La invitación pertenece a otro correo'; end if;

  insert into public.perfiles(id,nombre,apellidos)
  values (v_uid,coalesce(auth.jwt()->'user_metadata'->>'nombre',''),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;

  insert into public.miembros_club(club_id,perfil_id,rol,activo)
  values(v_inv.club_id,v_uid,v_inv.rol,true)
  on conflict(club_id,perfil_id,rol) do update set activo=true;

  update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now()
  where id=v_inv.id;
  return jsonb_build_object('club_id',v_inv.club_id,'rol',v_inv.rol,'estado','aceptada');
end; $$;
revoke all on function public.aceptar_invitacion_club(uuid) from public;
grant execute on function public.aceptar_invitacion_club(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. DOCUMENTOS DE SOCIOS Y FAMILIAS
-- ---------------------------------------------------------------------------
create table if not exists public.documentos_socios (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  nombre text not null,
  tipo text not null default 'otro',
  storage_path text not null,
  mime_type text,
  tamano_bytes bigint,
  visible_familia boolean not null default true,
  subido_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  foreign key (club_id,socio_id) references public.socios(club_id,id) on delete cascade
);
create index if not exists documentos_socios_club_socio on public.documentos_socios(club_id,socio_id,creado_en desc);
alter table public.documentos_socios enable row level security;
drop policy if exists documentos_socios_lectura on public.documentos_socios;
create policy documentos_socios_lectura on public.documentos_socios for select to authenticated
using (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or (visible_familia and public.puede_ver_socio(socio_id))
);
drop policy if exists documentos_socios_insertar on public.documentos_socios;
create policy documentos_socios_insertar on public.documentos_socios for insert to authenticated
with check (
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or public.puede_ver_socio(socio_id)
);
drop policy if exists documentos_socios_gestion on public.documentos_socios;
create policy documentos_socios_gestion on public.documentos_socios for update to authenticated
using (public.tiene_rol_club(club_id,'direccion','secretaria'))
with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
drop policy if exists documentos_socios_borrar on public.documentos_socios;
create policy documentos_socios_borrar on public.documentos_socios for delete to authenticated
using (public.tiene_rol_club(club_id,'direccion','secretaria'));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'member-documents','member-documents',false,10485760,
  array['image/jpeg','image/png','image/webp','application/pdf']
)
on conflict(id) do update set
  public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists member_documents_read on storage.objects;
create policy member_documents_read on storage.objects for select to authenticated
using (
  bucket_id='member-documents'
  and array_length(storage.foldername(name),1) >= 2
  and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_ver_socio(((storage.foldername(name))[2])::uuid)
  )
);
drop policy if exists member_documents_insert on storage.objects;
create policy member_documents_insert on storage.objects for insert to authenticated
with check (
  bucket_id='member-documents'
  and array_length(storage.foldername(name),1) >= 2
  and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_ver_socio(((storage.foldername(name))[2])::uuid)
  )
);
drop policy if exists member_documents_delete on storage.objects;
create policy member_documents_delete on storage.objects for delete to authenticated
using (
  bucket_id='member-documents'
  and public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
);

-- Lectura individual de notificaciones compartidas por rol o audiencia.
create table if not exists public.notificaciones_lecturas (
  notificacion_id uuid not null references public.notificaciones(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  leida_en timestamptz not null default now(),
  primary key(notificacion_id,perfil_id)
);
alter table public.notificaciones_lecturas enable row level security;
drop policy if exists notificaciones_lecturas_propias on public.notificaciones_lecturas;
create policy notificaciones_lecturas_propias on public.notificaciones_lecturas for select to authenticated
using(perfil_id=auth.uid());
drop policy if exists notificaciones_lecturas_insertar on public.notificaciones_lecturas;
create policy notificaciones_lecturas_insertar on public.notificaciones_lecturas for insert to authenticated
with check(perfil_id=auth.uid());

create or replace function public.app_marcar_notificacion_leida(p_notificacion_id uuid)
returns void language plpgsql security definer set search_path=public,auth
as $$
declare v_row public.notificaciones; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_row from public.notificaciones where id=p_notificacion_id;
  if v_row.id is null then raise exception 'Notificación no encontrada'; end if;
  if not (
    v_row.perfil_id=v_uid
    or (v_row.rol_destino is not null and public.tiene_rol_club(v_row.club_id,v_row.rol_destino))
    or (v_row.audiencia='todos' and public.es_miembro_club(v_row.club_id))
  ) then raise exception 'No tienes acceso a esta notificación'; end if;
  if v_row.perfil_id=v_uid then
    update public.notificaciones set leida=true,leida_en=now() where id=v_row.id;
  else
    insert into public.notificaciones_lecturas(notificacion_id,perfil_id) values(v_row.id,v_uid)
    on conflict(notificacion_id,perfil_id) do update set leida_en=now();
  end if;
end; $$;
revoke all on function public.app_marcar_notificacion_leida(uuid) from public;
grant execute on function public.app_marcar_notificacion_leida(uuid) to authenticated;

-- Publicaciones notificables una sola vez.
alter table public.comunicaciones add column if not exists notificada_en timestamptz;

-- ---------------------------------------------------------------------------
-- 3. OPERACIONES TRANSACCIONALES USADAS POR WEB Y APK
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
declare v_id uuid; v_h jsonb;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para gestionar grupos'; end if;
  if not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id) then raise exception 'La disciplina no pertenece al club'; end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre del grupo es obligatorio'; end if;
  if p_edad_min is not null and p_edad_max is not null and p_edad_min > p_edad_max then raise exception 'La edad mínima no puede superar la máxima'; end if;

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
    if nullif(v_h->>'dia_semana','') is not null and nullif(v_h->>'hora_inicio','') is not null and nullif(v_h->>'hora_fin','') is not null then
      insert into public.horarios_grupo(club_id,grupo_id,dia_semana,hora_inicio,hora_fin)
      values(p_club_id,v_id,(v_h->>'dia_semana')::smallint,(v_h->>'hora_inicio')::time,(v_h->>'hora_fin')::time);
    end if;
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
declare v_id uuid; v_link uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para gestionar alumnos'; end if;
  if nullif(trim(p_nombre),'') is null or nullif(trim(p_apellidos),'') is null then raise exception 'Nombre y apellidos son obligatorios'; end if;
  if p_disciplina_id is not null and not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id) then raise exception 'Disciplina no válida'; end if;
  if p_grupo_id is not null and not exists(select 1 from public.grupos where id=p_grupo_id and club_id=p_club_id and disciplina_id=p_disciplina_id) then raise exception 'El grupo no pertenece a la disciplina seleccionada'; end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=p_club_id) then raise exception 'Tarifa no válida'; end if;
  if p_grado_id is not null and not exists(select 1 from public.grados where id=p_grado_id and club_id=p_club_id and disciplina_id=p_disciplina_id) then raise exception 'El grado no pertenece a la disciplina'; end if;

  if p_id is null then
    insert into public.socios(club_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,grado_texto,tarifa_id,estado,contacto_emergencia,telefono_emergencia,notas_internas)
    values(p_club_id,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,nullif(trim(p_telefono),''),nullif(trim(p_email),''),nullif(trim(p_tutor_nombre),''),nullif(trim(p_grado_texto),''),p_tarifa_id,p_estado,nullif(trim(p_contacto_emergencia),''),nullif(trim(p_telefono_emergencia),''),nullif(trim(p_notas_internas),''))
    returning id into v_id;
  else
    update public.socios set nombre=trim(p_nombre),apellidos=trim(p_apellidos),fecha_nacimiento=p_fecha_nacimiento,
      telefono=nullif(trim(p_telefono),''),email=nullif(trim(p_email),''),tutor_nombre=nullif(trim(p_tutor_nombre),''),
      grado_texto=nullif(trim(p_grado_texto),''),tarifa_id=p_tarifa_id,estado=p_estado,
      contacto_emergencia=nullif(trim(p_contacto_emergencia),''),telefono_emergencia=nullif(trim(p_telefono_emergencia),''),
      notas_internas=nullif(trim(p_notas_internas),''),actualizado_en=now()
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Alumno no encontrado'; end if;
  end if;

  if p_disciplina_id is null then
    update public.socio_disciplinas set activa=false,fecha_fin=current_date where club_id=p_club_id and socio_id=v_id and activa;
  else
    -- La interfaz gestiona una matrícula principal; se mantiene el histórico de las anteriores.
    update public.socio_disciplinas set activa=false,fecha_fin=current_date
     where club_id=p_club_id and socio_id=v_id and disciplina_id<>p_disciplina_id and activa;
    insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,grado_id,activa,fecha_inicio,fecha_fin)
    values(p_club_id,v_id,p_disciplina_id,p_grupo_id,p_grado_id,true,current_date,null)
    on conflict(club_id,socio_id,disciplina_id) do update set
      grupo_id=excluded.grupo_id,grado_id=excluded.grado_id,activa=true,fecha_fin=null;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) from public;
grant execute on function public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text) to authenticated;

create or replace function public.app_aprobar_preinscripcion(p_preinscripcion_id uuid)
returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare p public.preinscripciones; v_socio uuid;
begin
  select * into p from public.preinscripciones where id=p_preinscripcion_id for update;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;

  select id into v_socio from public.socios
   where club_id=p.club_id and estado='prealta'
     and lower(nombre)=lower(p.nombre) and lower(apellidos)=lower(p.apellidos)
     and (perfil_id=p.solicitante_perfil_id or p.solicitante_perfil_id is null)
   order by creado_en desc limit 1;

  if v_socio is null then
    insert into public.socios(club_id,perfil_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,tarifa_id,estado)
    values(p.club_id,case when p.tipo_solicitud='adulto' then p.solicitante_perfil_id else null end,p.nombre,p.apellidos,p.fecha_nacimiento,p.telefono,p.tutor_email,p.tutor_nombre,p.tarifa_id,'activo')
    returning id into v_socio;
  else
    update public.socios set estado='activo',tarifa_id=p.tarifa_id,actualizado_en=now() where id=v_socio;
  end if;

  if p.disciplina_id is not null then
    insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grupo_id,activa)
    values(p.club_id,v_socio,p.disciplina_id,p.grupo_id,true)
    on conflict(club_id,socio_id,disciplina_id) do update set grupo_id=excluded.grupo_id,activa=true,fecha_fin=null;
  end if;
  if p.tipo_solicitud='menor' and p.solicitante_perfil_id is not null then
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(p.club_id,p.solicitante_perfil_id,v_socio,coalesce(p.parentesco,'Tutor/a responsable'),true)
    on conflict(club_id,tutor_perfil_id,socio_id) do update set contacto_principal=true;
  end if;
  update public.preinscripciones set estado='aprobada',revisada_por=auth.uid(),revisada_en=now() where id=p.id;
  if p.solicitante_perfil_id is not null then
    insert into public.notificaciones(club_id,perfil_id,tipo,titulo,cuerpo,ruta,leida,creada_por)
    values(p.club_id,p.solicitante_perfil_id,'inscripcion','Inscripción aprobada',p.nombre||' ya tiene la plaza confirmada.','home',false,auth.uid());
  end if;
  return v_socio;
end; $$;
revoke all on function public.app_aprobar_preinscripcion(uuid) from public;
grant execute on function public.app_aprobar_preinscripcion(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 4. RPCS OPERATIVAS PARA TODOS LOS FORMULARIOS PRINCIPALES
-- ---------------------------------------------------------------------------
create or replace function public.app_guardar_disciplina(
  p_club_id uuid, p_id uuid, p_nombre text, p_descripcion text,
  p_color text, p_activa boolean, p_orden smallint
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para gestionar disciplinas'; end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre de la disciplina es obligatorio'; end if;
  if p_id is null then
    insert into public.disciplinas(club_id,nombre,descripcion,color,activa,orden)
    values(p_club_id,trim(p_nombre),nullif(trim(p_descripcion),''),coalesce(nullif(trim(p_color),''),'#ffffff'),coalesce(p_activa,true),coalesce(p_orden,0))
    returning id into v_id;
  else
    update public.disciplinas set nombre=trim(p_nombre),descripcion=nullif(trim(p_descripcion),''),
      color=coalesce(nullif(trim(p_color),''),'#ffffff'),activa=coalesce(p_activa,true),orden=coalesce(p_orden,orden)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Disciplina no encontrada'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint) from public;
grant execute on function public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint) to authenticated;

create or replace function public.app_guardar_grado(
  p_club_id uuid, p_id uuid, p_disciplina_id uuid, p_nombre text,
  p_orden smallint, p_color text, p_meses_minimos smallint, p_activo boolean
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para gestionar grados'; end if;
  if not exists(select 1 from public.disciplinas where club_id=p_club_id and id=p_disciplina_id) then raise exception 'Disciplina no válida'; end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre del grado es obligatorio'; end if;
  if p_id is null then
    insert into public.grados(club_id,disciplina_id,nombre,orden,color,meses_minimos,activo)
    values(p_club_id,p_disciplina_id,trim(p_nombre),coalesce(p_orden,1),nullif(trim(p_color),''),p_meses_minimos,coalesce(p_activo,true))
    returning id into v_id;
  else
    update public.grados set disciplina_id=p_disciplina_id,nombre=trim(p_nombre),orden=coalesce(p_orden,orden),
      color=nullif(trim(p_color),''),meses_minimos=p_meses_minimos,activo=coalesce(p_activo,true)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Grado no encontrado'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_grado(uuid,uuid,uuid,text,smallint,text,smallint,boolean) from public;
grant execute on function public.app_guardar_grado(uuid,uuid,uuid,text,smallint,text,smallint,boolean) to authenticated;

create or replace function public.app_registrar_graduacion(
  p_club_id uuid, p_socio_id uuid, p_disciplina_id uuid, p_grado_id uuid,
  p_fecha date, p_examinador text, p_nota text
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid; v_anterior uuid; v_perfil uuid; v_alumno text; v_grado text;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para registrar graduaciones'; end if;
  if not exists(select 1 from public.socios where club_id=p_club_id and id=p_socio_id) then raise exception 'Alumno no válido'; end if;
  if not exists(select 1 from public.grados where club_id=p_club_id and id=p_grado_id and disciplina_id=p_disciplina_id) then raise exception 'El grado no pertenece a la disciplina'; end if;
  select grado_id into v_anterior from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id;
  insert into public.graduaciones(club_id,socio_id,disciplina_id,grado_id,grado_anterior_id,fecha,examinador,nota,registrado_por)
  values(p_club_id,p_socio_id,p_disciplina_id,p_grado_id,v_anterior,coalesce(p_fecha,current_date),nullif(trim(p_examinador),''),nullif(trim(p_nota),''),auth.uid())
  returning id into v_id;
  insert into public.socio_disciplinas(club_id,socio_id,disciplina_id,grado_id,activa)
  values(p_club_id,p_socio_id,p_disciplina_id,p_grado_id,true)
  on conflict(club_id,socio_id,disciplina_id) do update set grado_id=excluded.grado_id,activa=true,fecha_fin=null;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos),g.nombre into v_perfil,v_alumno,v_grado
  from public.socios s
  join public.grados g on g.id=p_grado_id and g.club_id=s.club_id
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=p_socio_id and s.club_id=p_club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p_club_id,v_perfil,'graduacion-'||v_id,'graduacion','Nuevo grado registrado',v_alumno||' ha alcanzado '||v_grado||'.','profile',jsonb_build_object('graduacion_id',v_id,'socio_id',p_socio_id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) from public;
grant execute on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) to authenticated;

create or replace function public.app_guardar_tarifa(
  p_club_id uuid, p_id uuid, p_nombre text, p_descripcion text,
  p_importe numeric, p_matricula numeric, p_periodicidad text, p_activa boolean
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','economia') then raise exception 'No tienes permiso para gestionar tarifas'; end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre de la tarifa es obligatorio'; end if;
  if coalesce(p_importe,0) < 0 or coalesce(p_matricula,0) < 0 then raise exception 'Los importes no pueden ser negativos'; end if;
  if p_id is null then
    insert into public.tarifas(club_id,nombre,descripcion,importe,matricula,periodicidad,activa,actualizada_por)
    values(p_club_id,trim(p_nombre),nullif(trim(p_descripcion),''),coalesce(p_importe,0),coalesce(p_matricula,0),coalesce(nullif(trim(p_periodicidad),''),'mensual'),coalesce(p_activa,true),auth.uid())
    returning id into v_id;
  else
    update public.tarifas set nombre=trim(p_nombre),descripcion=nullif(trim(p_descripcion),''),importe=coalesce(p_importe,0),
      matricula=coalesce(p_matricula,0),periodicidad=coalesce(nullif(trim(p_periodicidad),''),'mensual'),activa=coalesce(p_activa,true),
      actualizada_en=now(),actualizada_por=auth.uid()
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Tarifa no encontrada'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_tarifa(uuid,uuid,text,text,numeric,numeric,text,boolean) from public;
grant execute on function public.app_guardar_tarifa(uuid,uuid,text,text,numeric,numeric,text,boolean) to authenticated;

create or replace function public.app_guardar_material(
  p_club_id uuid, p_id uuid, p_disciplina_id uuid, p_nombre text,
  p_categoria text, p_descripcion text, p_imagen_url text, p_precio numeric,
  p_stock integer, p_obligatorio boolean, p_referencia text, p_activo boolean
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','economia','secretaria') then raise exception 'No tienes permiso para gestionar material'; end if;
  if p_disciplina_id is not null and not exists(select 1 from public.disciplinas where club_id=p_club_id and id=p_disciplina_id) then raise exception 'Disciplina no válida'; end if;
  if nullif(trim(p_nombre),'') is null then raise exception 'El nombre del material es obligatorio'; end if;
  if coalesce(p_precio,0) < 0 or coalesce(p_stock,0) < 0 then raise exception 'Precio y stock no pueden ser negativos'; end if;
  if p_id is null then
    insert into public.material_catalogo(club_id,disciplina_id,nombre,categoria,descripcion,imagen_url,precio,stock,obligatorio,referencia,activo)
    values(p_club_id,p_disciplina_id,trim(p_nombre),nullif(trim(p_categoria),''),nullif(trim(p_descripcion),''),nullif(trim(p_imagen_url),''),coalesce(p_precio,0),coalesce(p_stock,0),coalesce(p_obligatorio,false),nullif(trim(p_referencia),''),coalesce(p_activo,true))
    returning id into v_id;
  else
    update public.material_catalogo set disciplina_id=p_disciplina_id,nombre=trim(p_nombre),categoria=nullif(trim(p_categoria),''),
      descripcion=nullif(trim(p_descripcion),''),imagen_url=nullif(trim(p_imagen_url),''),precio=coalesce(p_precio,0),stock=coalesce(p_stock,0),
      obligatorio=coalesce(p_obligatorio,false),referencia=nullif(trim(p_referencia),''),activo=coalesce(p_activo,true)
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Material no encontrado'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_material(uuid,uuid,uuid,text,text,text,text,numeric,integer,boolean,text,boolean) from public;
grant execute on function public.app_guardar_material(uuid,uuid,uuid,text,text,text,text,numeric,integer,boolean,text,boolean) to authenticated;

create or replace function public.app_guardar_comunicacion(
  p_club_id uuid, p_id uuid, p_tipo text, p_titulo text, p_cuerpo text,
  p_audiencia text, p_estado text, p_evento_fecha timestamptz,
  p_ubicacion text, p_imagen_url text
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid; v_notificada timestamptz;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','comunicacion') then raise exception 'No tienes permiso para gestionar publicaciones'; end if;
  if p_tipo not in ('noticia','evento','clase','cartel') then raise exception 'Tipo de publicación no válido'; end if;
  if p_estado not in ('borrador','programada','publicada','archivada') then raise exception 'Estado no válido'; end if;
  if p_audiencia not in ('todos','familias','monitores') then raise exception 'Audiencia no válida'; end if;
  if nullif(trim(p_titulo),'') is null or nullif(trim(p_cuerpo),'') is null then raise exception 'Título y texto son obligatorios'; end if;
  if p_estado='programada' and p_evento_fecha is null then raise exception 'Indica la fecha de publicación o del evento'; end if;

  if p_id is null then
    insert into public.comunicaciones(club_id,tipo,titulo,cuerpo,audiencia,estado,evento_fecha,ubicacion,imagen_url,programada_para,publicada_en,creada_por)
    values(p_club_id,p_tipo,trim(p_titulo),trim(p_cuerpo),p_audiencia,p_estado,p_evento_fecha,nullif(trim(p_ubicacion),''),nullif(trim(p_imagen_url),''),case when p_estado='programada' then p_evento_fecha else null end,case when p_estado='publicada' then now() else null end,auth.uid())
    returning id,notificada_en into v_id,v_notificada;
  else
    update public.comunicaciones set tipo=p_tipo,titulo=trim(p_titulo),cuerpo=trim(p_cuerpo),audiencia=p_audiencia,estado=p_estado,
      evento_fecha=p_evento_fecha,ubicacion=nullif(trim(p_ubicacion),''),imagen_url=nullif(trim(p_imagen_url),''),
      programada_para=case when p_estado='programada' then p_evento_fecha else null end,
      publicada_en=case when p_estado='publicada' then coalesce(publicada_en,now()) else publicada_en end,
      notificada_en=notificada_en
    where id=p_id and club_id=p_club_id returning id,notificada_en into v_id,v_notificada;
    if v_id is null then raise exception 'Publicación no encontrada'; end if;
  end if;

  -- Una publicación inmediata genera las notificaciones internas desde el servidor.
  if p_estado='publicada' and v_notificada is null then
    if p_audiencia='todos' then
      insert into public.notificaciones(club_id,audiencia,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values(p_club_id,'todos','comunicacion-'||v_id||'-todos',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid());
    elsif p_audiencia='monitores' then
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values(p_club_id,'monitor','comunicacion-'||v_id||'-monitor',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid());
    else
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      values
        (p_club_id,'familia','comunicacion-'||v_id||'-familia',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid()),
        (p_club_id,'alumno','comunicacion-'||v_id||'-alumno',case when p_tipo='evento' then 'evento' else 'comunicacion' end,trim(p_titulo),trim(p_cuerpo),'communications',jsonb_build_object('comunicacion_id',v_id),auth.uid());
    end if;
    update public.comunicaciones set notificada_en=now() where id=v_id;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) from public;
grant execute on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) to authenticated;

create or replace function public.app_guardar_sesion(
  p_club_id uuid, p_id uuid, p_grupo_id uuid, p_fecha date,
  p_hora_inicio time, p_hora_fin time, p_monitor_nombre text,
  p_estado text, p_observacion_general text, p_codigo_acceso text
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_id uuid;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para gestionar sesiones'; end if;
  if not exists(select 1 from public.grupos where club_id=p_club_id and id=p_grupo_id) then raise exception 'Grupo no válido'; end if;
  if p_fecha is null or p_hora_inicio is null then raise exception 'Fecha y hora de inicio son obligatorias'; end if;
  if p_hora_fin is not null and p_hora_fin <= p_hora_inicio then raise exception 'La hora de fin debe ser posterior'; end if;
  if p_estado not in ('programada','en_curso','completada','cancelada') then raise exception 'Estado de sesión no válido'; end if;
  if p_id is null then
    insert into public.sesiones_entrenamiento(club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado,observacion_general,codigo_acceso)
    values(p_club_id,p_grupo_id,p_fecha,p_hora_inicio,p_hora_fin,nullif(trim(p_monitor_nombre),''),p_estado,nullif(trim(p_observacion_general),''),nullif(trim(p_codigo_acceso),''))
    returning id into v_id;
  else
    update public.sesiones_entrenamiento set grupo_id=p_grupo_id,fecha=p_fecha,hora_inicio=p_hora_inicio,hora_fin=p_hora_fin,
      monitor_nombre=nullif(trim(p_monitor_nombre),''),estado=p_estado,observacion_general=nullif(trim(p_observacion_general),''),codigo_acceso=nullif(trim(p_codigo_acceso),'')
    where id=p_id and club_id=p_club_id returning id into v_id;
    if v_id is null then raise exception 'Sesión no encontrada'; end if;
  end if;
  return v_id;
end; $$;
revoke all on function public.app_guardar_sesion(uuid,uuid,uuid,date,time,time,text,text,text,text) from public;
grant execute on function public.app_guardar_sesion(uuid,uuid,uuid,date,time,time,text,text,text,text) to authenticated;

create or replace function public.app_crear_preinscripcion(
  p_club_id uuid, p_tipo_solicitud text, p_nombre text, p_apellidos text,
  p_fecha_nacimiento date, p_tutor_nombre text, p_tutor_email text, p_telefono text,
  p_disciplina_id uuid, p_grupo_id uuid, p_tarifa_id uuid,
  p_parentesco text default null, p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path=public,auth
as $$
declare v_id uuid; v_solicitante uuid; v_edad smallint;
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then raise exception 'No perteneces al club'; end if;
  if p_tipo_solicitud not in ('adulto','menor') then raise exception 'Tipo de solicitud no válido'; end if;
  if nullif(trim(p_nombre),'') is null or nullif(trim(p_apellidos),'') is null then raise exception 'Nombre y apellidos son obligatorios'; end if;
  if nullif(trim(p_telefono),'') is null then raise exception 'El teléfono es obligatorio'; end if;
  if p_disciplina_id is not null and not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id and activa) then raise exception 'Disciplina no disponible'; end if;
  if p_grupo_id is not null and not exists(select 1 from public.grupos where id=p_grupo_id and club_id=p_club_id and activo and (p_disciplina_id is null or disciplina_id=p_disciplina_id)) then raise exception 'Grupo no disponible'; end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=p_club_id and activa) then raise exception 'Tarifa no disponible'; end if;
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then v_solicitante:=auth.uid(); end if;
  if p_fecha_nacimiento is not null then v_edad:=extract(year from age(current_date,p_fecha_nacimiento))::smallint; end if;
  insert into public.preinscripciones(club_id,solicitante_perfil_id,tipo_solicitud,nombre,apellidos,fecha_nacimiento,edad,tutor_nombre,tutor_email,telefono,disciplina_id,grupo_id,tarifa_id,parentesco,estado,observaciones)
  values(p_club_id,v_solicitante,p_tipo_solicitud,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,v_edad,nullif(trim(p_tutor_nombre),''),nullif(trim(p_tutor_email),''),trim(p_telefono),p_disciplina_id,p_grupo_id,p_tarifa_id,nullif(trim(p_parentesco),''),'enviada',nullif(trim(p_observaciones),''))
  returning id into v_id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select p_club_id,rol,'preinscripcion-'||v_id||'-'||rol::text,'inscripcion','Nueva preinscripción',trim(p_nombre||' '||p_apellidos)||' ha enviado una solicitud.','enrollments',jsonb_build_object('preinscripcion_id',v_id),auth.uid()
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol;
  return v_id;
end; $$;
revoke all on function public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text) from public;
grant execute on function public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text) to authenticated;

create or replace function public.app_rechazar_preinscripcion(p_preinscripcion_id uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public, auth
as $$
declare v_row public.preinscripciones;
begin
  select * into v_row from public.preinscripciones where id=p_preinscripcion_id for update;
  if v_row.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(v_row.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;
  update public.preinscripciones set estado='rechazada',observaciones=nullif(trim(p_motivo),''),revisada_por=auth.uid(),revisada_en=now() where id=v_row.id;
  if v_row.solicitante_perfil_id is not null then
    insert into public.notificaciones(club_id,perfil_id,tipo,titulo,cuerpo,ruta,leida,creada_por)
    values(v_row.club_id,v_row.solicitante_perfil_id,'inscripcion','Solicitud revisada',coalesce(nullif(trim(p_motivo),''),'La solicitud no ha sido aprobada.'),'home',false,auth.uid());
  end if;
end; $$;
revoke all on function public.app_rechazar_preinscripcion(uuid,text) from public;
grant execute on function public.app_rechazar_preinscripcion(uuid,text) to authenticated;

-- Pedidos de material con notificación y trazabilidad en una única operación.
create or replace function public.app_solicitar_material(
  p_socio_id uuid, p_material_id uuid, p_variante_id uuid,
  p_cantidad integer default 1, p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path = public, auth
as $$
declare v_socio public.socios; v_material public.material_catalogo; v_id uuid;
begin
  select * into v_socio from public.socios where id=p_socio_id;
  if v_socio.id is null or not public.puede_ver_socio(v_socio.id) then raise exception 'No tienes acceso al alumno'; end if;
  select * into v_material from public.material_catalogo where id=p_material_id and club_id=v_socio.club_id and activo;
  if v_material.id is null then raise exception 'Material no disponible'; end if;
  if coalesce(p_cantidad,0)<=0 then raise exception 'La cantidad debe ser mayor que cero'; end if;
  if p_variante_id is not null and not exists(select 1 from public.material_variantes where id=p_variante_id and club_id=v_socio.club_id and material_id=p_material_id and activa) then raise exception 'Variante no disponible'; end if;
  insert into public.material_pedidos(club_id,socio_id,material_id,variante_id,cantidad,importe_total,estado,observaciones,creado_por)
  values(v_socio.club_id,v_socio.id,v_material.id,p_variante_id,p_cantidad,v_material.precio*p_cantidad,'reservado',nullif(trim(p_observaciones),''),auth.uid())
  returning id into v_id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select v_socio.club_id,rol,'pedido-material-'||v_id||'-'||rol::text,'material','Nuevo pedido de material',
    trim(v_socio.nombre||' '||v_socio.apellidos)||' ha solicitado '||p_cantidad||' × '||v_material.nombre||'.','materials',jsonb_build_object('pedido_id',v_id),auth.uid()
  from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol;
  return v_id;
end; $$;
revoke all on function public.app_solicitar_material(uuid,uuid,uuid,integer,text) from public;
grant execute on function public.app_solicitar_material(uuid,uuid,uuid,integer,text) to authenticated;

create or replace function public.app_actualizar_pedido_material(p_pedido_id uuid,p_estado text)
returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare v_pedido public.material_pedidos; v_perfil uuid; v_nombre text;
begin
  select * into v_pedido from public.material_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Pedido no encontrado'; end if;
  if not public.tiene_rol_club(v_pedido.club_id,'direccion','secretaria','economia') then raise exception 'No tienes permiso'; end if;
  if p_estado not in ('reservado','preparado','entregado','cancelado') then raise exception 'Estado no válido'; end if;
  update public.material_pedidos set estado=p_estado,actualizado_en=now() where id=v_pedido.id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos) into v_perfil,v_nombre
  from public.socios s left join lateral(
    select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1
  )t on true where s.id=v_pedido.socio_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_pedido.club_id,v_perfil,'pedido-material-'||v_pedido.id||'-'||p_estado,'material','Pedido '||p_estado,
      v_nombre||': tu pedido de material está '||p_estado||'.','materials',jsonb_build_object('pedido_id',v_pedido.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_pedido.id;
end; $$;
revoke all on function public.app_actualizar_pedido_material(uuid,text) from public;
grant execute on function public.app_actualizar_pedido_material(uuid,text) to authenticated;

-- Activada por Cron/Edge Function para publicar y notificar contenido programado.
create or replace function public.publicar_comunicaciones_programadas(p_ahora timestamptz default now())
returns integer language plpgsql security definer set search_path = public, auth
as $$
declare v_row public.comunicaciones; v_count integer:=0;
begin
  for v_row in select * from public.comunicaciones where estado='programada' and programada_para<=p_ahora and notificada_en is null for update skip locked loop
    update public.comunicaciones set estado='publicada',publicada_en=coalesce(publicada_en,p_ahora) where id=v_row.id;
    if v_row.audiencia='todos' then
      insert into public.notificaciones(club_id,audiencia,clave,tipo,titulo,cuerpo,ruta,datos)
      values(v_row.club_id,'todos','comunicacion-'||v_row.id||'-todos',case when v_row.tipo='evento' then 'evento' else 'comunicacion' end,v_row.titulo,v_row.cuerpo,'communications',jsonb_build_object('comunicacion_id',v_row.id));
    elsif v_row.audiencia='monitores' then
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
      values(v_row.club_id,'monitor','comunicacion-'||v_row.id||'-monitor',case when v_row.tipo='evento' then 'evento' else 'comunicacion' end,v_row.titulo,v_row.cuerpo,'communications',jsonb_build_object('comunicacion_id',v_row.id));
    else
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
      values
       (v_row.club_id,'familia','comunicacion-'||v_row.id||'-familia',case when v_row.tipo='evento' then 'evento' else 'comunicacion' end,v_row.titulo,v_row.cuerpo,'communications',jsonb_build_object('comunicacion_id',v_row.id)),
       (v_row.club_id,'alumno','comunicacion-'||v_row.id||'-alumno',case when v_row.tipo='evento' then 'evento' else 'comunicacion' end,v_row.titulo,v_row.cuerpo,'communications',jsonb_build_object('comunicacion_id',v_row.id));
    end if;
    update public.comunicaciones set notificada_en=p_ahora where id=v_row.id;
    v_count:=v_count+1;
  end loop;
  return v_count;
end; $$;
revoke all on function public.publicar_comunicaciones_programadas(timestamptz) from public,anon,authenticated;
grant execute on function public.publicar_comunicaciones_programadas(timestamptz) to service_role;

-- Recordatorios de clase directos para alumnos y tutores.
create or replace function public.generar_recordatorios_clase(p_ahora timestamptz default now(),p_horas integer default 3)
returns integer language plpgsql security definer set search_path=public,auth
as $$
declare v_count integer;
begin
  with proximas as (
    select se.id sesion_id,se.club_id,se.grupo_id,se.fecha,se.hora_inicio,
      sd.socio_id,coalesce(s.perfil_id,t.tutor_perfil_id) perfil_id,trim(s.nombre||' '||s.apellidos) alumno,
      g.nombre grupo,(se.fecha+se.hora_inicio) at time zone c.zona_horaria inicio
    from public.sesiones_entrenamiento se
    join public.clubes c on c.id=se.club_id and c.activo
    join public.grupos g on g.id=se.grupo_id and g.club_id=se.club_id
    join public.socio_disciplinas sd on sd.club_id=se.club_id and sd.grupo_id=se.grupo_id and sd.activa
    join public.socios s on s.id=sd.socio_id and s.club_id=sd.club_id and s.estado='activo'
    left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
    where se.estado='programada'
  ), ins as (
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,programada_para)
    select club_id,perfil_id,'clase-'||sesion_id||'-'||socio_id,'clase','Próxima clase',
      alumno||' tiene '||grupo||' a las '||to_char(hora_inicio,'HH24:MI')||'.','schedule',
      jsonb_build_object('sesion_id',sesion_id,'socio_id',socio_id),p_ahora
    from proximas
    where perfil_id is not null and inicio>p_ahora and inicio<=p_ahora+make_interval(hours=>greatest(p_horas,1))
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing
    returning 1
  ) select count(*) into v_count from ins;
  return v_count;
end; $$;
revoke all on function public.generar_recordatorios_clase(timestamptz,integer) from public,anon,authenticated;
grant execute on function public.generar_recordatorios_clase(timestamptz,integer) to service_role;

-- ---------------------------------------------------------------------------
-- 5. VISTA DE PROGRESO PARA PERFIL DE USUARIO
-- ---------------------------------------------------------------------------
create or replace view public.v_progreso_socio
with (security_invoker=true)
as
select s.club_id,s.id as socio_id,s.nombre,s.apellidos,
  count(distinct a.id) filter(where a.estado='presente') as asistencias_presentes,
  count(distinct a.id) filter(where a.estado in ('presente','ausente','ausencia_justificada','retraso')) as asistencias_registradas,
  max(gra.fecha) as ultima_graduacion,
  max(g.nombre) filter(where g.id=sd.grado_id) as grado_actual,
  count(distinct seg.id) as observaciones_seguimiento
from public.socios s
left join public.socio_disciplinas sd on sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa
left join public.grados g on g.club_id=s.club_id and g.id=sd.grado_id
left join public.asistencias a on a.club_id=s.club_id and a.socio_id=s.id
left join public.graduaciones gra on gra.club_id=s.club_id and gra.socio_id=s.id
left join public.seguimiento seg on seg.club_id=s.club_id and seg.socio_id=s.id
where public.puede_ver_socio(s.id)
group by s.club_id,s.id,s.nombre,s.apellidos;

grant select on public.v_progreso_socio to authenticated;

-- Notificar a PostgREST de cambios de esquema.
notify pgrst, 'reload schema';
