do $$
begin
  if exists(select 1 from kombax_payments.connected_accounts where status='active' and not configuration_compatible) then
    raise exception 'INCOMPATIBLE_CONNECT_ACCOUNT_ACTIVE';
  end if;
  if exists(select 1 from kombax_payments.connected_accounts where configuration_compatible and
    (charge_model<>'direct' or stripe_fees_payer<>'account' or losses_responsibility<>'stripe' or stripe_dashboard_type<>'full')) then
    raise exception 'CONNECT_RESPONSIBILITY_CONFIGURATION_INVALID';
  end if;
  if exists(select 1 from kombax_payments.platform_fee_rules where active or percentage<>0 or fixed_amount_minor<>0) then
    raise exception 'PLATFORM_TRANSACTION_FEE_ENABLED';
  end if;
  if exists(select 1 from kombax_payments.payment_attempts where platform_fee_minor<>0) then
    raise exception 'NONZERO_PLATFORM_FEE_ATTEMPT';
  end if;
  if has_function_privilege('anon','public.app_stripe_event_apply_v260(jsonb)','EXECUTE') or
     has_function_privilege('authenticated','public.app_stripe_event_apply_v260(jsonb)','EXECUTE') then
    raise exception 'WEBHOOK_APPLIER_EXPOSED';
  end if;
end $$;

select 'KOMBAX R62 Connect direct charges: PASS' as result;
