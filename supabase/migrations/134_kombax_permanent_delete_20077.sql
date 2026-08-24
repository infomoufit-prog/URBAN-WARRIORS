begin;

-- ---------------------------------------------------------------------------
-- Permanent deletion with impact preview (scoped, explicit, audited)
-- ---------------------------------------------------------------------------
create or replace function public.app_ciclo_eliminar_preview_v133(
  p_club_id uuid,p_recurso_tipo text,p_recurso_id uuid
) returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare
  v_dep jsonb:='{}'::jsonb; v_storage jsonb:='[]'::jsonb; v_urls jsonb:='[]'::jsonb;
  v_state text; v_title text; v_actionable boolean:=false; v_allowed boolean:=true; v_reason text:=null;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_gestionar_ciclo_v038(p_club_id) then raise exception 'LIFECYCLE_FORBIDDEN'; end if;
  if p_recurso_id is null then raise exception 'LIFECYCLE_RESOURCE_REQUIRED'; end if;

  case p_recurso_tipo
    when 'publicacion' then
      select ciclo_estado,coalesce(nullif(texto,''),'Publicación'),
        jsonb_build_object('likes',(select count(*) from public.comunidad_likes l where l.club_id=p_club_id and l.publicacion_id=p_recurso_id)),
        coalesce(jsonb_agg(distinct jsonb_build_object('bucket','community-media','path',x.path)) filter(where x.path is not null),'[]'::jsonb)
      into v_state,v_title,v_dep,v_storage
      from public.publicaciones_comunidad p
      left join lateral (values(nullif(p.media_path,'')),(nullif(p.portada_automatica_path,'')),(nullif(p.portada_manual_path,''))) x(path) on true
      where p.club_id=p_club_id and p.id=p_recurso_id group by p.id;
    when 'comunicacion' then
      select ciclo_estado,coalesce(titulo,'Comunicación'),
        jsonb_build_object('notificaciones',(select count(*) from public.notificaciones n where n.club_id=p_club_id and n.datos->>'comunicacion_id'=p_recurso_id::text)),
        case when nullif(imagen_url,'') is null then '[]'::jsonb else jsonb_build_array(imagen_url) end
      into v_state,v_title,v_dep,v_urls from public.comunicaciones where club_id=p_club_id and id=p_recurso_id;
    when 'evento' then
      select ciclo_estado,coalesce(nombre,'Evento'),jsonb_build_object(
        'participantes',(select count(*) from public.evento_participantes x where x.club_id=p_club_id and x.evento_id=p_recurso_id),
        'combates',(select count(*) from public.evento_combates x where x.club_id=p_club_id and x.evento_id=p_recurso_id)
      ) into v_state,v_title,v_dep from public.eventos_competicion where club_id=p_club_id and id=p_recurso_id;
    when 'notificacion' then
      select ciclo_estado,coalesce(titulo,'Notificación'),public.app_notificacion_requiere_accion_v034(id),jsonb_build_object(
        'lecturas',(select count(*) from public.notificaciones_lecturas x where x.notificacion_id=p_recurso_id)
      ) into v_state,v_title,v_actionable,v_dep from public.notificaciones where club_id=p_club_id and id=p_recurso_id;
      if v_actionable then v_allowed:=false;v_reason:='Las notificaciones con acciones pendientes no se eliminan hasta resolver la acción.';end if;
    when 'material' then
      select ciclo_estado,coalesce(nombre,'Material'),jsonb_build_object(
        'pedidos',(select count(*) from public.material_pedidos x where x.club_id=p_club_id and x.material_id=p_recurso_id),
        'entregas',(select count(*) from public.material_entregas x where x.club_id=p_club_id and x.material_id=p_recurso_id)
      ),case when nullif(imagen_url,'') is null then '[]'::jsonb else jsonb_build_array(imagen_url) end
      into v_state,v_title,v_dep,v_urls from public.material_catalogo where club_id=p_club_id and id=p_recurso_id;
      if coalesce((v_dep->>'pedidos')::int,0)+coalesce((v_dep->>'entregas')::int,0)>0 then
        v_allowed:=false;v_reason:='El artículo tiene pedidos o entregas. Se conserva como histórico; solo Owner+OTP puede ejecutar una depuración excepcional.';
      end if;
    when 'documento' then
      select ciclo_estado,coalesce(nombre,'Documento'),jsonb_build_object('sustituciones',(select count(*) from public.documentos_socios x where x.reemplazado_por=p_recurso_id)),
        jsonb_build_array(jsonb_build_object('bucket','member-documents','path',storage_path))
      into v_state,v_title,v_dep,v_storage from public.documentos_socios where club_id=p_club_id and id=p_recurso_id;
    when 'seguimiento' then
      select ciclo_estado,coalesce(tipo,'Seguimiento'),jsonb_build_object('registros',1)
      into v_state,v_title,v_dep from public.seguimiento where club_id=p_club_id and id=p_recurso_id;
    when 'asistencia' then
      select ciclo_estado,'Asistencia',jsonb_build_object('registros',1)
      into v_state,v_title,v_dep from public.asistencias where club_id=p_club_id and id=p_recurso_id;
    when 'sesion' then
      select ciclo_estado,'Sesión '||fecha::text,jsonb_build_object(
        'asistencias',(select count(*) from public.asistencias x where x.club_id=p_club_id and x.sesion_id=p_recurso_id),
        'reservas',(select count(*) from public.reservas_sesion x where x.club_id=p_club_id and x.sesion_id=p_recurso_id),
        'accesos',(select count(*) from public.registros_acceso_clase x where x.club_id=p_club_id and x.sesion_id=p_recurso_id)
      ) into v_state,v_title,v_dep from public.sesiones_entrenamiento where club_id=p_club_id and id=p_recurso_id;
    else raise exception 'LIFECYCLE_RESOURCE_INVALID';
  end case;
  if v_state is null then raise exception 'LIFECYCLE_RESOURCE_NOT_FOUND'; end if;
  if v_state<>'papelera' then v_allowed:=false;v_reason:=coalesce(v_reason,'Para eliminar definitivamente, mueve primero el elemento a Papelera.');end if;
  return jsonb_build_object('ok',true,'allowed',v_allowed,'reason',v_reason,'resource_type',p_recurso_tipo,'resource_id',p_recurso_id,
    'title',v_title,'state',v_state,'dependencies',v_dep,'storage_objects',v_storage,'public_image_urls',v_urls,
    'confirmation','ELIMINAR','warning','La eliminación definitiva no se puede deshacer. Las métricas agregadas no identificativas ya conservan el valor estadístico cuando corresponde.');
