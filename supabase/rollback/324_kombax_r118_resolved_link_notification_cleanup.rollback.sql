-- R118 rollback: restore exact prior club-link notification trigger.
-- Historical manager notifications archived by the backfill are intentionally not reopened.
CREATE OR REPLACE FUNCTION private.kombax_club_link_notification_sync_r117()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_name text;
  v_result text;
  v_lifecycle_gateway text:=coalesce(current_setting('kombax.lifecycle_gateway',true),'');
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
      perform set_config('kombax.lifecycle_gateway','on',true);
      update public.notificaciones n
      set ciclo_estado='archivado',archivado_en=coalesce(n.archivado_en,now()),
          leida=true,leida_en=coalesce(n.leida_en,now())
      where n.club_id=new.club_id
        and n.ciclo_estado='activo'
        and n.datos->>'thread_id'=new.id::text
        and n.datos->>'kind'='club_link_request';
      perform set_config('kombax.lifecycle_gateway',v_lifecycle_gateway,true);

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
