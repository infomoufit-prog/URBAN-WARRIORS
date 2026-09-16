-- KOMBAX 20.116 R65 · Commerce + Events Operations
-- Phases 1–9: money flow, seller operations, finance, refunds, communications,
-- Events finance/refunds, Enterprise BI and financial QA hardening.
-- IMPORTANT: KOMBAX SaaS Billing is intentionally NOT activated here.
begin;

-- ---------------------------------------------------------------------------
-- 1) Private operational ledgers (service-role only)
-- ---------------------------------------------------------------------------
create table if not exists kombax_payments.commerce_refunds_r65(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  scope text not null check(scope in('showcase','event')),
  showcase_order_id uuid references kombax_payments.showcase_orders(id) on delete restrict,
  event_ticket_order_id uuid references kombax_payments.event_ticket_orders(id) on delete restrict,
  connected_account_id uuid not null references kombax_payments.connected_accounts(id) on delete restrict,
  stripe_account_id text not null,
  stripe_payment_intent_id text not null,
  stripe_refund_id text unique,
  amount_requested_minor integer not null check(amount_requested_minor>0),
  amount_succeeded_minor integer not null default 0 check(amount_succeeded_minor>=0),
  seller_amount_refunded_minor integer not null default 0 check(seller_amount_refunded_minor>=0),
  platform_fee_refunded_minor integer not null default 0 check(platform_fee_refunded_minor>=0),
  currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'),
  reason text,
  status text not null default 'prepared' check(status in('prepared','processing','succeeded','failed','cancelled')),
  refund_application_fee boolean not null default false,
  restock_requested boolean not null default false,
  restock_quantity integer not null default 0 check(restock_quantity>=0),
  restocked_quantity integer not null default 0 check(restocked_quantity>=0),
  failure_message text,
  stripe_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(actor_user_id,request_id),
  check((scope='showcase' and showcase_order_id is not null and event_ticket_order_id is null)
     or (scope='event' and event_ticket_order_id is not null and showcase_order_id is null))
);
create index if not exists idx_commerce_refunds_showcase_r65 on kombax_payments.commerce_refunds_r65(showcase_order_id,created_at desc);
create index if not exists idx_commerce_refunds_event_r65 on kombax_payments.commerce_refunds_r65(event_ticket_order_id,created_at desc);
create index if not exists idx_commerce_refunds_status_r65 on kombax_payments.commerce_refunds_r65(status,created_at);

