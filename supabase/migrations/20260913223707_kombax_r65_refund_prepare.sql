-- KOMBAX R65 live-aligned migration · 20260913223707_kombax_r65_refund_prepare
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- ---------------------------------------------------------------------------
-- 5) Refund preparation/finalization (service-only; Stripe stays server-side)
-- Direct charges: refund is created on the connected account. No reverse_transfer.
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_refund_prepare_internal_r65(
  p_actor_id uuid,p_scope text,p_order_id uuid,p_amount_minor integer,p_ticket_quantity integer,
  p_reason text,p_restock boolean,p_restock_quantity integer,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_existing kombax_payments.commerce_refunds_r65;v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;
  v_show kombax_payments.showcase_orders;v_evt kombax_payments.event_ticket_orders;v_item kombax_payments.showcase_order_items;
  v_refunded integer:=0;v_remaining integer;v_amount integer;v_ticket_qty integer:=0;v_refund uuid;v_fee boolean:=false;v_seller_refund integer:=0;v_fee_refund integer:=0;r record;
begin
  if p_actor_id is null or p_order_id is null or p_request_id is null or p_scope not in('showcase','event') then raise exception 'REFUND_REQUEST_INVALID'; end if;
  select * into v_existing from kombax_payments.commerce_refunds_r65 where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then
    return jsonb_build_object('refund_id',v_existing.id,'status',v_existing.status,'stripe_refund_id',v_existing.stripe_refund_id,'amount_minor',v_existing.amount_requested_minor,
      'stripe_account_id',v_existing.stripe_account_id,'payment_intent_id',v_existing.stripe_payment_intent_id,'refund_application_fee',v_existing.refund_application_fee,'idempotent',true);
  end if;

  if p_scope='showcase' then
    select * into strict v_show from kombax_payments.showcase_orders where id=p_order_id for update;
    if not kombax_payments.can_manage_provider(p_actor_id,v_show.seller_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    if exists(select 1 from kombax_payments.commerce_refunds_r65 where showcase_order_id=v_show.id and status in('prepared','processing')) then raise exception 'REFUND_ALREADY_PROCESSING'; end if;
    select * into strict v_attempt from kombax_payments.payment_attempts a where a.order_id=v_show.id and a.stripe_payment_intent_id is not null and a.status in('succeeded','refunded') order by a.created_at desc limit 1;
    select coalesce(sum(amount_succeeded_minor),0)::integer into v_refunded from kombax_payments.commerce_refunds_r65 where showcase_order_id=v_show.id and status='succeeded';
    v_remaining:=greatest(0,v_attempt.amount_minor-v_refunded); if v_remaining<=0 then raise exception 'ORDER_ALREADY_FULLY_REFUNDED'; end if;
    v_amount:=coalesce(nullif(p_amount_minor,0),v_remaining); if v_amount<=0 or v_amount>v_remaining then raise exception 'REFUND_AMOUNT_INVALID'; end if;
    if coalesce(p_restock,false) then
      select * into strict v_item from kombax_payments.showcase_order_items where order_id=v_show.id order by id limit 1;
      if coalesce(p_restock_quantity,0)<1 or p_restock_quantity>v_item.quantity then raise exception 'RESTOCK_QUANTITY_INVALID'; end if;
    end if;
  else
    select * into strict v_evt from kombax_payments.event_ticket_orders where id=p_order_id for update;
    if not kombax_payments.can_manage_event_r65(p_actor_id,v_evt.event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    if exists(select 1 from kombax_payments.commerce_refunds_r65 where event_ticket_order_id=v_evt.id and status in('prepared','processing')) then raise exception 'REFUND_ALREADY_PROCESSING'; end if;
    select * into strict v_attempt from kombax_payments.payment_attempts a where a.event_ticket_order_id=v_evt.id and a.stripe_payment_intent_id is not null and a.status in('succeeded','refunded') order by a.created_at desc limit 1;
    select coalesce(sum(amount_succeeded_minor),0)::integer into v_refunded from kombax_payments.commerce_refunds_r65 where event_ticket_order_id=v_evt.id and status='succeeded';
    v_remaining:=greatest(0,v_attempt.amount_minor-v_refunded); if v_remaining<=0 then raise exception 'ORDER_ALREADY_FULLY_REFUNDED'; end if;
    v_ticket_qty:=coalesce(nullif(p_ticket_quantity,0),case when p_amount_minor is null or p_amount_minor=0 then (select count(*) from kombax_payments.event_tickets t where t.order_id=v_evt.id and t.status='active' and not exists(select 1 from kombax_payments.commerce_refund_tickets_r65 rt where rt.ticket_id=t.id)) else 0 end);
    if v_ticket_qty<1 then raise exception 'EVENT_REFUND_TICKET_QUANTITY_REQUIRED'; end if;
    if v_ticket_qty>(select count(*) from kombax_payments.event_tickets t where t.order_id=v_evt.id and t.status='active' and not exists(select 1 from kombax_payments.commerce_refund_tickets_r65 rt where rt.ticket_id=t.id)) then raise exception 'EVENT_REFUND_TICKETS_UNAVAILABLE'; end if;
    v_amount:=round(v_ticket_qty * v_evt.checkout_total_minor::numeric / greatest(v_evt.quantity,1))::integer;
    if p_amount_minor is not null and p_amount_minor>0 and p_amount_minor<>v_amount then raise exception 'EVENT_REFUND_AMOUNT_MUST_MATCH_TICKETS'; end if;
    if v_amount>v_remaining then raise exception 'REFUND_AMOUNT_INVALID'; end if;
  end if;

  select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id and charge_model='direct';
  v_fee:=coalesce(v_attempt.platform_fee_minor,0)>0;
  v_seller_refund:=least(v_attempt.seller_amount_minor,round(v_attempt.seller_amount_minor * v_amount::numeric / greatest(v_attempt.amount_minor,1))::integer);
  v_fee_refund:=least(v_attempt.platform_fee_minor,round(v_attempt.platform_fee_minor * v_amount::numeric / greatest(v_attempt.amount_minor,1))::integer);
  insert into kombax_payments.commerce_refunds_r65(request_id,actor_user_id,scope,showcase_order_id,event_ticket_order_id,connected_account_id,stripe_account_id,stripe_payment_intent_id,
    amount_requested_minor,seller_amount_refunded_minor,platform_fee_refunded_minor,currency,reason,status,refund_application_fee,restock_requested,restock_quantity)
  values(p_request_id,p_actor_id,p_scope,case when p_scope='showcase' then p_order_id end,case when p_scope='event' then p_order_id end,v_account.id,v_account.stripe_account_id,v_attempt.stripe_payment_intent_id,
    v_amount,v_seller_refund,v_fee_refund,v_attempt.currency,left(nullif(btrim(p_reason),''),500),'prepared',v_fee,coalesce(p_restock,false) and p_scope='showcase',case when p_scope='showcase' and coalesce(p_restock,false) then greatest(coalesce(p_restock_quantity,0),0) else 0 end)
  returning id into v_refund;

  if p_scope='event' then
    for r in select t.id from kombax_payments.event_tickets t where t.order_id=p_order_id and t.status='active'
      and not exists(select 1 from kombax_payments.commerce_refund_tickets_r65 rt where rt.ticket_id=t.id)
      order by t.ticket_index limit v_ticket_qty
    loop insert into kombax_payments.commerce_refund_tickets_r65(refund_id,ticket_id) values(v_refund,r.id); end loop;
    update kombax_payments.event_ticket_orders set refund_state='refund_processing',refund_reason=left(nullif(btrim(p_reason),''),1000),refund_requested_at=coalesce(refund_requested_at,now()),updated_at=now() where id=p_order_id;
  end if;
  update kombax_payments.commerce_refunds_r65 set status='processing',updated_at=now() where id=v_refund;
  return jsonb_build_object('refund_id',v_refund,'status','processing','amount_minor',v_amount,'currency',lower(v_attempt.currency),'stripe_account_id',v_account.stripe_account_id,
    'payment_intent_id',v_attempt.stripe_payment_intent_id,'refund_application_fee',v_fee,'ticket_quantity',v_ticket_qty,'idempotent',false);
end $$;
revoke all on function public.app_stripe_refund_prepare_internal_r65(uuid,text,uuid,integer,integer,text,boolean,integer,uuid) from public,anon,authenticated;
grant execute on function public.app_stripe_refund_prepare_internal_r65(uuid,text,uuid,integer,integer,text,boolean,integer,uuid) to service_role;

create or replace function kombax_payments.apply_refund_success_r65(p_refund uuid,p_stripe_refund jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_r kombax_payments.commerce_refunds_r65;v_attempt kombax_payments.payment_attempts;v_total integer;v_item kombax_payments.showcase_order_items;v_product public.kombax_showcase_elementos;v_before integer;v_restock integer;v_order_status text;v_evt kombax_payments.event_ticket_orders;v_refunded_tickets integer;
begin
  select * into strict v_r from kombax_payments.commerce_refunds_r65 where id=p_refund for update;
  if v_r.status='succeeded' then return jsonb_build_object('ok',true,'idempotent',true,'refund_id',v_r.id); end if;
  update kombax_payments.commerce_refunds_r65 set status='succeeded',stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),amount_succeeded_minor=amount_requested_minor,
    stripe_payload=coalesce(p_stripe_refund,'{}'::jsonb),failure_message=null,completed_at=now(),updated_at=now() where id=v_r.id;

  if v_r.scope='showcase' then
    select * into strict v_attempt from kombax_payments.payment_attempts where order_id=v_r.showcase_order_id order by created_at desc limit 1;
    select coalesce(sum(amount_succeeded_minor),0)::integer into v_total from kombax_payments.commerce_refunds_r65 where showcase_order_id=v_r.showcase_order_id and status='succeeded';
    select status into v_order_status from kombax_payments.showcase_orders where id=v_r.showcase_order_id;
    if v_total>=v_attempt.amount_minor then
      update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_r.showcase_order_id;
      update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;
      insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
      values(v_r.showcase_order_id,v_order_status,'refunded',v_r.actor_user_id,'seller',jsonb_build_object('refund_id',v_r.id,'amount_minor',v_r.amount_succeeded_minor)) ;
    else
      insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
      values(v_r.showcase_order_id,v_order_status,v_order_status,v_r.actor_user_id,'seller',jsonb_build_object('partial_refund',true,'refund_id',v_r.id,'amount_minor',v_r.amount_succeeded_minor));
    end if;
    if v_r.restock_requested and v_r.restock_quantity>0 and v_r.restocked_quantity=0 then
      select * into strict v_item from kombax_payments.showcase_order_items where order_id=v_r.showcase_order_id order by id limit 1;
      select * into strict v_product from public.kombax_showcase_elementos where id=v_item.product_id for update;
      v_before:=coalesce(v_product.stock,0);v_restock:=least(v_r.restock_quantity,v_item.quantity);
      update public.kombax_showcase_elementos set stock=v_before+v_restock,actualizado_en=now() where id=v_product.id;
      insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,order_id,refund_id,movement_type,quantity_delta,stock_before,stock_after,actor_user_id,note,idempotency_key)
      values(v_product.marca_id,v_product.id,v_r.showcase_order_id,v_r.id,'refund_restock',v_restock,v_before,v_before+v_restock,v_r.actor_user_id,'Reposición asociada al reembolso','refund-restock:'||v_r.id::text)
      on conflict(idempotency_key) do nothing;
      update kombax_payments.commerce_refunds_r65 set restocked_quantity=v_restock,updated_at=now() where id=v_r.id;
    end if;
    perform kombax_payments.queue_communication_r65('showcase',(select seller_provider_id from kombax_payments.showcase_orders where id=v_r.showcase_order_id),null,v_r.showcase_order_id,null,
      (select buyer_user_id from kombax_payments.showcase_orders where id=v_r.showcase_order_id),(select buyer_email from kombax_payments.showcase_orders where id=v_r.showcase_order_id),
      'showcase_refund','Reembolso de tu pedido KOMBAX','El vendedor ha procesado un reembolso de tu pedido. Consulta el pedido para ver el estado actualizado.','seller',v_r.actor_user_id,'refund-success:'||v_r.id::text,
      jsonb_build_object('refund_id',v_r.id,'amount_minor',v_r.amount_succeeded_minor));
  else
    select * into strict v_evt from kombax_payments.event_ticket_orders where id=v_r.event_ticket_order_id for update;
    update kombax_payments.event_tickets t set status='refunded',updated_at=now()
    where exists(select 1 from kombax_payments.commerce_refund_tickets_r65 rt where rt.refund_id=v_r.id and rt.ticket_id=t.id) and t.status='active';
    select count(*) into v_refunded_tickets from kombax_payments.event_tickets where order_id=v_evt.id and status='refunded';
    select coalesce(sum(amount_succeeded_minor),0)::integer into v_total from kombax_payments.commerce_refunds_r65 where event_ticket_order_id=v_evt.id and status='succeeded';
    if v_total>=v_evt.checkout_total_minor or v_refunded_tickets>=v_evt.quantity then
      update kombax_payments.event_ticket_orders set status='refunded',refund_state='refunded',stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),refunded_at=now(),refund_completed_at=now(),updated_at=now() where id=v_evt.id;
      update kombax_payments.payment_attempts set status='refunded',updated_at=now() where event_ticket_order_id=v_evt.id;
    else
      update kombax_payments.event_ticket_orders set refund_state='partially_refunded',stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),refund_completed_at=now(),updated_at=now() where id=v_evt.id;
    end if;
    insert into kombax_payments.event_ticket_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
    values(v_evt.id,v_evt.status,case when v_total>=v_evt.checkout_total_minor or v_refunded_tickets>=v_evt.quantity then 'refunded' else v_evt.status end,v_r.actor_user_id,'organizer',
      jsonb_build_object('refund_id',v_r.id,'amount_minor',v_r.amount_succeeded_minor,'refunded_tickets',(select count(*) from kombax_payments.commerce_refund_tickets_r65 where refund_id=v_r.id)));
    perform kombax_payments.queue_communication_r65('event',null,v_evt.event_id,null,v_evt.id,v_evt.buyer_user_id,v_evt.buyer_email,
      'event_refund','Reembolso de entradas KOMBAX','El organizador ha procesado un reembolso de tus entradas. Los QR reembolsados han quedado invalidados.','organizer',v_r.actor_user_id,'event-refund-success:'||v_r.id::text,
      jsonb_build_object('refund_id',v_r.id,'amount_minor',v_r.amount_succeeded_minor));
  end if;
  return jsonb_build_object('ok',true,'refund_id',v_r.id,'status','succeeded');
end $$;
revoke all on function kombax_payments.apply_refund_success_r65(uuid,jsonb) from public,anon,authenticated;
grant execute on function kombax_payments.apply_refund_success_r65(uuid,jsonb) to service_role;

commit;
