-- KOMBAX build 20032 · 059 · invitaciones por código para alumnado y equipo.
-- Objetivos:
-- - dos flujos explícitos: ALUMNO y EQUIPO;
-- - código humano de un solo uso, ligado a email y club;
-- - rol de equipo encapsulado en la invitación;
-- - alumno invitado conserva regla de autorregistro 16+;
-- - compatibilidad con tokens UUID históricos del equipo;
-- - preparado para correo mediante Edge Function invite-email.
begin;

alter table public.invitaciones_club add column if not exists tipo_invitacion text not null default 'equipo';
alter table public.invitaciones_club add column if not exists codigo text;
alter table public.invitaciones_club add column if not exists nombre_destinatario text;
alter table public.invitaciones_club add column if not exists email_estado text not null default 'pendiente';
alter table public.invitaciones_club add column if not exists email_enviado_en timestamptz;
alter table public.invitaciones_club add column if not exists email_error text;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='invitaciones_club_tipo_v059') then
    alter table public.invitaciones_club add constraint invitaciones_club_tipo_v059 check(tipo_invitacion in ('alumno','equipo'));
  end if;
end $$;

update public.invitaciones_club set tipo_invitacion='equipo' where tipo_invitacion is null or tipo_invitacion not in ('alumno','equipo');

create or replace function public.app_kombax_invitation_code_v059(p_tipo text)
returns text language plpgsql volatile security definer set search_path=public as $$
declare v_prefix text;v_code text;v_try integer:=0;
begin
  v_prefix:=case lower(trim(coalesce(p_tipo,''))) when 'alumno' then 'ALU-' when 'equipo' then 'EQP-' else null end;
  if v_prefix is null then raise exception 'INVITATION_TYPE_INVALID';end if;
  loop
    v_try:=v_try+1;
    v_code:=v_prefix||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
    exit when not exists(select 1 from public.invitaciones_club i where upper(i.codigo)=upper(v_code));
    if v_try>=20 then raise exception 'INVITATION_CODE_GENERATION_FAILED';end if;
  end loop;
  return v_code;
end $$;
revoke all on function public.app_kombax_invitation_code_v059(text) from public,anon,authenticated;

-- Completa códigos en invitaciones históricas pendientes para mantener una sola UI.
do $$ declare r record; begin
  for r in select id,tipo_invitacion from public.invitaciones_club where codigo is null loop
    update public.invitaciones_club set codigo=public.app_kombax_invitation_code_v059(r.tipo_invitacion) where id=r.id;
  end loop;
end $$;

create unique index if not exists invitaciones_club_codigo_v059 on public.invitaciones_club(upper(codigo));
create index if not exists invitaciones_club_tipo_estado_v059 on public.invitaciones_club(club_id,tipo_invitacion,estado,creado_en desc);

create or replace function public.app_kombax_invitacion_crear_v059(
  p_club_id uuid,
  p_tipo text,
  p_email text,
  p_rol text default null,
  p_nombre text default null,
  p_expira_horas integer default 168
) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_tipo text:=lower(trim(coalesce(p_tipo,'')));v_email text:=lower(trim(coalesce(p_email,'')));v_role text:=lower(trim(coalesce(p_rol,'')));v_row public.invitaciones_club;v_coord boolean:=false;v_db_role public.rol_club;v_hours integer:=least(greatest(coalesce(p_expira_horas,168),1),720);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if v_tipo not in ('alumno','equipo') then raise exception 'Tipo de invitación no válido';end if;
  if v_email='' or position('@' in v_email)<2 then raise exception 'Indica un correo electrónico válido';end if;
  if not exists(select 1 from public.clubes c where c.id=p_club_id and c.activo) then raise exception 'Club no disponible';end if;

  if v_tipo='equipo' then
    if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo el Gestor de la app puede invitar miembros del equipo';end if;
    if v_role not in ('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'Rol de equipo no permitido';end if;
    v_coord:=v_role='coordinacion';
    v_db_role:=case when v_coord then 'secretaria'::public.rol_club else v_role::public.rol_club end;
  else
    if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para invitar alumnos';end if;
    v_db_role:='alumno'::public.rol_club;
  end if;

  update public.invitaciones_club set estado='revocada'
   where club_id=p_club_id and tipo_invitacion=v_tipo and lower(email)=v_email and estado='pendiente';

  insert into public.invitaciones_club(club_id,email,rol,invitado_por,coordinacion,tipo_invitacion,codigo,nombre_destinatario,expira_en,email_estado)
  values(p_club_id,v_email,v_db_role,auth.uid(),v_coord,v_tipo,public.app_kombax_invitation_code_v059(v_tipo),nullif(trim(coalesce(p_nombre,'')),''),now()+(v_hours||' hours')::interval,'pendiente')
  returning * into v_row;

  return jsonb_build_object(
    'id',v_row.id,'club_id',v_row.club_id,'tipo',v_row.tipo_invitacion,'email',v_row.email,'codigo',v_row.codigo,
    'rol',case when v_row.coordinacion then 'coordinacion' else v_row.rol::text end,'estado',v_row.estado,
    'expira_en',v_row.expira_en,'nombre',v_row.nombre_destinatario,'email_estado',v_row.email_estado
  );
end $$;
revoke all on function public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer) from public,anon;
grant execute on function public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer) to authenticated;

