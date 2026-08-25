-- KOMBAX RC13 build 20083 · Workspace Context Isolation
-- Additive hardening. No chat/message/history rows are rewritten or deleted.
-- Goal: a club workspace can only expose private Social state for identities that belong to that club workspace.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.kombax_workspace_club_access_v147(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select (select auth.uid()) is not null
    and p_club_id is not null
    and (
      exists(
        select 1
        from public.miembros_club mc
        where mc.club_id=p_club_id
          and mc.perfil_id=(select auth.uid())
          and mc.activo
      )
      or coalesce(public.app_kombax_support_club_v140(p_club_id),false)
    );
$$;
revoke all on function private.kombax_workspace_club_access_v147(uuid) from public,anon,authenticated;

create or replace function private.kombax_workspace_actor_allowed_v147(p_club_id uuid,p_social_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select private.kombax_workspace_club_access_v147(p_club_id)
    and p_social_id is not null
    and exists(
      select 1
      from public.kombax_social_perfiles sp
      left join public.identidades_sociales i on i.id=sp.identidad_social_id
      where sp.id=p_social_id
        and sp.visible
        and sp.estado='activo'
        and (
          (sp.sujeto_tipo='club' and sp.club_id=p_club_id
            and (public.app_kombax_social_puede_actuar_v051(sp.id)
              or coalesce(public.app_kombax_support_club_v140(p_club_id),false)))
          or
          (sp.sujeto_tipo='miembro'
            and i.club_origen_id=p_club_id
            and i.perfil_id=(select auth.uid())
            and i.estado='activa'
            and public.app_kombax_social_puede_actuar_v051(sp.id))
        )
    );
$$;
revoke all on function private.kombax_workspace_actor_allowed_v147(uuid,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_workspace_actor_ids_v147(p_club_id uuid)
returns table(social_id uuid)
language sql
stable
security definer
set search_path=''
as $$
  select sp.id
  from public.kombax_social_perfiles sp
  where private.kombax_workspace_actor_allowed_v147(p_club_id,sp.id)
  order by case when sp.sujeto_tipo='club' then 0 else 1 end,sp.creado_en,sp.id;
$$;
revoke all on function public.app_kombax_workspace_actor_ids_v147(uuid) from public,anon;
grant execute on function public.app_kombax_workspace_actor_ids_v147(uuid) to authenticated;

create or replace function public.app_kombax_workspace_social_profiles_v147(p_club_id uuid)
returns table(
  id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,
  banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,
  perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text
)
language sql
stable
security definer
set search_path=''
as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,
         public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
         public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),
         sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
         public.app_kombax_social_tipo_v051(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre,
         case when sp.sujeto_tipo='club' then coalesce(c.nombre,sp.nombre_publico)||' · Club'
              else sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end end
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where private.kombax_workspace_actor_allowed_v147(p_club_id,sp.id)
  order by case when sp.sujeto_tipo='club' then 0 else 1 end,sp.nombre_publico,sp.id;
$$;
revoke all on function public.app_kombax_workspace_social_profiles_v147(uuid) from public,anon;
grant execute on function public.app_kombax_workspace_social_profiles_v147(uuid) to authenticated;

create or replace function public.app_kombax_contactos_contexto_v147(
  p_club_id uuid,p_actor_social_id uuid,p_limit integer default 50
)
returns table(
  id uuid,remitente_id uuid,remitente_nombre text,destinatario_id uuid,destinatario_nombre text,
  motivo text,estado text,creado_en timestamptz,respondido_en timestamptz,cerrado_en timestamptz,
  direccion text,gestionable boolean,ultimo_mensaje text,ultimo_mensaje_en timestamptz,no_leidos integer,
  puede_chat boolean,puede_cerrar boolean,canal text,showcase_elemento_id uuid,
  showcase_producto_nombre text,showcase_producto_imagen_url text,showcase_marca_nombre text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_limit integer:=least(200,greatest(1,coalesce(p_limit,50)));
begin
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,p_actor_social_id) then
    raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN';
  end if;
  return query
  select c.id,rs.id,rs.nombre_publico,ds.id,ds.nombre_publico,c.motivo,c.estado,c.creado_en,c.respondido_en,c.cerrado_en,
    case when c.destinatario_social_id=p_actor_social_id then 'recibida' else 'enviada' end,
    c.estado='pendiente' and c.destinatario_social_id=p_actor_social_id,
    lm.texto,lm.creado_en,
    coalesce((select count(*)::integer from public.kombax_social_contacto_mensajes um
      where um.contacto_id=c.id and um.leido_en is null and um.autor_social_id<>p_actor_social_id),0),
    c.estado='aceptada'
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id),
    c.estado='aceptada',coalesce(c.canal,'social'),c.showcase_elemento_id,c.showcase_producto_nombre,
    c.showcase_producto_imagen_url,c.showcase_marca_nombre
  from public.kombax_social_contactos c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral (
    select m.texto,m.creado_en from public.kombax_social_contacto_mensajes m
    where m.contacto_id=c.id order by m.ordinal desc,m.id desc limit 1
  ) lm on true
  where (
    (c.remitente_social_id=p_actor_social_id and c.eliminado_remitente_en is null)
    or (c.destinatario_social_id=p_actor_social_id and c.eliminado_destinatario_en is null)
  )
  order by coalesce(lm.creado_en,c.creado_en) desc,c.id desc
  limit v_limit;
end;
$$;
revoke all on function public.app_kombax_contactos_contexto_v147(uuid,uuid,integer) from public,anon;
grant execute on function public.app_kombax_contactos_contexto_v147(uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_contact_mensajes_contexto_v147(
  p_club_id uuid,p_actor_social_id uuid,p_contacto_id uuid,
  p_before_ordinal integer default null,p_after_ordinal integer default null,p_limit integer default 30
)
returns table(
  id uuid,contacto_id uuid,autor_social_id uuid,autor_nombre text,ordinal integer,texto text,
  creado_en timestamptz,leido_en timestamptz,propio boolean,older_available boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_limit integer:=least(50,greatest(1,coalesce(p_limit,30)));
begin
  if p_before_ordinal is not null and p_after_ordinal is not null then raise exception 'KOMBAX_CONTACT_CURSOR_INVALID'; end if;
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,p_actor_social_id) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  if not exists(
    select 1 from public.kombax_social_contactos c where c.id=p_contacto_id
      and ((c.remitente_social_id=p_actor_social_id and c.eliminado_remitente_en is null)
        or (c.destinatario_social_id=p_actor_social_id and c.eliminado_destinatario_en is null))
  ) then raise exception 'KOMBAX_CONTACT_CONTEXT_FORBIDDEN'; end if;

  if p_after_ordinal is not null then
    return query
      select m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal,
        case when m.moderation_hidden then '[Mensaje retirado por moderación]' else m.texto end,
        m.creado_en,m.leido_en,m.autor_social_id=p_actor_social_id,false
      from public.kombax_social_contacto_mensajes m
      join public.kombax_social_perfiles sp on sp.id=m.autor_social_id
      where m.contacto_id=p_contacto_id and m.ordinal>p_after_ordinal
      order by m.ordinal asc,m.id asc limit v_limit;
  else
    return query
      with picked as (
        select m.* from public.kombax_social_contacto_mensajes m
        where m.contacto_id=p_contacto_id and (p_before_ordinal is null or m.ordinal<p_before_ordinal)
        order by m.ordinal desc,m.id desc limit v_limit
      ), meta as (select min(p.ordinal) min_ordinal from picked p)
      select p.id,p.contacto_id,p.autor_social_id,sp.nombre_publico,p.ordinal,
        case when p.moderation_hidden then '[Mensaje retirado por moderación]' else p.texto end,
        p.creado_en,p.leido_en,p.autor_social_id=p_actor_social_id,
        exists(select 1 from public.kombax_social_contacto_mensajes older
          where older.contacto_id=p_contacto_id and older.ordinal<(select min_ordinal from meta))
      from picked p join public.kombax_social_perfiles sp on sp.id=p.autor_social_id
      order by p.ordinal asc,p.id asc;
  end if;
end;
$$;
revoke all on function public.app_kombax_contact_mensajes_contexto_v147(uuid,uuid,uuid,integer,integer,integer) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_contexto_v147(uuid,uuid,uuid,integer,integer,integer) to authenticated;

create or replace function public.app_kombax_contact_mark_read_contexto_v147(
  p_club_id uuid,p_actor_social_id uuid,p_contacto_id uuid
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare v_count integer;
begin
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,p_actor_social_id) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  if not exists(select 1 from public.kombax_social_contactos c where c.id=p_contacto_id
    and ((c.remitente_social_id=p_actor_social_id and c.eliminado_remitente_en is null)
      or (c.destinatario_social_id=p_actor_social_id and c.eliminado_destinatario_en is null)))
  then raise exception 'KOMBAX_CONTACT_CONTEXT_FORBIDDEN'; end if;
  update public.kombax_social_contacto_mensajes m
    set leido_en=coalesce(m.leido_en,now())
    where m.contacto_id=p_contacto_id and m.leido_en is null and m.autor_social_id<>p_actor_social_id;
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;
revoke all on function public.app_kombax_contact_mark_read_contexto_v147(uuid,uuid,uuid) from public,anon;
grant execute on function public.app_kombax_contact_mark_read_contexto_v147(uuid,uuid,uuid) to authenticated;

create or replace function public.app_kombax_header_activity_contexto_v147(p_club_id uuid,p_actor_social_id uuid)
returns table(kombax_pending integer,relation_requests integer,contact_requests integer,message_unread integer)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,p_actor_social_id) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  return query
  with relation_count as (
    select count(*)::integer n from public.kombax_relaciones r where r.estado='pending' and r.destino_social_id=p_actor_social_id
  ), contact_count as (
    select count(*)::integer n from public.kombax_social_contactos c
    where c.estado='pendiente' and c.destinatario_social_id=p_actor_social_id and c.eliminado_destinatario_en is null
  ), unread_threads as (
    select count(distinct c.id)::integer n
    from public.kombax_social_contacto_mensajes m join public.kombax_social_contactos c on c.id=m.contacto_id
    where c.estado='aceptada' and m.leido_en is null and m.autor_social_id<>p_actor_social_id
      and ((c.remitente_social_id=p_actor_social_id and c.eliminado_remitente_en is null)
        or (c.destinatario_social_id=p_actor_social_id and c.eliminado_destinatario_en is null))
  )
  select (r.n+c.n)::integer,r.n,c.n,m.n from relation_count r,contact_count c,unread_threads m;
end;
$$;
revoke all on function public.app_kombax_header_activity_contexto_v147(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_header_activity_contexto_v147(uuid,uuid) to authenticated;

create or replace function public.app_kombax_header_summary_v147(p_club_id uuid,p_actor_social_id uuid)
returns table(
  club_unread_groups integer,club_unread_items integer,club_latest_id uuid,club_latest_title text,
  club_latest_body text,club_latest_created_at timestamptz,kombax_pending integer,
  relation_requests integer,contact_requests integer,message_unread integer
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare h record;k record;
begin
  if not private.kombax_workspace_club_access_v147(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;
  select * into k from public.app_kombax_header_activity_contexto_v147(p_club_id,p_actor_social_id);
  if public.es_miembro_club(p_club_id) then
    select * into h from public.app_kombax_header_summary_v106(p_club_id);
    return query select h.club_unread_groups,h.club_unread_items,h.club_latest_id,h.club_latest_title,h.club_latest_body,h.club_latest_created_at,k.kombax_pending,k.relation_requests,k.contact_requests,k.message_unread;
  else
    -- Owner/support sessions fail closed for club notifications if they are not a real member;
    -- importantly, global owner/federation message counts are never substituted here.
    return query select 0::integer,0::integer,null::uuid,null::text,null::text,null::timestamptz,k.kombax_pending,k.relation_requests,k.contact_requests,k.message_unread;
  end if;
end;
$$;
revoke all on function public.app_kombax_header_summary_v147(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_header_summary_v147(uuid,uuid) to authenticated;

create or replace function public.app_kombax_relaciones_contexto_v147(p_club_id uuid,p_actor_social_id uuid,p_limit integer default 50)
returns table(id uuid,origen_social_id uuid,origen_nombre text,destino_social_id uuid,destino_nombre text,tipo text,estado text,nota text,creado_en timestamptz,confirmado_en timestamptz,gestionable boolean)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,p_actor_social_id) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  return query select * from public.app_kombax_relaciones_v133(p_actor_social_id,least(150,greatest(1,coalesce(p_limit,50))));
end;
$$;
revoke all on function public.app_kombax_relaciones_contexto_v147(uuid,uuid,integer) from public,anon;
grant execute on function public.app_kombax_relaciones_contexto_v147(uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_context_network_mutate_v147(
  p_club_id uuid,p_operation text,p_payload jsonb,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_actor uuid;v_contact_id uuid;v_contact public.kombax_social_contactos;v_result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  if not private.kombax_workspace_club_access_v147(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;
  begin
    v_actor:=case
      when p_operation in ('kombax.contact.request','kombax.showcase.contact.request') then (v_payload->>'remitente_social_id')::uuid
      when p_operation='kombax.contact.message.send' then (v_payload->>'autor_social_id')::uuid
      else (v_payload->>'actor_social_id')::uuid
    end;
  exception when others then raise exception 'KOMBAX_WORKSPACE_ACTOR_REQUIRED'; end;
  if not private.kombax_workspace_actor_allowed_v147(p_club_id,v_actor) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  v_payload:=v_payload||jsonb_build_object('club_id',p_club_id);

  if p_operation in ('kombax.contact.message.send','kombax.social.contacto.estado','kombax.contact.close','kombax.contact.delete') then
    begin v_contact_id:=(v_payload->>'contacto_id')::uuid; exception when others then raise exception 'KOMBAX_CONTACT_CONTEXT_INVALID'; end;
    select * into v_contact from public.kombax_social_contactos where id=v_contact_id;
    if v_contact.id is null or v_actor not in (v_contact.remitente_social_id,v_contact.destinatario_social_id) then raise exception 'KOMBAX_CONTACT_CONTEXT_FORBIDDEN'; end if;
    if p_operation='kombax.social.contacto.estado' and v_actor<>v_contact.destinatario_social_id then raise exception 'KOMBAX_CONTACT_DECISION_CONTEXT_FORBIDDEN'; end if;
  end if;

  if p_operation='kombax.social.contacto.estado' then
    v_result:=public.app_kombax_social_mutate_v123(p_operation,v_payload-'actor_social_id',p_request_id);
  elsif p_operation in ('kombax.contact.request','kombax.showcase.contact.request','kombax.contact.message.send','kombax.contact.close','kombax.contact.delete') then
    v_result:=public.app_kombax_social_network_mutate_v107(p_operation,v_payload,p_request_id);
  else
    raise exception 'KOMBAX_CONTEXT_NETWORK_OPERATION_NOT_ALLOWED';
  end if;
  return v_result;
end;
$$;
revoke all on function public.app_kombax_context_network_mutate_v147(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_context_network_mutate_v147(uuid,text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_context_relation_mutate_v147(
  p_club_id uuid,p_operation text,p_payload jsonb,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_actor uuid;v_rel public.kombax_relaciones;v_id uuid;v_state text;
begin
  if (select auth.uid()) is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  if not private.kombax_workspace_club_access_v147(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;
  if p_operation='kombax.relation.request' then
    begin v_actor:=(v_payload->>'origen_social_id')::uuid; exception when others then raise exception 'KOMBAX_WORKSPACE_ACTOR_REQUIRED'; end;
    if not private.kombax_workspace_actor_allowed_v147(p_club_id,v_actor) then raise exception 'KOMBAX_WORKSPACE_ACTOR_FORBIDDEN'; end if;
  elsif p_operation='kombax.relation.state' then
    begin v_id:=(v_payload->>'relacion_id')::uuid; exception when others then raise exception 'KOMBAX_RELATION_ID_INVALID'; end;
    v_state:=lower(coalesce(v_payload->>'estado',''));
    select * into v_rel from public.kombax_relaciones where id=v_id;
    if v_rel.id is null then raise exception 'KOMBAX_RELATION_NOT_FOUND'; end if;
    if v_state in ('confirmed','rejected') then
      if private.kombax_workspace_actor_allowed_v147(p_club_id,v_rel.destino_social_id) then v_actor:=v_rel.destino_social_id; end if;
    else
      if private.kombax_workspace_actor_allowed_v147(p_club_id,v_rel.origen_social_id) then v_actor:=v_rel.origen_social_id;
      elsif private.kombax_workspace_actor_allowed_v147(p_club_id,v_rel.destino_social_id) then v_actor:=v_rel.destino_social_id; end if;
    end if;
    if v_actor is null then raise exception 'KOMBAX_RELATION_CONTEXT_FORBIDDEN'; end if;
  else
    raise exception 'KOMBAX_CONTEXT_RELATION_OPERATION_NOT_ALLOWED';
  end if;
  return public.app_kombax_relacion_mutate_v045(p_operation,(v_payload-'actor_social_id')||jsonb_build_object('club_id',p_club_id),p_request_id);
end;
$$;
revoke all on function public.app_kombax_context_relation_mutate_v147(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_context_relation_mutate_v147(uuid,text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_context_isolation_audit_v147(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_all uuid[];v_ctx uuid[];v_global_contacts int;v_context_contacts int;v_direct int;v_other_club int;
begin
  if not private.kombax_workspace_club_access_v147(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;
  select coalesce(array_agg(x.social_id),'{}'::uuid[]) into v_all from public.app_kombax_my_social_actor_ids_v106() x;
  select coalesce(array_agg(x.social_id),'{}'::uuid[]) into v_ctx from public.app_kombax_workspace_actor_ids_v147(p_club_id) x;
  select count(*)::int into v_global_contacts from public.kombax_social_contactos c
    where c.remitente_social_id=any(v_all) or c.destinatario_social_id=any(v_all);
  select count(*)::int into v_context_contacts from public.kombax_social_contactos c
    where c.remitente_social_id=any(v_ctx) or c.destinatario_social_id=any(v_ctx);
  select count(*)::int into v_direct from public.kombax_social_perfiles sp where sp.id=any(v_all) and sp.sujeto_tipo='perfil_directo';
  select count(*)::int into v_other_club from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.id=any(v_all) and sp.sujeto_tipo in ('club','miembro') and coalesce(sp.club_id,i.club_origen_id) is distinct from p_club_id;
  return jsonb_build_object(
    'ok',true,'club_id',p_club_id,
    'global_actor_count',coalesce(array_length(v_all,1),0),'workspace_actor_count',coalesce(array_length(v_ctx,1),0),
    'excluded_actor_count',greatest(coalesce(array_length(v_all,1),0)-coalesce(array_length(v_ctx,1),0),0),
    'direct_profiles_excluded',v_direct,'other_club_profiles_excluded',v_other_club,
    'global_contact_count',v_global_contacts,'workspace_contact_count',v_context_contacts,
    'contacts_excluded_from_workspace',greatest(v_global_contacts-v_context_contacts,0),
    'private_context_isolated',true
  );
end;
$$;
revoke all on function public.app_kombax_context_isolation_audit_v147(uuid) from public,anon;
grant execute on function public.app_kombax_context_isolation_audit_v147(uuid) to authenticated;

-- Audit function executable surface: no anonymous access to any 20083 private-context endpoint.
do $$
declare r regprocedure;
begin
  foreach r in array array[
    'public.app_kombax_workspace_actor_ids_v147(uuid)'::regprocedure,
    'public.app_kombax_workspace_social_profiles_v147(uuid)'::regprocedure,
    'public.app_kombax_contactos_contexto_v147(uuid,uuid,integer)'::regprocedure,
    'public.app_kombax_contact_mensajes_contexto_v147(uuid,uuid,uuid,integer,integer,integer)'::regprocedure,
    'public.app_kombax_contact_mark_read_contexto_v147(uuid,uuid,uuid)'::regprocedure,
    'public.app_kombax_header_activity_contexto_v147(uuid,uuid)'::regprocedure,
    'public.app_kombax_header_summary_v147(uuid,uuid)'::regprocedure,
    'public.app_kombax_relaciones_contexto_v147(uuid,uuid,integer)'::regprocedure,
    'public.app_kombax_context_network_mutate_v147(uuid,text,jsonb,uuid)'::regprocedure,
    'public.app_kombax_context_relation_mutate_v147(uuid,text,jsonb,uuid)'::regprocedure,
    'public.app_kombax_context_isolation_audit_v147(uuid)'::regprocedure
  ] loop
    execute format('revoke execute on function %s from public,anon',r);
  end loop;
end $$;

commit;
