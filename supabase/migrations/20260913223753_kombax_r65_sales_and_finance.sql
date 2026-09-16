-- KOMBAX R65 live-aligned migration · 20260913223753_kombax_r65_sales_and_finance
-- This file matches a migration version already recorded in the live Supabase project.
begin;
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
commit;
