-- KOMBAX R83 · Showcase cart checkout, variant line identity and webhook stock idempotency.
begin;

alter table kombax_payments.showcase_order_items
  drop constraint if exists showcase_order_items_order_id_product_id_key;
create unique index if not exists uq_showcase_order_items_variant_r83
  on kombax_payments.showcase_order_items(order_id,product_id,md5(variant::text));

create or replace function kombax_payments.apply_showcase_variant_stock_r83(p_order_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_line record;v_variants jsonb;v_next jsonb;
begin
  for v_line in
    select i.product_id,i.variant,sum(i.quantity)::integer quantity
    from kombax_payments.showcase_order_items i
    where i.order_id=p_order_id and i.variant is not null and i.variant<>'{}'::jsonb and i.variant<>'null'::jsonb
    group by i.product_id,i.variant
  loop
    select e.variantes into v_variants from public.kombax_showcase_elementos e where e.id=v_line.product_id for update;
    if jsonb_typeof(v_variants)='array' and jsonb_array_length(v_variants)>0 then
      select jsonb_agg(case when x.value=v_line.variant and x.value ? 'stock' and coalesce(x.value->>'stock','') ~ '^[0-9]+$'
        then jsonb_set(x.value,'{stock}',to_jsonb(greatest(0,(x.value->>'stock')::integer-v_line.quantity)),true)
        else x.value end order by x.ordinality)
      into v_next from jsonb_array_elements(v_variants) with ordinality as x(value,ordinality);
      if v_next is distinct from v_variants then
        update public.kombax_showcase_elementos set variantes=v_next,actualizado_en=now() where id=v_line.product_id;
      end if;
    end if;
  end loop;
end $$;
revoke all on function kombax_payments.apply_showcase_variant_stock_r83(uuid) from public,anon,authenticated;
grant execute on function kombax_payments.apply_showcase_variant_stock_r83(uuid) to service_role;

create or replace function public.app_stripe_checkout_prepare_cart_internal_r83(p_actor_id uuid,p_items jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_provider public.kombax_showcase_marcas;
  v_order kombax_payments.showcase_orders;v_item public.kombax_showcase_elementos;v_entry record;v_provider_id uuid;
  v_qty integer;v_product_qty integer;v_unit integer;v_total integer:=0;v_platform integer:=0;v_variant jsonb;
  v_lines jsonb:='[]'::jsonb;v_collect_shipping boolean:=false;v_currency text;v_variant_stock integer;v_existing_lines jsonb;
begin
  if p_actor_id is null or p_request_id is null then raise exception 'CHECKOUT_CART_INVALID'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>50 then raise exception 'CHECKOUT_CART_ITEMS_INVALID'; end if;
  select * into v_attempt from kombax_payments.payment_attempts a where a.actor_user_id=p_actor_id and a.request_id=p_request_id;
  if found then
    if v_attempt.kind<>'showcase_order' or coalesce(v_attempt.metadata->>'checkout_mode','')<>'cart' or v_attempt.order_id is null then raise exception 'CHECKOUT_REQUEST_ID_REUSED'; end if;
    select * into strict v_order from kombax_payments.showcase_orders where id=v_attempt.order_id;
    select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
    select coalesce(jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount_minor',i.unit_amount_minor,'variant',i.variant) order by i.product_name,i.id),'[]'::jsonb)
      into v_existing_lines from kombax_payments.showcase_order_items i where i.order_id=v_order.id;
    select exists(select 1 from kombax_payments.showcase_order_items i join public.kombax_showcase_elementos e on e.id=i.product_id where i.order_id=v_order.id and e.fulfillment in('seller_shipping','seller_shipping_or_pickup')) into v_collect_shipping;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind','showcase_order','status',v_attempt.status,'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id,
      'stripe_account_id',v_account.stripe_account_id,'amount_minor',v_attempt.amount_minor,'seller_amount_minor',v_attempt.seller_amount_minor,'buyer_service_fee_minor',v_attempt.buyer_service_fee_minor,
      'platform_percentage_fee_minor',v_attempt.platform_percentage_fee_minor,'platform_fee_minor',v_attempt.platform_fee_minor,'currency',lower(v_attempt.currency),'name','Pedido KOMBAX Showcase',
      'seller_name',v_order.seller_name,'collect_shipping',v_collect_shipping,'items',v_existing_lines);
  end if;
  for v_entry in
    select (x.value->>'product_id')::uuid product_id,coalesce(x.value->'variant','{}'::jsonb) variant,
      sum(greatest(1,least(coalesce(nullif(x.value->>'quantity','')::integer,1),100)))::integer quantity
    from jsonb_array_elements(p_items) x(value)
    where coalesce(x.value->>'product_id','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    group by (x.value->>'product_id')::uuid,coalesce(x.value->'variant','{}'::jsonb)
    order by (x.value->>'product_id')::uuid,md5(coalesce(x.value->'variant','{}'::jsonb)::text)
  loop
    v_qty:=v_entry.quantity;v_variant:=v_entry.variant;
    select * into strict v_item from public.kombax_showcase_elementos e where e.id=v_entry.product_id and e.estado='publicado' and e.commerce_enabled for update;
    if not kombax_commercial.provider_commerce_allowed_r64(v_item.marca_id) then raise exception 'SHOWCASE_COMMERCE_PLAN_OR_ACTIVATION_REQUIRED'; end if;
    if v_item.precio_venta is null or v_item.precio_venta<=0 then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    if v_provider_id is null then v_provider_id:=v_item.marca_id;v_currency:=upper(v_item.moneda);
    elsif v_provider_id is distinct from v_item.marca_id then raise exception 'SHOWCASE_CART_SINGLE_SELLER_REQUIRED';
    elsif v_currency is distinct from upper(v_item.moneda) then raise exception 'SHOWCASE_CART_SINGLE_CURRENCY_REQUIRED'; end if;
    select coalesce(sum(greatest(1,least(coalesce(nullif(y.value->>'quantity','')::integer,1),100))),0)::integer into v_product_qty
      from jsonb_array_elements(p_items) y(value) where y.value->>'product_id'=v_item.id::text;
    if v_item.stock is not null and v_item.stock<v_product_qty then raise exception 'PRODUCT_STOCK_INSUFFICIENT'; end if;
    if jsonb_typeof(v_item.variantes)='array' and jsonb_array_length(v_item.variantes)>0 then
      if v_variant='{}'::jsonb or v_variant='null'::jsonb or not (v_item.variantes @> jsonb_build_array(v_variant)) then raise exception 'PRODUCT_VARIANT_INVALID'; end if;
      if v_variant ? 'stock' and coalesce(v_variant->>'stock','') ~ '^[0-9]+$' then v_variant_stock:=(v_variant->>'stock')::integer;if v_variant_stock<v_qty then raise exception 'PRODUCT_VARIANT_STOCK_INSUFFICIENT'; end if; end if;
    else v_variant:='{}'::jsonb; end if;
    v_unit:=round(v_item.precio_venta*100)::integer;v_total:=v_total+(v_unit*v_qty);v_collect_shipping:=v_collect_shipping or v_item.fulfillment in('seller_shipping','seller_shipping_or_pickup');
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object('product_id',v_item.id,'name',v_item.nombre,'quantity',v_qty,'unit_amount_minor',v_unit,'variant',v_variant));
  end loop;
  if jsonb_array_length(v_lines)<1 then raise exception 'CHECKOUT_CART_ITEMS_INVALID'; end if;
  select * into strict v_provider from public.kombax_showcase_marcas p where p.id=v_provider_id and p.estado='publicada';
  select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type='showcase_provider' and a.subject_id=v_provider_id and a.status='active' and a.charges_enabled and a.payouts_enabled and a.configuration_compatible and a.charge_model='direct';
  v_platform:=kombax_payments.resolve_fee_minor('showcase',v_total,'showcase_provider',v_provider_id);
  insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,buyer_email,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,(select u.email from auth.users u where u.id=p_actor_id),v_total,v_currency) returning * into v_order;
  insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor,variant)
    select v_order.id,(z->>'product_id')::uuid,z->>'name',(z->>'quantity')::integer,(z->>'unit_amount_minor')::integer,coalesce(z->'variant','{}'::jsonb) from jsonb_array_elements(v_lines) z;
  insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source,detail) values(v_order.id,'received',p_actor_id,'buyer',jsonb_build_object('checkout_mode','cart','line_count',jsonb_array_length(v_lines)));
  insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,seller_amount_minor,buyer_service_fee_minor,platform_percentage_fee_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,'showcase_order',p_actor_id,v_account.id,v_order.id,v_total,v_total,0,v_platform,v_platform,v_currency,jsonb_build_object('checkout_mode','cart','seller',v_provider.nombre,'provider_id',v_provider.id,'line_count',jsonb_array_length(v_lines))) returning * into v_attempt;
  return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind','showcase_order','amount_minor',v_total,'seller_amount_minor',v_total,'buyer_service_fee_minor',0,
    'platform_percentage_fee_minor',v_platform,'platform_fee_minor',v_platform,'currency',lower(v_currency),'name','Pedido KOMBAX Showcase','seller_name',v_provider.nombre,
    'stripe_account_id',v_account.stripe_account_id,'collect_shipping',v_collect_shipping,'items',v_lines);
