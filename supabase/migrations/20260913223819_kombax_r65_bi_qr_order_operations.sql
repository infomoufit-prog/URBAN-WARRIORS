-- KOMBAX R65 live-aligned migration · 20260913223819_kombax_r65_bi_qr_order_operations
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- 7) Enterprise BI + safe tracking API
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commerce_track_r65(p_event_type text,p_provider_id uuid,p_product_id uuid,p_event_id uuid,p_order_id uuid,p_source text,p_amount_minor integer,p_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_provider uuid:=p_provider_id;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_event_type not in('product_impression','product_view','product_interest','showcase_checkout_start','event_view','ticket_checkout_start') then raise exception 'ANALYTICS_EVENT_NOT_CLIENT_WRITABLE'; end if;
  if p_product_id is not null then select marca_id into strict v_provider from public.kombax_showcase_elementos where id=p_product_id and estado='publicado'; end if;
  if p_event_type like 'product_%' or p_event_type='showcase_checkout_start' then if v_provider is null then raise exception 'ANALYTICS_PROVIDER_REQUIRED'; end if; end if;
  if p_event_type in('event_view','ticket_checkout_start') and p_event_id is null then raise exception 'ANALYTICS_EVENT_REQUIRED'; end if;
  insert into kombax_payments.commerce_analytics_events_r65(actor_user_id,event_type,provider_id,product_id,event_id,order_id,source,amount_minor,metadata)
  values(v_uid,p_event_type,v_provider,p_product_id,p_event_id,p_order_id,left(nullif(btrim(p_source),''),100),p_amount_minor,coalesce(p_metadata,'{}'::jsonb));
  return jsonb_build_object('ok',true);
end $$;
revoke all on function public.app_kombax_commerce_track_r65(text,uuid,uuid,uuid,uuid,text,integer,jsonb) from public,anon;
grant execute on function public.app_kombax_commerce_track_r65(text,uuid,uuid,uuid,uuid,text,integer,jsonb) to authenticated;

create or replace function public.app_kombax_showcase_bi_r65(p_provider_id uuid,p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_plan text;v_days integer:=least(greatest(coalesce(p_days,30),1),365);v_from timestamptz:=now()-(least(greatest(coalesce(p_days,30),1),365)*interval '1 day');
begin
  if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_plan:=kombax_commercial.seller_plan_r64('showcase_provider',p_provider_id);
  if v_plan not in('enterprise','brand_enterprise') then return jsonb_build_object('locked',true,'required_plan','enterprise','plan_code',v_plan); end if;
  return jsonb_build_object('locked',false,'days',v_days,'plan_code',v_plan,
    'impressions',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_impression' and occurred_at>=v_from),
    'views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_view' and occurred_at>=v_from),
    'interest',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_interest' and occurred_at>=v_from),
    'checkout_starts',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_checkout_start' and occurred_at>=v_from),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_purchase' and occurred_at>=v_from),
    'revenue_minor',(select coalesce(sum(amount_minor),0) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_purchase' and occurred_at>=v_from),
    'conversion_percent',round(100.0*(select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='showcase_purchase' and occurred_at>=v_from)/nullif((select count(*) from kombax_payments.commerce_analytics_events_r65 where provider_id=p_provider_id and event_type='product_view' and occurred_at>=v_from),0),2),
    'top_products',(select coalesce(jsonb_agg(to_jsonb(x) order by x.purchases desc),'[]'::jsonb) from (select a.product_id,e.nombre,count(*) purchases,coalesce(sum(a.amount_minor),0) revenue_minor from kombax_payments.commerce_analytics_events_r65 a join public.kombax_showcase_elementos e on e.id=a.product_id where a.provider_id=p_provider_id and a.event_type='showcase_purchase' and a.occurred_at>=v_from group by a.product_id,e.nombre order by purchases desc limit 10)x));
end $$;
revoke all on function public.app_kombax_showcase_bi_r65(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_bi_r65(uuid,integer) to authenticated;

create or replace function public.app_kombax_event_bi_r65(p_event_id uuid,p_days integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_seller jsonb;v_plan text;v_days integer:=least(greatest(coalesce(p_days,30),1),365);v_from timestamptz:=now()-(least(greatest(coalesce(p_days,30),1),365)*interval '1 day');
begin
  if v_uid is null or not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  v_seller:=kombax_payments.event_seller_r625(p_event_id);v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  if v_plan not in('enterprise','brand_enterprise') then return jsonb_build_object('locked',true,'required_plan','enterprise','plan_code',v_plan); end if;
  return jsonb_build_object('locked',false,'days',v_days,'plan_code',v_plan,
    'event_views',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='event_view' and occurred_at>=v_from),
    'checkout_starts',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_checkout_start' and occurred_at>=v_from),
    'purchases',(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_purchase' and occurred_at>=v_from),
    'checkins',(select count(*) from kombax_payments.event_ticket_checkin_audit where event_id=p_event_id and outcome='valid' and created_at>=v_from),
    'revenue_minor',(select coalesce(sum(amount_minor),0) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_purchase' and occurred_at>=v_from),
    'conversion_percent',round(100.0*(select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='ticket_purchase' and occurred_at>=v_from)/nullif((select count(*) from kombax_payments.commerce_analytics_events_r65 where event_id=p_event_id and event_type='event_view' and occurred_at>=v_from),0),2));
end $$;
revoke all on function public.app_kombax_event_bi_r65(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_bi_r65(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) QR access audit history
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_event_checkin_history_r65(p_event_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
    select a.id,a.ticket_id,a.actor_user_id,a.outcome,a.created_at,t.ticket_code,t.ticket_index,o.order_number,o.buyer_email
    from kombax_payments.event_ticket_checkin_audit a
      left join kombax_payments.event_tickets t on t.id=a.ticket_id
      left join kombax_payments.event_ticket_orders o on o.id=t.order_id
    where a.event_id=p_event_id order by a.created_at desc limit least(greatest(coalesce(p_limit,200),1),500)
  ) x);
end $$;
revoke all on function public.app_kombax_event_checkin_history_r65(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_checkin_history_r65(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Override order mutation: operational communications + paid cancellation guard
-- ---------------------------------------------------------------------------
create or replace function public.app_showcase_order_mutate_v259(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_order kombax_payments.showcase_orders;v_incident kombax_payments.showcase_incidents;v_status text;v_message text;v_previous text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_order from kombax_payments.showcase_orders where id=(p_payload->>'order_id')::uuid for update;v_previous:=v_order.status;
  if p_operation='status' then
    if not kombax_payments.can_manage_provider(v_uid,v_order.seller_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
    v_status:=p_payload->>'status';
    if v_status='cancelled' and v_order.status not in('received') then raise exception 'PAID_ORDER_CANCELLATION_REQUIRES_REFUND_CENTER'; end if;
    if not ((v_order.status='payment_confirmed' and v_status='preparing') or (v_order.status='preparing' and v_status='shipped') or (v_order.status='shipped' and v_status='delivered') or (v_order.status='received' and v_status='cancelled')) then raise exception 'ORDER_STATUS_TRANSITION_DENIED'; end if;
    if v_status='shipped' and coalesce(nullif(btrim(p_payload->>'tracking_number'),''),nullif(btrim(p_payload->>'tracking_url'),'')) is null then raise exception 'TRACKING_REQUIRED'; end if;
    update kombax_payments.showcase_orders set status=v_status,carrier=nullif(btrim(p_payload->>'carrier'),''),tracking_number=nullif(btrim(p_payload->>'tracking_number'),''),tracking_url=nullif(btrim(p_payload->>'tracking_url'),''),updated_at=now() where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail) values(v_order.id,v_order.status,v_status,v_uid,'seller',p_payload-'order_id');
    perform kombax_payments.queue_communication_r65('showcase',v_order.seller_provider_id,null,v_order.id,null,v_order.buyer_user_id,v_order.buyer_email,
      'showcase_'||v_status,
      case v_status when 'preparing' then 'Estamos preparando tu pedido KOMBAX' when 'shipped' then 'Tu pedido KOMBAX ha sido enviado' when 'delivered' then 'Tu pedido KOMBAX figura como entregado' else 'Actualización de tu pedido KOMBAX' end,
      case v_status when 'preparing' then 'El vendedor ha comenzado a preparar tu pedido.' when 'shipped' then 'El vendedor ha marcado tu pedido como enviado. Consulta KOMBAX para ver el seguimiento.' when 'delivered' then 'El vendedor ha marcado tu pedido como entregado.' else 'El estado de tu pedido se ha actualizado.' end,
      'seller',v_uid,'showcase-status:'||v_order.id::text||':'||v_status||':'||p_request_id::text,p_payload);
    return jsonb_build_object('ok',true,'order_id',v_order.id,'status',v_status,'request_id',p_request_id);
  elsif p_operation='incident' then
    v_message:=left(nullif(btrim(p_payload->>'message'),''),4000);
    if v_order.buyer_user_id<>v_uid and not kombax_payments.can_manage_provider(v_uid,v_order.seller_provider_id) then raise exception 'ORDER_ACCESS_DENIED'; end if;
    insert into kombax_payments.showcase_incidents(order_id,buyer_user_id,seller_provider_id,reason,status) values(v_order.id,v_order.buyer_user_id,v_order.seller_provider_id,left(coalesce(p_payload->>'reason','Incidencia'),120),'open') returning * into v_incident;
    if v_message is not null then insert into kombax_payments.showcase_incident_messages(incident_id,author_user_id,message) values(v_incident.id,v_uid,v_message); end if;
    update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail) values(v_order.id,v_previous,'incident',v_uid,case when v_order.buyer_user_id=v_uid then 'buyer' else 'seller' end,jsonb_build_object('incident_id',v_incident.id));
    return jsonb_build_object('ok',true,'incident_id',v_incident.id,'order_id',v_order.id,'request_id',p_request_id);
  end if;
  raise exception 'ORDER_OPERATION_NOT_SUPPORTED';
end $$;
revoke all on function public.app_showcase_order_mutate_v259(text,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_order_mutate_v259(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
commit;
