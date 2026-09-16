-- KOMBAX 20.112 R64 · Stripe Connect direct charges + platform fee + buyer ticket fee
-- Preserves connected-account direct charges. KOMBAX application fee is explicit and auditable.
begin;

-- R62 intentionally disabled fees; R64 explicitly supersedes that commercial decision.
alter table kombax_payments.platform_fee_rules drop constraint if exists platform_transaction_fees_disabled_r62;
alter table kombax_payments.payment_attempts drop constraint if exists payment_attempt_platform_fee_zero_r62;
alter table kombax_payments.platform_fee_rules drop constraint if exists platform_fee_rules_scope_check;
alter table kombax_payments.platform_fee_rules add constraint platform_fee_rules_scope_check check(scope in('club_fee','showcase','event_ticket'));

alter table kombax_payments.payment_attempts
  add column if not exists seller_amount_minor integer not null default 0 check(seller_amount_minor>=0),
  add column if not exists buyer_service_fee_minor integer not null default 0 check(buyer_service_fee_minor>=0),
  add column if not exists platform_percentage_fee_minor integer not null default 0 check(platform_percentage_fee_minor>=0);

update kombax_payments.payment_attempts
set seller_amount_minor=case when seller_amount_minor=0 then amount_minor else seller_amount_minor end
where amount_minor>0;

alter table kombax_payments.event_ticket_orders
  add column if not exists buyer_service_fee_minor integer not null default 0 check(buyer_service_fee_minor>=0),
  add column if not exists checkout_total_minor integer not null default 0 check(checkout_total_minor>=0);
update kombax_payments.event_ticket_orders
set checkout_total_minor=amount_total_minor+buyer_service_fee_minor
where checkout_total_minor=0 and amount_total_minor>0;

