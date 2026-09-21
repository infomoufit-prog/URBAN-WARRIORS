-- KOMBAX RC13 build 20063 · mensajería final Social + Showcase por producto.
-- Objetivos:
-- 1) separar visual y contractualmente chats Social y Showcase;
-- 2) permitir un hilo Showcase por producto y pareja de identidades;
-- 3) conservar snapshot mínimo del producto aunque la ficha se archive/elimine;
-- 4) contar conversaciones con mensajes sin leer en el badge superior;
-- 5) mantener compatibilidad con los RPC v106/v104 usados por build 20062.
begin;

alter table public.kombax_social_contactos
  add column if not exists canal text not null default 'social',
  add column if not exists showcase_elemento_id uuid references public.kombax_showcase_elementos(id) on delete set null,
  add column if not exists showcase_producto_nombre text,
  add column if not exists showcase_producto_imagen_url text,
  add column if not exists showcase_marca_nombre text;

alter table public.kombax_social_contactos
  drop constraint if exists kombax_social_contactos_canal_check;
alter table public.kombax_social_contactos
  add constraint kombax_social_contactos_canal_check check(canal in ('social','showcase'));

alter table public.kombax_social_contactos
  drop constraint if exists kombax_social_contactos_showcase_context_check;
alter table public.kombax_social_contactos
  add constraint kombax_social_contactos_showcase_context_check check(
    canal='social' or nullif(btrim(coalesce(showcase_producto_nombre,'')),'') is not null
  );

-- Los índices antiguos suponían un único hilo abierto por pareja. Showcase necesita
-- permitir hilos distintos cuando dos perfiles hablan de productos diferentes.
drop index if exists public.uq_kombax_social_contacto_pendiente_v041;
drop index if exists public.uq_kombax_contact_pair_open_v065;

create unique index if not exists uq_kombax_contact_social_pair_open_v107
on public.kombax_social_contactos(
  least(remitente_social_id,destinatario_social_id),
  greatest(remitente_social_id,destinatario_social_id)
)
where canal='social' and estado in ('pendiente','aceptada');

create unique index if not exists uq_kombax_contact_showcase_pair_item_open_v107
on public.kombax_social_contactos(
  least(remitente_social_id,destinatario_social_id),
  greatest(remitente_social_id,destinatario_social_id),
  showcase_elemento_id
)
where canal='showcase' and showcase_elemento_id is not null and estado in ('pendiente','aceptada');

create index if not exists idx_kombax_contact_channel_activity_v107
on public.kombax_social_contactos(canal,coalesce(cerrado_en,respondido_en,creado_en) desc,id desc);

