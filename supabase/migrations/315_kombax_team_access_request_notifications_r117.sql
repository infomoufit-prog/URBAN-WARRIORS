-- KOMBAX R117 build 20175
-- Consolidates live Supabase migration 20261003093015_team_access_request_notifications_r117_26.
-- Team access remains approval-gated. This migration only makes pending requests visible/actionable
-- to authorized club managers and keeps the legacy v060 fallback consistent.

CREATE OR REPLACE FUNCTION public.app_kombax_equipo_solicitar_v109(p_club_slug text, p_codigo text, p_rol_solicitado text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  uid uuid:=auth.uid();
  chk jsonb;
  cid uuid;
  ver integer;
  row public.kombax_solicitudes_equipo_club;
  mail text:=lower(coalesce(auth.jwt()->>'email',''));
  requested text:=lower(trim(coalesce(p_rol_solicitado,'')));
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if requested='' then requested:=null; end if;
  if requested is not null and requested not in ('coordinacion','secretaria','economia','comunicacion','monitor') then
    raise exception 'Selecciona un rol de equipo válido';
  end if;

  chk:=public.app_kombax_codigo_validar_v060(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'message',coalesce(chk->>'message','Código de equipo no válido.'));
  end if;

  cid:=(chk->>'club_id')::uuid;
  ver:=(chk->>'version')::integer;

  if exists(
    select 1 from public.miembros_club m
    where m.club_id=cid and m.perfil_id=uid and m.activo
      and m.rol in ('direccion','secretaria','economia','comunicacion','monitor')
  ) then
    raise exception 'Tu cuenta ya pertenece al equipo de este club';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(
    uid,
    coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),
    coalesce(auth.jwt()->'user_metadata'->>'apellidos','')
  )
  on conflict(id) do nothing;

  insert into public.kombax_solicitudes_equipo_club(
    club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,
    revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision,rol_solicitado
  )
  values(
    cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null,requested
  )
  on conflict(club_id,perfil_id) do update set
    email=excluded.email,
    estado='pendiente',
    codigo_version=excluded.codigo_version,
    actualizado_en=now(),
    revisado_en=null,
    revisado_por=null,
    rol_asignado=null,
    coordinacion=false,
    nota_revision=null,
    rol_solicitado=excluded.rol_solicitado
  returning * into row;

  insert into public.notificaciones(
    club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    cid,
    managers.perfil_id,
    'team-request-'||row.id::text,
    'inscripcion',
    'Nueva solicitud de acceso al equipo',
    coalesce(nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),''),mail)
      || case when requested is not null then ' solicita acceso como '||requested||'.' else ' solicita acceso al equipo.' end,
    'users',
    jsonb_build_object(
      'team_request_id',row.id,
      'requester_profile_id',uid,
      'requester_email',mail,
      'requested_role',requested
    ),
    uid
  from (
    select distinct m.perfil_id
    from public.miembros_club m
    where m.club_id=cid
      and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false))
  ) managers
  left join public.perfiles p on p.id=uid
  on conflict (club_id,perfil_id,clave)
    where clave is not null and perfil_id is not null
  do update set
    tipo=excluded.tipo,
    titulo=excluded.titulo,
    cuerpo=excluded.cuerpo,
    ruta=excluded.ruta,
    datos=excluded.datos,
    creada_por=excluded.creada_por,
    ciclo_estado='activo',
    leida=false,
    leida_en=null,
    creado_en=now();

  delete from public.notificaciones_lecturas nl
  using public.notificaciones n
  where nl.notificacion_id=n.id
    and n.club_id=cid
    and n.clave='team-request-'||row.id::text
    and n.perfil_id is not null;

  return jsonb_build_object(
    'ok',true,
    'id',row.id,
    'club_id',row.club_id,
    'club_slug',chk->>'club_slug',
    'club_nombre',chk->>'club_nombre',
    'estado',row.estado,
    'rol_solicitado',row.rol_solicitado,
    'creado_en',row.creado_en
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.app_kombax_equipo_solicitar_v060(p_club_slug text, p_codigo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  uid uuid:=auth.uid();
  chk jsonb;
  cid uuid;
  ver integer;
  row public.kombax_solicitudes_equipo_club;
  mail text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if uid is null then raise exception 'AUTH_REQUIRED';end if;
  chk:=public.app_kombax_codigo_validar_seguro_v086(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then
    return jsonb_build_object(
      'ok',false,
      'error_code',case when coalesce((chk->>'rate_limited')::boolean,false)
        then 'KOMBAX_ACCESS_CODE_RATE_LIMIT' else 'KOMBAX_ACCESS_CODE_INVALID' end,
      'message',case when coalesce((chk->>'rate_limited')::boolean,false)
        then 'Demasiados intentos. Espera 15 minutos antes de volver a probar.'
        else 'Código de equipo no válido.' end,
      'retry_after_seconds',coalesce((chk->>'retry_after_seconds')::integer,0)
    );
  end if;
  cid:=(chk->>'club_id')::uuid;
  ver:=(chk->>'version')::integer;

  if exists(select 1 from public.miembros_club m where m.club_id=cid and m.perfil_id=uid and m.activo) then
    raise exception 'Tu cuenta ya pertenece a este club';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(uid,coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),coalesce(auth.jwt()->'user_metadata'->>'apellidos',''))
  on conflict(id) do nothing;

  insert into public.kombax_solicitudes_equipo_club(
    club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,
    revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision
  )
  values(cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null)
  on conflict(club_id,perfil_id) do update set
    email=excluded.email,
    estado='pendiente',
    codigo_version=excluded.codigo_version,
    actualizado_en=now(),
    revisado_en=null,
    revisado_por=null,
    rol_asignado=null,
    coordinacion=false,
    nota_revision=null
  returning * into row;

  insert into public.notificaciones(
    club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
  )
  select
    cid,
    managers.perfil_id,
    'team-request-'||row.id::text,
    'inscripcion',
    'Nueva solicitud de acceso al equipo',
    coalesce(nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),''),mail)||' solicita acceso al equipo.',
    'users',
    jsonb_build_object(
      'team_request_id',row.id,
      'requester_profile_id',uid,
      'requester_email',mail,
      'requested_role',null
    ),
    uid
  from (
    select distinct m.perfil_id
    from public.miembros_club m
    where m.club_id=cid
      and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false))
  ) managers
  left join public.perfiles p on p.id=uid
  on conflict (club_id,perfil_id,clave)
    where clave is not null and perfil_id is not null
  do update set
    tipo=excluded.tipo,
    titulo=excluded.titulo,
    cuerpo=excluded.cuerpo,
    ruta=excluded.ruta,
    datos=excluded.datos,
    creada_por=excluded.creada_por,
    ciclo_estado='activo',
    leida=false,
    leida_en=null,
    creado_en=now();

  delete from public.notificaciones_lecturas nl
  using public.notificaciones n
  where nl.notificacion_id=n.id
    and n.club_id=cid
    and n.clave='team-request-'||row.id::text
    and n.perfil_id is not null;

  return jsonb_build_object('ok',true,'id',row.id,'club_id',row.club_id,'club_slug',chk->>'club_slug','club_nombre',chk->>'club_nombre','estado',row.estado,'creado_en',row.creado_en);
