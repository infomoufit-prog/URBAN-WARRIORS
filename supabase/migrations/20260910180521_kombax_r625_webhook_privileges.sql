-- KOMBAX R62.5 split migration aligned with remote Supabase history.
-- Derived without semantic changes from original 20260910192600 migration.

begin;
-- 6) WEBHOOK · cuotas + Showcase + ticketing con idempotencia común
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_event_apply_v260(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_id text:=p_event->>'id';v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_attempt kombax_payments.payment_attempts;
  v_due jsonb;v_payment_intent text;v_attempt_id uuid;v_expected text;v_actual text:=p_event->>'account';v_ticket_order kombax_payments.event_ticket_orders;
  v_shipping jsonb;v_buyer_email text;
begin
  if coalesce(v_actual,'')='' and v_type<>'account.updated' then raise exception 'CONNECTED_ACCOUNT_EVENT_REQUIRED'; end if;
  if coalesce(v_obj#>>'{metadata,attempt_id}','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then v_attempt_id:=(v_obj#>>'{metadata,attempt_id}')::uuid; end if;
  v_payment_intent:=case when v_type like 'payment_intent.%' then v_obj->>'id' else v_obj->>'payment_intent' end;
  select a.stripe_account_id into v_expected from kombax_payments.payment_attempts p join kombax_payments.connected_accounts a on a.id=p.connected_account_id
    where (v_attempt_id is not null and p.id=v_attempt_id) or (v_payment_intent is not null and p.stripe_payment_intent_id=v_payment_intent) order by p.created_at desc limit 1;
  if v_expected is not null and v_actual is distinct from v_expected then raise exception 'STRIPE_CONNECTED_ACCOUNT_MISMATCH'; end if;

  insert into kombax_payments.webhook_events(stripe_event_id,event_type,stripe_account_id,livemode,api_version,payload)
  values(v_id,v_type,v_actual,coalesce((p_event->>'livemode')::boolean,false),p_event->>'api_version',p_event)
  on conflict(stripe_event_id) do nothing;
  if not found then return jsonb_build_object('ok',true,'duplicate',true,'event_id',v_id); end if;

  if v_type='account.updated' then
    v_due:=coalesce(v_obj#>'{requirements,currently_due}','[]'::jsonb);
    update kombax_payments.connected_accounts set details_submitted=coalesce((v_obj->>'details_submitted')::boolean,false),charges_enabled=coalesce((v_obj->>'charges_enabled')::boolean,false),payouts_enabled=coalesce((v_obj->>'payouts_enabled')::boolean,false),requirements_due=v_due,requirements_eventually_due=coalesce(v_obj#>'{requirements,eventually_due}','[]'::jsonb),disabled_reason=v_obj#>>'{requirements,disabled_reason}',status=case when coalesce((v_obj->>'charges_enabled')::boolean,false) and coalesce((v_obj->>'payouts_enabled')::boolean,false) then 'active' when v_obj#>>'{requirements,disabled_reason}' is not null then 'restricted' when jsonb_array_length(v_due)>0 then 'action_required' when coalesce((v_obj->>'details_submitted')::boolean,false) then 'verification_pending' else 'pending' end,updated_at=now() where stripe_account_id=v_obj->>'id';
  else
    select * into v_attempt from kombax_payments.payment_attempts a where (v_attempt_id is not null and a.id=v_attempt_id) or (v_payment_intent is not null and a.stripe_payment_intent_id=v_payment_intent) order by a.created_at desc limit 1 for update;
    if found then
      if v_type in('payment_intent.succeeded','checkout.session.completed') and coalesce(v_obj->>'payment_status','paid') in('paid','no_payment_required') then
        update kombax_payments.payment_attempts set status='succeeded',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),updated_at=now() where id=v_attempt.id;
        if v_attempt.cuota_id is not null then
          update public.cuotas set estado='pagada',metodo_pago='tarjeta',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),pagada_en=now(),ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
          insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_en,observaciones)
          select q.club_id,q.id,q.socio_id,v_attempt.amount_minor/100.0,current_date,'tarjeta',coalesce(v_payment_intent,v_id),'validado',now(),'Stripe Checkout · webhook '||v_id from public.cuotas q where q.id=v_attempt.cuota_id and not exists(select 1 from public.pagos p where p.cuota_id=q.id and p.referencia=coalesce(v_payment_intent,v_id));
        elsif v_attempt.order_id is not null then
          v_shipping:=coalesce(v_obj#>'{collected_information,shipping_details}',v_obj->'shipping_details',v_obj#>'{customer_details,address}','{}'::jsonb);
          v_buyer_email:=coalesce(v_obj#>>'{customer_details,email}',v_obj->>'customer_email');
          update kombax_payments.showcase_orders set status='payment_confirmed',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),
            buyer_email=coalesce(v_buyer_email,buyer_email),shipping_name=coalesce(v_obj#>>'{collected_information,shipping_details,name}',v_obj#>>'{shipping_details,name}',v_obj#>>'{customer_details,name}',shipping_name),
            shipping_phone=coalesce(v_obj#>>'{customer_details,phone}',shipping_phone),
            shipping_address=case when jsonb_typeof(v_shipping)='object' then v_shipping else shipping_address end,updated_at=now()
          where id=v_attempt.order_id and status='received';
          if found then
            update public.kombax_showcase_elementos e set stock=case when e.stock is null then null else greatest(0,e.stock-i.quantity) end,actualizado_en=now() from kombax_payments.showcase_order_items i where i.order_id=v_attempt.order_id and i.product_id=e.id;
            insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,source,detail) values(v_attempt.order_id,'received','payment_confirmed','stripe',jsonb_build_object('event_id',v_id));
          end if;
        elsif v_attempt.event_ticket_order_id is not null then
          v_buyer_email:=coalesce(v_obj#>>'{customer_details,email}',v_obj->>'customer_email');
          update kombax_payments.event_ticket_orders set status='paid',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),buyer_email=coalesce(v_buyer_email,buyer_email),paid_at=coalesce(paid_at,now()),updated_at=now()
            where id=v_attempt.event_ticket_order_id and status in('pending_payment','payment_failed') returning * into v_ticket_order;
          if found then
            insert into kombax_payments.event_ticket_order_history(order_id,from_status,to_status,source,detail) values(v_ticket_order.id,'pending_payment','paid','stripe',jsonb_build_object('event_id',v_id));
            insert into kombax_payments.event_tickets(order_id,event_id,holder_user_id,ticket_index,ticket_code)
            select v_ticket_order.id,v_ticket_order.event_id,v_ticket_order.buyer_user_id,g,
              'KXT-'||upper(substr(replace(v_ticket_order.id::text,'-',''),1,8))||'-'||lpad(g::text,2,'0')
            from generate_series(1,v_ticket_order.quantity) g on conflict(order_id,ticket_index) do nothing;
          end if;
        end if;
      elsif v_type='payment_intent.payment_failed' then
        update kombax_payments.payment_attempts set status='failed',failure_code=v_obj#>>'{last_payment_error,code}',failure_message=left(v_obj#>>'{last_payment_error,message}',500),updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='fallida',ultimo_fallo=left(v_obj#>>'{last_payment_error,message}',500),ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id;
        update kombax_payments.event_ticket_orders set status='payment_failed',updated_at=now() where id=v_attempt.event_ticket_order_id and status='pending_payment';
      elsif v_type in('charge.refunded','refund.updated') then
        update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='reembolsada',actualizado_en=now() where id=v_attempt.cuota_id;
        update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_attempt.order_id;
        update kombax_payments.event_ticket_orders set status='refunded',refunded_at=now(),updated_at=now() where id=v_attempt.event_ticket_order_id;
        update kombax_payments.event_tickets set status='refunded',updated_at=now() where order_id=v_attempt.event_ticket_order_id and status<>'refunded';
      elsif v_type='charge.dispute.created' then
        update kombax_payments.payment_attempts set status='disputed',updated_at=now() where id=v_attempt.id;
        update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_attempt.order_id;
        update kombax_payments.event_ticket_orders set status='disputed',updated_at=now() where id=v_attempt.event_ticket_order_id;
      end if;
    end if;
  end if;
  update kombax_payments.webhook_events set status=case when v_type in('account.updated','checkout.session.completed','payment_intent.succeeded','payment_intent.payment_failed','charge.refunded','refund.updated','charge.dispute.created','payout.paid','payout.failed','setup_intent.succeeded') then 'processed' else 'ignored' end,processed_at=now() where stripe_event_id=v_id;
  return jsonb_build_object('ok',true,'duplicate',false,'event_id',v_id,'event_type',v_type);
exception when others then
  update kombax_payments.webhook_events set status='failed',error_message=left(sqlerrm,500),processed_at=now() where stripe_event_id=v_id;
  raise;
end $$;

-- ---------------------------------------------------------------------------
-- Privilegios
-- ---------------------------------------------------------------------------
revoke all on function kombax_payments.can_manage_event_organizer_connect_r625(uuid,uuid),kombax_payments.event_seller_r625(uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_manage_event_organizer_connect_r625(uuid,uuid),kombax_payments.event_seller_r625(uuid) to service_role;

revoke all on function public.app_kombax_event_ticketing_manage_status_r625(uuid),public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid),public.app_kombax_my_event_tickets_r625(integer),public.app_kombax_event_ticket_sales_r625(uuid,integer),public.app_kombax_event_ticket_mutate_r625(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_manage_status_r625(uuid),public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid),public.app_kombax_my_event_tickets_r625(integer),public.app_kombax_event_ticket_sales_r625(uuid,integer),public.app_kombax_event_ticket_mutate_r625(text,jsonb,uuid) to authenticated;

revoke all on function public.app_kombax_event_ticketing_public_r625(uuid[]),public.app_kombax_evento_entradas_estado_v173(uuid) from public;
grant execute on function public.app_kombax_event_ticketing_public_r625(uuid[]),public.app_kombax_evento_entradas_estado_v173(uuid) to anon,authenticated;

revoke all on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v260(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v260(jsonb) to service_role;

revoke all on function public.app_showcase_my_orders_v259(integer),public.app_showcase_seller_orders_v259(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid),public.app_stripe_connect_status_v259(text,uuid) from public,anon;
grant execute on function public.app_showcase_my_orders_v259(integer),public.app_showcase_seller_orders_v259(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid),public.app_stripe_connect_status_v259(text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