create or replace function public.app_kombax_invitacion_validar_v059(p_codigo text,p_email text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v public.invitaciones_club;v_club public.clubes;
begin
  select * into v from public.invitaciones_club i
   where upper(i.codigo)=upper(trim(coalesce(p_codigo,''))) and lower(i.email)=lower(trim(coalesce(p_email,'')))
     and i.estado='pendiente' and i.expira_en>now() limit 1;
  if v.id is null then return jsonb_build_object('valid',false);end if;
  select * into v_club from public.clubes where id=v.club_id and activo;
  if v_club.id is null then return jsonb_build_object('valid',false);end if;
  return jsonb_build_object('valid',true,'tipo',v.tipo_invitacion,'club_id',v.club_id,'club_slug',v_club.slug,'club_nombre',v_club.nombre,
    'email',v.email,'nombre',v.nombre_destinatario,'rol',case when v.coordinacion then 'coordinacion' else v.rol::text end,'expira_en',v.expira_en);
end $$;
revoke all on function public.app_kombax_invitacion_validar_v059(text,text) from public;
grant execute on function public.app_kombax_invitacion_validar_v059(text,text) to anon,authenticated;

create or replace function public.app_kombax_invitacion_aceptar_equipo_v059(p_codigo text)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v public.invitaciones_club;v_role text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v from public.invitaciones_club i where upper(i.codigo)=upper(trim(coalesce(p_codigo,''))) and i.tipo_invitacion='equipo' and i.estado='pendiente' for update;
  if v.id is null then raise exception 'Código de invitación no válido';end if;
  if v.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v.id;raise exception 'La invitación ha caducado';end if;
  if lower(v.email)<>v_email then raise exception 'La invitación pertenece a otro correo';end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(v_uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(v.email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;

  if v.coordinacion then
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values
      (v.club_id,v_uid,'secretaria',true,true),(v.club_id,v_uid,'economia',true,true),(v.club_id,v_uid,'comunicacion',true,true)
    on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;
    update public.miembros_club set coordinacion=false where club_id=v.club_id and perfil_id=v_uid and rol not in ('secretaria','economia','comunicacion');
    v_role:='coordinacion';
  else
    insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
    values(v.club_id,v_uid,v.rol,true,false)
    on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;
    v_role:=v.rol::text;
  end if;

  update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v.id;
  return jsonb_build_object('club_id',v.club_id,'rol',v_role,'estado','aceptada','codigo',v.codigo);
end $$;
revoke all on function public.app_kombax_invitacion_aceptar_equipo_v059(text) from public,anon;
grant execute on function public.app_kombax_invitacion_aceptar_equipo_v059(text) to authenticated;

create or replace function public.app_kombax_invitacion_email_payload_v059(p_invitacion_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v public.invitaciones_club;v_club public.clubes;v_role text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v from public.invitaciones_club where id=p_invitacion_id;
  if v.id is null then raise exception 'Invitación no encontrada';end if;
  if v.tipo_invitacion='equipo' then
    if not public.tiene_rol_club(v.club_id,'direccion') then raise exception 'No tienes permiso para enviar esta invitación';end if;
  else
    if not public.tiene_rol_club(v.club_id,'direccion','secretaria') then raise exception 'No tienes permiso para enviar esta invitación';end if;
  end if;
  select * into v_club from public.clubes where id=v.club_id;
  v_role:=case when v.coordinacion then 'coordinacion' else v.rol::text end;
  return jsonb_build_object('id',v.id,'tipo',v.tipo_invitacion,'email',v.email,'codigo',v.codigo,'nombre',v.nombre_destinatario,
    'rol',v_role,'club_id',v.club_id,'club_nombre',v_club.nombre,'club_slug',v_club.slug,'expira_en',v.expira_en,'estado',v.estado);
end $$;
revoke all on function public.app_kombax_invitacion_email_payload_v059(uuid) from public,anon;
grant execute on function public.app_kombax_invitacion_email_payload_v059(uuid) to authenticated;

create or replace function public.app_kombax_invitacion_email_estado_v059(p_invitacion_id uuid,p_estado text,p_error text default null)
returns boolean language plpgsql security definer set search_path=public,auth as $$
declare v public.invitaciones_club;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v from public.invitaciones_club where id=p_invitacion_id;
  if v.id is null then raise exception 'Invitación no encontrada';end if;
  if v.tipo_invitacion='equipo' and not public.tiene_rol_club(v.club_id,'direccion') then raise exception 'No tienes permiso';end if;
  if v.tipo_invitacion='alumno' and not public.tiene_rol_club(v.club_id,'direccion','secretaria') then raise exception 'No tienes permiso';end if;
  update public.invitaciones_club set email_estado=left(coalesce(nullif(trim(p_estado),''),'error'),30),email_enviado_en=case when p_estado='enviado' then now() else email_enviado_en end,email_error=left(nullif(trim(coalesce(p_error,'')),''),1000) where id=p_invitacion_id;
  return true;
end $$;
revoke all on function public.app_kombax_invitacion_email_estado_v059(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_invitacion_email_estado_v059(uuid,text,text) to authenticated;

-- Intercepta exclusivamente cuenta.registrar cuando viene de un código ALUMNO.
do $$ begin
  if to_regprocedure('public.app_mutate_v160_pre_invites_059(text,jsonb,uuid)') is null and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_invites_059;
  end if;
end $$;
revoke all on function public.app_mutate_v160_pre_invites_059(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_code text:=upper(trim(coalesce(v_payload->>'invite_code','')));v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v_inv public.invitaciones_club;v_club public.clubes;v_existing public.app_mutation_requests;v_result jsonb;
begin
  if p_operation='cuenta.registrar' and v_code<>'' then
    if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null and v_existing.user_id=v_uid and v_existing.operation=p_operation and v_existing.result is not null then return v_existing.result;end if;

    select * into v_inv from public.invitaciones_club i where upper(i.codigo)=v_code and i.tipo_invitacion='alumno' and i.estado='pendiente' for update;
    if v_inv.id is null then raise exception 'Código de alumno no válido';end if;
    if v_inv.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v_inv.id;raise exception 'La invitación de alumno ha caducado';end if;
    if lower(v_inv.email)<>v_email then raise exception 'La invitación pertenece a otro correo';end if;
    select * into v_club from public.clubes where id=v_inv.club_id and activo;
    if v_club.id is null then raise exception 'Club no disponible';end if;
    v_payload:=jsonb_set(v_payload,'{club_slug}',to_jsonb(v_club.slug),true);
    v_result:=public.app_mutate_v160_pre_invites_059(p_operation,v_payload,p_request_id);
    update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v_inv.id;
    v_result:=jsonb_set(v_result,'{data,invitation}',jsonb_build_object('tipo','alumno','codigo',v_inv.codigo),true);
    update public.app_mutation_requests set result=v_result where request_id=p_request_id;
    return v_result;
  end if;
  return public.app_mutate_v160_pre_invites_059(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Contrato visible para Platform Admin.
create or replace function public.app_kombax_release_contract_v056()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return jsonb_build_object('ok',true,'build',20032,
    'identity_context',to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null,
    'public_profiles',to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null,
    'social_media',to_regprocedure('public.app_kombax_social_mutate_v053(text,jsonb,uuid)') is not null,
    'showcase_actions',to_regprocedure('public.app_kombax_showcase_mutate_v054(text,jsonb,uuid)') is not null,
    'platform_admin',to_regprocedure('public.app_kombax_platform_dashboard_v055()') is not null,
    'invitation_codes',to_regprocedure('public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer)') is not null,
    'tables',jsonb_build_object('social_media',to_regclass('public.kombax_social_media') is not null,'showcase_saved',to_regclass('public.kombax_showcase_guardados') is not null,'team_permissions',to_regclass('public.kombax_club_team_permissions') is not null,'actor_audit',to_regclass('public.kombax_actor_audit') is not null,'platform_admins',to_regclass('public.kombax_platform_admins') is not null));
end $$;
revoke all on function public.app_kombax_release_contract_v056() from public,anon;
grant execute on function public.app_kombax_release_contract_v056() to authenticated;

notify pgrst,'reload schema';
commit;
