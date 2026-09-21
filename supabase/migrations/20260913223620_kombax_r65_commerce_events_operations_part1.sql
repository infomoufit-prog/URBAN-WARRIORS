-- KOMBAX R65 live-aligned migration · 20260913223620_kombax_r65_commerce_events_operations_part1
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- KOMBAX 20.116 R65 · Commerce + Events Operations
-- Phases 1–9: money flow, seller operations, finance, refunds, communications,
-- Events finance/refunds, Enterprise BI and financial QA hardening.
-- IMPORTANT: KOMBAX SaaS Billing is intentionally NOT activated here.

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

commit;
