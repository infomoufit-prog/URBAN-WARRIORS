-- KOMBAX R77 exact date-window analytics for calendar periods and custom ranges.

create or replace function public.app_kombax_showcase_analytics_range_r77(
  p_provider_id uuid,
  p_from timestamptz,
  p_to timestamptz
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := auth.uid();
  v_from timestamptz := p_from;
  v_to timestamptz := p_to;
  v_days integer := greatest(1,ceil(extract(epoch from (p_to-p_from))/86400.0)::integer);
  v_prev_from timestamptz := p_from - (p_to-p_from);
  v_provider public.kombax_showcase_marcas;
  v_current jsonb;
  v_previous jsonb;
  v_series jsonb;
  v_products jsonb;
  v_categories jsonb;
begin
  if p_from is null or p_to is null or p_from>=p_to or p_to-p_from>interval '366 days' then raise exception 'ANALYTICS_RANGE_INVALID'; end if;
  if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then
    raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';
  end if;
  select * into strict v_provider from public.kombax_showcase_marcas where id=p_provider_id;

  with paid_orders as (
    select o.* from kombax_payments.showcase_orders o
    where o.seller_provider_id=p_provider_id
      and o.status in ('payment_confirmed','preparing','shipped','delivered')
      and o.created_at>=v_from and o.created_at<v_to
  ), order_units as (
    select coalesce(sum(i.quantity),0)::bigint units
    from kombax_payments.showcase_order_items i join paid_orders o on o.id=i.order_id
  )
  select jsonb_build_object(
    'orders',count(*),
    'gross_minor',coalesce(sum(amount_total_minor),0),
    'ticket_average_minor',case when count(*)=0 then 0 else round(coalesce(sum(amount_total_minor),0)::numeric/count(*))::bigint end,
    'units',coalesce((select units from order_units),0),
    'buyers',count(distinct coalesce(buyer_user_id::text,lower(buyer_email))),
    'repeat_buyers',(select count(*) from (select coalesce(buyer_user_id::text,lower(buyer_email)) k from paid_orders group by 1 having count(*)>1) q),
    'refunds_minor',(select coalesce(sum(r.amount_succeeded_minor),0) from kombax_payments.commerce_refunds_r65 r join kombax_payments.showcase_orders o on o.id=r.showcase_order_id where o.seller_provider_id=p_provider_id and r.status='succeeded' and r.created_at>=v_from and r.created_at<v_to),
    'platform_fee_minor',(select coalesce(sum(a.platform_fee_minor),0) from kombax_payments.payment_attempts a join paid_orders o on o.id=a.order_id where a.status in('succeeded','refunded')),
    'impressions',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_impression' and occurred_at>=v_from and occurred_at<v_to),
    'views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_view' and occurred_at>=v_from and occurred_at<v_to),
    'interest',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_interest' and occurred_at>=v_from and occurred_at<v_to),
    'checkout_starts',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_checkout_start' and occurred_at>=v_from and occurred_at<v_to),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_purchase' and occurred_at>=v_from and occurred_at<v_to),
    'inquiries',(select count(*) from public.kombax_showcase_inquiries_r58 where marca_id=p_provider_id and creada_en>=v_from and creada_en<v_to),
    'products_active',(select count(*) from public.kombax_showcase_elementos where marca_id=p_provider_id and listing_kind='product' and estado='publicado'),
    'low_stock',(select count(*) from public.kombax_showcase_elementos where marca_id=p_provider_id and listing_kind='product' and estado='publicado' and stock is not null and stock between 1 and stock_alert_threshold),
    'out_of_stock',(select count(*) from public.kombax_showcase_elementos where marca_id=p_provider_id and listing_kind='product' and estado='publicado' and stock=0)
  ) into v_current from paid_orders;

  with paid_orders as (
    select o.* from kombax_payments.showcase_orders o
    where o.seller_provider_id=p_provider_id
      and o.status in ('payment_confirmed','preparing','shipped','delivered')
      and o.created_at>=v_prev_from and o.created_at<v_from
  )
  select jsonb_build_object(
    'orders',count(*),
    'gross_minor',coalesce(sum(amount_total_minor),0),
    'buyers',count(distinct coalesce(buyer_user_id::text,lower(buyer_email))),
    'views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_view' and occurred_at>=v_prev_from and occurred_at<v_from),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_purchase' and occurred_at>=v_prev_from and occurred_at<v_from)
  ) into v_previous from paid_orders;

  with days as (
    select generate_series(date_trunc('day',v_from),date_trunc('day',v_to - interval '1 millisecond'),interval '1 day') d
  ), sales as (
    select date_trunc('day',o.created_at) d,count(*) orders,coalesce(sum(o.amount_total_minor),0) gross_minor
    from kombax_payments.showcase_orders o
    where o.seller_provider_id=p_provider_id and o.status in ('payment_confirmed','preparing','shipped','delivered') and o.created_at>=v_from and o.created_at<v_to
    group by 1
  ), traffic as (
    select date_trunc('day',a.occurred_at) d,
      count(*) filter(where a.event_type='product_view') views,
      count(*) filter(where a.event_type='product_interest') interest
    from kombax_payments.commerce_analytics_events_r65 a
    where a.provider_id=p_provider_id and a.occurred_at>=v_from and a.occurred_at<v_to
    group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object('date',to_char(days.d,'YYYY-MM-DD'),'orders',coalesce(s.orders,0),'gross_minor',coalesce(s.gross_minor,0),'views',coalesce(t.views,0),'interest',coalesce(t.interest,0)) order by days.d),'[]'::jsonb)
  into v_series from days left join sales s on s.d=days.d left join traffic t on t.d=days.d;

  with sold as (
    select i.product_id,sum(i.quantity)::int units,count(distinct i.order_id)::int orders,sum(i.quantity*i.unit_amount_minor)::bigint revenue_minor
    from kombax_payments.showcase_order_items i join kombax_payments.showcase_orders o on o.id=i.order_id
    where o.seller_provider_id=p_provider_id and o.status in ('payment_confirmed','preparing','shipped','delivered') and o.created_at>=v_from and o.created_at<v_to
    group by i.product_id
  ), traffic as (
    select product_id,
      count(*) filter(where event_type='product_impression') impressions,
      count(*) filter(where event_type='product_view') views,
      count(*) filter(where event_type='product_interest') interest
    from kombax_payments.commerce_analytics_events_r65
    where provider_id=p_provider_id and product_id is not null and occurred_at>=v_from and occurred_at<v_to
    group by product_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',e.id,'name',e.nombre,'image_url',e.imagen_url,'product_type',coalesce(nullif(e.product_type,''),'Sin clasificar'),'status',e.estado,'stock',e.stock,
    'units',coalesce(s.units,0),'orders',coalesce(s.orders,0),'revenue_minor',coalesce(s.revenue_minor,0),
    'impressions',coalesce(t.impressions,0),'views',coalesce(t.views,0),'interest',coalesce(t.interest,0),
    'conversion_percent',case when coalesce(t.views,0)=0 then null else round(100.0*coalesce(s.orders,0)/t.views,2) end
  ) order by coalesce(s.revenue_minor,0) desc,e.nombre),'[]'::jsonb)
  into v_products
  from public.kombax_showcase_elementos e left join sold s on s.product_id=e.id left join traffic t on t.product_id=e.id
  where e.marca_id=p_provider_id and e.listing_kind='product';

  select coalesce(jsonb_agg(to_jsonb(x) order by x.revenue_minor desc),'[]'::jsonb) into v_categories from (
    select coalesce(nullif(e.product_type,''),'Sin clasificar') category,sum(i.quantity)::int units,sum(i.quantity*i.unit_amount_minor)::bigint revenue_minor
    from kombax_payments.showcase_order_items i join kombax_payments.showcase_orders o on o.id=i.order_id join public.kombax_showcase_elementos e on e.id=i.product_id
    where o.seller_provider_id=p_provider_id and o.status in ('payment_confirmed','preparing','shipped','delivered') and o.created_at>=v_from and o.created_at<v_to
    group by 1
  ) x;

  return jsonb_build_object(
    'ok',true,'scope','showcase','provider_id',p_provider_id,'days',v_days,'from',v_from,'to',v_to,
    'entity',jsonb_build_object('id',v_provider.id,'name',v_provider.nombre,'type',v_provider.sujeto_tipo,'logo_url',coalesce(v_provider.logo_url,(select c.logo_url from public.clubes c where c.id=v_provider.club_id)),'club_id',v_provider.club_id),
    'current',coalesce(v_current,'{}'::jsonb),'previous',coalesce(v_previous,'{}'::jsonb),'series',coalesce(v_series,'[]'::jsonb),'products',coalesce(v_products,'[]'::jsonb),'categories',coalesce(v_categories,'[]'::jsonb)
  );
