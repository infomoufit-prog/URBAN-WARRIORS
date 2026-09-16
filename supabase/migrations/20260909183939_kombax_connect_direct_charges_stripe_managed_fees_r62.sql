-- KOMBAX R62 · Stripe Connect SaaS: cargos directos y tarifas gestionadas por Stripe.
-- La cuenta conectada cobra a su cliente, recibe los fondos y asume tarifas, reembolsos
-- y disputas. KOMBAX no crea destination charges ni activa application fees.

begin;

alter table kombax_payments.connected_accounts
  add column if not exists charge_model text,
  add column if not exists stripe_fees_payer text,
  add column if not exists losses_responsibility text,
  add column if not exists stripe_dashboard_type text,
  add column if not exists configuration_compatible boolean;

-- Las cuentas creadas por R61 tenían la configuración marketplace anterior. No se
-- reutilizan silenciosamente porque Stripe fija estas responsabilidades al crearlas.
update kombax_payments.connected_accounts
set charge_model=coalesce(charge_model,'legacy_destination'),
    stripe_fees_payer=coalesce(stripe_fees_payer,'application'),
    losses_responsibility=coalesce(losses_responsibility,'application'),
    stripe_dashboard_type=coalesce(stripe_dashboard_type,'express'),
    configuration_compatible=coalesce(configuration_compatible,false),
    status=case when configuration_compatible is null then 'action_required' else status end,
    charges_enabled=case when configuration_compatible is null then false else charges_enabled end,
    updated_at=now();

alter table kombax_payments.connected_accounts
  alter column charge_model set default 'direct',
  alter column stripe_fees_payer set default 'account',
  alter column losses_responsibility set default 'stripe',
  alter column stripe_dashboard_type set default 'full',
  alter column configuration_compatible set default true;
alter table kombax_payments.connected_accounts
  alter column charge_model set not null,
  alter column stripe_fees_payer set not null,
  alter column losses_responsibility set not null,
  alter column stripe_dashboard_type set not null,
  alter column configuration_compatible set not null;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_direct_model_r62 check(charge_model in('direct','legacy_destination')),
  add constraint connected_accounts_fee_payer_r62 check(stripe_fees_payer in('account','application')),
  add constraint connected_accounts_losses_r62 check(losses_responsibility in('stripe','application')),
  add constraint connected_accounts_dashboard_r62 check(stripe_dashboard_type in('full','express')),
  add constraint connected_accounts_compatible_r62 check(not configuration_compatible or
    (charge_model='direct' and stripe_fees_payer='account' and losses_responsibility='stripe' and stripe_dashboard_type='full'));

-- Customers y métodos guardados pertenecen a cada cuenta conectada en cargos directos.
alter table kombax_payments.customers
  add column if not exists connected_account_id uuid references kombax_payments.connected_accounts(id) on delete restrict;
update kombax_payments.customers c set connected_account_id=a.id
from kombax_payments.payment_authorizations p
join kombax_payments.connected_accounts a on a.subject_type='club' and a.club_id=p.club_id
where p.user_id=c.user_id and p.stripe_customer_id=c.stripe_customer_id and c.connected_account_id is null;
alter table kombax_payments.customers drop constraint if exists customers_user_id_key;
create unique index if not exists uq_connect_customer_account_user_r62
  on kombax_payments.customers(connected_account_id,user_id) where connected_account_id is not null;

alter table kombax_payments.payment_authorizations
  add column if not exists connected_account_id uuid references kombax_payments.connected_accounts(id) on delete restrict;
update kombax_payments.payment_authorizations p set connected_account_id=a.id
from kombax_payments.connected_accounts a where a.subject_type='club' and a.club_id=p.club_id and p.connected_account_id is null;
create index if not exists idx_payment_authorization_account_r62
  on kombax_payments.payment_authorizations(connected_account_id,user_id,active);

-- R62 no permite comisiones por transacción. Una futura monetización requiere otra
-- migración y aprobación explícita, separada de las suscripciones SaaS de Billing.
update kombax_payments.platform_fee_rules set active=false where active;
alter table kombax_payments.platform_fee_rules
  add constraint platform_transaction_fees_disabled_r62
  check(not active and percentage=0 and fixed_amount_minor=0);
alter table kombax_payments.payment_attempts
  add constraint payment_attempt_platform_fee_zero_r62 check(platform_fee_minor=0);

create or replace function kombax_payments.resolve_fee_minor(p_scope text,p_amount_minor integer,p_subject_type text,p_subject_id uuid)
returns integer language sql stable security definer set search_path='' as $$ select 0; $$;

