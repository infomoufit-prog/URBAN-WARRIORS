-- KOMBAX R62.5 split migration aligned with remote Supabase history.
-- Derived without semantic changes from original 20260910192600 migration.

begin;
-- 4) CHECKOUT · nuevo kind event_ticket + shipping para Showcase
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_checkout_prepare_internal_v259(p_actor_id uuid,p_kind text,p_reference_id uuid,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_fee public.cuotas;v_item public.kombax_showcase_elementos;
  v_provider public.kombax_showcase_marcas;v_order kombax_payments.showcase_orders;v_ticket_order kombax_payments.event_ticket_orders;
  v_event public.kombax_eventos_publicos;v_seller jsonb;v_amount int;v_platform int;v_qty int:=greatest(1,least(coalesce(p_quantity,1),100));
  v_name text;v_seller_name text;v_reserved int:=0;v_collect_shipping boolean:=false;
begin
  select * into v_attempt from kombax_payments.payment_attempts where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then
    if v_attempt.kind<>p_kind
      or (p_kind='club_fee' and v_attempt.cuota_id is distinct from p_reference_id)
      or (p_kind='showcase_order' and nullif(v_attempt.metadata->>'product_id','')::uuid is distinct from p_reference_id)
      or (p_kind='event_ticket' and nullif(v_attempt.metadata->>'event_id','')::uuid is distinct from p_reference_id) then
      raise exception 'CHECKOUT_REQUEST_ID_REUSED';
    end if;
    select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
    if v_attempt.cuota_id is not null then
      select q.concepto into v_name from public.cuotas q where q.id=v_attempt.cuota_id;
    elsif v_attempt.order_id is not null then
      select o.seller_name,i.product_name,(e.fulfillment in('seller_shipping','seller_shipping_or_pickup')) into v_seller_name,v_name,v_collect_shipping
      from kombax_payments.showcase_orders o left join kombax_payments.showcase_order_items i on i.order_id=o.id
      left join public.kombax_showcase_elementos e on e.id=i.product_id where o.id=v_attempt.order_id limit 1;
    elsif v_attempt.event_ticket_order_id is not null then
      select o.seller_name,e.nombre||' · '||o.quantity||case when o.quantity=1 then ' entrada' else ' entradas' end into v_seller_name,v_name
      from kombax_payments.event_ticket_orders o join public.kombax_eventos_publicos e on e.id=o.event_id where o.id=v_attempt.event_ticket_order_id;
    end if;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_attempt.order_id,'event_ticket_order_id',v_attempt.event_ticket_order_id,'kind',v_attempt.kind,'status',v_attempt.status,
      'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id,'stripe_account_id',v_account.stripe_account_id,
      'amount_minor',v_attempt.amount_minor,'platform_fee_minor',v_attempt.platform_fee_minor,'currency',lower(v_attempt.currency),
      'name',coalesce(v_name,'Pago KOMBAX'),'seller_name',v_seller_name,'collect_shipping',v_collect_shipping);
  end if;

  if p_kind='club_fee' then
    if not kombax_payments.can_pay_fee(p_actor_id,p_reference_id) then raise exception 'FEE_PAYMENT_DENIED'; end if;
    select * into strict v_fee from public.cuotas where id=p_reference_id for update;
    if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta') then raise exception 'FEE_NOT_PAYABLE'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='club' and subject_id=v_fee.club_id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_fee.importe*100)::int;v_platform:=kombax_payments.resolve_fee_minor('club_fee',v_amount,'club',v_fee.club_id);
    if v_platform<>0 then raise exception 'PLATFORM_TRANSACTION_FEE_DISABLED'; end if;
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,v_platform,'EUR',jsonb_build_object('concept',v_fee.concepto)) returning * into v_attempt;
    update public.cuotas set estado='procesando',metodo_pago='stripe_checkout',actualizado_en=now() where id=v_fee.id;
    return jsonb_build_object('attempt_id',v_attempt.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_fee.concepto,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);

  elsif p_kind='showcase_order' then
    v_qty:=greatest(1,least(coalesce(p_quantity,1),100));
    select * into strict v_item from public.kombax_showcase_elementos where id=p_reference_id and estado='publicado' and commerce_enabled for update;
    if v_item.precio_venta is null or v_item.precio_venta<=0 or (v_item.stock is not null and v_item.stock<v_qty) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=v_item.marca_id and estado='publicada';
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=v_provider.id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_item.precio_venta*100)::int*v_qty;v_platform:=kombax_payments.resolve_fee_minor('showcase',v_amount,'showcase_provider',v_provider.id);
    if v_platform<>0 then raise exception 'PLATFORM_TRANSACTION_FEE_DISABLED'; end if;
    insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,buyer_email,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,(select u.email from auth.users u where u.id=p_actor_id),v_amount,'EUR') returning * into v_order;
    insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor) values(v_order.id,v_item.id,v_item.nombre,v_qty,round(v_item.precio_venta*100)::int);
    insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source) values(v_order.id,'received',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_order.id,v_amount,v_platform,'EUR',jsonb_build_object('product_id',v_item.id,'seller',v_provider.nombre)) returning * into v_attempt;
    v_collect_shipping:=v_item.fulfillment in('seller_shipping','seller_shipping_or_pickup');
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_item.nombre,'seller_name',v_provider.nombre,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',v_collect_shipping);

  elsif p_kind='event_ticket' then
    select * into strict v_event from public.kombax_eventos_publicos where id=p_reference_id for update;
    if not v_event.ticketing_enabled or v_event.ticketing_mode<>'kombax' then raise exception 'EVENT_TICKETING_NOT_ENABLED'; end if;
    if v_event.estado in('borrador','cancelado','finalizado') then raise exception 'EVENT_TICKET_NOT_ON_SALE'; end if;
    if v_event.tickets_abren_en is not null and now()<v_event.tickets_abren_en then raise exception 'EVENT_TICKET_SALE_NOT_OPEN'; end if;
    if v_event.tickets_cierran_en is not null and now()>v_event.tickets_cierran_en then raise exception 'EVENT_TICKET_SALE_CLOSED'; end if;
    if v_event.ticket_price_minor is null or v_event.ticket_capacity is null then raise exception 'EVENT_TICKETING_CONFIGURATION_REQUIRED'; end if;
    v_qty:=greatest(1,least(coalesce(p_quantity,1),v_event.ticket_limit_per_order,20));
    select coalesce(sum(o.quantity),0)::int into v_reserved from kombax_payments.event_ticket_orders o
      where o.event_id=v_event.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()));
    if v_reserved+v_qty>v_event.ticket_capacity then raise exception 'EVENT_TICKETS_SOLD_OUT'; end if;
    v_seller:=kombax_payments.event_seller_r625(v_event.id);
    select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid
      and a.status='active' and a.charges_enabled and a.payouts_enabled and a.configuration_compatible and a.charge_model='direct';
    v_amount:=v_event.ticket_price_minor*v_qty;v_platform:=0;v_seller_name:=v_seller->>'seller_name';
    insert into kombax_payments.event_ticket_orders(order_number,buyer_user_id,event_id,seller_subject_type,seller_subject_id,seller_name,quantity,unit_amount_minor,amount_total_minor,currency,buyer_email)
    values('KXT-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_event.id,v_seller->>'subject_type',(v_seller->>'subject_id')::uuid,v_seller_name,v_qty,v_event.ticket_price_minor,v_amount,v_event.ticket_currency,(select u.email from auth.users u where u.id=p_actor_id)) returning * into v_ticket_order;
    insert into kombax_payments.event_ticket_order_history(order_id,to_status,actor_user_id,source) values(v_ticket_order.id,'pending_payment',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,event_ticket_order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_ticket_order.id,v_amount,0,v_event.ticket_currency,jsonb_build_object('event_id',v_event.id,'ticket_order_id',v_ticket_order.id,'quantity',v_qty,'seller',v_seller_name)) returning * into v_attempt;
    return jsonb_build_object('attempt_id',v_attempt.id,'event_ticket_order_id',v_ticket_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',0,
      'currency',lower(v_event.ticket_currency),'name',v_event.nombre||' · '||v_qty||case when v_qty=1 then ' entrada' else ' entradas' end,'seller_name',v_seller_name,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);
  else
    raise exception 'CHECKOUT_KIND_INVALID';
  end if;
end $$;

create or replace function public.app_stripe_attempt_attach_internal_v259(p_attempt_id uuid,p_checkout_session_id text,p_payment_intent_id text default null,p_setup_intent_id text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  update kombax_payments.payment_attempts set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,stripe_setup_intent_id=p_setup_intent_id,status='checkout_created',updated_at=now() where id=p_attempt_id;
  update kombax_payments.showcase_orders o set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,updated_at=now()
    from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.order_id=o.id;
  update kombax_payments.event_ticket_orders o set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,updated_at=now()
    from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.event_ticket_order_id=o.id;
end $$;

-- ---------------------------------------------------------------------------
-- 5) SHOWCASE · RPC de pedidos enriquecido + transiciones
-- ---------------------------------------------------------------------------
create or replace function public.app_showcase_my_orders_v259(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'seller',o.seller_name,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,'status',o.status,
    'carrier',o.carrier,'tracking_number',o.tracking_number,'tracking_url',o.tracking_url,'created_at',o.created_at,'updated_at',o.updated_at,
    'items',coalesce((select jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount',i.unit_amount_minor/100.0) order by i.product_name) from kombax_payments.showcase_order_items i where i.order_id=o.id),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,'to_status',h.to_status,'source',h.source,'created_at',h.created_at) order by h.created_at) from kombax_payments.showcase_order_history h where h.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.showcase_orders where buyer_user_id=auth.uid() order by created_at desc limit least(greatest(p_limit,1),200)) o;
$$;

create or replace function public.app_showcase_seller_orders_v259(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not kombax_payments.can_manage_provider(auth.uid(),p_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'seller_provider_id',o.seller_provider_id,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,'status',o.status,
    'buyer_email',o.buyer_email,'shipping_name',o.shipping_name,'shipping_phone',o.shipping_phone,'shipping_address',o.shipping_address,
    'carrier',o.carrier,'tracking_number',o.tracking_number,'tracking_url',o.tracking_url,'created_at',o.created_at,'updated_at',o.updated_at,
    'items',coalesce((select jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount',i.unit_amount_minor/100.0) order by i.product_name) from kombax_payments.showcase_order_items i where i.order_id=o.id),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,'to_status',h.to_status,'source',h.source,'created_at',h.created_at) order by h.created_at) from kombax_payments.showcase_order_history h where h.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.showcase_orders where seller_provider_id=p_provider_id order by created_at desc limit least(greatest(p_limit,1),200)) o);
end $$;

create or replace function public.app_showcase_order_mutate_v259(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_order kombax_payments.showcase_orders;v_incident kombax_payments.showcase_incidents;v_status text;v_message text;v_allowed boolean:=false;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_order from kombax_payments.showcase_orders where id=(p_payload->>'order_id')::uuid for update;
  if p_operation='showcase.order.status' then
    if not kombax_payments.can_manage_provider(v_uid,v_order.seller_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
    v_status:=p_payload->>'status';
    v_allowed:=case
      when v_order.status='received' then v_status in('cancelled','incident')
      when v_order.status='payment_confirmed' then v_status in('preparing','delivered','cancelled','incident')
      when v_order.status='preparing' then v_status in('shipped','delivered','cancelled','incident')
      when v_order.status='shipped' then v_status in('delivered','incident')
      when v_order.status='delivered' then v_status='incident'
      else false end;
    if not v_allowed then raise exception 'ORDER_STATUS_TRANSITION_INVALID'; end if;
    if v_status='shipped' and nullif(btrim(p_payload->>'tracking_number'),'') is null then raise exception 'TRACKING_REQUIRED'; end if;
    update kombax_payments.showcase_orders set status=v_status,
      carrier=case when v_status='shipped' then nullif(btrim(p_payload->>'carrier'),'') else carrier end,
      tracking_number=case when v_status='shipped' then nullif(btrim(p_payload->>'tracking_number'),'') else tracking_number end,
      tracking_url=case when v_status='shipped' then nullif(btrim(p_payload->>'tracking_url'),'') else tracking_url end,updated_at=now()
    where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
      values(v_order.id,v_order.status,v_status,v_uid,'seller',jsonb_build_object('carrier',p_payload->>'carrier','tracking_number',p_payload->>'tracking_number'));
  elsif p_operation='showcase.incident.open' then
    if v_order.buyer_user_id<>v_uid then raise exception 'BUYER_ACCESS_DENIED'; end if;
    v_message:=btrim(coalesce(p_payload->>'message',''));if char_length(v_message)<3 then raise exception 'INCIDENT_MESSAGE_REQUIRED'; end if;
    insert into kombax_payments.showcase_incidents(order_id,buyer_user_id,seller_provider_id,reason) values(v_order.id,v_uid,v_order.seller_provider_id,left(v_message,120)) returning * into v_incident;
    insert into kombax_payments.showcase_incident_messages(incident_id,author_user_id,message) values(v_incident.id,v_uid,v_message);
    update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source) values(v_order.id,v_order.status,'incident',v_uid,'buyer');
    v_status:='incident';
  else raise exception 'ORDER_OPERATION_INVALID'; end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('order_id',v_order.id,'status',v_status,'incident_id',v_incident.id));
end $$;

-- ---------------------------------------------------------------------------
commit;
