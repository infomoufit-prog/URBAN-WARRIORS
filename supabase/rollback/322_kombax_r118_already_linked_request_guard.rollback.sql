-- R118 rollback for already-linked request guard.
-- Restores the exact function body. Repaired historical thread states are not reopened,
-- because doing so would intentionally recreate obsolete tasks.
CREATE OR REPLACE FUNCTION public.app_kombax_club_link_request_r117(p_club_id uuid, p_request_kind text DEFAULT 'member'::text, p_mensaje text DEFAULT NULL::text, p_target_socio_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_kind text:=lower(btrim(coalesce(p_request_kind,'member')));
  v_text text:=btrim(coalesce(p_mensaje,''));
  v_thread uuid;
  v_msg uuid;
  v_name text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_kind not in ('member','family') then raise exception 'KOMBAX_CLUB_LINK_REQUEST_KIND_INVALID'; end if;
  if char_length(v_text)<2 or char_length(v_text)>1000 then raise exception 'KOMBAX_CLUB_INTEREST_TEXT_INVALID'; end if;
  if not exists(select 1 from public.clubes where id=p_club_id and activo) then raise exception 'KOMBAX_CLUB_NOT_AVAILABLE'; end if;
  if p_target_socio_id is not null and not exists(select 1 from public.socios where id=p_target_socio_id and club_id=p_club_id) then
    raise exception 'KOMBAX_STUDENT_NOT_FOUND';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(
    v_uid,
    coalesce(auth.jwt()->'user_metadata'->>'nombre',split_part(coalesce(auth.jwt()->>'email','usuario'),'@',1)),
    coalesce(auth.jwt()->'user_metadata'->>'apellidos','')
  ) on conflict(id) do nothing;

  select btrim(concat_ws(' ',p.nombre,p.apellidos)) into v_name
  from public.perfiles p where p.id=v_uid;

  insert into public.kombax_club_interest_threads_r58(
    club_id,account_id,estado,request_kind,target_socio_id,resolved_by,resolved_at,resolution
  )
  values(p_club_id,v_uid,'abierta',v_kind,p_target_socio_id,null,null,null)
  on conflict(club_id,account_id)
  do update set
    estado='abierta',
    request_kind=excluded.request_kind,
    target_socio_id=excluded.target_socio_id,
    resolved_by=null,
    resolved_at=null,
    resolution=null,
    actualizada_en=now()
  returning id into v_thread;

  insert into public.kombax_club_interest_messages_r58(thread_id,autor_perfil_id,texto)
  values(v_thread,v_uid,v_text)
  returning id into v_msg;

  insert into public.notificaciones(
    club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    p_club_id,rol,
    'club-link-'||v_thread::text||'-'||rol::text,
    'inscripcion',
    case when v_kind='family' then 'Solicitud de vinculación familiar' else 'Solicitud de vinculación como miembro' end,
    coalesce(nullif(v_name,''),'Una cuenta KOMBAX')||' solicita autorización del club.',
    'members',
    jsonb_build_object(
      'thread_id',v_thread,'account_id',v_uid,'message_id',v_msg,
      'kind','club_link_request','request_kind',v_kind,'target_socio_id',p_target_socio_id
    ),
    v_uid
  from unnest(array['direccion','secretaria']::public.rol_club[]) rol
  on conflict (club_id,rol_destino,clave)
  where (clave is not null and rol_destino is not null)
  do update set
    titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
    leida=false,leida_en=null,ciclo_estado='activo',
    archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null,creado_en=now();

  return jsonb_build_object(
    'ok',true,'thread_id',v_thread,'message_id',v_msg,'request_kind',v_kind,
    'membership_created',false,'club_notified',true,
    'code_required',false,'club_authorization_required',true
  );
end $function$;
