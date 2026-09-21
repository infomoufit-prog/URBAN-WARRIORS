do $$
begin
  if to_regclass('kombax_payments.connected_accounts') is null then raise exception 'CONNECTED_ACCOUNTS_MISSING'; end if;
  if to_regclass('kombax_payments.payment_attempts') is null then raise exception 'PAYMENT_ATTEMPTS_MISSING'; end if;
  if to_regclass('kombax_payments.webhook_events') is null then raise exception 'WEBHOOK_EVENTS_MISSING'; end if;
  if to_regclass('kombax_payments.showcase_orders') is null then raise exception 'SHOWCASE_ORDERS_MISSING'; end if;
  if to_regprocedure('public.app_stripe_event_apply_v259(jsonb)') is null then raise exception 'WEBHOOK_APPLIER_MISSING'; end if;
  if to_regprocedure('public.app_showcase_order_mutate_v259(text,jsonb,uuid)') is null then raise exception 'ORDER_API_MISSING'; end if;
  if has_function_privilege('anon','public.app_stripe_event_apply_v259(jsonb)','EXECUTE') then raise exception 'WEBHOOK_APPLIER_EXPOSED'; end if;
  if has_function_privilege('authenticated','public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid)','EXECUTE') then raise exception 'CHECKOUT_INTERNAL_EXPOSED'; end if;
  if exists(select 1 from kombax_payments.platform_fee_rules where percentage<>0 or fixed_amount_minor<>0) then raise exception 'UNAPPROVED_PLATFORM_FEE_CONFIGURED'; end if;
  if exists(select 1 from public.kombax_showcase_elementos where commerce_enabled and precio_venta is null) then raise exception 'COMMERCE_PRODUCT_WITHOUT_PRICE'; end if;
end $$;

select 'KOMBAX R61 payments verification: PASS' as result;
