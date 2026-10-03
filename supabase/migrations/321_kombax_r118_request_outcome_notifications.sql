-- KOMBAX R118 · request outcome notifications
-- Additive behavior only: existing manager task notifications keep their lifecycle.
-- This adds explicit requester feedback after approval/rejection.

CREATE OR REPLACE FUNCTION private.kombax_club_link_notification_sync_r117()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
declare
  v_name text;
  v_result text;
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

      v_result:=lower(coalesce(new.resolution,''));
      if v_result in ('approved','rejected') then
        insert into public.notificaciones(
          club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
        ) values(
          new.club_id,new.account_id,
          'club-link-'||v_result||'-'||new.id::text,
          'inscripcion',
          case when v_result='approved' then 'Vinculación aprobada' else 'Vinculación rechazada' end,
          case
            when v_result='approved' and new.request_kind='family' then 'El club ha autorizado tu acceso familiar.'
            when v_result='approved' then 'El club ha confirmado tu membresía.'
            else 'El club ha revisado y rechazado la solicitud de vinculación.'
          end,
          case when v_result='approved' and new.request_kind='family' then 'students'
               when v_result='approved' then 'social'
               else 'dashboard' end,
          jsonb_build_object(
            'thread_id',new.id,'club_id',new.club_id,'request_kind',new.request_kind,
            'outcome',v_result,'target_socio_id',new.target_socio_id
          ),
          new.resolved_by
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

CREATE OR REPLACE FUNCTION private.kombax_membership_claim_notification_sync_r117()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','auth'
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

      if new.estado in ('aprobada','rechazada') then
        insert into public.notificaciones(
          club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
        ) values(
          new.club_id,new.account_id,
          'membership-claim-'||case when new.estado='aprobada' then 'approved' else 'rejected' end||'-'||new.id::text,
          'inscripcion',
          case when new.estado='aprobada' then 'Vinculación aprobada' else 'Vinculación rechazada' end,
          case when new.estado='aprobada'
            then 'El club ha vinculado tu cuenta con tu ficha de alumno.'
            else 'El club ha revisado y rechazado la solicitud de vinculación a la ficha.'
          end,
          'dashboard',
          jsonb_build_object(
            'membership_claim_id',new.id,'socio_id',new.socio_id,
            'outcome',case when new.estado='aprobada' then 'approved' else 'rejected' end
          ),
          new.resuelto_por
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

CREATE OR REPLACE FUNCTION private.kombax_team_request_notification_sync_r117()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
declare
  v_name text;
  v_role text;
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

      if new.estado in ('aprobada','rechazada') then
        v_role:=case when coalesce(new.coordinacion,false) then 'coordinacion'
                     else new.rol_asignado::text end;
        insert into public.notificaciones(
          club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
        ) values(
          new.club_id,new.perfil_id,
          'team-request-'||case when new.estado='aprobada' then 'approved' else 'rejected' end||'-'||new.id::text,
          'inscripcion',
          case when new.estado='aprobada' then 'Acceso al equipo aprobado' else 'Solicitud de equipo rechazada' end,
          case when new.estado='aprobada'
            then 'El club ha aprobado tu acceso al equipo'||case when v_role is not null then ' como '||v_role else '' end||'.'
            else 'El club ha revisado y rechazado tu solicitud de acceso al equipo.'
          end,
          'dashboard',
          jsonb_build_object(
            'team_request_id',new.id,'club_id',new.club_id,
            'outcome',case when new.estado='aprobada' then 'approved' else 'rejected' end,
            'role',v_role
          ),
          new.revisado_por
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

do $$
begin
  if position('Acceso al equipo aprobado' in pg_get_functiondef('private.kombax_team_request_notification_sync_r117()'::regprocedure))=0 then
    raise exception 'R118_ASSERT_TEAM_OUTCOME_NOTIFICATION_MISSING';
  end if;
  if position('Vinculación rechazada' in pg_get_functiondef('private.kombax_membership_claim_notification_sync_r117()'::regprocedure))=0 then
    raise exception 'R118_ASSERT_CLAIM_REJECTION_NOTIFICATION_MISSING';
  end if;
end $$;
