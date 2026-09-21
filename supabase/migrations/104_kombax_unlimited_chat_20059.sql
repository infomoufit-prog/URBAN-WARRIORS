begin;

-- Normas KOMBAX Social 1.3: el Contacto KOMBAX conserva aceptación previa,
-- protección de menores, bloqueo y solo texto, pero el chat aceptado deja de
-- tener un límite artificial de mensajes. No fuerza la reapertura de hilos
-- cerrados históricamente ni altera consentimientos existentes.
update public.textos_legales
set vigente=false
where tipo='comunidad_general' and vigente and version<>'1.3.0';

insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'comunidad_general','1.3.0',
E'NORMAS DE KOMBAX SOCIAL · 1.3\n\nKOMBAX Social es una capa pública general y opcional, separada de la Comunidad del Club y de la gestión administrativa. Activarla no publica email, teléfono, fecha de nacimiento, domicilio, documentos, finanzas ni relaciones familiares.\n\nIdentidad y afiliación. Un perfil Miembro puede mostrar su afiliación a un club cuando KOMBAX la verifica contra una membresía real y activa. La afiliación puede ocultarse públicamente sin alterar la pertenencia administrativa al club. El perfil del Miembro y el perfil del Club siguen siendo identidades independientes.\n\nContenido. Se permiten actualizaciones deportivas, resultados, eventos, oportunidades y publicaciones de afiliación verificadas. Se prohíben acoso, amenazas, odio o discriminación, explotación o sexualización de menores, violencia ilícita, datos privados de terceros, suplantación, spam y contenido ilegal.\n\nContacto KOMBAX. Para iniciar una conversación es obligatorio enviar una solicitud con motivo y primer mensaje. El chat solo se habilita cuando la otra identidad acepta. Una vez aceptado, el historial permanece abierto y no tiene un límite artificial de mensajes. En esta fase el chat es solo de texto: no admite imágenes, vídeos, audios, archivos ni grupos. Cualquiera de los participantes puede cerrar su conversación.\n\nMenores. KOMBAX Social puede estar disponible desde la edad mínima social verificada por el club, pero Contacto KOMBAX queda bloqueado cuando cualquiera de los perfiles personales corresponde a una persona menor de 18 años.\n\nSeguridad. Los participantes pueden bloquear y denunciar. Un bloqueo impide iniciar o continuar Contacto KOMBAX. Los mensajes privados no son de lectura global para moderadores; cualquier revisión excepcional deberá vincularse a un flujo de denuncia específico.\n\nModeración. KOMBAX puede ocultar contenido público, revisar denuncias y suspender el acceso social sin alterar la membresía administrativa del club.',true
from public.clubes c
on conflict(club_id,tipo,version) do update
set cuerpo=excluded.cuerpo,vigente=true;

-- 20.059: chats aceptados dejan de tener un límite funcional de mensajes.
-- El ordinal pasa a integer para que la columna legacy SMALLINT no se convierta
-- en un nuevo límite técnico al crecer conversaciones reales.
alter table public.kombax_social_contacto_mensajes
  drop constraint if exists kombax_social_contacto_mensajes_ordinal_check;

alter table public.kombax_social_contacto_mensajes
  alter column ordinal type integer using ordinal::integer;

alter table public.kombax_social_contacto_mensajes
  add constraint kombax_social_contacto_mensajes_ordinal_check check (ordinal>=1);