end $$;
revoke all on function public.app_ciclo_eliminar_preview_v133(uuid,text,uuid) from public,anon;
grant execute on function public.app_ciclo_eliminar_preview_v133(uuid,text,uuid) to authenticated;

create or replace function public.app_ciclo_eliminar_definitivo_v133(
  p_club_id uuid,p_recurso_tipo text,p_recurso_id uuid,p_confirmacion text
) returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid(); v_plan jsonb; v_storage jsonb; v_urls jsonb; v_deleted int:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if upper(btrim(coalesce(p_confirmacion,'')))<>'ELIMINAR' then raise exception 'LIFECYCLE_DELETE_CONFIRMATION_REQUIRED'; end if;
  v_plan:=public.app_ciclo_eliminar_preview_v133(p_club_id,p_recurso_tipo,p_recurso_id);
  if coalesce((v_plan->>'allowed')::boolean,false) is not true then raise exception 'LIFECYCLE_DELETE_NOT_ALLOWED:%',coalesce(v_plan->>'reason',''); end if;
  v_storage:=coalesce(v_plan->'storage_objects','[]'::jsonb);v_urls:=coalesce(v_plan->'public_image_urls','[]'::jsonb);
  perform set_config('kombax.lifecycle_gateway','on',true);
  case p_recurso_tipo
    when 'publicacion' then delete from public.publicaciones_comunidad where club_id=p_club_id and id=p_recurso_id;
    when 'comunicacion' then
      delete from public.notificaciones where club_id=p_club_id and datos->>'comunicacion_id'=p_recurso_id::text;
      delete from public.comunicaciones where club_id=p_club_id and id=p_recurso_id;
    when 'evento' then delete from public.eventos_competicion where club_id=p_club_id and id=p_recurso_id;
    when 'notificacion' then delete from public.notificaciones where club_id=p_club_id and id=p_recurso_id;
    when 'material' then delete from public.material_catalogo where club_id=p_club_id and id=p_recurso_id;
    when 'documento' then delete from public.documentos_socios where club_id=p_club_id and id=p_recurso_id;
    when 'seguimiento' then delete from public.seguimiento where club_id=p_club_id and id=p_recurso_id;
    when 'asistencia' then delete from public.asistencias where club_id=p_club_id and id=p_recurso_id;
    when 'sesion' then delete from public.sesiones_entrenamiento where club_id=p_club_id and id=p_recurso_id;
    else raise exception 'LIFECYCLE_RESOURCE_INVALID';
  end case;
  get diagnostics v_deleted=row_count;
  if v_deleted=0 then raise exception 'LIFECYCLE_RESOURCE_NOT_FOUND'; end if;
  insert into public.contenido_ciclo_auditoria(club_id,recurso_tipo,recurso_id,accion,estado_anterior,estado_nuevo,motivo,realizado_por)
  values(p_club_id,p_recurso_tipo,p_recurso_id,'eliminar_definitivo','papelera','eliminado','Eliminación definitiva confirmada con previsualización de impacto',v_uid);
  return jsonb_build_object('ok',true,'deleted',true,'resource_type',p_recurso_tipo,'resource_id',p_recurso_id,
    'storage_objects',v_storage,'public_image_urls',v_urls,'dependencies',v_plan->'dependencies');
end $$;
revoke all on function public.app_ciclo_eliminar_definitivo_v133(uuid,text,uuid,text) from public,anon;
grant execute on function public.app_ciclo_eliminar_definitivo_v133(uuid,text,uuid,text) to authenticated;

-- ---------------------------------------------------------------------------

notify pgrst,'reload schema';
commit;
