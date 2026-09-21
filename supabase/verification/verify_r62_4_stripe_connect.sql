-- Ejecutar DESPUÉS de aplicar 20260910175619_kombax_stripe_connect_hardening_federation_r62_4.sql
-- en el proyecto de TEST. Sólo verifica; no modifica datos.
do $$
begin
  if not exists(select 1 from information_schema.columns where table_schema='kombax_payments' and table_name='connected_accounts' and column_name='federation_profile_id') then
    raise exception 'R624_FEDERATION_ACCOUNT_COLUMN_MISSING';
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='kombax_payments' and table_name='connected_accounts' and column_name='requirements_pending_verification') then
    raise exception 'R624_REQUIREMENTS_PENDING_COLUMN_MISSING';
  end if;
  if exists(select 1 from kombax_payments.connected_accounts a left join public.perfiles_kombax_directos d on d.id=a.federation_profile_id
    where a.subject_type='federation' and (a.federation_profile_id is distinct from a.subject_id or d.id is null or d.tipo<>'federacion')) then
    raise exception 'R624_FEDERATION_SUBJECT_MAPPING_INVALID';
  end if;
  if exists(select 1 from kombax_payments.connected_accounts where
    (subject_type='club' and (club_id is distinct from subject_id or showcase_provider_id is not null or federation_profile_id is not null)) or
    (subject_type='showcase_provider' and (showcase_provider_id is distinct from subject_id or club_id is not null or federation_profile_id is not null)) or
    (subject_type='federation' and (federation_profile_id is distinct from subject_id or club_id is not null or showcase_provider_id is not null))) then
    raise exception 'R624_CROSS_ENTITY_MAPPING_INVALID';
  end if;
  if exists(select stripe_account_id from kombax_payments.connected_accounts group by stripe_account_id having count(*)>1) then
    raise exception 'R624_STRIPE_ACCOUNT_REUSED_ACROSS_ENTITIES';
  end if;
  if exists(select 1 from kombax_payments.connected_accounts where configuration_compatible and
    (charge_model<>'direct' or stripe_fees_payer<>'account' or losses_responsibility<>'stripe' or stripe_dashboard_type<>'full')) then
    raise exception 'R624_CONNECT_RESPONSIBILITY_CONFIGURATION_INVALID';
  end if;
  if exists(select 1 from kombax_payments.connected_accounts where status='active' and (not charges_enabled or not payouts_enabled or not configuration_compatible)) then
    raise exception 'R624_ACTIVE_ACCOUNT_NOT_READY';
  end if;
  if exists(select 1 from kombax_payments.platform_fee_rules where active or percentage<>0 or fixed_amount_minor<>0) then
    raise exception 'R624_PLATFORM_TRANSACTION_FEE_ENABLED';
  end if;
  if exists(select 1 from kombax_payments.payment_attempts where platform_fee_minor<>0) then
    raise exception 'R624_NONZERO_PLATFORM_FEE_ATTEMPT';
  end if;
  if has_function_privilege('anon','public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean)','EXECUTE') or
     has_function_privilege('authenticated','public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean)','EXECUTE') or
     has_function_privilege('anon','public.app_stripe_connect_sync_internal_v261(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text)','EXECUTE') or
     has_function_privilege('authenticated','public.app_stripe_connect_sync_internal_v261(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text)','EXECUTE') then
    raise exception 'R624_INTERNAL_CONNECT_RPC_EXPOSED';
  end if;
end $$;

select 'KOMBAX R62.4 Stripe Connect hardening: PASS' as result;