end $$;
revoke all on function public.app_stripe_checkout_prepare_cart_internal_r83(uuid,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.app_stripe_checkout_prepare_cart_internal_r83(uuid,jsonb,uuid) to service_role;

-- Payment events are authoritative and stock changes only on the first received -> payment_confirmed transition.
create or replace function public.app_stripe_event_apply_v259(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id text:=p_event->>'id';v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_attempt kombax_payments.payment_attempts;v_due jsonb;v_payment_intent text;v_order_transitioned boolean:=false;
begin
  insert into kombax_payments.webhook_events(stripe_event_id,event_type,stripe_account_id,livemode,api_version,payload)
  values(v_id,v_type,p_event->>'account',coalesce((p_event->>'livemode')::boolean,false),p_event->>'api_version',p_event) on conflict(stripe_event_id) do nothing;
  if not found then return jsonb_build_object('ok',true,'duplicate',true,'event_id',v_id); end if;
  if v_type='account.updated' then
    v_due:=coalesce(v_obj#>'{requirements,currently_due}','[]'::jsonb);
    update kombax_payments.connected_accounts set details_submitted=coalesce((v_obj->>'details_submitted')::boolean,false),charges_enabled=coalesce((v_obj->>'charges_enabled')::boolean,false),payouts_enabled=coalesce((v_obj->>'payouts_enabled')::boolean,false),requirements_due=v_due,requirements_eventually_due=coalesce(v_obj#>'{requirements,eventually_due}','[]'::jsonb),disabled_reason=v_obj#>>'{requirements,disabled_reason}',status=case when coalesce((v_obj->>'charges_enabled')::boolean,false) and coalesce((v_obj->>'payouts_enabled')::boolean,false) then 'active' when v_obj#>>'{requirements,disabled_reason}' is not null then 'restricted' when jsonb_array_length(v_due)>0 then 'action_required' when coalesce((v_obj->>'details_submitted')::boolean,false) then 'verification_pending' else 'pending' end,updated_at=now() where stripe_account_id=v_obj->>'id';
  else
    v_payment_intent:=case when v_type like 'payment_intent.%' then v_obj->>'id' else v_obj->>'payment_intent' end;
    select * into v_attempt from kombax_payments.payment_attempts a where a.id=nullif(v_obj#>>'{metadata,attempt_id}','')::uuid or (v_payment_intent is not null and a.stripe_payment_intent_id=v_payment_intent) order by a.created_at desc limit 1 for update;
    if found then
      if v_type in('payment_intent.succeeded','checkout.session.completed') and coalesce(v_obj->>'payment_status','paid') in('paid','no_payment_required') then
        update kombax_payments.payment_attempts set status='succeeded',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),failure_code=null,failure_message=null,updated_at=now() where id=v_attempt.id;
        if v_attempt.cuota_id is not null then
          update public.cuotas set estado='pagada',metodo_pago='tarjeta',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),pagada_en=coalesce(pagada_en,now()),ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
          insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_en,observaciones)
            select q.club_id,q.id,q.socio_id,v_attempt.amount_minor/100.0,current_date,'tarjeta',coalesce(v_payment_intent,v_id),'validado',now(),'Stripe Checkout · webhook '||v_id from public.cuotas q where q.id=v_attempt.cuota_id and not exists(select 1 from public.pagos p where p.cuota_id=q.id and p.referencia=coalesce(v_payment_intent,v_id));
        elsif v_attempt.order_id is not null then
          update kombax_payments.showcase_orders set status='payment_confirmed',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),updated_at=now() where id=v_attempt.order_id and status='received';
          v_order_transitioned:=found;
          if v_order_transitioned then
            with ordered as (select i.product_id,sum(i.quantity)::integer quantity from kombax_payments.showcase_order_items i where i.order_id=v_attempt.order_id group by i.product_id)
            update public.kombax_showcase_elementos e set stock=case when e.stock is null then null else greatest(0,e.stock-o.quantity) end,actualizado_en=now() from ordered o where o.product_id=e.id;
            perform kombax_payments.apply_showcase_variant_stock_r83(v_attempt.order_id);
            insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,source,detail) values(v_attempt.order_id,'received','payment_confirmed','stripe',jsonb_build_object('event_id',v_id));
          end if;
        end if;
      elsif v_type='payment_intent.payment_failed' then
        update kombax_payments.payment_attempts set status='failed',failure_code=v_obj#>>'{last_payment_error,code}',failure_message=left(v_obj#>>'{last_payment_error,message}',500),updated_at=now() where id=v_attempt.id and status not in('succeeded','refunded');
        update public.cuotas set estado='fallida',ultimo_fallo=left(v_obj#>>'{last_payment_error,message}',500),ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id and estado<>'pagada';
      elsif v_type in('charge.refunded','refund.updated') then
        update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;update public.cuotas set estado='reembolsada',actualizado_en=now() where id=v_attempt.cuota_id;update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_attempt.order_id;
      elsif v_type='charge.dispute.created' then
        update kombax_payments.payment_attempts set status='disputed',updated_at=now() where id=v_attempt.id;update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_attempt.order_id;
      end if;
    end if;
  end if;
  update kombax_payments.webhook_events set status=case when v_type in('account.updated','checkout.session.completed','payment_intent.succeeded','payment_intent.payment_failed','charge.refunded','refund.updated','charge.dispute.created','payout.paid','payout.failed','setup_intent.succeeded') then 'processed' else 'ignored' end,processed_at=now() where stripe_event_id=v_id;
  return jsonb_build_object('ok',true,'duplicate',false,'event_id',v_id,'event_type',v_type,'order_transitioned',v_order_transitioned);
exception when others then update kombax_payments.webhook_events set status='failed',error_message=left(sqlerrm,500),processed_at=now() where stripe_event_id=v_id;raise;
end $$;
revoke all on function public.app_stripe_event_apply_v259(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_event_apply_v259(jsonb) to service_role;
notify pgrst,'reload schema';
commit;
