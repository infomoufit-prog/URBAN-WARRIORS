-- KOMBAX 20.109 R59 · ENROLLMENT / ACTIVATION / ACCOUNT FLOW
-- Derivada de R58. Cierra las reglas de alta nueva, migración histórica, menores,
-- vinculación Espectador->membresía y activación por correo sin crear duplicados.

begin;

-- -----------------------------------------------------------------------------
-- 1) Preinscripción nueva: email de acceso obligatorio.
--    Compatibilidad: tutor_email sigue existiendo; email_acceso explicita el uso.
-- -----------------------------------------------------------------------------
alter table public.preinscripciones
  add column if not exists email_acceso text,
  add column if not exists kombax_activacion_estado text not null default 'pendiente_alta',
  add column if not exists kombax_invitacion_id uuid;

alter table public.preinscripciones drop constraint if exists preinscripciones_kombax_activacion_estado_check;
alter table public.preinscripciones add constraint preinscripciones_kombax_activacion_estado_check
  check(kombax_activacion_estado in ('pendiente_alta','pendiente_email','invitacion_pendiente','activa','no_aplica'));

update public.preinscripciones
set email_acceso=lower(btrim(tutor_email))
where email_acceso is null and tutor_email is not null and btrim(tutor_email)<>'';

create index if not exists idx_preinscripciones_email_acceso_r59
  on public.preinscripciones(club_id,lower(email_acceso))
  where email_acceso is not null and btrim(email_acceso)<>'';

-- La FK a invitaciones se crea de forma tolerante para bases históricas.
do $$ begin
  if not exists(select 1 from pg_constraint where conname='preinscripciones_kombax_invitacion_r59_fk') then
    alter table public.preinscripciones add constraint preinscripciones_kombax_invitacion_r59_fk
      foreign key(kombax_invitacion_id) references public.invitaciones_club(id) on delete set null;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2) Nuevas preinscripciones: adulto => email propio; menor => email tutor.
