CREATE OR REPLACE FUNCTION public.app_kombax_invitacion_crear_v059(p_club_id uuid, p_tipo text, p_email text, p_rol text DEFAULT NULL::text, p_nombre text DEFAULT NULL::text, p_expira_horas integer DEFAULT 168)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$ declare v_tipo text:=lower(trim(coalesce(p_tipo,'')));v_email text:=lower(trim(coalesce(p_email,'')));v_role text:=lower(trim(coalesce(p_rol,'')));v_row public.invitaciones_club;v_coord boolean:=false;v_db_role public.rol_club;v_hours integer:=least(greatest(coalesce(p_expira_horas,168),1),720); begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;if v_tipo not in ('alumno','equipo') then raise exception 'Tipo de invitación no válido';end if;if v_email='' or position('@' in v_email)<2 then raise exception 'Indica un correo electrónico válido';end if;if not exists(select 1 from public.clubes c where c.id=p_club_id and c.activo) then raise exception 'Club no disponible';end if;if v_tipo='equipo' then if not public.tiene_rol_club(p_club_id,'direccion') then raise exception 'Solo el Gestor de la app puede invitar miembros del equipo';end if;if v_role not in ('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'Rol de equipo no permitido';end if;v_coord:=v_role='coordinacion';v_db_role:=case when v_coord then 'secretaria'::public.rol_club else v_role::public.rol_club end;else if not public.tiene_rol_club(p_club_id,'direccion','secretaria') then raise exception 'No tienes permiso para invitar alumnos';end if;v_db_role:='alumno'::public.rol_club;end if;update public.invitaciones_club set estado='revocada' where club_id=p_club_id and tipo_invitacion=v_tipo and lower(email)=v_email and estado='pendiente';insert into public.invitaciones_club(club_id,email,rol,invitado_por,coordinacion,tipo_invitacion,codigo,nombre_destinatario,expira_en,email_estado) values(p_club_id,v_email,v_db_role,auth.uid(),v_coord,v_tipo,public.app_kombax_invitation_code_v059(v_tipo),nullif(trim(coalesce(p_nombre,'')),''),now()+(v_hours||' hours')::interval,'pendiente') returning * into v_row;return jsonb_build_object('id',v_row.id,'club_id',v_row.club_id,'tipo',v_row.tipo_invitacion,'email',v_row.email,'codigo',v_row.codigo,'rol',case when v_row.coordinacion then 'coordinacion' else v_row.rol::text end,'estado',v_row.estado,'expira_en',v_row.expira_en,'nombre',v_row.nombre_destinatario,'email_estado',v_row.email_estado);end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_invitacion_aceptar_equipo_v059(p_codigo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$ declare v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v public.invitaciones_club;v_role text; begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;select * into v from public.invitaciones_club i where upper(i.codigo)=upper(trim(coalesce(p_codigo,''))) and i.tipo_invitacion='equipo' and i.estado='pendiente' for update;if v.id is null then raise exception 'Código de invitación no válido';end if;if v.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v.id;raise exception 'La invitación ha caducado';end if;if lower(v.email)<>v_email then raise exception 'La invitación pertenece a otro correo';end if;insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(v.email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;if v.coordinacion then insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values (v.club_id,v_uid,'secretaria',true,true),(v.club_id,v_uid,'economia',true,true),(v.club_id,v_uid,'comunicacion',true,true) on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;update public.miembros_club set coordinacion=false where club_id=v.club_id and perfil_id=v_uid and rol not in ('secretaria','economia','comunicacion');v_role:='coordinacion';else insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values(v.club_id,v_uid,v.rol,true,false) on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;v_role:=v.rol::text;end if;update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v.id;return jsonb_build_object('club_id',v.club_id,'rol',v_role,'estado','aceptada','codigo',v.codigo);end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_solicitud_equipo_resolver_v060(p_solicitud_id uuid, p_estado text, p_rol text DEFAULT NULL::text, p_nota text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare s public.kombax_solicitudes_equipo_club; st text:=lower(trim(coalesce(p_estado,''))); role text:=lower(trim(coalesce(p_rol,''))); db_role public.rol_club; is_coord boolean:=false;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into s from public.kombax_solicitudes_equipo_club where id=p_solicitud_id for update;
  if s.id is null then raise exception 'Solicitud no encontrada';end if;
  if not public.app_kombax_club_owner_fix14(s.club_id) then raise exception 'No tienes permiso para revisar esta solicitud';end if;
  if st not in ('aprobada','rechazada') then raise exception 'Estado no válido';end if;
  if s.estado<>'pendiente' then raise exception 'La solicitud ya ha sido revisada';end if;

  if st='aprobada' then
    if role not in ('coordinacion','secretaria','economia','comunicacion','monitor') then raise exception 'Selecciona un rol de equipo válido';end if;
    is_coord:=role='coordinacion';
    if is_coord and not public.tiene_rol_club(s.club_id,'direccion') then raise exception 'Solo el Gestor puede conceder Coordinación';end if;
    if is_coord then
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values
        (s.club_id,s.perfil_id,'secretaria',true,true),(s.club_id,s.perfil_id,'economia',true,true),(s.club_id,s.perfil_id,'comunicacion',true,true)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;
      db_role:='secretaria';
    else
      db_role:=role::public.rol_club;
      insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion)
      values(s.club_id,s.perfil_id,db_role,true,false)
      on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;
    end if;
  end if;

  update public.kombax_solicitudes_equipo_club
     set estado=st,revisado_en=now(),revisado_por=auth.uid(),rol_asignado=case when st='aprobada' then db_role else null end,coordinacion=case when st='aprobada' then is_coord else false end,nota_revision=left(nullif(trim(coalesce(p_nota,'')),''),1000),actualizado_en=now()
   where id=s.id;
  return jsonb_build_object('id',s.id,'club_id',s.club_id,'perfil_id',s.perfil_id,'estado',st,'rol',case when is_coord then 'coordinacion' when st='aprobada' then db_role::text else null end);
end $function$
;