end $$;


revoke all on function public.app_kombax_showcase_analytics_range_r77(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.app_kombax_showcase_analytics_range_r77(uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.app_kombax_event_analytics_range_r77(
  p_event_id uuid,
  p_from timestamptz,
  p_to timestamptz
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := auth.uid();
  v_from timestamptz := p_from;
  v_to timestamptz := p_to;
  v_days integer := greatest(1,ceil(extract(epoch from (p_to-p_from))/86400.0)::integer);
  v_prev_from timestamptz := p_from - (p_to-p_from);
  v_event public.kombax_eventos_publicos;
  v_current jsonb;
  v_previous jsonb;
  v_series jsonb;
  v_results jsonb;
begin
  if p_from is null or p_to is null or p_from>=p_to or p_to-p_from>interval '366 days' then raise exception 'ANALYTICS_RANGE_INVALID'; end if;
  if v_uid is null or not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into strict v_event from public.kombax_eventos_publicos where id=p_event_id;

  with paid_orders as (
    select * from kombax_payments.event_ticket_orders where event_id=p_event_id and status='paid' and coalesce(paid_at,created_at)>=v_from and coalesce(paid_at,created_at)<v_to
  )
  select jsonb_build_object(
    'orders',count(*),'tickets',coalesce(sum(quantity),0),'gross_minor',coalesce(sum(amount_total_minor),0),
    'ticket_average_minor',case when count(*)=0 then 0 else round(coalesce(sum(amount_total_minor),0)::numeric/count(*))::bigint end,
    'buyers',count(distinct coalesce(buyer_user_id::text,lower(buyer_email))),
    'refunds_minor',(select coalesce(sum(r.amount_succeeded_minor),0) from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id and r.status='succeeded' and r.created_at>=v_from and r.created_at<v_to),
    'views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='event_view' and occurred_at>=v_from and occurred_at<v_to),
    'checkout_starts',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_checkout_start' and occurred_at>=v_from and occurred_at<v_to),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_purchase' and occurred_at>=v_from and occurred_at<v_to),
    'checkins',(select count(*) from kombax_payments.event_ticket_checkin_audit where event_id=p_event_id and outcome='valid' and created_at>=v_from and created_at<v_to),
    'tickets_paid_all',(select coalesce(sum(quantity),0) from kombax_payments.event_ticket_orders where event_id=p_event_id and status='paid'),
    'tickets_used_all',(select count(*) from kombax_payments.event_tickets where event_id=p_event_id and status='used'),
    'tickets_active_all',(select count(*) from kombax_payments.event_tickets where event_id=p_event_id and status='active'),
    'capacity',coalesce(v_event.ticket_capacity,v_event.aforo,0),
    'participants',(select count(*) from public.app_kombax_evento_participantes_v161(p_event_id))
  ) into v_current from paid_orders;

  with paid_orders as (
    select * from kombax_payments.event_ticket_orders where event_id=p_event_id and status='paid' and coalesce(paid_at,created_at)>=v_prev_from and coalesce(paid_at,created_at)<v_from
  )
  select jsonb_build_object(
    'orders',count(*),'tickets',coalesce(sum(quantity),0),'gross_minor',coalesce(sum(amount_total_minor),0),
    'buyers',count(distinct coalesce(buyer_user_id::text,lower(buyer_email))),
    'views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='event_view' and occurred_at>=v_prev_from and occurred_at<v_from),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_purchase' and occurred_at>=v_prev_from and occurred_at<v_from)
  ) into v_previous from paid_orders;

  with days as (
    select generate_series(date_trunc('day',v_from),date_trunc('day',v_to - interval '1 millisecond'),interval '1 day') d
  ), sales as (
    select date_trunc('day',coalesce(paid_at,created_at)) d,count(*) orders,coalesce(sum(quantity),0) tickets,coalesce(sum(amount_total_minor),0) gross_minor
    from kombax_payments.event_ticket_orders
    where event_id=p_event_id and status='paid' and coalesce(paid_at,created_at)>=v_from and coalesce(paid_at,created_at)<v_to group by 1
  ), traffic as (
    select date_trunc('day',occurred_at) d,count(*) filter(where event_type='event_view') views,count(*) filter(where event_type='ticket_checkout_start') checkout_starts
    from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and occurred_at>=v_from and occurred_at<v_to group by 1
  ), checks as (
    select date_trunc('day',created_at) d,count(*) filter(where outcome='valid') checkins from kombax_payments.event_ticket_checkin_audit where event_id=p_event_id and created_at>=v_from and created_at<v_to group by 1
  )
  select coalesce(jsonb_agg(jsonb_build_object('date',to_char(days.d,'YYYY-MM-DD'),'orders',coalesce(s.orders,0),'tickets',coalesce(s.tickets,0),'gross_minor',coalesce(s.gross_minor,0),'views',coalesce(t.views,0),'checkout_starts',coalesce(t.checkout_starts,0),'checkins',coalesce(c.checkins,0)) order by days.d),'[]'::jsonb)
  into v_series from days left join sales s on s.d=days.d left join traffic t on t.d=days.d left join checks c on c.d=days.d;

  select jsonb_build_object(
    'total',count(*),
    'completed',count(*) filter(where estado='finalizado' or resultado_estado='oficial'),
    'pending',count(*) filter(where estado<>'cancelado' and not (estado='finalizado' or resultado_estado='oficial')),
    'ko_tko',count(*) filter(where lower(coalesce(metodo_resultado,resultado,'')) ~ '(ko|tko|nocaut|knockout)'),
    'submissions',count(*) filter(where lower(coalesce(metodo_resultado,resultado,'')) ~ '(sumisi|submission|tap)'),
    'decisions',count(*) filter(where lower(coalesce(metodo_resultado,resultado,'')) ~ '(decision|decisión|puntos)'),
    'cancelled',count(*) filter(where estado='cancelado')
  ) into v_results from public.app_kombax_evento_resultados_v164(p_event_id);

  return jsonb_build_object(
    'ok',true,'scope','event','event_id',p_event_id,'days',v_days,'from',v_from,'to',v_to,
    'entity',jsonb_build_object('id',v_event.id,'name',v_event.nombre,'organizer',v_event.organizador_nombre,'poster_url',v_event.cartel_url,'date',v_event.fecha_inicio,'venue',v_event.lugar_nombre,'city',v_event.municipio,'capacity',coalesce(v_event.ticket_capacity,v_event.aforo,0)),
    'current',coalesce(v_current,'{}'::jsonb),'previous',coalesce(v_previous,'{}'::jsonb),'series',coalesce(v_series,'[]'::jsonb),'results',coalesce(v_results,'{}'::jsonb)
  );
end $$;


revoke all on function public.app_kombax_event_analytics_range_r77(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.app_kombax_event_analytics_range_r77(uuid,timestamptz,timestamptz) to authenticated;
notify pgrst,'reload schema';
