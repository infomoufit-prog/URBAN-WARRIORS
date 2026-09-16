-- KOMBAX R62.5 · verification only. Run AFTER the R62.5 migration in TEST.
-- No writes. Raises an exception if a required commerce/ticketing invariant is missing.
do $$
declare v_rls boolean;v_count integer;
begin
  if to_regclass('kombax_payments.event_ticket_orders') is null
     or to_regclass('kombax_payments.event_tickets') is null
     or to_regclass('kombax_payments.event_ticket_order_history') is null then
    raise exception 'R625_EVENT_TICKETING_TABLES_MISSING';
  end if;

  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_eventos_publicos' and column_name='ticketing_mode')
     or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_eventos_publicos' and column_name='ticket_price_minor')
     or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_eventos_publicos' and column_name='ticket_capacity') then
    raise exception 'R625_EVENT_TICKETING_COLUMNS_MISSING';
  end if;

  if not exists(select 1 from pg_constraint where conrelid='kombax_payments.connected_accounts'::regclass and conname='connected_accounts_subject_type_check' and pg_get_constraintdef(oid) like '%event_organizer%') then
    raise exception 'R625_EVENT_ORGANIZER_CONNECT_SUBJECT_MISSING';
  end if;

  if exists(select 1 from kombax_payments.connected_accounts where configuration_compatible and (charge_model<>'direct' or stripe_fees_payer<>'account' or losses_responsibility<>'stripe')) then
    raise exception 'R625_CONNECT_DIRECT_CHARGE_INVARIANT_BROKEN';
  end if;

  if exists(select stripe_account_id from kombax_payments.connected_accounts group by stripe_account_id having count(*)>1) then
    raise exception 'R625_STRIPE_ACCOUNT_REUSED_ACROSS_ENTITIES';
  end if;

  if exists(select 1 from kombax_payments.payment_attempts where kind in('showcase_order','event_ticket') and platform_fee_minor<>0) then
    raise exception 'R625_PLATFORM_TRANSACTION_FEE_MUST_BE_ZERO';
  end if;

  select relrowsecurity into v_rls from pg_class where oid='kombax_payments.event_ticket_orders'::regclass;if not v_rls then raise exception 'R625_TICKET_ORDERS_RLS_DISABLED';end if;
  select relrowsecurity into v_rls from pg_class where oid='kombax_payments.event_tickets'::regclass;if not v_rls then raise exception 'R625_TICKETS_RLS_DISABLED';end if;

  if has_table_privilege('anon','kombax_payments.event_ticket_orders','select') or has_table_privilege('authenticated','kombax_payments.event_ticket_orders','select') then
    raise exception 'R625_TICKET_TABLE_DIRECT_ACCESS_EXPOSED';
  end if;

  if to_regprocedure('public.app_kombax_event_ticketing_public_r625(uuid[])') is null
     or to_regprocedure('public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid)') is null
     or to_regprocedure('public.app_kombax_my_event_tickets_r625(integer)') is null
     or to_regprocedure('public.app_kombax_event_ticket_sales_r625(uuid,integer)') is null then
    raise exception 'R625_EVENT_TICKETING_RPC_MISSING';
  end if;

  if not has_function_privilege('authenticated','public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid)','execute') then
    raise exception 'R625_EVENT_TICKETING_MANAGE_GRANT_MISSING';
  end if;
  if has_function_privilege('anon','public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid)','execute') then
    raise exception 'R625_EVENT_TICKETING_MANAGE_EXPOSED_TO_ANON';
  end if;

  if exists(select 1 from kombax_payments.event_ticket_orders where quantity<1 or quantity>20 or amount_total_minor<=0) then
    raise exception 'R625_INVALID_TICKET_ORDER';
  end if;
  if exists(select 1 from kombax_payments.event_ticket_orders o where o.status='paid' and (select count(*) from kombax_payments.event_tickets t where t.order_id=o.id)<>o.quantity) then
    raise exception 'R625_PAID_ORDER_TICKET_COUNT_MISMATCH';
  end if;
end $$;

select 'KOMBAX R62.5 SHOWCASE + EVENTS TICKETING VERIFY: PASS' as result;
