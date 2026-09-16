-- KOMBAX R65 live-aligned migration · 20260913223837_kombax_r65_webhook_v265
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- 10) Webhook v265: protects partial refunds and adds R65 ledgers/analytics/comms.
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_event_apply_v265(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_result jsonb;v_pi text;v_refund_id text;v_attempt kombax_payments.payment_attempts;v_order kombax_payments.showcase_orders;v_evt kombax_payments.event_ticket_orders;v_item record;v_stock integer;v_known kombax_payments.commerce_refunds_r65;
begin
  -- Refund events must NOT delegate to v260 because v260 historically marks partial refunds as full.
  if v_type in('refund.created','refund.updated','refund.failed','charge.refunded') then
    v_refund_id:=case when v_type like 'refund.%' then v_obj->>'id' else null end;
    v_pi:=coalesce(v_obj->>'payment_intent',v_obj#>>'{charge,payment_intent}');
    if v_refund_id is not null then
      select * into v_known from kombax_payments.commerce_refunds_r65
      where stripe_refund_id=v_refund_id or id=nullif(v_obj#>>'{metadata,kombax_refund_id}','')::uuid
      order by case when stripe_refund_id=v_refund_id then 0 else 1 end limit 1;
      if v_known.id is not null and v_known.stripe_refund_id is null then
        update kombax_payments.commerce_refunds_r65 set stripe_refund_id=v_refund_id,stripe_payload=v_obj,updated_at=now() where id=v_known.id;
      end if;
    end if;
    if v_known.id is not null then
      if coalesce(v_obj->>'status','')='succeeded' or v_type='refund.created' and coalesce(v_obj->>'status','succeeded')='succeeded' then
        perform kombax_payments.apply_refund_success_r65(v_known.id,v_obj);
      elsif v_type='refund.failed' or coalesce(v_obj->>'status','')='failed' then
        update kombax_payments.commerce_refunds_r65 set status='failed',failure_message=left(coalesce(v_obj->>'failure_reason','STRIPE_REFUND_FAILED'),500),stripe_payload=v_obj,updated_at=now() where id=v_known.id and status<>'succeeded';
      end if;
      return jsonb_build_object('ok',true,'handled','r65_refund','refund_id',v_known.id);
    end if;
    -- External/manual Stripe refunds: preserve safety. Only fully refunded charges collapse order state;
    -- partial external refunds are flagged for manual reconciliation and never auto-restock stock.
    if v_type='charge.refunded' then
      v_pi:=v_obj->>'payment_intent';
      select * into v_attempt from kombax_payments.payment_attempts where stripe_payment_intent_id=v_pi order by created_at desc limit 1;
      if v_attempt.id is not null then
        if coalesce((v_obj->>'amount_refunded')::integer,0)>=v_attempt.amount_minor then
          update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;
          if v_attempt.order_id is not null then update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_attempt.order_id; end if;
          if v_attempt.event_ticket_order_id is not null then
            update kombax_payments.event_ticket_orders set status='refunded',refund_state='refunded',refund_completed_at=now(),refunded_at=now(),updated_at=now() where id=v_attempt.event_ticket_order_id;
            update kombax_payments.event_tickets set status='refunded',updated_at=now() where order_id=v_attempt.event_ticket_order_id and status='active';
          end if;
        else
          if v_attempt.event_ticket_order_id is not null then update kombax_payments.event_ticket_orders set refund_state='manual_review',refund_reason='Reembolso parcial detectado directamente en Stripe',updated_at=now() where id=v_attempt.event_ticket_order_id; end if;
          if v_attempt.order_id is not null then insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,source,detail) select id,status,status,'stripe',jsonb_build_object('manual_partial_refund',true,'amount_refunded',v_obj->>'amount_refunded') from kombax_payments.showcase_orders where id=v_attempt.order_id; end if;
        end if;
      end if;
    end if;
    return jsonb_build_object('ok',true,'handled','refund_external_or_ignored');
  end if;

  v_result:=public.app_stripe_event_apply_v260(p_event);
  -- Idempotent post-processing for successful payments.
  if v_type in('checkout.session.completed','checkout.session.async_payment_succeeded','payment_intent.succeeded') then
    v_pi:=coalesce(v_obj->>'payment_intent',case when v_type='payment_intent.succeeded' then v_obj->>'id' end);
    select * into v_attempt from kombax_payments.payment_attempts a where a.id=nullif(v_obj#>>'{metadata,attempt_id}','')::uuid or (v_pi is not null and a.stripe_payment_intent_id=v_pi) order by a.created_at desc limit 1;
    if v_attempt.order_id is not null then
      select * into v_order from kombax_payments.showcase_orders where id=v_attempt.order_id;
      for v_item in select i.*,e.marca_id,e.stock from kombax_payments.showcase_order_items i join public.kombax_showcase_elementos e on e.id=i.product_id where i.order_id=v_attempt.order_id
      loop
        -- The legacy webhook already decremented stock. Record the resulting movement once.
        v_stock:=v_item.stock;
        insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,order_id,movement_type,quantity_delta,stock_before,stock_after,note,idempotency_key)
        values(v_item.marca_id,v_item.product_id,v_attempt.order_id,'sale',-v_item.quantity,case when v_stock is null then null else v_stock+v_item.quantity end,v_stock,'Venta confirmada por Stripe','sale:'||v_attempt.order_id::text||':'||v_item.product_id::text)
        on conflict(idempotency_key) do nothing;
      end loop;
      insert into kombax_payments.commerce_analytics_events_r65(actor_user_id,event_type,provider_id,product_id,order_id,amount_minor,source,metadata)
      select v_attempt.actor_user_id,'showcase_purchase',v_order.seller_provider_id,i.product_id,v_order.id,v_attempt.seller_amount_minor,'stripe',jsonb_build_object('payment_attempt_id',v_attempt.id)
      from kombax_payments.showcase_order_items i where i.order_id=v_order.id and not exists(select 1 from kombax_payments.commerce_analytics_events_r65 a where a.event_type='showcase_purchase' and a.order_id=v_order.id);
      perform kombax_payments.queue_communication_r65('showcase',v_order.seller_provider_id,null,v_order.id,null,v_order.buyer_user_id,v_order.buyer_email,
        'showcase_payment_confirmed','Pago confirmado · pedido KOMBAX','Tu pago se ha confirmado y el vendedor ya puede preparar el pedido.','stripe',null,'showcase-paid:'||v_order.id::text,jsonb_build_object('order_number',v_order.order_number));
    elsif v_attempt.event_ticket_order_id is not null then
      select * into v_evt from kombax_payments.event_ticket_orders where id=v_attempt.event_ticket_order_id;
      insert into kombax_payments.commerce_analytics_events_r65(actor_user_id,event_type,event_id,order_id,amount_minor,source,metadata)
      select v_attempt.actor_user_id,'ticket_purchase',v_evt.event_id,v_evt.id,v_attempt.seller_amount_minor,'stripe',jsonb_build_object('quantity',v_evt.quantity,'payment_attempt_id',v_attempt.id)
      where not exists(select 1 from kombax_payments.commerce_analytics_events_r65 a where a.event_type='ticket_purchase' and a.order_id=v_evt.id);
      perform kombax_payments.queue_communication_r65('event',null,v_evt.event_id,null,v_evt.id,v_evt.buyer_user_id,v_evt.buyer_email,
        'event_ticket_payment_confirmed','Entradas KOMBAX confirmadas','Tu pago se ha confirmado. Tus entradas y QR están disponibles en KOMBAX Events.','stripe',null,'event-paid:'||v_evt.id::text,jsonb_build_object('order_number',v_evt.order_number,'quantity',v_evt.quantity));
    end if;
  end if;
  return coalesce(v_result,jsonb_build_object('ok',true));
end $$;
revoke all on function public.app_stripe_event_apply_v265(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_event_apply_v265(jsonb) to service_role;

-- Add BI checkin event without altering the atomic checkin RPC semantics: a helper invoked by UI after valid checkin is not trusted for access,
-- so server-side BI is additionally backfilled from audit in BI queries if needed. No access decision depends on analytics.

-- ---------------------------------------------------------------------------
commit;
