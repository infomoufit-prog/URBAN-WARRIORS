-- KOMBAX R87 · event finance subject context for transversal Finance center
begin;

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
  return jsonb_build_object(
    'currency','EUR','gross_minor',v_gross,'seller_refunds_minor',v_refunds,
    'buyer_refunds_minor',(select coalesce(sum(r.amount_succeeded_minor),0) from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id and r.status='succeeded'),
    'platform_fee_minor',v_fee,'estimated_organizer_net_before_stripe_minor',greatest(0,v_gross-v_refunds-v_fee),'orders',v_orders,'plan_code',v_plan,
    'seller_subject_type',v_seller->>'subject_type','seller_subject_id',v_seller->>'subject_id','seller_name',v_seller->>'seller_name',
    'refunds_pending',(select count(*) from kombax_payments.event_ticket_orders where event_id=p_event_id and refund_state in('refund_pending','refund_processing','refund_failed','manual_review')),
    'note','El neto es estimado antes de las tarifas de procesamiento de Stripe; saldo y payouts se consultan directamente a Stripe.','recent_refunds',
    (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select r.id,r.event_ticket_order_id,r.amount_succeeded_minor,r.status,r.reason,r.created_at,r.completed_at from kombax_payments.commerce_refunds_r65 r join kombax_payments.event_ticket_orders o on o.id=r.event_ticket_order_id where o.event_id=p_event_id order by r.created_at desc limit 30)x)
  );
end $$;
revoke all on function public.app_kombax_event_finance_r65(uuid) from public,anon;
grant execute on function public.app_kombax_event_finance_r65(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