create or replace function public.app_stripe_connect_status_v259(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_ok boolean:=false;v_row kombax_payments.connected_accounts;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=v_uid and m.activo and m.rol in('direccion','secretaria','economia'));
  elsif p_subject_type='showcase_provider' then v_ok:=kombax_payments.can_manage_provider(v_uid,p_subject_id); end if;
  if not v_ok then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_row from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  if not found then return jsonb_build_object('status','not_configured','charges_enabled',false,'payouts_enabled',false,'details_submitted',false,
    'charge_model','direct','stripe_fees_payer','account','losses_responsibility','stripe','configuration_compatible',true); end if;
  return jsonb_build_object('status',v_row.status,'charges_enabled',v_row.charges_enabled,'payouts_enabled',v_row.payouts_enabled,
    'details_submitted',v_row.details_submitted,'requirements_due',v_row.requirements_due,'updated_at',v_row.updated_at,
    'charge_model',v_row.charge_model,'stripe_fees_payer',v_row.stripe_fees_payer,'losses_responsibility',v_row.losses_responsibility,
    'stripe_dashboard_type',v_row.stripe_dashboard_type,'configuration_compatible',v_row.configuration_compatible);
end $$;

create or replace function public.app_stripe_connect_prepare_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_ok boolean:=false;v_name text;v_email text;v_account kombax_payments.connected_accounts;
begin
  if p_actor_id is null then raise exception 'ACTOR_REQUIRED'; end if;
  if p_subject_type='club' then
    select exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol='direccion'),c.nombre,c.email
      into v_ok,v_name,v_email from public.clubes c where c.id=p_subject_id;
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
    select m.nombre,null into v_name,v_email from public.kombax_showcase_marcas m where m.id=p_subject_id;
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'display_name',v_name,'email',v_email,
    'stripe_account_id',v_account.stripe_account_id,'status',coalesce(v_account.status,'not_configured'),
    'configuration_compatible',coalesce(v_account.configuration_compatible,true),'charge_model',coalesce(v_account.charge_model,'direct'));
end $$;

create or replace function public.app_stripe_connect_attach_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_stripe_account_id text)
returns void language plpgsql security definer set search_path='' as $$
begin
  insert into kombax_payments.connected_accounts(subject_type,subject_id,club_id,showcase_provider_id,stripe_account_id,created_by,
    charge_model,stripe_fees_payer,losses_responsibility,stripe_dashboard_type,configuration_compatible)
  values(p_subject_type,p_subject_id,case when p_subject_type='club' then p_subject_id end,
    case when p_subject_type='showcase_provider' then p_subject_id end,p_stripe_account_id,p_actor_id,'direct','account','stripe','full',true)
  on conflict(subject_type,subject_id) do update set stripe_account_id=excluded.stripe_account_id,charge_model='direct',
    stripe_fees_payer='account',losses_responsibility='stripe',stripe_dashboard_type='full',configuration_compatible=true,updated_at=now();
end $$;

-- Verifica que los eventos de cargos directos proceden de la misma cuenta conectada
-- asociada al intento antes de delegar en el ledger idempotente de R61.
create or replace function public.app_stripe_event_apply_v260(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_obj jsonb:=p_event#>'{data,object}';v_attempt_id uuid;v_payment_intent text;v_expected text;v_actual text:=p_event->>'account';
begin
  if coalesce(v_actual,'')='' and p_event->>'type'<>'account.updated' then raise exception 'CONNECTED_ACCOUNT_EVENT_REQUIRED'; end if;
  if coalesce(v_obj#>>'{metadata,attempt_id}','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_attempt_id:=(v_obj#>>'{metadata,attempt_id}')::uuid;
  end if;
  v_payment_intent:=case when p_event->>'type' like 'payment_intent.%' then v_obj->>'id' else v_obj->>'payment_intent' end;
  select a.stripe_account_id into v_expected
  from kombax_payments.payment_attempts p join kombax_payments.connected_accounts a on a.id=p.connected_account_id
  where (v_attempt_id is not null and p.id=v_attempt_id) or (v_payment_intent is not null and p.stripe_payment_intent_id=v_payment_intent)
  order by p.created_at desc limit 1;
  if v_expected is not null and v_actual is distinct from v_expected then raise exception 'STRIPE_CONNECTED_ACCOUNT_MISMATCH'; end if;
  return public.app_stripe_event_apply_v259(p_event);
end $$;

revoke all on function public.app_stripe_event_apply_v260(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_event_apply_v260(jsonb) to service_role;

notify pgrst,'reload schema';
commit;
