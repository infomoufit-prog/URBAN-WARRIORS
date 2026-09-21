-- KOMBAX RC13 build 20041 · ciclo de vida del contenido + eliminación segura.
-- Objetivos: eliminación real de publicaciones propias y fichas Showcase,
-- eliminación por participante de Contacto KOMBAX sin borrar la copia de la contraparte,
-- y gateways versionados para mantener compatibilidad.
begin;

alter table public.kombax_social_contactos
  add column if not exists eliminado_remitente_en timestamptz,
  add column if not exists eliminado_destinatario_en timestamptz;

-- Acceso a un contacto desde la perspectiva actual: debe quedar al menos una identidad
-- controlada por el usuario cuya copia no haya sido eliminada.
create or replace function public.app_kombax_contact_can_access_v067(p_contacto_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.kombax_social_contactos c
    where c.id=p_contacto_id and (
      (public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) and c.eliminado_remitente_en is null)
      or
      (public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id) and c.eliminado_destinatario_en is null)
    )
  );
$$;
revoke all on function public.app_kombax_contact_can_access_v067(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_contactos_v067()
returns table(
  id uuid,remitente_id uuid,remitente_nombre text,destinatario_id uuid,destinatario_nombre text,
  motivo text,estado text,creado_en timestamptz,respondido_en timestamptz,cerrado_en timestamptz,
  direccion text,gestionable boolean,mensajes_count integer,mensajes_limite integer,mensajes_restantes integer,
  ultimo_mensaje text,ultimo_mensaje_en timestamptz,no_leidos integer,puede_chat boolean,puede_cerrar boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select c.id,rs.id,rs.nombre_publico,ds.id,ds.nombre_publico,c.motivo,c.estado,c.creado_en,c.respondido_en,c.cerrado_en,
    case
      when public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id) and not public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'recibida'
      when public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'enviada'
      else 'contacto'
    end,
    c.estado='pendiente' and public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id),
    coalesce(stats.cnt,0)::integer,c.mensajes_limite::integer,greatest(c.mensajes_limite-coalesce(stats.cnt,0),0)::integer,
    stats.last_text,stats.last_at,
    coalesce((select count(*)::integer from public.kombax_social_contacto_mensajes um where um.contacto_id=c.id and um.leido_en is null and not public.app_kombax_social_puede_actuar_v051(um.autor_social_id)),0),
    c.estado='aceptada' and coalesce(stats.cnt,0)<c.mensajes_limite
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not case when public.app_kombax_social_puede_actuar_v051(c.remitente_social_id)
        then public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id)
        else public.app_kombax_contact_pair_blocked_v065(c.destinatario_social_id,c.remitente_social_id) end,
    c.estado='aceptada'
  from public.kombax_social_contactos c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral(
    select count(*)::integer cnt,
      (array_agg(m.texto order by m.ordinal desc))[1] last_text,
      max(m.creado_en) last_at
    from public.kombax_social_contacto_mensajes m where m.contacto_id=c.id
  ) stats on true
  where public.app_kombax_contact_can_access_v067(c.id)
  order by coalesce(stats.last_at,c.creado_en) desc
  limit 200;
end $$;
revoke all on function public.app_kombax_contactos_v067() from public,anon;
grant execute on function public.app_kombax_contactos_v067() to authenticated;

