-- 106_kombax_10k_concurrent_scale_20061.sql
-- 20.061 · 10K CONCURRENT SCALE READINESS
-- Reduce helper amplification in hot Social/chat reads while preserving the existing authorization model.

begin;

create index if not exists idx_kombax_social_contacto_remitente_v106
  on public.kombax_social_contactos(remitente_social_id,estado,creado_en desc);

-- Internal actor set. Candidate rows are narrowed by ownership/management first;
-- the canonical v051 authorization helper remains the final decision.
create or replace function public.app_kombax_my_social_actor_ids_v106()
returns table(social_id uuid)
language sql
stable
security definer
set search_path to 'public','auth'
as $$
  with candidates as (
    select sp.id
    from public.kombax_social_perfiles sp
    join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.sujeto_tipo='miembro' and i.perfil_id=auth.uid()

    union

    select sp.id
    from public.kombax_social_perfiles sp
    where sp.sujeto_tipo='club'
      and exists(
        select 1
        from public.miembros_club mc
        where mc.club_id=sp.club_id and mc.perfil_id=auth.uid() and mc.activo
      )

    union

    select sp.id
    from public.kombax_social_perfiles sp
    join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
    where sp.sujeto_tipo='perfil_directo'
      and (
        d.perfil_id=auth.uid()
        or exists(
          select 1
          from public.kombax_perfil_gestores g
          where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'
        )
      )
  )
  select c.id
  from candidates c
  where public.app_kombax_social_puede_actuar_v051(c.id);
$$;
revoke all on function public.app_kombax_my_social_actor_ids_v106() from public,anon,authenticated;

create or replace function public.app_kombax_contact_can_access_v106(p_contacto_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public','auth'
as $$
  with actors as materialized (
    select social_id from public.app_kombax_my_social_actor_ids_v106()
  )
  select exists(
    select 1
    from public.kombax_social_contactos c
    where c.id=p_contacto_id
      and (
        (c.remitente_social_id in (select social_id from actors) and c.eliminado_remitente_en is null)
        or
        (c.destinatario_social_id in (select social_id from actors) and c.eliminado_destinatario_en is null)
      )
  );
$$;
revoke all on function public.app_kombax_contact_can_access_v106(uuid) from public,anon,authenticated;

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
      and c.destinatario_social_id=any(v_actor_ids)
      and c.eliminado_destinatario_en is null
  ),
  unread_count as (
    select count(*)::integer n
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
  from relation_count r,contact_count c,unread_count m;
end
$$;
revoke all on function public.app_kombax_header_activity_v106() from public,anon;
grant execute on function public.app_kombax_header_activity_v106() to authenticated;

create or replace function public.app_kombax_header_summary_v106(p_club_id uuid)
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
language plpgsql
stable
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_club_id is null or not public.es_miembro_club(p_club_id) then raise exception 'CLUB_ACCESS_REQUIRED'; end if;

  return query
  with visible as materialized (
    select n.id,n.tipo,n.titulo,n.cuerpo,n.creado_en,
      coalesce(l.notificacion_id is not null,n.leida,false) as leida
    from public.notificaciones n
    left join public.notificaciones_lecturas l
      on l.notificacion_id=n.id and l.perfil_id=v_uid
    where n.club_id=p_club_id
      and n.ciclo_estado='activo'
      and (
        n.perfil_id=v_uid
        or n.audiencia='todos'
        or (n.rol_destino is not null and public.tiene_rol_club(p_club_id,n.rol_destino))
      )
    order by n.creado_en desc,n.id desc
    limit 1000
  ),
  unread as materialized (
    select v.*,public.app_notificacion_requiere_accion_v034(v.id) as requiere_accion
    from visible v
    where not v.leida
  ),
  club_stats as (
    select count(*)::integer as unread_items,
      count(distinct case
        when u.requiere_accion then 'accion'
        when u.tipo in ('reserva_sesion','sesion_cambio','clase') then 'sesiones'
        when u.tipo='comunidad' then 'comunidad'
        when u.tipo in ('comunicacion','evento') then 'comunicaciones'
        else 'otros'
      end)::integer as unread_groups
    from unread u
  ),
  latest as (
    select v.id,v.titulo,v.cuerpo,v.creado_en
    from visible v
    order by v.creado_en desc,v.id desc
    limit 1
  ),
  kombax as (
    select * from public.app_kombax_header_activity_v106()
  )
  select cs.unread_groups,cs.unread_items,
    l.id,l.titulo,l.cuerpo,l.creado_en,
    coalesce(k.kombax_pending,0)::integer,
    coalesce(k.relation_requests,0)::integer,
    coalesce(k.contact_requests,0)::integer,
    coalesce(k.message_unread,0)::integer
  from club_stats cs
  left join latest l on true
  left join kombax k on true;
end
$$;
revoke all on function public.app_kombax_header_summary_v106(uuid) from public,anon;
grant execute on function public.app_kombax_header_summary_v106(uuid) to authenticated;

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

create or replace function public.app_kombax_contact_mensajes_v106(
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
set search_path to 'public','auth'
as $$
declare
  v_limit integer:=least(50,greatest(1,coalesce(p_limit,30)));
  v_actor_ids uuid[];
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_before_ordinal is not null and p_after_ordinal is not null then
    raise exception 'KOMBAX_CONTACT_CURSOR_INVALID';
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  if not exists(
    select 1
    from public.kombax_social_contactos c
    where c.id=p_contacto_id
      and (
        (c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null)
        or
        (c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null)
      )
  ) then
    raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';
  end if;

  if p_after_ordinal is not null then
    return query
    select
      m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal,m.texto,m.creado_en,m.leido_en,
      m.autor_social_id=any(v_actor_ids),
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
      p.autor_social_id=any(v_actor_ids),
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
end
$$;
revoke all on function public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer) to authenticated;

create or replace function public.app_kombax_contact_mark_read_v106(p_contacto_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_actor_ids uuid[];
  v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  if not exists(
    select 1
    from public.kombax_social_contactos c
    where c.id=p_contacto_id
      and (
        (c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null)
        or
        (c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null)
      )
  ) then
    raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';
  end if;

  update public.kombax_social_contacto_mensajes m
  set leido_en=coalesce(m.leido_en,now())
  where m.contacto_id=p_contacto_id
    and m.leido_en is null
    and not (m.autor_social_id=any(v_actor_ids));

  get diagnostics v_count=row_count;
  return v_count;
end
$$;
revoke all on function public.app_kombax_contact_mark_read_v106(uuid) from public,anon;
grant execute on function public.app_kombax_contact_mark_read_v106(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
