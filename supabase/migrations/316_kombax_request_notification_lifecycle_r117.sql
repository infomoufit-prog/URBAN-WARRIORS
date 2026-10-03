-- KOMBAX R117 build 20176
-- Consolidates live migration request_notification_lifecycle_r117_27.
-- Pending actions remain visible until the underlying entity is resolved.

CREATE OR REPLACE FUNCTION private.kombax_club_link_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_name text;
begin
  if tg_op='INSERT' or old.estado is distinct from new.estado then
    select nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),'') into v_name
    from public.perfiles p where p.id=new.account_id;

    if new.estado='abierta' then
      insert into public.notificaciones(
        club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,rol,'club-link-'||new.id::text||'-'||rol::text,'inscripcion',
        case when new.request_kind='family' then 'Solicitud de vinculación familiar'
             else 'Solicitud de vinculación como miembro' end,
        coalesce(v_name,'Una cuenta KOMBAX')||' solicita autorización del club.',
        'members',
        jsonb_build_object(
          'thread_id',new.id,'account_id',new.account_id,'kind','club_link_request',
          'request_kind',new.request_kind,'target_socio_id',new.target_socio_id
        ),
        new.account_id
      from unnest(array['direccion','secretaria']::public.rol_club[]) rol
      on conflict (club_id,rol_destino,clave)
      where clave is not null and rol_destino is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'thread_id'=new.id::text
        and n.datos->>'kind'='club_link_request';
    end if;
  end if;
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION private.kombax_membership_claim_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_name text;
begin
  if tg_op='INSERT' or old.estado is distinct from new.estado then
    select nullif(trim(concat_ws(' ',s.nombre,s.apellidos)),'') into v_name
    from public.socios s where s.id=new.socio_id and s.club_id=new.club_id;

    if new.estado='pendiente' then
      insert into public.notificaciones(
        club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,rol,'membership-claim-'||new.id::text||'-'||rol::text,'inscripcion',
        'Solicitud de vinculación a ficha existente',
        coalesce(v_name,'Un alumno')||' solicita vincular su cuenta KOMBAX.',
        'members',
        jsonb_build_object(
          'membership_claim_id',new.id,'socio_id',new.socio_id,'account_id',new.account_id
        ),
        new.account_id
      from unnest(array['direccion','secretaria']::public.rol_club[]) rol
      on conflict (club_id,rol_destino,clave)
      where clave is not null and rol_destino is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'membership_claim_id'=new.id::text;

      if new.estado='aprobada' then
        insert into public.notificaciones(
          club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
        ) values(
          new.club_id,new.account_id,'membership-claim-approved-'||new.id::text,
          'inscripcion','Vinculación aprobada',
          'El club ha vinculado tu cuenta con tu ficha de alumno.',
          'dashboard',
          jsonb_build_object('membership_claim_id',new.id,'socio_id',new.socio_id),
          case when exists(select 1 from public.perfiles p where p.id=auth.uid()) then auth.uid() else null end
        )
        on conflict (club_id,perfil_id,clave)
        where clave is not null and perfil_id is not null
        do nothing;
      end if;
    end if;
  end if;
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION private.kombax_payment_validation_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if tg_op='INSERT' or old.estado_validacion is distinct from new.estado_validacion then
    if new.estado_validacion='pendiente' then
      insert into public.notificaciones(
        club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,rol,'pago-pendiente-'||new.id||'-'||rol::text,'cuota',
        'Justificante pendiente de validar',
        'Un usuario ha comunicado un pago pendiente de validación.',
        'fees',
        jsonb_build_object('cuota_id',new.cuota_id,'pago_id',new.id),
        case when exists(select 1 from public.perfiles p where p.id=auth.uid()) then auth.uid() else null end
      from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol
      on conflict(club_id,rol_destino,clave)
      where clave is not null and rol_destino is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'pago_id'=new.id::text
        and n.clave like 'pago-pendiente-%';
    end if;
  end if;
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION private.kombax_preinscripcion_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
begin
  if tg_op='INSERT' or old.estado is distinct from new.estado then
    if new.estado in ('enviada','en_revision','pendiente_documentacion') then
      insert into public.notificaciones(
        club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,rol,
        'preinscripcion-'||new.id||'-'||rol::text,
        'inscripcion','Nueva preinscripción',
        trim(concat_ws(' ',new.nombre,new.apellidos))||' ha enviado una solicitud.',
        'enrollments',
        jsonb_build_object('preinscripcion_id',new.id,'self_service',new.solicitante_perfil_id is not null),
        case when exists(select 1 from public.perfiles p where p.id=auth.uid()) then auth.uid() else null end
      from unnest(array['direccion','secretaria']::public.rol_club[]) rol
      on conflict(club_id,rol_destino,clave)
      where clave is not null and rol_destino is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'preinscripcion_id'=new.id::text
        and n.rol_destino is not null;
    end if;
  end if;
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION private.kombax_team_request_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_name text;
begin
  if tg_op='INSERT' or old.estado is distinct from new.estado then
    select nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),'') into v_name
    from public.perfiles p where p.id=new.perfil_id;

    if new.estado='pendiente' then
      insert into public.notificaciones(
        club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
      )
      select
        new.club_id,m.perfil_id,'team-request-'||new.id::text,'inscripcion',
        'Nueva solicitud de acceso al equipo',
        coalesce(v_name,new.email,'Una cuenta KOMBAX')||
          case when new.rol_solicitado is not null then ' solicita acceso como '||new.rol_solicitado||'.'
               else ' solicita acceso al equipo.' end,
        'users',
        jsonb_build_object(
          'team_request_id',new.id,'requester_profile_id',new.perfil_id,
          'requester_email',new.email,'requested_role',new.rol_solicitado
        ),
        new.perfil_id
      from (
        select distinct mc.perfil_id
        from public.miembros_club mc
        where mc.club_id=new.club_id and mc.activo
          and (mc.rol='direccion' or coalesce(mc.coordinacion,false))
      ) m
      on conflict (club_id,perfil_id,clave)
      where clave is not null and perfil_id is not null
      do update set
        titulo=excluded.titulo,cuerpo=excluded.cuerpo,ruta=excluded.ruta,datos=excluded.datos,
        ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
    else
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'team_request_id'=new.id::text;
    end if;
  end if;
  return new;
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
      select 1 from public.kombax_solicitudes_equipo_club r
      where r.club_id=v_n.club_id and r.id=v_id and r.estado='pendiente'
        and exists(
          select 1 from public.miembros_club m
          where m.club_id=v_n.club_id and m.perfil_id=v_uid and m.activo
            and (m.rol='direccion' or coalesce(m.coordinacion,false))
        )
    );
  end if;

  if v_n.tipo='inscripcion' and nullif(v_n.datos->>'thread_id','') is not null
     and v_n.datos->>'kind'='club_link_request' then
    begin v_id:=(v_n.datos->>'thread_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.kombax_club_interest_threads_r58 t
      where t.club_id=v_n.club_id and t.id=v_id and t.estado='abierta'
        and (
          public.tiene_rol_club(v_n.club_id,'direccion','secretaria')
          or exists(
            select 1 from public.miembros_club mc
            where mc.club_id=v_n.club_id and mc.perfil_id=v_uid and mc.activo and mc.coordinacion
          )
        )
    );
  end if;

  if v_n.tipo='inscripcion' and nullif(v_n.datos->>'membership_claim_id','') is not null then
    begin v_id:=(v_n.datos->>'membership_claim_id')::uuid; exception when others then return false; end;
    return exists(
      select 1 from public.kombax_membership_claims_r58 c
      where c.club_id=v_n.club_id and c.id=v_id and c.estado='pendiente'
        and public.tiene_rol_club(v_n.club_id,'direccion','secretaria')
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

drop trigger if exists trg_kombax_club_link_notification_sync_r117 on public.kombax_club_interest_threads_r58;
CREATE TRIGGER trg_kombax_club_link_notification_sync_r117 AFTER INSERT OR UPDATE OF estado ON kombax_club_interest_threads_r58 FOR EACH ROW EXECUTE FUNCTION private.kombax_club_link_notification_sync_r117();

drop trigger if exists trg_kombax_membership_claim_notification_sync_r117 on public.kombax_membership_claims_r58;
CREATE TRIGGER trg_kombax_membership_claim_notification_sync_r117 AFTER INSERT OR UPDATE OF estado ON kombax_membership_claims_r58 FOR EACH ROW EXECUTE FUNCTION private.kombax_membership_claim_notification_sync_r117();

drop trigger if exists trg_kombax_payment_validation_notification_sync_r117 on public.pagos;
CREATE TRIGGER trg_kombax_payment_validation_notification_sync_r117 AFTER INSERT OR UPDATE OF estado_validacion ON pagos FOR EACH ROW EXECUTE FUNCTION private.kombax_payment_validation_notification_sync_r117();

drop trigger if exists trg_kombax_preinscripcion_notification_sync_r117 on public.preinscripciones;
CREATE TRIGGER trg_kombax_preinscripcion_notification_sync_r117 AFTER INSERT OR UPDATE OF estado ON preinscripciones FOR EACH ROW EXECUTE FUNCTION private.kombax_preinscripcion_notification_sync_r117();

drop trigger if exists trg_kombax_team_request_notification_sync_r117 on public.kombax_solicitudes_equipo_club;
CREATE TRIGGER trg_kombax_team_request_notification_sync_r117 AFTER INSERT OR UPDATE OF estado ON kombax_solicitudes_equipo_club FOR EACH ROW EXECUTE FUNCTION private.kombax_team_request_notification_sync_r117();

-- Backfill only real pending records; no synthetic QA data.
insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
select p.club_id,rol,'pago-pendiente-'||p.id||'-'||rol::text,'cuota',
       'Justificante pendiente de validar','Un usuario ha comunicado un pago pendiente de validación.',
       'fees',jsonb_build_object('cuota_id',p.cuota_id,'pago_id',p.id),p.comunicado_por
from public.pagos p
cross join unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol
where p.estado_validacion='pendiente'
on conflict(club_id,rol_destino,clave)
where clave is not null and rol_destino is not null
do update set ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;

insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
select c.club_id,rol,'membership-claim-'||c.id::text||'-'||rol::text,'inscripcion',
       'Solicitud de vinculación a ficha existente',
       trim(concat_ws(' ',s.nombre,s.apellidos))||' solicita vincular su cuenta KOMBAX.',
       'members',jsonb_build_object('membership_claim_id',c.id,'socio_id',c.socio_id,'account_id',c.account_id),c.account_id
from public.kombax_membership_claims_r58 c
join public.socios s on s.id=c.socio_id and s.club_id=c.club_id
cross join unnest(array['direccion','secretaria']::public.rol_club[]) rol
where c.estado='pendiente'
on conflict(club_id,rol_destino,clave)
where clave is not null and rol_destino is not null
do update set ciclo_estado='activo',archivado_en=null,archivado_por=null,papelera_en=null,papelera_por=null;
