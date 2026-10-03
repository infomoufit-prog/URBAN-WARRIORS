-- KOMBAX R118 · prevent already-satisfied membership requests
CREATE OR REPLACE FUNCTION public.app_kombax_club_link_request_r117(
  p_club_id uuid,
  p_request_kind text DEFAULT 'member'::text,
  p_mensaje text DEFAULT NULL::text,
  p_target_socio_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','auth'
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

  -- R118: a confirmed member must never recreate a pending member request.
  -- Family is intentionally not short-circuited without an explicit target student:
  -- an existing guardian may legitimately request linkage to another child.
  if v_kind='member'
     and exists(
       select 1 from public.miembros_club m
       where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo and m.rol='alumno'
     )
     and exists(
       select 1 from public.socios s
       where s.club_id=p_club_id and s.perfil_id=v_uid and s.estado='activo'
         and s.kombax_acceso_estado='activo'
     ) then
    return jsonb_build_object(
      'ok',true,'already_linked',true,'club_id',p_club_id,
      'request_kind','member','membership_created',false,
      'club_notified',false,'code_required',false,
      'club_authorization_required',false,'private_club_access_enabled',true
    );
  end if;

  if v_kind='family' and p_target_socio_id is not null
     and exists(
       select 1 from public.miembros_club m
       where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo and m.rol='familia'
     )
     and exists(
       select 1 from public.tutores_socios ts
       where ts.club_id=p_club_id and ts.tutor_perfil_id=v_uid and ts.socio_id=p_target_socio_id
     ) then
    return jsonb_build_object(
      'ok',true,'already_linked',true,'club_id',p_club_id,
      'request_kind','family','target_socio_id',p_target_socio_id,
      'membership_created',false,'club_notified',false,'code_required',false,
      'club_authorization_required',false,'private_club_access_enabled',true
    );
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
end
$function$;

-- Repair only real, already-satisfied member requests. No synthetic data is created.
-- R117 notification lifecycle is guarded, so this repair enters the lifecycle gateway
-- for the duration of the state transition.
select set_config('kombax.lifecycle_gateway','on',true);
update public.kombax_club_interest_threads_r58 t
set estado='respondida',
    resolved_at=coalesce(t.resolved_at,now()),
    resolution='already_linked',
    actualizada_en=now()
where t.estado='abierta'
  and t.request_kind='member'
  and exists(
    select 1 from public.miembros_club m
    where m.club_id=t.club_id and m.perfil_id=t.account_id and m.activo and m.rol='alumno'
  )
  and exists(
    select 1 from public.socios s
    where s.club_id=t.club_id and s.perfil_id=t.account_id and s.estado='activo'
      and s.kombax_acceso_estado='activo'
  );
select set_config('kombax.lifecycle_gateway','',true);

do $
begin
 if position('already_linked' in pg_get_functiondef('public.app_kombax_club_link_request_r117(uuid,text,text,uuid)'::regprocedure))=0 then
   raise exception 'R118_ASSERT_ALREADY_LINKED_GUARD_MISSING';
 end if;
end $$;
