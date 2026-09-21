-- KOMBAX R69 · Events Operations Center
-- Live-aligned migration: 20260914083811_kombax_r69_event_center_operations
begin;

create or replace function public.app_kombax_event_center_list_r69(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  return (
    with manageable as (
      select e.*
      from public.kombax_eventos_publicos e
      where public.app_kombax_evento_puede_gestionar_v160(e.id)
      order by coalesce(e.fecha_inicio,e.actualizado_en) desc nulls last,e.actualizado_en desc
      limit least(greatest(coalesce(p_limit,100),1),200)
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',e.id,
      'slug',e.slug,
      'tipo',e.tipo,
      'nombre',e.nombre,
      'resumen',e.resumen,
      'estado',e.estado,
      'visibilidad',e.visibilidad,
      'fecha_inicio',e.fecha_inicio,
      'fecha_fin',e.fecha_fin,
      'lugar_nombre',e.lugar_nombre,
      'municipio',e.municipio,
      'provincia',e.provincia,
      'cartel_url',e.cartel_url,
      'banner_url',e.banner_url,
      'tema_visual',e.tema_visual,
      'organizador_nombre',e.organizador_nombre,
      'publicado_en',e.publicado_en,
      'actualizado_en',e.actualizado_en,
      'publication_status',case when e.estado='borrador' then 'draft' when e.estado='cancelado' then 'cancelled' when e.publicado_en is not null then 'published' else coalesce(e.estado,'draft') end,
      'ticketing_enabled',coalesce(e.ticketing_enabled,false),
      'ticketing_mode',coalesce(e.ticketing_mode,'none'),
      'ticket_capacity',e.ticket_capacity,
      'ticket_price_minor',e.ticket_price_minor,
      'ticket_currency',coalesce(e.ticket_currency,'EUR'),
      'ticketing_service_status',coalesce((select sa.status from kombax_commercial.service_access sa where sa.subject_type='event' and sa.subject_id=e.id and sa.service_code='events_ticketing' order by sa.updated_at desc limit 1),'not_requested'),
      'ticketing_active',kombax_commercial.event_ticketing_active_r628(e.id),
      'contracts_ready',kombax_commercial.event_contracts_ready_r628(e.id),
      'tickets_paid',coalesce((select sum(o.quantity)::int from kombax_payments.event_ticket_orders o where o.event_id=e.id and o.status='paid'),0),
      'tickets_reserved',coalesce((select sum(o.quantity)::int from kombax_payments.event_ticket_orders o where o.event_id=e.id and o.status='pending_payment' and o.expires_at>now()),0),
      'tickets_used',(select count(*)::int from kombax_payments.event_tickets t where t.event_id=e.id and t.status='used'),
      'tickets_refunded',(select count(*)::int from kombax_payments.event_tickets t where t.event_id=e.id and t.status='refunded'),
      'revenue_minor',coalesce((select sum(o.amount_total_minor)::bigint from kombax_payments.event_ticket_orders o where o.event_id=e.id and o.status='paid'),0),
      'views_30d',(select count(*)::int from kombax_payments.commerce_analytics_events_r65 a where a.event_id=e.id and a.event_type='event_view' and a.occurred_at>=now()-interval '30 days'),
      'checkout_starts_30d',(select count(*)::int from kombax_payments.commerce_analytics_events_r65 a where a.event_id=e.id and a.event_type='ticket_checkout_start' and a.occurred_at>=now()-interval '30 days'),
      'purchases_30d',(select count(*)::int from kombax_payments.commerce_analytics_events_r65 a where a.event_id=e.id and a.event_type='ticket_purchase' and a.occurred_at>=now()-interval '30 days'),
      'can_manage',true
    ) order by coalesce(e.fecha_inicio,e.actualizado_en) desc nulls last,e.actualizado_en desc),'[]'::jsonb)
    from manageable e
  );
end
$$;

revoke all on function public.app_kombax_event_center_list_r69(integer) from public,anon;
grant execute on function public.app_kombax_event_center_list_r69(integer) to authenticated;

commit;