create table if not exists kombax_payments.commerce_refund_tickets_r65(
  refund_id uuid not null references kombax_payments.commerce_refunds_r65(id) on delete restrict,
  ticket_id uuid not null references kombax_payments.event_tickets(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(refund_id,ticket_id),
  unique(ticket_id)
);

create table if not exists kombax_payments.showcase_stock_movements_r65(
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.kombax_showcase_marcas(id) on delete restrict,
  product_id uuid not null references public.kombax_showcase_elementos(id) on delete restrict,
  order_id uuid references kombax_payments.showcase_orders(id) on delete restrict,
  refund_id uuid references kombax_payments.commerce_refunds_r65(id) on delete restrict,
  movement_type text not null check(movement_type in('sale','refund_restock','manual_adjustment','correction')),
  quantity_delta integer not null check(quantity_delta<>0),
  stock_before integer,
  stock_after integer,
  actor_user_id uuid references public.perfiles(id) on delete restrict,
  note text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create index if not exists idx_stock_movements_provider_r65 on kombax_payments.showcase_stock_movements_r65(provider_id,created_at desc);
create index if not exists idx_stock_movements_product_r65 on kombax_payments.showcase_stock_movements_r65(product_id,created_at desc);

create table if not exists kombax_payments.commerce_communications_r65(
  id uuid primary key default gen_random_uuid(),
  scope text not null check(scope in('showcase','event')),
  provider_id uuid references public.kombax_showcase_marcas(id) on delete restrict,
  event_id uuid references public.kombax_eventos_publicos(id) on delete restrict,
  showcase_order_id uuid references kombax_payments.showcase_orders(id) on delete restrict,
  event_ticket_order_id uuid references kombax_payments.event_ticket_orders(id) on delete restrict,
  recipient_user_id uuid references public.perfiles(id) on delete restrict,
  recipient_email text,
  template_code text not null,
  subject text not null,
  body_text text not null,
  payload jsonb not null default '{}'::jsonb,
  source text not null default 'system' check(source in('system','seller','organizer','stripe')),
  actor_user_id uuid references public.perfiles(id) on delete restrict,
  status text not null default 'queued' check(status in('queued','processing','sent','failed','cancelled')),
  attempts integer not null default 0 check(attempts>=0),
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,
  last_error text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check((scope='showcase' and provider_id is not null) or (scope='event' and event_id is not null))
);
create index if not exists idx_comms_queue_r65 on kombax_payments.commerce_communications_r65(status,scheduled_for,created_at);
create index if not exists idx_comms_provider_r65 on kombax_payments.commerce_communications_r65(provider_id,created_at desc);
create index if not exists idx_comms_event_r65 on kombax_payments.commerce_communications_r65(event_id,created_at desc);

create table if not exists kombax_payments.commerce_analytics_events_r65(
  id bigserial primary key,
  actor_user_id uuid references public.perfiles(id) on delete set null,
  event_type text not null check(event_type in(
    'product_impression','product_view','product_interest','showcase_checkout_start','showcase_purchase',
    'event_view','ticket_checkout_start','ticket_purchase','ticket_checkin'
  )),
  provider_id uuid references public.kombax_showcase_marcas(id) on delete restrict,
  product_id uuid references public.kombax_showcase_elementos(id) on delete restrict,
  event_id uuid references public.kombax_eventos_publicos(id) on delete restrict,
  order_id uuid,
  source text,
  amount_minor integer check(amount_minor is null or amount_minor>=0),
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_analytics_provider_r65 on kombax_payments.commerce_analytics_events_r65(provider_id,event_type,occurred_at desc);
create index if not exists idx_analytics_event_r65 on kombax_payments.commerce_analytics_events_r65(event_id,event_type,occurred_at desc);
create index if not exists idx_analytics_product_r65 on kombax_payments.commerce_analytics_events_r65(product_id,event_type,occurred_at desc);

create table if not exists kombax_payments.event_refund_batches_r65(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  reason text,
  status text not null default 'processing' check(status in('processing','completed','completed_with_errors','cancelled')),
  requested_orders integer not null default 0,
  succeeded_orders integer not null default 0,
  failed_orders integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(actor_user_id,request_id)
);

-- Private schemas still get RLS as defense in depth; client roles get zero direct table access.
do $$ declare t regclass; begin
  foreach t in array array[
    'kombax_payments.commerce_refunds_r65'::regclass,
    'kombax_payments.commerce_refund_tickets_r65'::regclass,
    'kombax_payments.showcase_stock_movements_r65'::regclass,
    'kombax_payments.commerce_communications_r65'::regclass,
    'kombax_payments.commerce_analytics_events_r65'::regclass,
    'kombax_payments.event_refund_batches_r65'::regclass
  ] loop execute format('alter table %s enable row level security',t); end loop;
end $$;
revoke all on kombax_payments.commerce_refunds_r65,kombax_payments.commerce_refund_tickets_r65,
  kombax_payments.showcase_stock_movements_r65,kombax_payments.commerce_communications_r65,
  kombax_payments.commerce_analytics_events_r65,kombax_payments.event_refund_batches_r65
from public,anon,authenticated;
grant all on kombax_payments.commerce_refunds_r65,kombax_payments.commerce_refund_tickets_r65,
  kombax_payments.showcase_stock_movements_r65,kombax_payments.commerce_communications_r65,
  kombax_payments.commerce_analytics_events_r65,kombax_payments.event_refund_batches_r65
  to service_role;
grant usage,select on sequence kombax_payments.commerce_analytics_events_r65_id_seq to service_role;

-- Partial refunds must not be collapsed into a full-order state.
alter table kombax_payments.event_ticket_orders drop constraint if exists event_ticket_refund_state_r63;
alter table kombax_payments.event_ticket_orders add constraint event_ticket_refund_state_r65
  check(refund_state in('not_required','refund_pending','refund_processing','partially_refunded','refunded','refund_failed','manual_review'));

-- Cancellation now also captures orders that were partially refunded before the event was cancelled.
create or replace function public.app_kombax_event_cancel_commercial_plan_r63(p_event_id uuid,p_reason text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_count integer;v_reason text:=left(nullif(btrim(p_reason),''),1000);
begin
  if v_uid is null or p_request_id is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if v_reason is null then raise exception 'EVENT_CANCELLATION_REASON_REQUIRED'; end if;
  update public.kombax_eventos_publicos set estado='cancelado',ticketing_enabled=false,actualizado_en=now() where id=p_event_id;
  update kombax_payments.event_ticket_orders set refund_state='refund_pending',refund_reason=v_reason,refund_requested_at=coalesce(refund_requested_at,now()),updated_at=now()
  where event_id=p_event_id and status='paid' and refund_state in('not_required','partially_refunded','refund_failed','manual_review');
  get diagnostics v_count=row_count;
  insert into kombax_payments.event_ticket_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
  select o.id,o.status,o.status,v_uid,'organizer',jsonb_build_object('event_cancelled',true,'refund_state','refund_pending','reason',v_reason,'request_id',p_request_id)
  from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.refund_state='refund_pending';
  return jsonb_build_object('ok',true,'event_id',p_event_id,'event_status','cancelado','refunds_pending',v_count,'money_moved',false,'next_action','PROCESS_REFUNDS_IN_KOMBAX');
end $$;
revoke all on function public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Permission helpers
-- ---------------------------------------------------------------------------
create or replace function kombax_payments.can_manage_event_r65(p_actor uuid,p_event uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_seller jsonb;v_type text;v_id uuid;
begin
  if p_actor is null or p_event is null then return false; end if;
  if exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo) then return true; end if;
  begin v_seller:=kombax_payments.event_seller_r625(p_event); exception when others then return false; end;
  v_type:=v_seller->>'subject_type';v_id:=(v_seller->>'subject_id')::uuid;
  if v_type='club' then
    return exists(select 1 from public.miembros_club m where m.club_id=v_id and m.perfil_id=p_actor and m.activo and m.rol in('direccion','secretaria','economia'));
  elsif v_type='showcase_provider' then
    return kombax_payments.can_manage_provider(p_actor,v_id);
  elsif v_type='federation' then
    return kombax_payments.can_manage_federation_connect_r624(p_actor,v_id);
  elsif v_type='event_organizer' then
    return kombax_payments.can_manage_event_organizer_connect_r625(p_actor,v_id);
  end if;
  return false;
end $$;
revoke all on function kombax_payments.can_manage_event_r65(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_manage_event_r65(uuid,uuid) to service_role;

create or replace function kombax_payments.connected_account_for_event_r65(p_event uuid)
returns kombax_payments.connected_accounts language plpgsql stable security definer set search_path='' as $$
declare v_seller jsonb;v_row kombax_payments.connected_accounts;
begin
  v_seller:=kombax_payments.event_seller_r625(p_event);
  select * into strict v_row from kombax_payments.connected_accounts a
  where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid
    and a.status='active' and a.charges_enabled and a.charge_model='direct'
  order by a.updated_at desc limit 1;
  return v_row;
end $$;
revoke all on function kombax_payments.connected_account_for_event_r65(uuid) from public,anon,authenticated;
grant execute on function kombax_payments.connected_account_for_event_r65(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3) Communication helper and queue
-- ---------------------------------------------------------------------------
create or replace function kombax_payments.queue_communication_r65(
  p_scope text,p_provider uuid,p_event uuid,p_showcase_order uuid,p_event_order uuid,
  p_recipient_user uuid,p_recipient_email text,p_template text,p_subject text,p_body text,
  p_source text,p_actor uuid,p_key text,p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into kombax_payments.commerce_communications_r65(
    scope,provider_id,event_id,showcase_order_id,event_ticket_order_id,recipient_user_id,recipient_email,
    template_code,subject,body_text,payload,source,actor_user_id,idempotency_key
  ) values(p_scope,p_provider,p_event,p_showcase_order,p_event_order,p_recipient_user,nullif(lower(btrim(p_recipient_email)),''),
    p_template,left(p_subject,240),left(p_body,10000),coalesce(p_payload,'{}'::jsonb),coalesce(p_source,'system'),p_actor,left(p_key,240))
  on conflict(idempotency_key) do update set updated_at=now()
  returning id into v_id;
  return v_id;
end $$;
revoke all on function kombax_payments.queue_communication_r65(text,uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function kombax_payments.queue_communication_r65(text,uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,text,jsonb) to service_role;

create or replace function public.app_kombax_commerce_communications_r65(p_scope text,p_subject_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_allowed boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_scope='showcase' then v_allowed:=kombax_payments.can_manage_provider(v_uid,p_subject_id);
  elsif p_scope='event' then v_allowed:=kombax_payments.can_manage_event_r65(v_uid,p_subject_id); end if;
  if not v_allowed then raise exception 'COMMERCE_MANAGE_REQUIRED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
    select c.id,c.template_code,c.subject,c.body_text,c.status,c.attempts,c.sent_at,c.last_error,c.created_at,c.source,
      c.recipient_email,c.showcase_order_id,c.event_ticket_order_id
    from kombax_payments.commerce_communications_r65 c
    where (p_scope='showcase' and c.provider_id=p_subject_id) or (p_scope='event' and c.event_id=p_subject_id)
    order by c.created_at desc limit least(greatest(coalesce(p_limit,100),1),300)
  ) x);
end $$;
revoke all on function public.app_kombax_commerce_communications_r65(text,uuid,integer) from public,anon;
grant execute on function public.app_kombax_commerce_communications_r65(text,uuid,integer) to authenticated;

create or replace function public.app_kombax_event_attendee_message_r65(p_event_id uuid,p_subject text,p_message text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_count integer:=0;r record;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if char_length(btrim(coalesce(p_subject,''))) not between 3 and 160 or char_length(btrim(coalesce(p_message,''))) not between 3 and 4000 then raise exception 'MESSAGE_INVALID'; end if;
  for r in select o.id,o.buyer_user_id,o.buyer_email,o.order_number from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.status='paid'
  loop
    perform kombax_payments.queue_communication_r65('event',null,p_event_id,null,r.id,r.buyer_user_id,r.buyer_email,'event_organizer_message',p_subject,p_message,'organizer',v_uid,
      'event-message:'||p_request_id::text||':'||r.id::text,jsonb_build_object('order_number',r.order_number));
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'queued',v_count,'request_id',p_request_id);
end $$;
revoke all on function public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Seller Center Pro: stock ledger + safe manual adjustment
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_stock_movements_r65(p_provider_id uuid,p_product_id uuid default null,p_limit integer default 150)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
    select m.id,m.product_id,e.nombre as product_name,m.order_id,m.refund_id,m.movement_type,m.quantity_delta,m.stock_before,m.stock_after,m.note,m.created_at
    from kombax_payments.showcase_stock_movements_r65 m join public.kombax_showcase_elementos e on e.id=m.product_id
    where m.provider_id=p_provider_id and (p_product_id is null or m.product_id=p_product_id)
    order by m.created_at desc limit least(greatest(coalesce(p_limit,150),1),500)
  ) x);
end $$;
revoke all on function public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_showcase_stock_adjust_r65(p_product_id uuid,p_new_stock integer,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_item public.kombax_showcase_elementos;v_before integer;v_delta integer;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if p_new_stock is null or p_new_stock<0 then raise exception 'STOCK_INVALID'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_product_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_before:=coalesce(v_item.stock,0);v_delta:=p_new_stock-v_before;
  if v_delta=0 then return jsonb_build_object('ok',true,'product_id',p_product_id,'stock',p_new_stock,'changed',false); end if;
  update public.kombax_showcase_elementos set stock=p_new_stock,actualizado_en=now(),actualizado_por=v_uid where id=p_product_id;
  insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,movement_type,quantity_delta,stock_before,stock_after,actor_user_id,note,idempotency_key)
  values(v_item.marca_id,p_product_id,'manual_adjustment',v_delta,v_before,p_new_stock,v_uid,left(nullif(btrim(p_note),''),500),'manual:'||v_uid::text||':'||p_request_id::text)
  on conflict(idempotency_key) do nothing;
  return jsonb_build_object('ok',true,'product_id',p_product_id,'stock',p_new_stock,'previous_stock',v_before,'changed',true);
end $$;
revoke all on function public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid) to authenticated;

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

create or replace function public.app_stripe_refund_finalize_internal_r65(p_refund_id uuid,p_status text,p_stripe_refund jsonb,p_error text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_r kombax_payments.commerce_refunds_r65;
begin
  select * into strict v_r from kombax_payments.commerce_refunds_r65 where id=p_refund_id for update;
  if p_status='succeeded' then return kombax_payments.apply_refund_success_r65(p_refund_id,p_stripe_refund); end if;
  if p_status='processing' then
    update kombax_payments.commerce_refunds_r65 set status='processing',failure_message=null,
      stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),stripe_payload=coalesce(p_stripe_refund,'{}'::jsonb),updated_at=now() where id=p_refund_id;
    return jsonb_build_object('ok',true,'refund_id',p_refund_id,'status','processing');
  end if;
  update kombax_payments.commerce_refunds_r65 set status='failed',failure_message=left(coalesce(p_error,p_stripe_refund#>>'{failure_reason}','REFUND_FAILED'),500),
    stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),stripe_payload=coalesce(p_stripe_refund,'{}'::jsonb),updated_at=now() where id=p_refund_id;
  if v_r.scope='event' then update kombax_payments.event_ticket_orders set refund_state='refund_failed',updated_at=now() where id=v_r.event_ticket_order_id and refund_state='refund_processing'; end if;
  return jsonb_build_object('ok',false,'refund_id',p_refund_id,'status','failed');
end $$;
revoke all on function public.app_stripe_refund_finalize_internal_r65(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.app_stripe_refund_finalize_internal_r65(uuid,text,jsonb,text) to service_role;

-- Cancellation queue: returns order ids only after actor authorization.
create or replace function public.app_kombax_event_refund_batch_internal_r65(p_actor_id uuid,p_event_id uuid,p_reason text,p_request_id uuid,p_limit integer default 25)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch kombax_payments.event_refund_batches_r65;v_orders jsonb;v_pending integer;
begin
  if not kombax_payments.can_manage_event_r65(p_actor_id,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  insert into kombax_payments.event_refund_batches_r65(request_id,event_id,actor_user_id,reason)
  values(p_request_id,p_event_id,p_actor_id,left(nullif(btrim(p_reason),''),1000))
  on conflict(actor_user_id,request_id) do update set updated_at=now() returning * into v_batch;
  select coalesce(jsonb_agg(id order by created_at),'[]'::jsonb) into v_orders from (
    select o.id from kombax_payments.event_ticket_orders o
    where o.event_id=p_event_id and o.status='paid' and o.refund_state in('refund_pending','refund_failed','manual_review')
    order by o.created_at limit least(greatest(coalesce(p_limit,25),1),25)
  ) q;
  select count(*) into v_pending from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.status='paid' and o.refund_state in('refund_pending','refund_processing','refund_failed','manual_review');
  update kombax_payments.event_refund_batches_r65 set requested_orders=greatest(requested_orders,jsonb_array_length(v_orders)),updated_at=now() where id=v_batch.id;
  return jsonb_build_object('batch_id',v_batch.id,'orders',v_orders,'pending',v_pending,'reason',coalesce(v_batch.reason,p_reason));
end $$;
revoke all on function public.app_kombax_event_refund_batch_internal_r65(uuid,uuid,text,uuid,integer) from public,anon,authenticated;
grant execute on function public.app_kombax_event_refund_batch_internal_r65(uuid,uuid,text,uuid,integer) to service_role;

create or replace function public.app_kombax_event_refund_batch_finalize_internal_r65(p_batch_id uuid,p_succeeded integer,p_failed integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch kombax_payments.event_refund_batches_r65;v_pending integer;v_status text;
begin
  select * into strict v_batch from kombax_payments.event_refund_batches_r65 where id=p_batch_id for update;
  select count(*) into v_pending from kombax_payments.event_ticket_orders where event_id=v_batch.event_id and status='paid' and refund_state in('refund_pending','refund_processing','refund_failed','manual_review');
  v_status:=case when v_pending=0 and coalesce(p_failed,0)=0 then 'completed' when v_pending=0 then 'completed_with_errors' else 'processing' end;
  update kombax_payments.event_refund_batches_r65 set succeeded_orders=succeeded_orders+greatest(coalesce(p_succeeded,0),0),failed_orders=failed_orders+greatest(coalesce(p_failed,0),0),status=v_status,
    completed_at=case when v_status like 'completed%' then now() else completed_at end,updated_at=now() where id=p_batch_id;
  return jsonb_build_object('ok',true,'batch_id',p_batch_id,'status',v_status,'remaining',v_pending);
end $$;
revoke all on function public.app_kombax_event_refund_batch_finalize_internal_r65(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.app_kombax_event_refund_batch_finalize_internal_r65(uuid,integer,integer) to service_role;

-- ---------------------------------------------------------------------------
-- R65 sales projection adds refund state without changing the legacy R6252 contract.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_event_ticket_sales_r65(p_event_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_orders jsonb;v_dashboard jsonb;
begin
  if v_uid is null or not kombax_payments.can_event_ticket_action_r6252(p_event_id,v_uid,'sales') then raise exception 'EVENT_TICKET_SALES_REQUIRED'; end if;
  v_dashboard:=public.app_kombax_event_ticket_dashboard_r6252(p_event_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'quantity',o.quantity,'amount_total',o.amount_total_minor/100.0,
    'checkout_total',o.checkout_total_minor/100.0,'buyer_service_fee',o.buyer_service_fee_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,
    'refund_state',o.refund_state,'refund_reason',o.refund_reason,'refund_requested_at',o.refund_requested_at,'refund_completed_at',o.refund_completed_at,
    'buyer_email',o.buyer_email,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'status',t.status,'used_at',t.used_at,'ticket_index',t.ticket_index) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb) into v_orders
  from (select * from kombax_payments.event_ticket_orders where event_id=p_event_id order by created_at desc limit least(greatest(coalesce(p_limit,200),1),500)) o;
  return v_dashboard||jsonb_build_object('orders',v_orders);
end $$;
revoke all on function public.app_kombax_event_ticket_sales_r65(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_ticket_sales_r65(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Finance centers + connected-account context
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_finance_r65(p_provider_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_gross bigint;v_refunds bigint;v_fee bigint;v_orders integer;v_pending integer;v_plan text;
begin
  if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  select coalesce(sum(a.seller_amount_minor),0),coalesce(sum(a.platform_fee_minor),0),count(*) into v_gross,v_fee,v_orders
    from kombax_payments.payment_attempts a join kombax_payments.showcase_orders o on o.id=a.order_id
    where o.seller_provider_id=p_provider_id and a.status in('succeeded','refunded');
  select coalesce(sum(r.seller_amount_refunded_minor),0) into v_refunds from kombax_payments.commerce_refunds_r65 r join kombax_payments.showcase_orders o on o.id=r.showcase_order_id
    where o.seller_provider_id=p_provider_id and r.status='succeeded';
  v_fee:=greatest(0,v_fee-coalesce((select sum(r.platform_fee_refunded_minor) from kombax_payments.commerce_refunds_r65 r join kombax_payments.showcase_orders o on o.id=r.showcase_order_id where o.seller_provider_id=p_provider_id and r.status='succeeded'),0));
  select count(*) into v_pending from kombax_payments.showcase_orders where seller_provider_id=p_provider_id and status in('payment_confirmed','preparing','shipped');
  v_plan:=kombax_commercial.seller_plan_r64('showcase_provider',p_provider_id);
  return jsonb_build_object('currency','EUR','gross_minor',v_gross,'seller_refunds_minor',v_refunds,'buyer_refunds_minor',(select coalesce(sum(r.amount_succeeded_minor),0) from kombax_payments.commerce_refunds_r65 r join kombax_payments.showcase_orders o on o.id=r.showcase_order_id where o.seller_provider_id=p_provider_id and r.status='succeeded'),'platform_fee_minor',v_fee,
    'estimated_seller_net_before_stripe_minor',greatest(0,v_gross-v_refunds-v_fee),'orders',v_orders,'open_orders',v_pending,'plan_code',v_plan,
    'note','El neto es estimado antes de las tarifas de procesamiento de Stripe; saldo y payouts se consultan directamente a Stripe.','recent_refunds',
    (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select r.id,r.showcase_order_id,r.amount_succeeded_minor,r.status,r.reason,r.created_at,r.completed_at from kombax_payments.commerce_refunds_r65 r join kombax_payments.showcase_orders o on o.id=r.showcase_order_id where o.seller_provider_id=p_provider_id order by r.created_at desc limit 30)x));
end $$;
revoke all on function public.app_kombax_showcase_finance_r65(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_finance_r65(uuid) to authenticated;

create or replace function public.app_kombax_event_finance_r65(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_gross bigint;v_refunds bigint;v_fee bigint;v_orders integer;v_seller jsonb;v_plan text;
begin
  if v_uid is null or not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select coalesce(sum(a.seller_amount_minor),0),coalesce(sum(a.platform_fee_minor),0),count(*) into v_gross,v_fee,v_orders
    from kombax_payments.payment_attempts a join kombax_payments.event_ticket_orders o on o.id=a.event_ticket_order_id
    where o.event_id=p_event_id and a.status in('succeeded','refunded');
  select coalesce(sum(r.seller_amount_refunded_minor),0) into v_refunds from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id
    where o.event_id=p_event_id and r.status='succeeded';
  v_fee:=greatest(0,v_fee-coalesce((select sum(r.platform_fee_refunded_minor) from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id and r.status='succeeded'),0));
  v_seller:=kombax_payments.event_seller_r625(p_event_id);v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  return jsonb_build_object('currency','EUR','gross_minor',v_gross,'seller_refunds_minor',v_refunds,'buyer_refunds_minor',(select coalesce(sum(r.amount_succeeded_minor),0) from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id and r.status='succeeded'),'platform_fee_minor',v_fee,
    'estimated_organizer_net_before_stripe_minor',greatest(0,v_gross-v_refunds-v_fee),'orders',v_orders,'plan_code',v_plan,
    'refunds_pending',(select count(*) from kombax_payments.event_ticket_orders where event_id=p_event_id and refund_state in('refund_pending','refund_processing','refund_failed','manual_review')),
    'note','El neto es estimado antes de las tarifas de procesamiento de Stripe; saldo y payouts se consultan directamente a Stripe.','recent_refunds',
    (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select r.id,r.event_ticket_order_id,r.amount_succeeded_minor,r.status,r.reason,r.created_at,r.completed_at from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id order by r.created_at desc limit 30)x));
end $$;
revoke all on function public.app_kombax_event_finance_r65(uuid) from public,anon;
grant execute on function public.app_kombax_event_finance_r65(uuid) to authenticated;

create or replace function public.app_stripe_account_finance_context_internal_r65(p_actor_id uuid,p_scope text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_account kombax_payments.connected_accounts;v_seller jsonb;
begin
  if p_scope='showcase' then
    if not kombax_payments.can_manage_provider(p_actor_id,p_subject_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=p_subject_id order by updated_at desc limit 1;
  elsif p_scope='event' then
    if not kombax_payments.can_manage_event_r65(p_actor_id,p_subject_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    v_seller:=kombax_payments.event_seller_r625(p_subject_id);
    select * into strict v_account from kombax_payments.connected_accounts where subject_type=v_seller->>'subject_type' and subject_id=(v_seller->>'subject_id')::uuid order by updated_at desc limit 1;
  else raise exception 'FINANCE_SCOPE_INVALID'; end if;
  return jsonb_build_object('stripe_account_id',v_account.stripe_account_id,'charges_enabled',v_account.charges_enabled,'payouts_enabled',v_account.payouts_enabled,'status',v_account.status,'charge_model',v_account.charge_model);
end $$;
revoke all on function public.app_stripe_account_finance_context_internal_r65(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.app_stripe_account_finance_context_internal_r65(uuid,text,uuid) to service_role;

-- ---------------------------------------------------------------------------
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
-- 11) Outbox claim/finalize service functions
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commerce_outbox_claim_internal_r65(p_limit integer default 40)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_rows jsonb;
begin
  with picked as (
    select id from kombax_payments.commerce_communications_r65
    where status in('queued','failed') and scheduled_for<=now() and attempts<5
    order by scheduled_for,created_at limit least(greatest(coalesce(p_limit,40),1),100) for update skip locked
  ), upd as (
    update kombax_payments.commerce_communications_r65 c set status='processing',attempts=attempts+1,updated_at=now()
    from picked p where c.id=p.id
    returning c.id,c.recipient_email,c.recipient_user_id,c.subject,c.body_text,c.template_code,c.payload,c.attempts
  ) select coalesce(jsonb_agg(to_jsonb(upd)),'[]'::jsonb) into v_rows from upd;
  return v_rows;
end $$;
revoke all on function public.app_kombax_commerce_outbox_claim_internal_r65(integer) from public,anon,authenticated;
grant execute on function public.app_kombax_commerce_outbox_claim_internal_r65(integer) to service_role;

create or replace function public.app_kombax_commerce_outbox_finalize_internal_r65(p_id uuid,p_ok boolean,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  update kombax_payments.commerce_communications_r65 set status=case when p_ok then 'sent' else 'failed' end,sent_at=case when p_ok then now() else sent_at end,
    last_error=case when p_ok then null else left(coalesce(p_error,'SEND_FAILED'),500) end,scheduled_for=case when p_ok then scheduled_for else now()+interval '15 minutes' end,updated_at=now() where id=p_id;
end $$;
revoke all on function public.app_kombax_commerce_outbox_finalize_internal_r65(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.app_kombax_commerce_outbox_finalize_internal_r65(uuid,boolean,text) to service_role;

-- Explicitly remove PUBLIC execution from every new SECURITY DEFINER endpoint, including internal helpers.
revoke execute on function public.app_kombax_commerce_communications_r65(text,uuid,integer),
  public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid),
  public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer),
  public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid),
  public.app_kombax_showcase_finance_r65(uuid),public.app_kombax_event_finance_r65(uuid),public.app_kombax_event_ticket_sales_r65(uuid,integer),
  public.app_kombax_commerce_track_r65(text,uuid,uuid,uuid,uuid,text,integer,jsonb),
  public.app_kombax_showcase_bi_r65(uuid,integer),public.app_kombax_event_bi_r65(uuid,integer),
  public.app_kombax_event_checkin_history_r65(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid)
from public;

commit;