-- Compatibilidad con la build 20062 que permanece desplegada en Netlify durante la QA móvil.
-- Sus RPC históricos solo deben ver/crear conversaciones Social; Showcase queda reservado a v107.
create or replace function public.app_kombax_social_network_mutate_v104(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_actor uuid;
  v_target uuid;
  v_contact_id uuid;
  v_contact public.kombax_social_contactos;
  v_message public.kombax_social_contacto_mensajes;
  v_reason text;
  v_text text;
  v_next_ordinal integer;
begin
  if p_operation not in ('kombax.contact.request','kombax.contact.message.send') then
    return public.app_kombax_social_network_mutate_v067(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;

  select * into v_existing
  from public.app_mutation_requests
  where request_id=p_request_id;

  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;

  if p_operation='kombax.contact.request' then
    begin
      v_actor:=(v_payload->>'remitente_social_id')::uuid;
      v_target:=(v_payload->>'destinatario_social_id')::uuid;
    exception when others then
      raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';
    end;

    if v_actor=v_target then raise exception 'KOMBAX_CONTACT_SELF_FORBIDDEN';end if;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_CONTACT_SOURCE_NOT_OWNED';end if;
    if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then
      raise exception 'KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS';
    end if;
    if public.app_kombax_contact_pair_blocked_v065(v_actor,v_target) then raise exception 'KOMBAX_CONTACT_BLOCKED';end if;
    if exists(
      select 1
      from public.kombax_social_contactos c
      where least(c.remitente_social_id,c.destinatario_social_id)=least(v_actor,v_target)
        and greatest(c.remitente_social_id,c.destinatario_social_id)=greatest(v_actor,v_target)
        and coalesce(c.canal,'social')='social'
        and c.estado in ('pendiente','aceptada')
    ) then
      raise exception 'KOMBAX_CONTACT_THREAD_ALREADY_OPEN';
    end if;

    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));
    if v_reason not in ('entrenamiento','competicion','evento','colaboracion','patrocinio','informacion','otro') then
      raise exception 'KOMBAX_CONTACT_REASON_INVALID';
    end if;
    v_text:=btrim(coalesce(v_payload->>'mensaje',''));
    if char_length(v_text)<10 or char_length(v_text)>500 then raise exception 'KOMBAX_CONTACT_REQUEST_TEXT_INVALID';end if;

    insert into public.kombax_social_contactos(remitente_social_id,destinatario_social_id,creado_por,motivo,mensaje)
    values(v_actor,v_target,v_uid,v_reason,v_text)
    returning * into v_contact;

    v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado);

  elsif p_operation='kombax.contact.message.send' then
    begin
      v_contact_id:=(v_payload->>'contacto_id')::uuid;
      v_actor:=(v_payload->>'autor_social_id')::uuid;
    exception when others then
      raise exception 'KOMBAX_CONTACT_MESSAGE_CONTEXT_INVALID';
    end;

    select * into v_contact
    from public.kombax_social_contactos
    where id=v_contact_id
    for update;

    if v_contact.id is null then raise exception 'KOMBAX_CONTACT_NOT_FOUND';end if;
    if v_actor not in (v_contact.remitente_social_id,v_contact.destinatario_social_id)
      or not public.app_kombax_social_puede_actuar_v051(v_actor) then
      raise exception 'KOMBAX_CONTACT_MESSAGE_SENDER_FORBIDDEN';
    end if;
    if v_contact.estado<>'aceptada' then raise exception 'KOMBAX_CONTACT_NOT_OPEN';end if;

    v_target:=case
      when v_actor=v_contact.remitente_social_id then v_contact.destinatario_social_id
      else v_contact.remitente_social_id
    end;

    if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then
      raise exception 'KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS';
    end if;
    if public.app_kombax_contact_pair_blocked_v065(v_actor,v_target) then raise exception 'KOMBAX_CONTACT_BLOCKED';end if;

    v_text:=btrim(coalesce(v_payload->>'texto',''));
    if char_length(v_text)<1 or char_length(v_text)>500 then raise exception 'KOMBAX_CONTACT_MESSAGE_TEXT_INVALID';end if;

    select coalesce(max(m.ordinal),0)+1
    into v_next_ordinal
    from public.kombax_social_contacto_mensajes m
    where m.contacto_id=v_contact.id;

    insert into public.kombax_social_contacto_mensajes(contacto_id,autor_social_id,creado_por,ordinal,texto)
    values(v_contact.id,v_actor,v_uid,v_next_ordinal,v_text)
    returning * into v_message;

    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
    select
      v_uid,
      v_actor,
      coalesce(sp.club_id,i.club_origen_id),
      'social.contact.message',
      'contact_message',
      v_message.id,
      jsonb_build_object('contact_id',v_contact.id,'ordinal',v_message.ordinal,'chat_mode','open')
    from public.kombax_social_perfiles sp
    left join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.id=v_actor;

    v_result:=to_jsonb(v_message)||jsonb_build_object('cerrado',false);
  end if;

  v_result:=jsonb_build_object(
    'ok',true,
    'operation',p_operation,
    'request_id',p_request_id,
    'data',coalesce(v_result,'{}'::jsonb)
  );
  update public.app_mutation_requests
  set result=v_result,completed_at=now()
  where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests
  where request_id=p_request_id and result is null;
  raise;
