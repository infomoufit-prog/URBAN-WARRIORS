-- Restore the authenticated acceptance endpoint used by the frontend, retaining personal-code safeguards.
CREATE OR REPLACE FUNCTION public.app_kombax_invitacion_aceptar_equipo_v059(p_codigo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare v_uid uuid:=auth.uid();v_email text:=lower(coalesce(auth.jwt()->>'email',''));v public.invitaciones_club;v_role text; begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
if not exists(select 1 from auth.users u where u.id=v_uid and u.deleted_at is null and u.email_confirmed_at is not null) then raise exception 'KOMBAX_EMAIL_CONFIRMATION_REQUIRED';end if;
if not exists(select 1 from auth.users u where u.id=v_uid and lower(u.email)=v_email) then raise exception 'La invitación pertenece a otro correo';end if;
select * into v from public.invitaciones_club i where upper(i.codigo)=upper(trim(coalesce(p_codigo,''))) and i.tipo_invitacion='equipo' and i.estado='pendiente' for update;if v.id is null then raise exception 'Código de invitación no válido';end if;if v.expira_en<=now() then update public.invitaciones_club set estado='caducada' where id=v.id;raise exception 'La invitación ha caducado';end if;if lower(v.email)<>v_email then raise exception 'La invitación pertenece a otro correo';end if;
if v.rol::text not in ('secretaria','economia','comunicacion','monitor') then raise exception 'INVITATION_TEAM_ROLE_NOT_ALLOWED';end if;
insert into public.perfiles(id,nombre,apellidos) values(v_uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(v.email,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos','')) on conflict(id) do nothing;if v.coordinacion then insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values (v.club_id,v_uid,'secretaria',true,true),(v.club_id,v_uid,'economia',true,true),(v.club_id,v_uid,'comunicacion',true,true) on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=true;update public.miembros_club set coordinacion=false where club_id=v.club_id and perfil_id=v_uid and rol not in ('secretaria','economia','comunicacion');v_role:='coordinacion';else insert into public.miembros_club(club_id,perfil_id,rol,activo,coordinacion) values(v.club_id,v_uid,v.rol,true,false) on conflict(club_id,perfil_id,rol) do update set activo=true,coordinacion=false;v_role:=v.rol::text;end if;update public.invitaciones_club set estado='aceptada',aceptado_por=v_uid,aceptado_en=now() where id=v.id;return jsonb_build_object('club_id',v.club_id,'rol',v_role,'estado','aceptada','codigo',v.codigo);end $function$
;
revoke all on function public.app_kombax_invitacion_aceptar_equipo_v059(text) from public,anon;
grant execute on function public.app_kombax_invitacion_aceptar_equipo_v059(text) to authenticated;
