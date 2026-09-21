-- KOMBAX R62.5.1 · Pilot stabilization verification
-- Read-only verification after remote migrations 20260910175619..20260910180842.
do $$
begin
  if to_regclass('kombax_payments.event_ticket_orders') is null
    or to_regclass('kombax_payments.event_tickets') is null
    or to_regclass('kombax_payments.event_ticket_order_history') is null then
    raise exception 'R6251_TICKETING_TABLES_MISSING';
  end if;

  if not exists(select 1 from pg_indexes where schemaname='kombax_payments' and indexname='idx_payment_attempts_event_ticket_order_r625') then
    raise exception 'R6251_PAYMENT_ATTEMPT_TICKET_INDEX_MISSING';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='kombax_payments' and indexname='idx_event_ticket_history_actor_r625') then
    raise exception 'R6251_TICKET_HISTORY_ACTOR_INDEX_MISSING';
  end if;

  if exists(
    select 1 from kombax_payments.connected_accounts
    where configuration_compatible
      and (charge_model<>'direct' or stripe_fees_payer<>'account' or losses_responsibility<>'stripe')
  ) then raise exception 'R6251_DIRECT_CHARGE_INVARIANT_BROKEN'; end if;

  if exists(
    select 1 from kombax_payments.payment_attempts
    where kind in('showcase_order','event_ticket') and platform_fee_minor<>0
  ) then raise exception 'R6251_PLATFORM_TRANSACTION_FEE_NONZERO'; end if;

  if exists(
    select stripe_account_id from kombax_payments.connected_accounts
    group by stripe_account_id having count(*)>1
  ) then raise exception 'R6251_CONNECTED_ACCOUNT_REUSED'; end if;

  if has_table_privilege('anon','kombax_payments.event_ticket_orders','select')
     or has_table_privilege('authenticated','kombax_payments.event_ticket_orders','select')
     or has_table_privilege('anon','kombax_payments.event_tickets','select')
     or has_table_privilege('authenticated','kombax_payments.event_tickets','select') then
    raise exception 'R6251_DIRECT_TICKETING_ACCESS_EXPOSED';
  end if;

  if not exists(select 1 from pg_class where oid='kombax_payments.event_ticket_orders'::regclass and relrowsecurity)
     or not exists(select 1 from pg_class where oid='kombax_payments.event_tickets'::regclass and relrowsecurity) then
    raise exception 'R6251_TICKETING_RLS_DISABLED';
  end if;

  if to_regprocedure('public.app_kombax_evento_entradas_estado_v173(uuid)') is null
     or to_regprocedure('public.app_kombax_event_ticketing_public_r625(uuid[])') is null
     or to_regprocedure('public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid)') is null
     or to_regprocedure('public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid)') is null then
    raise exception 'R6251_REQUIRED_RPC_MISSING';
  end if;
end $$;
select 'KOMBAX R62.5.1 PILOT STABILIZATION VERIFY: PASS' as result;
