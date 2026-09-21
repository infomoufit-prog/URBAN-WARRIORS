-- KOMBAX RC13 build 20077 · Global data lifecycle & history hardening
-- Safe lifecycle + metrics + retention: operational data is paginated, expendable data is purged,
-- useful historical facts are aggregated into non-identifying metrics before retention cleanup.
-- Normal users keep explicit, impact-previewed permanent deletion for scoped content.
-- Legacy blind deep-delete operations remain restricted to MFA-privileged platform Owner or synthetic E2E cleanup data.

begin;

create or replace function public.app_kombax_force_delete_is_qa_v133(p_operation text,p_payload jsonb)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  begin
    v_id:=case p_operation
      when 'grupo.eliminar_forzado' then nullif(p_payload->>'grupo_id','')::uuid
      when 'alumno.eliminar_forzado' then nullif(p_payload->>'socio_id','')::uuid
      when 'sesion.eliminar_forzado' then nullif(p_payload->>'sesion_id','')::uuid
      when 'disciplina.eliminar_forzado' then nullif(p_payload->>'disciplina_id','')::uuid
      when 'grado.eliminar_forzado' then nullif(p_payload->>'grado_id','')::uuid
      when 'tarifa.eliminar_forzado' then nullif(p_payload->>'tarifa_id','')::uuid
      when 'material.eliminar_forzado' then nullif(p_payload->>'material_id','')::uuid
      else null end;
  exception when others then return false; end;
  if v_id is null then return false; end if;
  return case p_operation
    when 'grupo.eliminar_forzado' then exists(select 1 from public.grupos where id=v_id and nombre like 'E2E_RC10_%')
    when 'alumno.eliminar_forzado' then exists(select 1 from public.socios where id=v_id and (apellidos like 'E2E_RC10_%' or nombre like 'E2E_RC10_%'))
    when 'sesion.eliminar_forzado' then exists(select 1 from public.sesiones_entrenamiento where id=v_id and coalesce(observacion_general,'') ilike '%E2E%')
    when 'disciplina.eliminar_forzado' then exists(select 1 from public.disciplinas where id=v_id and nombre like 'E2E_RC10_%')
    when 'grado.eliminar_forzado' then exists(select 1 from public.grados where id=v_id and nombre like 'E2E_RC10_%')
    when 'tarifa.eliminar_forzado' then exists(select 1 from public.tarifas where id=v_id and nombre like 'E2E_RC10_%')
    when 'material.eliminar_forzado' then exists(select 1 from public.material_catalogo where id=v_id and nombre like 'E2E_RC10_%')
    else false end;
end $$;
revoke all on function public.app_kombax_force_delete_is_qa_v133(text,jsonb) from public,anon,authenticated;
grant execute on function public.app_kombax_force_delete_is_qa_v133(text,jsonb) to service_role;