end $$;

revoke all on function public.app_kombax_social_network_mutate_v104(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_network_mutate_v104(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_header_activity_v106()
returns table(
  kombax_pending integer,
  relation_requests integer,
  contact_requests integer,
  message_unread integer
)
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
  v_actor_ids uuid[];
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_social_acceso_v041() then
    return query select 0,0,0,0;
    return;
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  return query
  with relation_count as (
    select count(*)::integer n
    from public.kombax_relaciones r
    where r.estado='pending'
      and r.destino_social_id=any(v_actor_ids)
  ),
  contact_count as (
    select count(*)::integer n
    from public.kombax_social_contactos c
    where c.estado='pendiente'
      and coalesce(c.canal,'social')='social'
      and c.destinatario_social_id=any(v_actor_ids)
      and c.eliminado_destinatario_en is null
  ),
  unread_count as (
    select count(*)::integer n
    from public.kombax_social_contacto_mensajes m
    join public.kombax_social_contactos c on c.id=m.contacto_id
    where c.estado='aceptada'
      and coalesce(c.canal,'social')='social'
      and m.leido_en is null
      and not (m.autor_social_id=any(v_actor_ids))
      and (
        (c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null)
        or
        (c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null)
      )
  )
  select (r.n+c.n)::integer,r.n,c.n,m.n
  from relation_count r,contact_count c,unread_count m;
end
$$;
revoke all on function public.app_kombax_header_activity_v106() from public,anon;
grant execute on function public.app_kombax_header_activity_v106() to authenticated;

create or replace function public.app_kombax_contactos_v106()
returns table(
  id uuid,
  remitente_id uuid,
  remitente_nombre text,
  destinatario_id uuid,
  destinatario_nombre text,
  motivo text,
  estado text,
  creado_en timestamptz,
  respondido_en timestamptz,
  cerrado_en timestamptz,
  direccion text,
  gestionable boolean,
  ultimo_mensaje text,
  ultimo_mensaje_en timestamptz,
  no_leidos integer,
  puede_chat boolean,
  puede_cerrar boolean
)
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare
  v_actor_ids uuid[];
begin
  if not public.app_kombax_social_acceso_v041() then
    raise exception 'SOCIAL_ACCESS_REQUIRED';
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  return query
  with accessible as materialized (
    select c.*
    from public.kombax_social_contactos c
    where coalesce(c.canal,'social')='social' and c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null
    union
    select c.*
    from public.kombax_social_contactos c
    where coalesce(c.canal,'social')='social' and c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null
  )
  select
    c.id,
    rs.id,
    rs.nombre_publico,
    ds.id,
    ds.nombre_publico,
    c.motivo,
    c.estado,
    c.creado_en,
    c.respondido_en,
    c.cerrado_en,
    case
      when c.destinatario_social_id=any(v_actor_ids) and not (c.remitente_social_id=any(v_actor_ids)) then 'recibida'
      when c.remitente_social_id=any(v_actor_ids) then 'enviada'
      else 'contacto'
    end,
    c.estado='pendiente' and c.destinatario_social_id=any(v_actor_ids),
    last_message.texto,
    last_message.creado_en,
    coalesce((
      select count(*)::integer
      from public.kombax_social_contacto_mensajes um
      where um.contacto_id=c.id
        and um.leido_en is null
        and not (um.autor_social_id=any(v_actor_ids))
    ),0),
    c.estado='aceptada'
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not case
        when c.remitente_social_id=any(v_actor_ids)
          then public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id)
        else public.app_kombax_contact_pair_blocked_v065(c.destinatario_social_id,c.remitente_social_id)
      end,
    c.estado='aceptada'
  from accessible c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral (
    select m.texto,m.creado_en
    from public.kombax_social_contacto_mensajes m
    where m.contacto_id=c.id
    order by m.ordinal desc,m.id desc
    limit 1
  ) last_message on true
  order by coalesce(last_message.creado_en,c.creado_en) desc,c.id desc
  limit 200;
end
$$;
revoke all on function public.app_kombax_contactos_v106() from public,anon;
grant execute on function public.app_kombax_contactos_v106() to authenticated;

-- Runtime de red. Las operaciones no relacionadas con la creación de hilos se
-- delegan a v104 para conservar chat ilimitado, recibos de lectura y borrado existente.
create or replace function public.app_kombax_social_network_mutate_v107(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_actor uuid;
  v_target uuid;
  v_contact public.kombax_social_contactos;
  v_reason text;
  v_text text;
  v_channel text;
  v_item_id uuid;
  v_item public.kombax_showcase_elementos;
  v_brand public.kombax_showcase_marcas;
  v_was_existing boolean:=false;
begin
  if p_operation not in ('kombax.contact.request','kombax.showcase.contact.request') then
    return public.app_kombax_social_network_mutate_v104(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;

  select * into v_existing
  from public.app_mutation_requests
  where request_id=p_request_id;

  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;

  begin
    v_actor:=(v_payload->>'remitente_social_id')::uuid;
  exception when others then
    raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';
  end;
  if not public.app_kombax_social_puede_actuar_v051(v_actor) then
    raise exception 'KOMBAX_CONTACT_SOURCE_NOT_OWNED';
  end if;

  v_text:=btrim(coalesce(v_payload->>'mensaje',''));
  if char_length(v_text)<10 or char_length(v_text)>500 then
    raise exception 'KOMBAX_CONTACT_REQUEST_TEXT_INVALID';
  end if;

  if p_operation='kombax.showcase.contact.request' then
    v_channel:='showcase';
    begin
      v_item_id:=(v_payload->>'elemento_id')::uuid;
    exception when others then
      raise exception 'SHOWCASE_CONTACT_ITEM_INVALID';
    end;

    select e.* into v_item
    from public.kombax_showcase_elementos e
    where e.id=v_item_id and e.estado='publicado';
    if v_item.id is null then raise exception 'SHOWCASE_CONTACT_ITEM_NOT_PUBLIC';end if;

    select m.* into v_brand
    from public.kombax_showcase_marcas m
    where m.id=v_item.marca_id and m.estado='publicada';
    if v_brand.id is null then raise exception 'SHOWCASE_CONTACT_PROVIDER_NOT_PUBLIC';end if;

    if v_brand.sujeto_tipo='club' then
      select sp.id into v_target
      from public.kombax_social_perfiles sp
      where sp.sujeto_tipo='club' and sp.club_id=v_brand.club_id and sp.estado='activo'
      order by sp.creado_en asc,sp.id asc limit 1;
    else
      select sp.id into v_target
      from public.kombax_social_perfiles sp
      where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=v_brand.perfil_directo_id and sp.estado='activo'
      order by sp.creado_en asc,sp.id asc limit 1;
    end if;
    if v_target is null then raise exception 'SHOWCASE_CONTACT_PROVIDER_UNAVAILABLE';end if;
    v_reason:='informacion';
  else
    v_channel:='social';
    begin
      v_target:=(v_payload->>'destinatario_social_id')::uuid;
    exception when others then
      raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';
    end;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));
    if v_reason not in ('entrenamiento','competicion','evento','colaboracion','patrocinio','informacion','otro') then
      raise exception 'KOMBAX_CONTACT_REASON_INVALID';
    end if;
  end if;

  if v_actor=v_target then raise exception 'KOMBAX_CONTACT_SELF_FORBIDDEN';end if;
  if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then
    raise exception 'KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS';
  end if;
  if public.app_kombax_contact_pair_blocked_v065(v_actor,v_target) then
    raise exception 'KOMBAX_CONTACT_BLOCKED';
  end if;

  if v_channel='social' then
    select c.* into v_contact
    from public.kombax_social_contactos c
    where c.canal='social'
      and least(c.remitente_social_id,c.destinatario_social_id)=least(v_actor,v_target)
      and greatest(c.remitente_social_id,c.destinatario_social_id)=greatest(v_actor,v_target)
      and c.estado in ('pendiente','aceptada')
    order by c.creado_en desc,c.id desc limit 1;
  else
    select c.* into v_contact
    from public.kombax_social_contactos c
    where c.canal='showcase'
      and c.showcase_elemento_id=v_item_id
      and least(c.remitente_social_id,c.destinatario_social_id)=least(v_actor,v_target)
      and greatest(c.remitente_social_id,c.destinatario_social_id)=greatest(v_actor,v_target)
      and c.estado in ('pendiente','aceptada')
    order by c.creado_en desc,c.id desc limit 1;
  end if;

  if v_contact.id is null then
    insert into public.kombax_social_contactos(
      remitente_social_id,destinatario_social_id,creado_por,motivo,mensaje,canal,
      showcase_elemento_id,showcase_producto_nombre,showcase_producto_imagen_url,showcase_marca_nombre
    ) values(
      v_actor,v_target,v_uid,v_reason,v_text,v_channel,
      case when v_channel='showcase' then v_item_id else null end,
      case when v_channel='showcase' then v_item.nombre else null end,
      case when v_channel='showcase' then v_item.imagen_url else null end,
      case when v_channel='showcase' then v_brand.nombre else null end
    ) returning * into v_contact;

    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
    select
      v_uid,v_actor,coalesce(sp.club_id,i.club_origen_id),
      case when v_channel='showcase' then 'showcase.contact.request' else 'social.contact.request' end,
      'contact',v_contact.id,
      jsonb_build_object('channel',v_channel,'showcase_item_id',v_contact.showcase_elemento_id)
    from public.kombax_social_perfiles sp
    left join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.id=v_actor;
  else
    v_was_existing:=true;
  end if;

  v_result:=jsonb_build_object(
    'ok',true,
    'operation',p_operation,
    'request_id',p_request_id,
    'data',jsonb_build_object(
      'id',v_contact.id,
      'estado',v_contact.estado,
      'canal',coalesce(v_contact.canal,'social'),
      'showcase_elemento_id',v_contact.showcase_elemento_id,
      'existing',v_was_existing
    )
  );
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_network_mutate_v107(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_network_mutate_v107(text,jsonb,uuid) to authenticated;

-- Lista de conversaciones: conserva el contrato v106 y añade contexto de canal/producto.
create or replace function public.app_kombax_contactos_v107()
returns table(
  id uuid,
  remitente_id uuid,
  remitente_nombre text,
  destinatario_id uuid,
  destinatario_nombre text,
  motivo text,
  estado text,
  creado_en timestamptz,
  respondido_en timestamptz,
  cerrado_en timestamptz,
  direccion text,
  gestionable boolean,
  ultimo_mensaje text,
  ultimo_mensaje_en timestamptz,
  no_leidos integer,
  puede_chat boolean,
  puede_cerrar boolean,
  canal text,
  showcase_elemento_id uuid,
  showcase_producto_nombre text,
  showcase_producto_imagen_url text,
  showcase_marca_nombre text
)
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_actor_ids uuid[];
begin
  if not public.app_kombax_social_acceso_v041() then
    raise exception 'SOCIAL_ACCESS_REQUIRED';
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  return query
  with accessible as materialized (
    select c.*
    from public.kombax_social_contactos c
    where c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null
    union
    select c.*
    from public.kombax_social_contactos c
    where c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null
  )
  select
    c.id,
    rs.id,
    rs.nombre_publico,
    ds.id,
    ds.nombre_publico,
    c.motivo,
    c.estado,
    c.creado_en,
    c.respondido_en,
    c.cerrado_en,
    case
      when c.destinatario_social_id=any(v_actor_ids) and not (c.remitente_social_id=any(v_actor_ids)) then 'recibida'
      when c.remitente_social_id=any(v_actor_ids) then 'enviada'
      else 'contacto'
    end,
    c.estado='pendiente' and c.destinatario_social_id=any(v_actor_ids),
    last_message.texto,
    last_message.creado_en,
    coalesce((
      select count(*)::integer
      from public.kombax_social_contacto_mensajes um
      where um.contacto_id=c.id
        and um.leido_en is null
        and not (um.autor_social_id=any(v_actor_ids))
    ),0),
    c.estado='aceptada'
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not case
        when c.remitente_social_id=any(v_actor_ids)
          then public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id)
        else public.app_kombax_contact_pair_blocked_v065(c.destinatario_social_id,c.remitente_social_id)
      end,
    c.estado='aceptada',
    coalesce(c.canal,'social'),
    c.showcase_elemento_id,
    c.showcase_producto_nombre,
    c.showcase_producto_imagen_url,
    c.showcase_marca_nombre
  from accessible c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral (
    select m.texto,m.creado_en
    from public.kombax_social_contacto_mensajes m
    where m.contacto_id=c.id
    order by m.ordinal desc,m.id desc
    limit 1
  ) last_message on true
  order by coalesce(last_message.creado_en,c.creado_en) desc,c.id desc
  limit 200;
end
$$;
revoke all on function public.app_kombax_contactos_v107() from public,anon;
grant execute on function public.app_kombax_contactos_v107() to authenticated;

-- El badge de Mensajes representa conversaciones con mensajes pendientes de abrir,
-- no la suma de todos los mensajes individuales de un mismo hilo.
create or replace function public.app_kombax_header_activity_v107()
returns table(
  kombax_pending integer,
  relation_requests integer,
  contact_requests integer,
  message_unread integer
)
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_actor_ids uuid[];
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_social_acceso_v041() then
    return query select 0,0,0,0;
    return;
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  return query
  with relation_count as (
    select count(*)::integer n
    from public.kombax_relaciones r
    where r.estado='pending' and r.destino_social_id=any(v_actor_ids)
  ),
  contact_count as (
    select count(*)::integer n
    from public.kombax_social_contactos c
    where c.estado='pendiente'
      and c.destinatario_social_id=any(v_actor_ids)
      and c.eliminado_destinatario_en is null
  ),
  unread_threads as (
    select count(distinct c.id)::integer n
    from public.kombax_social_contacto_mensajes m
    join public.kombax_social_contactos c on c.id=m.contacto_id
    where c.estado='aceptada'
      and m.leido_en is null
      and not (m.autor_social_id=any(v_actor_ids))
      and (
        (c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null)
        or
        (c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null)
      )
  )
  select (r.n+c.n)::integer,r.n,c.n,m.n
  from relation_count r,contact_count c,unread_threads m;
end $$;
revoke all on function public.app_kombax_header_activity_v107() from public,anon;
grant execute on function public.app_kombax_header_activity_v107() to authenticated;

create or replace function public.app_kombax_header_summary_v107(p_club_id uuid)
returns table(
  club_unread_groups integer,
  club_unread_items integer,
  club_latest_id uuid,
  club_latest_title text,
  club_latest_body text,
  club_latest_created_at timestamptz,
  kombax_pending integer,
  relation_requests integer,
  contact_requests integer,
  message_unread integer
)
language sql
stable
security definer
set search_path=public,auth
as $$
  select
    h.club_unread_groups,h.club_unread_items,h.club_latest_id,h.club_latest_title,
    h.club_latest_body,h.club_latest_created_at,
    k.kombax_pending,k.relation_requests,k.contact_requests,k.message_unread
  from public.app_kombax_header_summary_v106(p_club_id) h
  cross join public.app_kombax_header_activity_v107() k;
$$;
revoke all on function public.app_kombax_header_summary_v107(uuid) from public,anon;
grant execute on function public.app_kombax_header_summary_v107(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
