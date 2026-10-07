CREATE OR REPLACE FUNCTION public.app_kombax_profile_contacts_fix18(p_social_id uuid,p_limit integer default 50)
 RETURNS TABLE(id uuid, remitente_id uuid, remitente_nombre text, destinatario_id uuid, destinatario_nombre text, motivo text, estado text, creado_en timestamp with time zone, respondido_en timestamp with time zone, cerrado_en timestamp with time zone, direccion text, gestionable boolean, ultimo_mensaje text, ultimo_mensaje_en timestamp with time zone, no_leidos integer, puede_chat boolean, puede_cerrar boolean, canal text, showcase_elemento_id uuid, showcase_producto_nombre text, showcase_producto_imagen_url text, showcase_marca_nombre text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_actor_ids uuid[];
begin
  if not public.app_kombax_social_acceso_v041() then
    raise exception 'SOCIAL_ACCESS_REQUIRED';
  end if;

  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids
  from public.app_kombax_my_social_actor_ids_v106() a;

  if not (p_social_id=any(v_actor_ids)) then return; end if;

  return query
  with accessible as materialized (
    select c.*
    from public.kombax_social_contactos c
    where c.remitente_social_id=p_social_id and c.eliminado_remitente_en is null
    union
    select c.*
    from public.kombax_social_contactos c
    where c.destinatario_social_id=p_social_id and c.eliminado_destinatario_en is null
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
  limit least(greatest(coalesce(p_limit,50),1),200);
end
$function$;

REVOKE ALL ON FUNCTION public.app_kombax_profile_contacts_fix18(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_kombax_profile_contacts_fix18(uuid,integer) TO authenticated;