--    Las migraciones históricas NO usan esta obligación: pueden crear socios sin email.
-- -----------------------------------------------------------------------------
create or replace function public.app_crear_preinscripcion(
  p_club_id uuid, p_tipo_solicitud text, p_nombre text, p_apellidos text,
  p_fecha_nacimiento date, p_tutor_nombre text, p_tutor_email text, p_telefono text,
  p_disciplina_id uuid, p_grupo_id uuid, p_tarifa_id uuid,
  p_parentesco text default null, p_observaciones text default null
) returns uuid
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_id uuid; v_solicitante uuid; v_edad smallint; v_email text;
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then raise exception 'No perteneces al club'; end if;
  if p_tipo_solicitud not in ('adulto','menor') then raise exception 'Tipo de solicitud no válido'; end if;
  if nullif(trim(p_nombre),'') is null or nullif(trim(p_apellidos),'') is null then raise exception 'Nombre y apellidos son obligatorios'; end if;
  if nullif(trim(p_telefono),'') is null then raise exception 'El teléfono es obligatorio'; end if;
  if p_fecha_nacimiento is null then raise exception 'KOMBAX_BIRTHDATE_REQUIRED_FOR_NEW_ENROLLMENT'; end if;
  v_edad:=extract(year from age(current_date,p_fecha_nacimiento))::smallint;
  if p_tipo_solicitud='adulto' and v_edad<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
  if p_tipo_solicitud='menor' and v_edad>=16 then raise exception 'KOMBAX_ADULT_MUST_USE_ADULT_FLOW'; end if;

  v_email:=lower(btrim(coalesce(p_tutor_email,'')));
  if v_email='' or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    if p_tipo_solicitud='menor' then
      raise exception 'KOMBAX_TUTOR_EMAIL_REQUIRED_FOR_NEW_MINOR';
    else
      raise exception 'KOMBAX_ADULT_EMAIL_REQUIRED_FOR_NEW_ENROLLMENT';
    end if;
  end if;
  if p_tipo_solicitud='menor' and nullif(btrim(coalesce(p_tutor_nombre,'')),'') is null then
    raise exception 'KOMBAX_TUTOR_NAME_REQUIRED_FOR_NEW_MINOR';
  end if;

  if p_disciplina_id is not null and not exists(select 1 from public.disciplinas where id=p_disciplina_id and club_id=p_club_id and activa) then raise exception 'Disciplina no disponible'; end if;
  if p_grupo_id is not null and not exists(select 1 from public.grupos where id=p_grupo_id and club_id=p_club_id and activo and (p_disciplina_id is null or disciplina_id=p_disciplina_id)) then raise exception 'Grupo no disponible'; end if;
  if p_tarifa_id is not null and not exists(select 1 from public.tarifas where id=p_tarifa_id and club_id=p_club_id and activa) then raise exception 'Tarifa no disponible'; end if;
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then v_solicitante:=auth.uid(); end if;

  -- Para alumnos con acceso autónomo (16+) el email identifica un posible registro ya existente dentro del club.
  -- No lo fusionamos aquí: evitamos crear una preinscripción duplicada y mandamos al club
  -- a revisar/activar la ficha administrativa existente.
  if p_tipo_solicitud='adulto' then
    if exists(select 1 from public.socios s where s.club_id=p_club_id and lower(btrim(coalesce(s.email,'')))=v_email and s.estado in ('activo','prealta','suspendido')) then
      raise exception 'KOMBAX_EXISTING_MEMBER_EMAIL_USE_EXISTING_RECORD';
    end if;
    if exists(select 1 from public.preinscripciones p where p.club_id=p_club_id and p.tipo_solicitud='adulto'
      and lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')))=v_email and p.estado in ('enviada','en_revision','pendiente_documentacion','lista_espera')) then
      raise exception 'KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT_EMAIL';
    end if;
  end if;

  insert into public.preinscripciones(
    club_id,solicitante_perfil_id,tipo_solicitud,nombre,apellidos,fecha_nacimiento,edad,
    tutor_nombre,tutor_email,email_acceso,telefono,disciplina_id,grupo_id,tarifa_id,parentesco,
    estado,observaciones,kombax_activacion_estado
  )
  values(
    p_club_id,v_solicitante,p_tipo_solicitud,trim(p_nombre),trim(p_apellidos),p_fecha_nacimiento,v_edad,
    case when p_tipo_solicitud='menor' then nullif(trim(p_tutor_nombre),'') end,
    v_email,v_email,trim(p_telefono),p_disciplina_id,p_grupo_id,p_tarifa_id,nullif(trim(p_parentesco),''),
    'enviada',nullif(trim(p_observaciones),''),'pendiente_alta'
  ) returning id into v_id;

  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select p_club_id,rol,'preinscripcion-'||v_id||'-'||rol::text,'inscripcion','Nueva preinscripción',
    trim(p_nombre||' '||p_apellidos)||' ha enviado una solicitud.','enrollments',jsonb_build_object('preinscripcion_id',v_id),auth.uid()
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol;
  return v_id;
end; $$;
revoke all on function public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text) from public;
grant execute on function public.app_crear_preinscripcion(uuid,text,text,text,date,text,text,text,uuid,uuid,uuid,text,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Aprobación: reutiliza la ficha existente por cuenta/email cuando es inequívoca.
--    Nunca fusiona por nombre solamente. Si encuentra una posible ficha histórica sin
--    email (nombre + DOB), exige revisión manual en vez de crear un duplicado.
-- -----------------------------------------------------------------------------
create or replace function public.app_aprobar_preinscripcion(p_preinscripcion_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth
as $$
declare
  p public.preinscripciones;
  v_socio uuid; v_ocupacion integer; v_plazas integer; v_email text;
  v_email_count integer:=0; v_possible_count integer:=0;
begin
  select * into p from public.preinscripciones where id=p_preinscripcion_id for update;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;
  v_email:=lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')));

  if p.estado='aprobada' then
    select s.id into v_socio from public.socios s
    where s.club_id=p.club_id and (
      (p.tipo_solicitud='adulto' and p.solicitante_perfil_id is not null and s.perfil_id=p.solicitante_perfil_id)
      or (p.tipo_solicitud='adulto' and v_email<>'' and lower(btrim(coalesce(s.email,'')))=v_email)
      or (p.tipo_solicitud='menor' and lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos) and s.fecha_nacimiento is not distinct from p.fecha_nacimiento)
    ) order by s.creado_en desc limit 1;
    return v_socio;
  end if;
  if p.estado in ('rechazada','cancelada') then raise exception 'La solicitud está cerrada'; end if;
  if p.disciplina_id is null or not exists(select 1 from public.disciplinas where id=p.disciplina_id and club_id=p.club_id and activa) then raise exception 'La solicitud necesita una disciplina activa'; end if;
  if p.grupo_id is null then raise exception 'Asigna un grupo antes de aprobar'; end if;
  select plazas into v_plazas from public.grupos where id=p.grupo_id and club_id=p.club_id and disciplina_id=p.disciplina_id and activo;
  if not found then raise exception 'El grupo no está disponible para la disciplina'; end if;
  select count(distinct socio_id) into v_ocupacion from public.socio_disciplinas where club_id=p.club_id and grupo_id=p.grupo_id and activa;
  if v_plazas is not null and v_ocupacion>=v_plazas then
    update public.preinscripciones set estado='lista_espera',revisada_por=auth.uid(),revisada_en=now(),
      observaciones=coalesce(observaciones,'Grupo completo: trasladada automáticamente a lista de espera.') where id=p.id;
    raise exception 'El grupo está completo. La solicitud se ha trasladado a lista de espera';
  end if;
  if p.tarifa_id is not null and not exists(select 1 from public.tarifas where id=p.tarifa_id and club_id=p.club_id and activa) then raise exception 'La tarifa seleccionada no está disponible'; end if;

  if p.tipo_solicitud='adulto' then
    if p.solicitante_perfil_id is not null then
      select s.id into v_socio from public.socios s where s.club_id=p.club_id and s.perfil_id=p.solicitante_perfil_id order by s.creado_en desc limit 1;
    end if;
    if v_socio is null and v_email<>'' then
      select count(*) into v_email_count from public.socios s
      where s.club_id=p.club_id and lower(btrim(coalesce(s.email,'')))=v_email and s.estado<>'baja';
      if v_email_count>1 then raise exception 'KOMBAX_AMBIGUOUS_EXISTING_MEMBER_EMAIL'; end if;
      if v_email_count=1 then
        select s.id into v_socio from public.socios s where s.club_id=p.club_id and lower(btrim(coalesce(s.email,'')))=v_email and s.estado<>'baja' limit 1;
      end if;
    end if;
    if v_socio is null and p.fecha_nacimiento is not null then
      select count(*) into v_possible_count from public.socios s
      where s.club_id=p.club_id and s.perfil_id is null and coalesce(btrim(s.email),'')=''
        and lower(btrim(s.nombre))=lower(btrim(p.nombre)) and lower(btrim(s.apellidos))=lower(btrim(p.apellidos))
        and s.fecha_nacimiento=p.fecha_nacimiento and s.estado<>'baja';
      if v_possible_count>0 then raise exception 'KOMBAX_POSSIBLE_IMPORTED_MEMBER_REVIEW_REQUIRED'; end if;
    end if;
  else
    select s.id into v_socio from public.socios s
    where s.club_id=p.club_id and lower(s.nombre)=lower(p.nombre) and lower(s.apellidos)=lower(p.apellidos)
      and s.fecha_nacimiento is not distinct from p.fecha_nacimiento
    order by s.creado_en desc limit 1;
  end if;

  if v_socio is null then
    insert into public.socios(club_id,perfil_id,nombre,apellidos,fecha_nacimiento,telefono,email,tutor_nombre,tarifa_id,estado,kombax_acceso_estado)
    values(
      p.club_id,case when p.tipo_solicitud='adulto' then p.solicitante_perfil_id end,
      p.nombre,p.apellidos,p.fecha_nacimiento,p.telefono,
      case when p.tipo_solicitud='adulto' then nullif(v_email,'') else null end,
      case when p.tipo_solicitud='menor' then p.tutor_nombre end,p.tarifa_id,'activo',
      case when p.tipo_solicitud='adulto' and p.solicitante_perfil_id is not null then 'activo' else 'sin_activar' end
    ) returning id into v_socio;
  else
    update public.socios set
      nombre=p.nombre,apellidos=p.apellidos,fecha_nacimiento=p.fecha_nacimiento,telefono=p.telefono,
      email=case when p.tipo_solicitud='adulto' then coalesce(nullif(v_email,''),email) else email end,
      tutor_nombre=case when p.tipo_solicitud='menor' then p.tutor_nombre else tutor_nombre end,
      tarifa_id=coalesce(p.tarifa_id,tarifa_id),estado='activo',actualizado_en=now()
    where id=v_socio;
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

-- -----------------------------------------------------------------------------
-- 4) Aprobación KOMBAX: aprueba la plaza y prepara invitación ligada a ESA ficha.
--    El envío real de email sigue en invite-email; si falla, la ficha/invitación quedan
--    guardadas y se pueden reenviar desde Alumnos.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_preinscripcion_aprobar_r59(p_preinscripcion_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  p public.preinscripciones; v_socio_id uuid; v_socio public.socios; v_email text; v_inv jsonb;
begin
  select * into p from public.preinscripciones where id=p_preinscripcion_id;
  if p.id is null then raise exception 'Preinscripción no encontrada'; end if;
  if not public.tiene_rol_club(p.club_id,'direccion','secretaria') then raise exception 'No tienes permiso'; end if;
  v_email:=lower(btrim(coalesce(p.email_acceso,p.tutor_email,'')));
  v_socio_id:=public.app_aprobar_preinscripcion(p_preinscripcion_id);
  select * into v_socio from public.socios where id=v_socio_id and club_id=p.club_id for update;

  if p.tipo_solicitud='adulto' and v_socio.perfil_id is not null then
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(p.club_id,v_socio.perfil_id,'alumno',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;
    update public.socios set kombax_acceso_estado='activo',kombax_acceso_email=coalesce(nullif(v_email,''),email),kombax_acceso_modo='alumno',
      kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now()) where id=v_socio_id;
    update public.preinscripciones set kombax_activacion_estado='activa' where id=p.id;
    return jsonb_build_object('ok',true,'socio_id',v_socio_id,'activation','already_linked','email',v_email);
  end if;

  if v_email='' then
    update public.preinscripciones set kombax_activacion_estado='pendiente_email' where id=p.id;
    return jsonb_build_object('ok',true,'socio_id',v_socio_id,'activation','missing_email');
  end if;

  v_inv:=public.app_kombax_alumno_invitar_r58(p.club_id,v_socio_id,v_email);
  update public.preinscripciones set kombax_activacion_estado='invitacion_pendiente',
    kombax_invitacion_id=(v_inv->>'id')::uuid,email_acceso=v_email where id=p.id;
  return jsonb_build_object('ok',true,'socio_id',v_socio_id,'activation','invitation_pending','email',v_email,
    'invitation_id',v_inv->>'id','codigo',v_inv->>'codigo','modo',case when p.tipo_solicitud='menor' then 'tutor' else 'alumno' end);
end $$;
revoke all on function public.app_kombax_preinscripcion_aprobar_r59(uuid) from public,anon;
grant execute on function public.app_kombax_preinscripcion_aprobar_r59(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5) Aceptación R59. Los menores de 16 se vinculan mediante tutor; desde 16 años
--    el alumno puede activar su propia cuenta. La ficha del menor siempre se conserva separada.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_alumno_aceptar_r59(p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid(); v_email text; v_confirmed timestamptz; v_inv public.invitaciones_club; v_socio public.socios;
  v_age integer; v_mode text; v_other uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select lower(coalesce(email,'')),email_confirmed_at into v_email,v_confirmed from auth.users where id=v_uid;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED'; end if;
  select * into v_inv from public.invitaciones_club i
  where upper(i.codigo)=upper(btrim(coalesce(p_codigo,''))) and i.tipo_invitacion='alumno' and i.estado='pendiente' for update;
  if v_inv.id is null or v_inv.socio_id is null then raise exception 'KOMBAX_BOUND_STUDENT_INVITATION_REQUIRED'; end if;
  if v_inv.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v_inv.id; raise exception 'La invitación ha caducado'; end if;
  if lower(v_inv.email)<>v_email then raise exception 'La invitación pertenece a otro correo'; end if;
  perform pg_advisory_xact_lock(hashtext(v_inv.club_id::text||':'||v_uid::text));
  select * into v_socio from public.socios where id=v_inv.socio_id and club_id=v_inv.club_id for update;
  if v_socio.id is null then raise exception 'KOMBAX_STUDENT_NOT_FOUND'; end if;
  if v_socio.estado in ('baja','suspendido') then raise exception 'KOMBAX_STUDENT_NOT_ACTIVE'; end if;
  if v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_BIRTHDATE_REQUIRED_BEFORE_ACTIVATION'; end if;
  v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento));

  insert into public.perfiles(id,nombre,apellidos)
  values(v_uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(v_email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;

  if v_age<16 then
    insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
    values(v_inv.club_id,v_uid,v_socio.id,'Tutor/a responsable',true)
    on conflict(club_id,tutor_perfil_id,socio_id) do update set contacto_principal=true;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(v_inv.club_id,v_uid,'familia',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;
    v_mode:='tutor';
  else
    if v_socio.perfil_id is not null and v_socio.perfil_id<>v_uid then raise exception 'KOMBAX_STUDENT_ALREADY_LINKED_TO_OTHER_ACCOUNT'; end if;
    select id into v_other from public.socios where club_id=v_inv.club_id and perfil_id=v_uid and id<>v_socio.id limit 1;
    if v_other is not null then raise exception 'KOMBAX_ACCOUNT_ALREADY_HAS_STUDENT_MEMBERSHIP_IN_CLUB'; end if;
    update public.socios set perfil_id=v_uid where id=v_socio.id and club_id=v_inv.club_id;
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(v_inv.club_id,v_uid,'alumno',true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true;
    v_mode:='alumno';
  end if;

  update public.socios set kombax_acceso_estado='activo',kombax_acceso_email=v_email,kombax_acceso_modo=v_mode,
    kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now())
  where id=v_socio.id and club_id=v_inv.club_id;
  update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v_inv.id;
  update public.preinscripciones set kombax_activacion_estado='activa'
    where kombax_invitacion_id=v_inv.id or (club_id=v_inv.club_id and estado='aprobada' and lower(coalesce(email_acceso,''))=v_email);
  return jsonb_build_object('ok',true,'club_id',v_inv.club_id,'socio_id',v_socio.id,'modo',v_mode,'estado','activo');
end $$;
revoke all on function public.app_kombax_alumno_aceptar_r59(text) from public,anon;
grant execute on function public.app_kombax_alumno_aceptar_r59(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Espectador existente -> ficha importada: revisión del club y resolución.
-- -----------------------------------------------------------------------------
create or replace function public.app_kombax_membership_claims_club_r59(p_club_id uuid)
returns table(claim_id uuid,socio_id uuid,nombre text,apellidos text,account_id uuid,account_email text,solicitado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_FORBIDDEN'; end if;
  return query
  select c.id,s.id,s.nombre,s.apellidos,c.account_id,lower(coalesce(u.email,'')),c.solicitado_en
  from public.kombax_membership_claims_r58 c
  join public.socios s on s.club_id=c.club_id and s.id=c.socio_id
  left join auth.users u on u.id=c.account_id
  where c.club_id=p_club_id and c.estado='pendiente'
  order by c.solicitado_en asc;
end $$;
revoke all on function public.app_kombax_membership_claims_club_r59(uuid) from public,anon;
grant execute on function public.app_kombax_membership_claims_club_r59(uuid) to authenticated;

create or replace function public.app_kombax_membership_claim_resolve_r59(p_claim_id uuid,p_aprobar boolean)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_claim public.kombax_membership_claims_r58; v_socio public.socios; v_email text; v_confirmed timestamptz; v_other uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_claim from public.kombax_membership_claims_r58 where id=p_claim_id for update;
  if v_claim.id is null then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_NOT_FOUND'; end if;
  if not public.tiene_rol_club(v_claim.club_id,'direccion','secretaria') then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_FORBIDDEN'; end if;
  if v_claim.estado<>'pendiente' then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_ALREADY_RESOLVED'; end if;
  select * into v_socio from public.socios where club_id=v_claim.club_id and id=v_claim.socio_id for update;
  if v_socio.id is null then raise exception 'KOMBAX_STUDENT_NOT_FOUND'; end if;

  if not p_aprobar then
    update public.kombax_membership_claims_r58 set estado='rechazada',resuelto_en=now(),resuelto_por=auth.uid() where id=v_claim.id;
    if not exists(select 1 from public.kombax_membership_claims_r58 c where c.club_id=v_claim.club_id and c.socio_id=v_claim.socio_id and c.estado='pendiente' and c.id<>v_claim.id) then
      update public.socios set kombax_acceso_estado='sin_activar',kombax_acceso_actualizado_en=now() where id=v_socio.id and perfil_id is null;
    end if;
    return jsonb_build_object('ok',true,'estado','rechazada','socio_id',v_socio.id);
  end if;

  select lower(coalesce(email,'')),email_confirmed_at into v_email,v_confirmed from auth.users where id=v_claim.account_id;
  if v_confirmed is null then raise exception 'KOMBAX_EMAIL_VERIFICATION_REQUIRED'; end if;
  if v_socio.perfil_id is not null and v_socio.perfil_id<>v_claim.account_id then raise exception 'KOMBAX_STUDENT_ALREADY_LINKED_TO_OTHER_ACCOUNT'; end if;
  if lower(btrim(coalesce(v_socio.email,'')))<>v_email then raise exception 'KOMBAX_MEMBERSHIP_CLAIM_EMAIL_MISMATCH'; end if;
  select id into v_other from public.socios where club_id=v_claim.club_id and perfil_id=v_claim.account_id and id<>v_socio.id limit 1;
  if v_other is not null then raise exception 'KOMBAX_ACCOUNT_ALREADY_HAS_STUDENT_MEMBERSHIP_IN_CLUB'; end if;

  perform pg_advisory_xact_lock(hashtext(v_claim.club_id::text||':'||v_claim.account_id::text));
  update public.socios set perfil_id=v_claim.account_id,kombax_acceso_estado='activo',kombax_acceso_email=v_email,kombax_acceso_modo='alumno',
    kombax_acceso_actualizado_en=now(),kombax_vinculado_en=coalesce(kombax_vinculado_en,now()) where id=v_socio.id;
  insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
  values(v_claim.club_id,v_claim.account_id,'alumno',true,false)
  on conflict(club_id,perfil_id,rol) do update set activo=true;
  update public.kombax_membership_claims_r58 set estado='aprobada',resuelto_en=now(),resuelto_por=auth.uid() where id=v_claim.id;
  update public.kombax_membership_claims_r58 set estado='rechazada',resuelto_en=now(),resuelto_por=auth.uid()
    where club_id=v_claim.club_id and socio_id=v_claim.socio_id and estado='pendiente' and id<>v_claim.id;
  return jsonb_build_object('ok',true,'estado','aprobada','club_id',v_claim.club_id,'socio_id',v_socio.id,'account_id',v_claim.account_id);
end $$;
revoke all on function public.app_kombax_membership_claim_resolve_r59(uuid,boolean) from public,anon;
grant execute on function public.app_kombax_membership_claim_resolve_r59(uuid,boolean) to authenticated;


-- -----------------------------------------------------------------------------
-- 7) Autorregistro de alumno: 16+. Los menores de 16 usan tutor; desde los 16
--    años se permite la membresía autónoma de alumno ya definida históricamente.
-- -----------------------------------------------------------------------------
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_student_age_r59(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception 'R59: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_student_age_r59;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_student_age_r59(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb); v_dob date; v_age integer;
begin
  if p_operation='cuenta.registrar' and lower(coalesce(v_payload->>'tipo_cuenta',''))='adulto' then
    begin v_dob:=nullif(v_payload->>'fecha_nacimiento_adulto','')::date; exception when others then raise exception 'Fecha de nacimiento no válida'; end;
    if v_dob is null then raise exception 'La fecha de nacimiento es obligatoria para inscribirte como alumno'; end if;
    if v_dob>current_date then raise exception 'La fecha de nacimiento no puede ser futura'; end if;
    v_age:=extract(year from age(current_date,v_dob))::integer;
    if v_age<16 then raise exception 'KOMBAX_MINOR_MUST_USE_TUTOR_FLOW'; end if;
  end if;
  return public.app_mutate_v160_pre_student_age_r59(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