-- Bandeja ligera: no cuenta todo el historial de cada conversación.
-- Los campos *_limite de v067 quedan únicamente como compatibilidad histórica;
-- el runtime 20.059 consume este contrato v104 sin límite.
create or replace function public.app_kombax_contactos_v104()
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
set search_path=public,auth
as $$
begin
  if not public.app_kombax_social_acceso_v041() then
    raise exception 'SOCIAL_ACCESS_REQUIRED';
  end if;

  return query
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
      when public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id)
        and not public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'recibida'
      when public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'enviada'
      else 'contacto'
    end,
    c.estado='pendiente' and public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id),
    last_message.texto,
    last_message.creado_en,
    coalesce((
      select count(*)::integer
      from public.kombax_social_contacto_mensajes um
      where um.contacto_id=c.id
        and um.leido_en is null
        and not public.app_kombax_social_puede_actuar_v051(um.autor_social_id)
    ),0),
    c.estado='aceptada'
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id),
    c.estado='aceptada'
  from public.kombax_social_contactos c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral (
    select m.texto,m.creado_en
    from public.kombax_social_contacto_mensajes m
    where m.contacto_id=c.id
    order by m.ordinal desc,m.id desc
    limit 1
  ) last_message on true
  where public.app_kombax_contact_can_access_v067(c.id)
  order by coalesce(last_message.creado_en,c.creado_en) desc,c.id desc
  limit 200;
end $$;

revoke all on function public.app_kombax_contactos_v104() from public,anon;
grant execute on function public.app_kombax_contactos_v104() to authenticated;

-- Historial paginado por ordinal. p_before_ordinal carga mensajes anteriores;
-- p_after_ordinal permite sincronización incremental sin recargar el hilo completo.
create or replace function public.app_kombax_contact_mensajes_v104(
  p_contacto_id uuid,
  p_before_ordinal integer default null,
  p_after_ordinal integer default null,
  p_limit integer default 30
)
returns table(
  id uuid,
  contacto_id uuid,
  autor_social_id uuid,
  autor_nombre text,
  ordinal integer,
  texto text,
  creado_en timestamptz,
  leido_en timestamptz,
  propio boolean,
  older_available boolean
)
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_limit integer:=least(50,greatest(1,coalesce(p_limit,30)));
begin
  if auth.uid() is null or not public.app_kombax_contact_can_access_v067(p_contacto_id) then
    raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';
  end if;
  if p_before_ordinal is not null and p_after_ordinal is not null then
    raise exception 'KOMBAX_CONTACT_CURSOR_INVALID';
  end if;

  if p_after_ordinal is not null then
    return query
    select
      m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal,m.texto,m.creado_en,m.leido_en,
      public.app_kombax_social_puede_actuar_v051(m.autor_social_id),
      false
    from public.kombax_social_contacto_mensajes m
    join public.kombax_social_perfiles sp on sp.id=m.autor_social_id
    where m.contacto_id=p_contacto_id
      and m.ordinal>p_after_ordinal
    order by m.ordinal asc,m.id asc
    limit v_limit;
  else
    return query
    with picked as (
      select m.*
      from public.kombax_social_contacto_mensajes m
      where m.contacto_id=p_contacto_id
        and (p_before_ordinal is null or m.ordinal<p_before_ordinal)
      order by m.ordinal desc,m.id desc
      limit v_limit
    ), meta as (
      select min(p.ordinal) as min_ordinal from picked p
    )
    select
      p.id,p.contacto_id,p.autor_social_id,sp.nombre_publico,p.ordinal,p.texto,p.creado_en,p.leido_en,
      public.app_kombax_social_puede_actuar_v051(p.autor_social_id),
      exists(
        select 1
        from public.kombax_social_contacto_mensajes older
        where older.contacto_id=p_contacto_id
          and older.ordinal<(select min_ordinal from meta)
      )
    from picked p
    join public.kombax_social_perfiles sp on sp.id=p.autor_social_id
    order by p.ordinal asc,p.id asc;
  end if;
end $$;

revoke all on function public.app_kombax_contact_mensajes_v104(uuid,integer,integer,integer) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_v104(uuid,integer,integer,integer) to authenticated;

-- Nueva mutación de red. Mantiene el Contact Gate existente y sustituye solo
-- request/send para retirar el cierre automático y el límite de 20 mensajes.
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

notify pgrst,'reload schema';
commit;