-- Wrap the active mutation gateway without changing its existing contract.
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_lifecycle_133;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_lifecycle_133(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_destructive constant text[]:=array[
    'grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado',
    'disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado',
    'material.eliminar_forzado','publicacion.limpiar_antiguas'
  ];
begin
  if p_operation=any(v_destructive)
     and not coalesce(public.app_kombax_es_platform_admin_v055(),false)
     and not public.app_kombax_force_delete_is_qa_v133(p_operation,coalesce(p_payload,'{}'::jsonb)) then
    raise exception 'KOMBAX_DESTRUCTIVE_DELETE_OWNER_MFA_REQUIRED';
  end if;
  return public.app_mutate_v160_pre_lifecycle_133(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Expire trash safely: after 30 days it becomes non-restorable archived history.
create or replace function public.app_ciclo_expirar_club_v133(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_table text; v_type text; v_count integer; v_total integer:=0; v_ids uuid[];
begin
  if p_club_id is null then raise exception 'LIFECYCLE_CLUB_REQUIRED'; end if;
  foreach v_type in array array['publicacion','comunicacion','evento','notificacion','material','documento','seguimiento','asistencia','sesion'] loop
    v_table:=case v_type
      when 'publicacion' then 'publicaciones_comunidad' when 'comunicacion' then 'comunicaciones'
      when 'evento' then 'eventos_competicion' when 'notificacion' then 'notificaciones'
      when 'material' then 'material_catalogo' when 'documento' then 'documentos_socios'
      when 'seguimiento' then 'seguimiento' when 'asistencia' then 'asistencias'
      when 'sesion' then 'sesiones_entrenamiento' end;
    execute format('select array_agg(id) from public.%I where club_id=$1 and ciclo_estado=''papelera'' and restaurar_hasta is not null and restaurar_hasta<=now()',v_table)
      into v_ids using p_club_id;
    v_count:=coalesce(array_length(v_ids,1),0);
    if v_count>0 then
      perform set_config('kombax.lifecycle_gateway','on',true);
      execute format('update public.%I set ciclo_estado=''archivado'',archivado_en=coalesce(archivado_en,now()),archivado_por=coalesce(archivado_por,papelera_por),papelera_en=null,papelera_por=null,restaurar_hasta=null where club_id=$1 and id=any($2)',v_table)
        using p_club_id,v_ids;
      insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
      select p_club_id,v_type,x,'papelera_expirada','papelera','archivado','Fin de ventana de restauración de 30 días',null
      from unnest(v_ids) x;
      v_total:=v_total+v_count;
    end if;
  end loop;
  -- Operational retention: keep normal screens short without destroying traceability.
  -- Completed/cancelled sessions older than 60 days become Historical.
  select array_agg(id) into v_ids
  from public.sesiones_entrenamiento
  where club_id=p_club_id and ciclo_estado='activo' and estado in ('completada','cancelada') and fecha < current_date-60;
  v_count:=coalesce(array_length(v_ids,1),0);
  if v_count>0 then
    perform set_config('kombax.lifecycle_gateway','on',true);
    update public.sesiones_entrenamiento set ciclo_estado='archivado',archivado_en=now(),archivado_por=null
    where club_id=p_club_id and id=any(v_ids);
    insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
    select p_club_id,'sesion',x,'archivo_automatico','activo','archivado','Sesión finalizada hace más de 60 días',null from unnest(v_ids) x;
    v_total:=v_total+v_count;
  end if;

  -- Informational notifications older than 90 days leave the active center.
  select array_agg(id) into v_ids
  from public.notificaciones n
  where n.club_id=p_club_id and n.ciclo_estado='activo' and n.creado_en < now()-interval '90 days'
    and not public.app_notificacion_requiere_accion_v034(n.id);
  v_count:=coalesce(array_length(v_ids,1),0);
  if v_count>0 then
    perform set_config('kombax.lifecycle_gateway','on',true);
    update public.notificaciones set ciclo_estado='archivado',archivado_en=now(),archivado_por=null
    where club_id=p_club_id and id=any(v_ids);
    insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
    select p_club_id,'notificacion',x,'archivo_automatico','activo','archivado','Aviso informativo con más de 90 días',null from unnest(v_ids) x;
    v_total:=v_total+v_count;
  end if;

  return jsonb_build_object('ok',true,'club_id',p_club_id,'procesados',v_total);
end $$;
revoke all on function public.app_ciclo_expirar_club_v133(uuid) from public,anon,authenticated;
grant execute on function public.app_ciclo_expirar_club_v133(uuid) to service_role;

create or replace function public.app_ciclo_mantenimiento_v133(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_gestionar_ciclo_v038(p_club_id) then raise exception 'LIFECYCLE_FORBIDDEN'; end if;
  return public.app_ciclo_expirar_club_v133(p_club_id);
end $$;
revoke all on function public.app_ciclo_mantenimiento_v133(uuid) from public,anon;
grant execute on function public.app_ciclo_mantenimiento_v133(uuid) to authenticated;

-- Global scheduled entrypoint. Service role only.
create or replace function public.app_ciclo_mantenimiento_global_v133()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid; v_total integer:=0; v_result jsonb;
begin
  for v_club in select id from public.clubes loop
    v_result:=public.app_ciclo_expirar_club_v133(v_club);
    v_total:=v_total+coalesce((v_result->>'procesados')::integer,0);
  end loop;
  return jsonb_build_object('ok',true,'expirados',v_total,'checked_at',now());
end $$;
revoke all on function public.app_ciclo_mantenimiento_global_v133() from public,anon,authenticated;
grant execute on function public.app_ciclo_mantenimiento_global_v133() to service_role;

-- Restore guard: expired trash can no longer be restored. Archive remains restorable manually.
create or replace function public.app_ciclo_accion_v038(
  p_club_id uuid,p_recurso_tipo text,p_ids uuid[],p_accion text,p_motivo text default null
) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_table text;v_id uuid;v_old text;v_new text;v_count integer:=0;v_restore timestamptz;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_gestionar_ciclo_v038(p_club_id) then raise exception 'LIFECYCLE_FORBIDDEN'; end if;
  if p_accion is null or p_accion not in ('archivar','papelera','restaurar') then raise exception 'LIFECYCLE_ACTION_INVALID'; end if;
  if coalesce(array_length(p_ids,1),0)=0 or array_length(p_ids,1)>200 then raise exception 'LIFECYCLE_IDS_INVALID'; end if;
  v_table:=case p_recurso_tipo
    when 'publicacion' then 'publicaciones_comunidad' when 'comunicacion' then 'comunicaciones'
    when 'evento' then 'eventos_competicion' when 'notificacion' then 'notificaciones'
    when 'material' then 'material_catalogo' when 'documento' then 'documentos_socios'
    when 'seguimiento' then 'seguimiento' when 'asistencia' then 'asistencias'
    when 'sesion' then 'sesiones_entrenamiento' else null end;
  if v_table is null then raise exception 'LIFECYCLE_RESOURCE_INVALID'; end if;
  if p_recurso_tipo='notificacion' and p_accion<>'restaurar' and exists(
    select 1 from public.notificaciones n where n.club_id=p_club_id and n.id=any(p_ids)
      and public.app_notificacion_requiere_accion_v034(n.id)
  ) then raise exception 'LIFECYCLE_ACTIONABLE_NOTIFICATION'; end if;

  perform set_config('kombax.lifecycle_gateway','on',true);
  foreach v_id in array p_ids loop
    execute format('select ciclo_estado,restaurar_hasta from public.%I where club_id=$1 and id=$2 for update',v_table)
      into v_old,v_restore using p_club_id,v_id;
    if v_old is null then continue; end if;
    if p_accion='restaurar' and v_old='papelera' and v_restore is not null and v_restore<=now() then
      raise exception 'LIFECYCLE_RESTORE_EXPIRED';
    end if;
    v_new:=case p_accion when 'archivar' then 'archivado' when 'papelera' then 'papelera' else 'activo' end;
    if v_old=v_new then continue; end if;
    execute format('update public.%I set ciclo_estado=$1,archivado_en=case when $1=''archivado'' then coalesce(archivado_en,now()) when $1=''activo'' then null else archivado_en end,archivado_por=case when $1=''archivado'' then coalesce(archivado_por,$2) when $1=''activo'' then null else archivado_por end,papelera_en=case when $1=''papelera'' then now() else null end,papelera_por=case when $1=''papelera'' then $2 else null end,restaurar_hasta=case when $1=''papelera'' then now()+interval ''30 days'' else null end where club_id=$3 and id=$4',v_table)
      using v_new,v_uid,p_club_id,v_id;
    insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
    values(p_club_id,p_recurso_tipo,v_id,p_accion,v_old,v_new,nullif(btrim(coalesce(p_motivo,'')),''),v_uid);
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'club_id',p_club_id,'recurso_tipo',p_recurso_tipo,'accion',p_accion,'actualizados',v_count);
end $$;
revoke all on function public.app_ciclo_accion_v038(uuid,text,uuid[],text,text) from public,anon;
grant execute on function public.app_ciclo_accion_v038(uuid,text,uuid[],text,text) to authenticated;

-- Indexes for high-growth operational history.
create index if not exists idx_kombax_sessions_cycle_date_v133 on public.sesiones_entrenamiento(club_id,ciclo_estado,fecha desc,id desc);
create index if not exists idx_kombax_attendance_cycle_time_v133 on public.asistencias(club_id,ciclo_estado,registrado_en desc,id desc);
create index if not exists idx_kombax_notifications_cycle_time_v133 on public.notificaciones(club_id,ciclo_estado,creado_en desc,id desc);
create index if not exists idx_kombax_documents_cycle_time_v133 on public.documentos_socios(club_id,ciclo_estado,creado_en desc,id desc);
create index if not exists idx_kombax_tracking_cycle_date_v133 on public.seguimiento(club_id,ciclo_estado,fecha desc,id desc);
create index if not exists idx_kombax_material_orders_time_v133 on public.material_pedidos(club_id,creado_en desc,id desc);
create index if not exists idx_kombax_fees_due_v133 on public.cuotas(club_id,vencimiento desc,id desc);
create index if not exists idx_kombax_payments_date_v133 on public.pagos(club_id,fecha desc,id desc);
create index if not exists idx_kombax_receipts_period_v133 on public.recibos_cuota(club_id,periodo desc,id desc);
create index if not exists idx_kombax_contacts_actor_created_v133 on public.kombax_social_contactos(remitente_social_id,creado_en desc,id desc);
create index if not exists idx_kombax_contacts_target_created_v133 on public.kombax_social_contactos(destinatario_social_id,creado_en desc,id desc);


-- Bounded readers for high-growth non-feed areas. Old RPCs remain as compatibility fallbacks.
create or replace function public.app_kombax_contactos_v133(p_limit integer default 50)
returns table(
  id uuid,remitente_id uuid,remitente_nombre text,destinatario_id uuid,destinatario_nombre text,
  motivo text,estado text,creado_en timestamptz,respondido_en timestamptz,cerrado_en timestamptz,
  direccion text,gestionable boolean,ultimo_mensaje text,ultimo_mensaje_en timestamptz,no_leidos integer,
  puede_chat boolean,puede_cerrar boolean,canal text,showcase_elemento_id uuid,showcase_producto_nombre text,
  showcase_producto_imagen_url text,showcase_marca_nombre text
)
language sql stable security definer set search_path=public,auth as $$
  select * from public.app_kombax_contactos_v107()
  limit least(greatest(coalesce(p_limit,50),1),200);
$$;
revoke all on function public.app_kombax_contactos_v133(integer) from public,anon;
grant execute on function public.app_kombax_contactos_v133(integer) to authenticated;

create or replace function public.app_kombax_relaciones_v133(p_social_id uuid,p_limit integer default 50)
returns table(
  id uuid,origen_social_id uuid,origen_nombre text,destino_social_id uuid,destino_nombre text,
  tipo text,estado text,nota text,creado_en timestamptz,confirmado_en timestamptz,gestionable boolean
)
language sql stable security definer set search_path=public,auth as $$
  select * from public.app_kombax_relaciones_v068(p_social_id)
  limit least(greatest(coalesce(p_limit,50),1),150);
$$;
revoke all on function public.app_kombax_relaciones_v133(uuid,integer) from public,anon;
grant execute on function public.app_kombax_relaciones_v133(uuid,integer) to authenticated;

create or replace function public.app_kombax_showcase_mis_elementos_v133(p_marca_id uuid,p_limit integer default 60)
returns table(
  id uuid,marca_id uuid,categoria_id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,
  precio_orientativo numeric,moneda text,visitar_url text,donde_encontrar_url text,contacto_url text,estado text,destacado boolean,
  etiqueta_destacada text,publicado_en timestamptz,actualizado_en timestamptz,cta_tipo text,cta_label text
)
language sql stable security definer set search_path=public,auth as $$
  select * from public.app_kombax_showcase_mis_elementos_v054(p_marca_id)
  limit least(greatest(coalesce(p_limit,60),1),200);
$$;
revoke all on function public.app_kombax_showcase_mis_elementos_v133(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_mis_elementos_v133(uuid,integer) to authenticated;

-- Server-side notification center default is reduced; callers can progressively request more up to 300.
create or replace function public.app_notificaciones_centro_v133(p_club_id uuid,p_limit integer default 120)
returns setof jsonb language sql stable security definer set search_path=public,auth as $$
  select * from public.app_notificaciones_centro_v037(p_club_id,least(greatest(coalesce(p_limit,120),1),300));
$$;
revoke all on function public.app_notificaciones_centro_v133(uuid,integer) from public,anon;
grant execute on function public.app_notificaciones_centro_v133(uuid,integer) to authenticated;



notify pgrst,'reload schema';
commit;