create or replace function kombax_commercial.ticket_buyer_fee_minor_r64()
returns integer language sql stable security definer set search_path='' as $$
  select coalesce((select (value #>> '{}')::integer from kombax_commercial.runtime_config_r64 where config_key='ticketing_buyer_fee_minor'),150);
$$;
revoke all on function kombax_commercial.ticket_buyer_fee_minor_r64() from public,anon,authenticated;
grant execute on function kombax_commercial.ticket_buyer_fee_minor_r64() to service_role;

-- Configurable fee resolution: exact rules override plan defaults. The percentage is applied to seller face value, never to Ticketing buyer fee.
create or replace function kombax_payments.resolve_fee_minor(p_scope text,p_amount_minor integer,p_subject_type text,p_subject_id uuid)
returns integer language plpgsql stable security definer set search_path='' as $$
declare v_plan text;v_rule kombax_payments.platform_fee_rules;v_percent numeric(7,4):=0;v_fixed integer:=0;
begin
  if p_amount_minor is null or p_amount_minor<=0 then return 0; end if;
  v_plan:=kombax_commercial.seller_plan_r64(p_subject_type,p_subject_id);
  select * into v_rule
  from kombax_payments.platform_fee_rules r
  where r.scope=p_scope and r.active and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
    and (r.seller_subject_type is null or r.seller_subject_type=p_subject_type)
    and (r.seller_subject_id is null or r.seller_subject_id=p_subject_id)
    and (r.plan_code is null or r.plan_code=v_plan)
  order by
    (r.seller_subject_id is not null) desc,
    (r.seller_subject_type is not null) desc,
    (r.plan_code is not null) desc,
    r.priority desc,r.starts_at desc
  limit 1;
  if found then
    v_percent:=v_rule.percentage;v_fixed:=v_rule.fixed_amount_minor;
  else
    select coalesce(p.platform_fee_percent,1.5) into v_percent
    from kombax_commercial.plan_pricing_r64 p where p.plan_code=v_plan and p.active;
    if not found then
      -- Legacy subscriptions stay operational but adopt the R64 standard transaction fee unless explicitly overridden.
      v_percent:=case when v_plan in('enterprise','brand_enterprise') then 0 else 1.5 end;
    end if;
  end if;
  return greatest(0,least(p_amount_minor,round(p_amount_minor*(v_percent/100.0))::integer+coalesce(v_fixed,0)));
end $$;
revoke all on function kombax_payments.resolve_fee_minor(text,integer,text,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.resolve_fee_minor(text,integer,text,uuid) to service_role;

-- Ticketing is included permanently only for Enterprise/Brand Enterprise. Other subjects use an active per-event entitlement/service access.
create or replace function kombax_commercial.event_ticketing_active_r628(p_event_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_seller jsonb;v_plan text;
begin
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  if v_plan in('enterprise','brand_enterprise') then return true; end if;
  return exists(select 1 from kombax_commercial.service_access a where a.subject_type='event' and a.subject_id=p_event_id and a.service_code='events_ticketing' and a.status='active')
    or kombax_commercial.entitlement_active_r64('event',p_event_id,'EVENT_TICKETING',p_event_id);
end $$;
revoke all on function kombax_commercial.event_ticketing_active_r628(uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.event_ticketing_active_r628(uuid) to service_role;

-- Determine whether a Showcase provider currently has transaction rights.
create or replace function kombax_commercial.provider_commerce_allowed_r64(p_provider_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_provider public.kombax_showcase_marcas;v_plan text;v_subject_type text;v_subject_id uuid;
begin
  select * into v_provider from public.kombax_showcase_marcas where id=p_provider_id;
  if not found then return false; end if;
  if v_provider.sujeto_tipo='club' then v_subject_type:='club';v_subject_id:=v_provider.club_id;
  else v_subject_type:='direct_profile';v_subject_id:=v_provider.perfil_directo_id; end if;
  v_plan:=kombax_commercial.active_plan_r64(v_subject_type,v_subject_id);
  -- Keep R63 legacy plans working until they are explicitly migrated.
  if v_plan in('enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then return true; end if;
  if v_plan='premium' then return kombax_commercial.entitlement_active_r64(v_subject_type,v_subject_id,'SHOWCASE_COMMERCE',null); end if;
  return false;
end $$;
revoke all on function kombax_commercial.provider_commerce_allowed_r64(uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.provider_commerce_allowed_r64(uuid) to service_role;

-- Preserve R63 GPSR/safety fields while adding the commercial capability gate.
create or replace function public.app_showcase_commerce_mutate_v259(p_item_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_item public.kombax_showcase_elementos;v_enabled boolean:=coalesce((p_payload->>'commerce_enabled')::boolean,false);v_price numeric;v_stock integer;v_safety text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_item_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  if v_item.listing_kind='professional_service' and v_enabled then raise exception 'SHOWCASE_SERVICE_CHECKOUT_DISABLED'; end if;
  if v_enabled and not kombax_commercial.provider_commerce_allowed_r64(v_item.marca_id) then raise exception 'SHOWCASE_COMMERCE_PLAN_OR_ACTIVATION_REQUIRED'; end if;
  v_price:=nullif(p_payload->>'precio_venta','')::numeric;v_stock:=nullif(p_payload->>'stock','')::integer;
  v_safety:=coalesce(nullif(p_payload->>'safety_status',''),'allowed');
  if v_enabled and (v_price is null or v_price<=0) then raise exception 'COMMERCE_PRICE_REQUIRED'; end if;
  if v_enabled and not kombax_marketplace.seller_ready_r627(v_item.marca_id) then raise exception 'KOMBAX_SELLER_CENTER_REQUIRED'; end if;
  if v_enabled and v_safety in('prohibited','removed_illegal','removed_safety') then raise exception 'SHOWCASE_PRODUCT_SAFETY_BLOCKED'; end if;
  update public.kombax_showcase_elementos set commerce_enabled=case when listing_kind='professional_service' then false else v_enabled end,
    precio_venta=case when listing_kind='professional_service' then null else v_price end,
    stock=case when listing_kind='professional_service' then null else v_stock end,
    variantes=case when listing_kind='professional_service' then '[]'::jsonb else coalesce(p_payload->'variantes','[]'::jsonb) end,
    fulfillment=coalesce(nullif(p_payload->>'fulfillment',''),'seller_shipping'),
    shipping_policy=nullif(btrim(p_payload->>'shipping_policy'),''),returns_policy=nullif(btrim(p_payload->>'returns_policy'),''),
    manufacturer_name=left(nullif(btrim(p_payload->>'manufacturer_name'),''),240),manufacturer_contact=left(nullif(btrim(p_payload->>'manufacturer_contact'),''),500),
    eu_responsible_person=left(nullif(btrim(p_payload->>'eu_responsible_person'),''),500),model_reference=left(nullif(btrim(p_payload->>'model_reference'),''),160),
    product_identifier=left(nullif(btrim(p_payload->>'product_identifier'),''),160),safety_warnings=left(nullif(btrim(p_payload->>'safety_warnings'),''),3000),
    safety_information_url=nullif(btrim(p_payload->>'safety_information_url'),''),regulatory_documents=coalesce(p_payload->'regulatory_documents','[]'::jsonb),
    ce_marking_applicable=case when p_payload ? 'ce_marking_applicable' then (p_payload->>'ce_marking_applicable')::boolean else null end,
    ce_marking_declared=case when p_payload ? 'ce_marking_declared' then (p_payload->>'ce_marking_declared')::boolean else false end,
    safety_status=v_safety,actualizado_por=v_uid,actualizado_en=now()
  where id=p_item_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('id',p_item_id,'commerce_enabled',case when v_item.listing_kind='professional_service' then false else v_enabled end,'safety_status',v_safety));
end $$;
revoke all on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Checkout preparation: face amount + platform percentage + Ticketing buyer fee.
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_checkout_prepare_internal_v259(p_actor_id uuid,p_kind text,p_reference_id uuid,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_fee public.cuotas;v_item public.kombax_showcase_elementos;
  v_provider public.kombax_showcase_marcas;v_order kombax_payments.showcase_orders;v_ticket_order kombax_payments.event_ticket_orders;
  v_event public.kombax_eventos_publicos;v_seller jsonb;v_amount int;v_face int;v_platform_pct int;v_buyer_fee int;v_total_platform int;
  v_qty int:=greatest(1,least(coalesce(p_quantity,1),100));v_name text;v_seller_name text;v_reserved int:=0;v_collect_shipping boolean:=false;
begin
  select * into v_attempt from kombax_payments.payment_attempts where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then
    if v_attempt.kind<>p_kind
      or (p_kind='club_fee' and v_attempt.cuota_id is distinct from p_reference_id)
      or (p_kind='showcase_order' and nullif(v_attempt.metadata->>'product_id','')::uuid is distinct from p_reference_id)
      or (p_kind='event_ticket' and nullif(v_attempt.metadata->>'event_id','')::uuid is distinct from p_reference_id) then raise exception 'CHECKOUT_REQUEST_ID_REUSED'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
    if v_attempt.cuota_id is not null then select q.concepto into v_name from public.cuotas q where q.id=v_attempt.cuota_id;
    elsif v_attempt.order_id is not null then
      select o.seller_name,i.product_name,(e.fulfillment in('seller_shipping','seller_shipping_or_pickup')) into v_seller_name,v_name,v_collect_shipping
      from kombax_payments.showcase_orders o left join kombax_payments.showcase_order_items i on i.order_id=o.id left join public.kombax_showcase_elementos e on e.id=i.product_id where o.id=v_attempt.order_id limit 1;
    elsif v_attempt.event_ticket_order_id is not null then
      select o.seller_name,e.nombre into v_seller_name,v_name from kombax_payments.event_ticket_orders o join public.kombax_eventos_publicos e on e.id=o.event_id where o.id=v_attempt.event_ticket_order_id;
    end if;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_attempt.order_id,'event_ticket_order_id',v_attempt.event_ticket_order_id,'kind',v_attempt.kind,'status',v_attempt.status,
      'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id,'stripe_account_id',v_account.stripe_account_id,
      'amount_minor',v_attempt.amount_minor,'seller_amount_minor',v_attempt.seller_amount_minor,'buyer_service_fee_minor',v_attempt.buyer_service_fee_minor,
      'platform_percentage_fee_minor',v_attempt.platform_percentage_fee_minor,'platform_fee_minor',v_attempt.platform_fee_minor,'currency',lower(v_attempt.currency),
      'ticket_quantity',coalesce(nullif(v_attempt.metadata->>'quantity','')::integer,1),'ticket_unit_amount_minor',nullif(v_attempt.metadata->>'ticket_unit_amount_minor','')::integer,
      'name',coalesce(v_name,'Pago KOMBAX'),'seller_name',v_seller_name,'collect_shipping',v_collect_shipping);
  end if;

  if p_kind='club_fee' then
    if not kombax_payments.can_pay_fee(p_actor_id,p_reference_id) then raise exception 'FEE_PAYMENT_DENIED'; end if;
    select * into strict v_fee from public.cuotas where id=p_reference_id for update;
    if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta') then raise exception 'FEE_NOT_PAYABLE'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='club' and subject_id=v_fee.club_id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_face:=round(v_fee.importe*100)::int;v_platform_pct:=kombax_payments.resolve_fee_minor('club_fee',v_face,'club',v_fee.club_id);v_amount:=v_face;v_total_platform:=v_platform_pct;
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,seller_amount_minor,buyer_service_fee_minor,platform_percentage_fee_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,v_face,0,v_platform_pct,v_total_platform,'EUR',jsonb_build_object('concept',v_fee.concepto)) returning * into v_attempt;
    update public.cuotas set estado='procesando',metodo_pago='stripe_checkout',actualizado_en=now() where id=v_fee.id;
    return jsonb_build_object('attempt_id',v_attempt.id,'kind',p_kind,'amount_minor',v_amount,'seller_amount_minor',v_face,'buyer_service_fee_minor',0,'platform_percentage_fee_minor',v_platform_pct,'platform_fee_minor',v_total_platform,'currency','eur','name',v_fee.concepto,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);

  elsif p_kind='showcase_order' then
    v_qty:=greatest(1,least(coalesce(p_quantity,1),100));
    select * into strict v_item from public.kombax_showcase_elementos where id=p_reference_id and estado='publicado' and commerce_enabled for update;
    if not kombax_commercial.provider_commerce_allowed_r64(v_item.marca_id) then raise exception 'SHOWCASE_COMMERCE_PLAN_OR_ACTIVATION_REQUIRED'; end if;
    if v_item.precio_venta is null or v_item.precio_venta<=0 or (v_item.stock is not null and v_item.stock<v_qty) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=v_item.marca_id and estado='publicada';
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=v_provider.id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_face:=round(v_item.precio_venta*100)::int*v_qty;v_platform_pct:=kombax_payments.resolve_fee_minor('showcase',v_face,'showcase_provider',v_provider.id);v_amount:=v_face;v_total_platform:=v_platform_pct;
    insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,buyer_email,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,(select u.email from auth.users u where u.id=p_actor_id),v_face,'EUR') returning * into v_order;
    insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor) values(v_order.id,v_item.id,v_item.nombre,v_qty,round(v_item.precio_venta*100)::int);
    insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source) values(v_order.id,'received',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,seller_amount_minor,buyer_service_fee_minor,platform_percentage_fee_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_order.id,v_amount,v_face,0,v_platform_pct,v_total_platform,'EUR',jsonb_build_object('product_id',v_item.id,'seller',v_provider.nombre)) returning * into v_attempt;
    v_collect_shipping:=v_item.fulfillment in('seller_shipping','seller_shipping_or_pickup');
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind',p_kind,'amount_minor',v_amount,'seller_amount_minor',v_face,'buyer_service_fee_minor',0,'platform_percentage_fee_minor',v_platform_pct,'platform_fee_minor',v_total_platform,'currency','eur','name',v_item.nombre,'seller_name',v_provider.nombre,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',v_collect_shipping);

  elsif p_kind='event_ticket' then
    select * into strict v_event from public.kombax_eventos_publicos where id=p_reference_id for update;
    if not v_event.ticketing_enabled or v_event.ticketing_mode<>'kombax' then raise exception 'EVENT_TICKETING_NOT_ENABLED'; end if;
    if v_event.estado in('borrador','cancelado','finalizado') then raise exception 'EVENT_TICKET_NOT_ON_SALE'; end if;
    if v_event.tickets_abren_en is not null and now()<v_event.tickets_abren_en then raise exception 'EVENT_TICKET_SALE_NOT_OPEN'; end if;
    if v_event.tickets_cierran_en is not null and now()>v_event.tickets_cierran_en then raise exception 'EVENT_TICKET_SALE_CLOSED'; end if;
    if v_event.ticket_price_minor is null or v_event.ticket_capacity is null then raise exception 'EVENT_TICKETING_CONFIGURATION_REQUIRED'; end if;
    if v_event.ticket_capacity>coalesce((select (value#>>'{}')::integer from kombax_commercial.runtime_config_r64 where config_key='large_event_threshold'),1000) then raise exception 'EVENT_LARGE_EVENT_TERMS_REQUIRED'; end if;
    v_qty:=greatest(1,least(coalesce(p_quantity,1),v_event.ticket_limit_per_order,20));
    select coalesce(sum(o.quantity),0)::int into v_reserved from kombax_payments.event_ticket_orders o where o.event_id=v_event.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()));
    if v_reserved+v_qty>v_event.ticket_capacity then raise exception 'EVENT_TICKETS_SOLD_OUT'; end if;
    v_seller:=kombax_payments.event_seller_r625(v_event.id);
    select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid and a.status='active' and a.charges_enabled and a.payouts_enabled and a.configuration_compatible and a.charge_model='direct';
    v_face:=v_event.ticket_price_minor*v_qty;v_buyer_fee:=kombax_commercial.ticket_buyer_fee_minor_r64()*v_qty;
    v_platform_pct:=kombax_payments.resolve_fee_minor('event_ticket',v_face,v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
    v_amount:=v_face+v_buyer_fee;v_total_platform:=v_buyer_fee+v_platform_pct;v_seller_name:=v_seller->>'seller_name';
    insert into kombax_payments.event_ticket_orders(order_number,buyer_user_id,event_id,seller_subject_type,seller_subject_id,seller_name,quantity,unit_amount_minor,amount_total_minor,buyer_service_fee_minor,checkout_total_minor,currency,buyer_email)
    values('KXT-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_event.id,v_seller->>'subject_type',(v_seller->>'subject_id')::uuid,v_seller_name,v_qty,v_event.ticket_price_minor,v_face,v_buyer_fee,v_amount,v_event.ticket_currency,(select u.email from auth.users u where u.id=p_actor_id)) returning * into v_ticket_order;
    insert into kombax_payments.event_ticket_order_history(order_id,to_status,actor_user_id,source) values(v_ticket_order.id,'pending_payment',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,event_ticket_order_id,amount_minor,seller_amount_minor,buyer_service_fee_minor,platform_percentage_fee_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_ticket_order.id,v_amount,v_face,v_buyer_fee,v_platform_pct,v_total_platform,v_event.ticket_currency,
      jsonb_build_object('event_id',v_event.id,'ticket_order_id',v_ticket_order.id,'quantity',v_qty,'ticket_unit_amount_minor',v_event.ticket_price_minor,'seller',v_seller_name)) returning * into v_attempt;
    return jsonb_build_object('attempt_id',v_attempt.id,'event_ticket_order_id',v_ticket_order.id,'kind',p_kind,'amount_minor',v_amount,'seller_amount_minor',v_face,
      'buyer_service_fee_minor',v_buyer_fee,'platform_percentage_fee_minor',v_platform_pct,'platform_fee_minor',v_total_platform,'ticket_quantity',v_qty,
      'ticket_unit_amount_minor',v_event.ticket_price_minor,'currency',lower(v_event.ticket_currency),'name',v_event.nombre,'seller_name',v_seller_name,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);
  else raise exception 'CHECKOUT_KIND_INVALID'; end if;
end $$;

revoke all on function public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid) to service_role;

notify pgrst,'reload schema';
commit;