end
$function$;

CREATE OR REPLACE FUNCTION public.app_notificacion_requiere_accion_v034(p_notificacion_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_n public.notificaciones;
  v_id uuid;
  v_flag text;
begin
  if v_uid is null then return false; end if;
  select * into v_n
  from public.notificaciones n
  where n.id=p_notificacion_id
    and (
      n.perfil_id=v_uid
      or n.audiencia='todos' and public.es_miembro_club(n.club_id)
      or n.rol_destino is not null and public.tiene_rol_club(n.club_id,n.rol_destino)
    );
  if v_n.id is null then return false; end if;

  if v_n.tipo='inscripcion' and nullif(v_n.datos->>'team_request_id','') is not null then
    begin v_id:=(v_n.datos->>'team_request_id')::uuid; exception when others then return false; end;
    return exists(
      select 1
      from public.kombax_solicitudes_equipo_club r
      where r.club_id=v_n.club_id
        and r.id=v_id
        and r.estado='pendiente'
        and exists(
          select 1 from public.miembros_club m
          where m.club_id=v_n.club_id
            and m.perfil_id=v_uid
            and m.activo
            and (m.rol='direccion' or coalesce(m.coordinacion,false))
        )
    );
  end if;

  v_flag:=lower(coalesce(v_n.datos->>'requiere_accion',''));
  if v_flag in ('true','1','si','sí') then return true; end if;
  if v_flag in ('false','0','no') then return false; end if;

  if v_n.tipo='inscripcion' and nullif(v_n.datos->>'preinscripcion_id','') is not null then
    begin v_id:=(v_n.datos->>'preinscripcion_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.preinscripciones p
      where p.club_id=v_n.club_id and p.id=v_id
        and p.estado in ('enviada','en_revision','pendiente_documentacion')
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria')
    );
  end if;

  if v_n.tipo='material' and nullif(v_n.datos->>'pedido_id','') is not null then
    begin v_id:=(v_n.datos->>'pedido_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.material_pedidos mp
      where mp.club_id=v_n.club_id and mp.id=v_id
        and mp.estado in ('reservado','pendiente_validacion','preparado')
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
    );
  end if;

  if v_n.tipo in ('cuota','pago','validacion_pago') and nullif(v_n.datos->>'pago_id','') is not null then
    begin v_id:=(v_n.datos->>'pago_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.pagos p
      where p.club_id=v_n.club_id and p.id=v_id and p.estado_validacion='pendiente'
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
    );
  end if;

  if v_n.tipo in ('cuota','aviso_cobro') and nullif(v_n.datos->>'cuota_id','') is not null then
    begin v_id:=(v_n.datos->>'cuota_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.cuotas q
      where q.club_id=v_n.club_id and q.id=v_id
        and q.estado in ('pendiente','vencida','parcialmente_pagada','pendiente_validacion')
        and (
          public.puede_aportar_pago_socio(q.socio_id)
          or public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia')
        )
    );
  end if;

  if v_n.tipo='cuota' and nullif(v_n.datos->>'cantidad','') is not null
     and public.tiene_rol_club(v_n.club_id,'direccion','secretaria','economia') then
    return exists(select 1 from public.cuotas q where q.club_id=v_n.club_id and q.estado='vencida');
  end if;

  return false;
end
$function$;
