-- 105_kombax_platform_performance_20060.sql
-- 20.060 · PLATFORM PERFORMANCE & SCALE HARDENING
-- Resumen de cabecera de bajo coste + índice de feed activo de notificaciones.

create index if not exists idx_notificaciones_club_active_feed_v105
  on public.notificaciones (club_id, creado_en desc, id desc)
  where ciclo_estado='activo';

create or replace function public.app_kombax_header_summary_v105(p_club_id uuid)
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
    select v.id,v.titulo,v.cuerpo,v.creado_en from visible v
    order by v.creado_en desc,v.id desc limit 1
  ),
  kombax as (
    select * from public.app_kombax_header_activity_v103()
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

revoke all on function public.app_kombax_header_summary_v105(uuid) from public,anon;
grant execute on function public.app_kombax_header_summary_v105(uuid) to authenticated;