create or replace function public.app_kombax_contact_mensajes_v067(p_contacto_id uuid)
returns table(id uuid,contacto_id uuid,autor_social_id uuid,autor_nombre text,ordinal integer,texto text,creado_en timestamptz,leido_en timestamptz,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.app_kombax_contact_can_access_v067(p_contacto_id) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  return query
  select m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal::integer,m.texto,m.creado_en,m.leido_en,
    public.app_kombax_social_puede_actuar_v051(m.autor_social_id)
  from public.kombax_social_contacto_mensajes m
  join public.kombax_social_perfiles sp on sp.id=m.autor_social_id
  where m.contacto_id=p_contacto_id
  order by m.ordinal,m.creado_en,m.id;
end $$;
revoke all on function public.app_kombax_contact_mensajes_v067(uuid) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_v067(uuid) to authenticated;

create or replace function public.app_kombax_contact_mark_read_v067(p_contacto_id uuid)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;
begin
  if auth.uid() is null or not public.app_kombax_contact_can_access_v067(p_contacto_id) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  update public.kombax_social_contacto_mensajes m set leido_en=coalesce(m.leido_en,now())
  where m.contacto_id=p_contacto_id and m.leido_en is null
    and not public.app_kombax_social_puede_actuar_v051(m.autor_social_id);
  get diagnostics v_count=row_count;
  return v_count;
end $$;
revoke all on function public.app_kombax_contact_mark_read_v067(uuid) from public,anon;
grant execute on function public.app_kombax_contact_mark_read_v067(uuid) to authenticated;

-- Contacto: "Eliminar conversación" elimina únicamente la copia de la identidad elegida.
-- También cierra el hilo abierto para evitar que lleguen nuevos mensajes a una bandeja eliminada.
create or replace function public.app_kombax_social_network_mutate_v067(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_contact_id uuid;v_actor uuid;v_contact public.kombax_social_contactos;
begin
  if p_operation<>'kombax.contact.delete' then
    return public.app_kombax_social_network_mutate_v065(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;
  begin v_contact_id:=(v_payload->>'contacto_id')::uuid;v_actor:=(v_payload->>'actor_social_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_DELETE_CONTEXT_INVALID';end;
  select * into v_contact from public.kombax_social_contactos where id=v_contact_id for update;
  if v_contact.id is null then raise exception 'KOMBAX_CONTACT_NOT_FOUND';end if;
  if v_actor not in (v_contact.remitente_social_id,v_contact.destinatario_social_id) or not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_CONTACT_DELETE_FORBIDDEN';end if;
  update public.kombax_social_contactos set
    eliminado_remitente_en=case when v_actor=remitente_social_id then coalesce(eliminado_remitente_en,now()) else eliminado_remitente_en end,
    eliminado_destinatario_en=case when v_actor=destinatario_social_id then coalesce(eliminado_destinatario_en,now()) else eliminado_destinatario_en end,
    estado=case when estado in ('pendiente','aceptada') then 'cerrada' else estado end,
    cerrado_por=case when estado in ('pendiente','aceptada') then v_uid else cerrado_por end,
    cerrado_en=case when estado in ('pendiente','aceptada') then coalesce(cerrado_en,now()) else cerrado_en end
  where id=v_contact_id returning * into v_contact;
  insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,accion,objeto_tipo,objeto_id,detalle)
    values(v_uid,v_actor,'social.contact.delete','contact',v_contact.id,jsonb_build_object('scope','participant_copy'));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_contact.id,'estado',v_contact.estado,'eliminado',true,'actor_social_id',v_actor));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_network_mutate_v067(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_network_mutate_v067(text,jsonb,uuid) to authenticated;

-- Social: eliminar una publicación propia es eliminación física de la publicación.
-- Interacciones dependientes desaparecen por FK ON DELETE CASCADE. La multimedia social
-- se retira únicamente cuando no pertenece al álbum y ninguna otra publicación la usa.
create or replace function public.app_kombax_social_mutate_v067(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_post_id uuid;v_post public.kombax_social_publicaciones;v_media public.kombax_social_media;v_storage text;v_remove_media boolean:=false;
begin
  if p_operation<>'kombax.social.eliminar' then
    return public.app_kombax_social_mutate_v065(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;
  begin v_post_id:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
  select * into v_post from public.kombax_social_publicaciones where id=v_post_id for update;
  if v_post.id is null then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
  if not public.app_kombax_social_puede_actuar_v051(v_post.autor_perfil_id) then raise exception 'KOMBAX_POST_DELETE_FORBIDDEN';end if;
  if v_post.social_media_id is not null then
    select * into v_media from public.kombax_social_media where id=v_post.social_media_id for update;
  end if;
  delete from public.kombax_social_publicaciones where id=v_post.id;
  if v_media.id is not null and not v_media.en_album and not exists(select 1 from public.kombax_social_publicaciones p where p.social_media_id=v_media.id) then
    update public.kombax_social_media set estado='removed',actualizado_en=now() where id=v_media.id;
    v_storage:=v_media.storage_path;v_remove_media:=true;
  end if;
  insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,accion,objeto_tipo,objeto_id,detalle)
    values(v_uid,v_post.autor_perfil_id,'social.post.delete','social_post',v_post.id,jsonb_build_object('media_removed',v_remove_media));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_post.id,'deleted',true,'media_removed',v_remove_media,'storage_path',v_storage));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v067(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v067(text,jsonb,uuid) to authenticated;

-- Showcase: el gestor puede eliminar físicamente una ficha propia. Guardados asociados
-- se eliminan por cascade; se devuelven URLs para que el cliente limpie únicamente objetos
-- de Storage pertenecientes al usuario autenticado.
create or replace function public.app_kombax_showcase_mutate_v067(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_item_id uuid;v_item public.kombax_showcase_elementos;v_brand public.kombax_showcase_marcas;
begin
  if p_operation<>'kombax.showcase.elemento.eliminar' then
    return public.app_kombax_showcase_mutate_v054(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;
  begin v_item_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
  select * into v_item from public.kombax_showcase_elementos where id=v_item_id for update;
  if v_item.id is null or not public.app_kombax_showcase_puede_gestionar_v045(v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
  select * into v_brand from public.kombax_showcase_marcas where id=v_item.marca_id;
  delete from public.kombax_showcase_elementos where id=v_item.id;
  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
    values(v_uid,v_brand.club_id,'showcase.item.delete','showcase_item',v_item.id,jsonb_build_object('marca_id',v_item.marca_id));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_item.id,'deleted',true,'imagen_url',v_item.imagen_url,'galeria',v_item.galeria));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
