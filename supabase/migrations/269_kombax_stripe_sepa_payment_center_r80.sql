-- KOMBAX R80 · Stripe Connect universal payment center + SEPA Direct Debit
-- Additive migration. Preserves Direct Charges and the existing card checkout flows.

alter type public.estado_cuota add value if not exists 'disputada';

begin;

alter table kombax_payments.connected_accounts
  add column if not exists card_payments_status text not null default 'inactive',
  add column if not exists sepa_debit_payments_status text not null default 'inactive',
  add column if not exists payouts_status text not null default 'inactive';

update kombax_payments.connected_accounts
set card_payments_status=case when charges_enabled then 'active' else coalesce(nullif(card_payments_status,''),'inactive') end,
    payouts_status=case when payouts_enabled then 'active' else coalesce(nullif(payouts_status,''),'inactive') end
where true;

create table if not exists kombax_payments.payment_method_preferences_r80(
  subject_type text not null check(subject_type in('club','showcase_provider','federation','event_organizer')),
  subject_id uuid not null,
  card_enabled boolean not null default true,
  sepa_enabled boolean not null default false,
  updated_by uuid references public.perfiles(id) on delete restrict,
  updated_at timestamptz not null default now(),
  primary key(subject_type,subject_id)
);

insert into kombax_payments.payment_method_preferences_r80(subject_type,subject_id,card_enabled,sepa_enabled)
select subject_type,subject_id,true,false from kombax_payments.connected_accounts
on conflict(subject_type,subject_id) do nothing;

create table if not exists kombax_payments.connected_customers_r80(
  id uuid primary key default gen_random_uuid(),
  connected_account_id uuid not null references kombax_payments.connected_accounts(id) on delete restrict,
  payer_user_id uuid not null references public.perfiles(id) on delete restrict,
  stripe_customer_id text not null check(stripe_customer_id ~ '^cus_'),
  payer_email text,
  payer_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(connected_account_id,payer_user_id),
  unique(connected_account_id,stripe_customer_id)
);

create table if not exists kombax_payments.sepa_mandates_r80(
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check(subject_type in('club','showcase_provider','federation','event_organizer')),
  subject_id uuid not null,
  connected_account_id uuid not null references kombax_payments.connected_accounts(id) on delete restrict,
  payer_user_id uuid not null references public.perfiles(id) on delete restrict,
  club_id uuid references public.clubes(id) on delete restrict,
  socio_id uuid,
  stripe_customer_id text not null check(stripe_customer_id ~ '^cus_'),
  stripe_payment_method_id text not null check(stripe_payment_method_id ~ '^pm_'),
  stripe_mandate_id text,
  last4 text check(last4 is null or last4 ~ '^[0-9A-Za-z]{2,8}$'),
  holder_name text,
  status text not null default 'pending' check(status in('pending','active','inactive','revoked','failed')),
  consent_version text not null default 'KOMBAX-SEPA-R80-1',
  consent_text text not null default 'Autorizo los adeudos SEPA correspondientes a los servicios contratados con la entidad cobradora identificada en Stripe.',
  consented_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete restrict
);
create unique index if not exists uq_sepa_mandate_active_r80
  on kombax_payments.sepa_mandates_r80(connected_account_id,payer_user_id,club_id,socio_id)
  where status='active';
create index if not exists idx_sepa_mandate_subject_r80 on kombax_payments.sepa_mandates_r80(subject_type,subject_id,status,updated_at desc);
create index if not exists idx_sepa_mandate_pm_r80 on kombax_payments.sepa_mandates_r80(stripe_payment_method_id);
create index if not exists idx_sepa_mandate_stripe_r80 on kombax_payments.sepa_mandates_r80(stripe_mandate_id) where stripe_mandate_id is not null;

alter table kombax_payments.payment_method_preferences_r80 enable row level security;
alter table kombax_payments.connected_customers_r80 enable row level security;
alter table kombax_payments.sepa_mandates_r80 enable row level security;
revoke all on kombax_payments.payment_method_preferences_r80,kombax_payments.connected_customers_r80,kombax_payments.sepa_mandates_r80 from public,anon,authenticated;
grant all on kombax_payments.payment_method_preferences_r80,kombax_payments.connected_customers_r80,kombax_payments.sepa_mandates_r80 to service_role;

-- Extend manual/validated payment storage to identify SEPA explicitly.
alter table public.pagos drop constraint if exists pagos_metodo_check;
alter table public.pagos add constraint pagos_metodo_check check(metodo in('transferencia','bizum','efectivo','tarjeta','sepa','otro')) not valid;
alter table public.pagos validate constraint pagos_metodo_check;

create or replace function kombax_payments.can_access_subject_r80(p_actor uuid,p_subject_type text,p_subject_id uuid,p_manage boolean default false)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  if p_actor is null or p_subject_id is null then return false; end if;
  if p_subject_type='club' then
    return exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor and m.activo and m.rol in('direccion','secretaria','economia') and (not p_manage or m.rol='direccion'));
  elsif p_subject_type='showcase_provider' then
    return kombax_payments.can_manage_provider(p_actor,p_subject_id);
  elsif p_subject_type='federation' then
    return case when p_manage then kombax_payments.can_manage_federation_connect_r624(p_actor,p_subject_id) else kombax_payments.can_view_federation_connect_r624(p_actor,p_subject_id) end;
  elsif p_subject_type='event_organizer' then
    return kombax_payments.can_manage_event_organizer_connect_r625(p_actor,p_subject_id);
  end if;
  return false;
end $$;

create or replace function public.app_stripe_payment_methods_status_r80(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_uid uuid:=(select auth.uid());v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;
  v_use_cases jsonb:='[]'::jsonb;v_active_mandates int:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not kombax_payments.can_access_subject_r80(v_uid,p_subject_type,p_subject_id,false) then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type=p_subject_type and p.subject_id=p_subject_id;
  if p_subject_type='club' then v_use_cases:='["club_fees_card","club_fees_sepa"]'::jsonb;
  elsif p_subject_type='showcase_provider' then v_use_cases:='["showcase_card"]'::jsonb;
  elsif p_subject_type='event_organizer' then v_use_cases:='["event_ticketing_card"]'::jsonb;
  elsif p_subject_type='federation' then v_use_cases:='["federation_card","federation_recurring_sepa"]'::jsonb; end if;
  if v_account.id is not null then
    select count(*) into v_active_mandates from kombax_payments.sepa_mandates_r80 m where m.connected_account_id=v_account.id and m.status='active';
  end if;
  return jsonb_build_object(
    'subject_type',p_subject_type,'subject_id',p_subject_id,
    'status',coalesce(v_account.status,'not_configured'),'stripe_account_connected',v_account.id is not null,
    'details_submitted',coalesce(v_account.details_submitted,false),'charges_enabled',coalesce(v_account.charges_enabled,false),'payouts_enabled',coalesce(v_account.payouts_enabled,false),
    'card_enabled',coalesce(v_pref.card_enabled,true),'sepa_enabled',coalesce(v_pref.sepa_enabled,false),
    'card_capability_status',coalesce(v_account.card_payments_status,case when v_account.charges_enabled then 'active' else 'inactive' end,'inactive'),
    'sepa_capability_status',coalesce(v_account.sepa_debit_payments_status,'inactive'),'payouts_status',coalesce(v_account.payouts_status,case when v_account.payouts_enabled then 'active' else 'inactive' end,'inactive'),
    'requirements_due',coalesce(v_account.requirements_due,'[]'::jsonb),'requirements_eventually_due',coalesce(v_account.requirements_eventually_due,'[]'::jsonb),
    'requirements_pending_verification',coalesce(v_account.requirements_pending_verification,'[]'::jsonb),'disabled_reason',v_account.disabled_reason,
    'active_mandates',v_active_mandates,'use_cases',v_use_cases,
    'direct_charges',true,'immediate_checkout_method','card','sepa_delayed_notification',true
  );
end $$;
revoke all on function public.app_stripe_payment_methods_status_r80(text,uuid) from public,anon;
grant execute on function public.app_stripe_payment_methods_status_r80(text,uuid) to authenticated;

create or replace function public.app_stripe_payment_method_toggle_r80(p_subject_type text,p_subject_id uuid,p_method text,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_row kombax_payments.payment_method_preferences_r80;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_method not in('card','sepa') then raise exception 'PAYMENT_METHOD_INVALID'; end if;
  if p_method='sepa' and p_enabled and p_subject_type not in('club','federation') then raise exception 'SEPA_NOT_AVAILABLE_FOR_SERVICE'; end if;
  if not kombax_payments.can_access_subject_r80(v_uid,p_subject_type,p_subject_id,true) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  insert into kombax_payments.payment_method_preferences_r80(subject_type,subject_id,card_enabled,sepa_enabled,updated_by)
  values(p_subject_type,p_subject_id,case when p_method='card' then p_enabled else true end,case when p_method='sepa' then p_enabled else false end,v_uid)
  on conflict(subject_type,subject_id) do update set
    card_enabled=case when p_method='card' then p_enabled else kombax_payments.payment_method_preferences_r80.card_enabled end,
    sepa_enabled=case when p_method='sepa' then p_enabled else kombax_payments.payment_method_preferences_r80.sepa_enabled end,
    updated_by=v_uid,updated_at=now()
  returning * into v_row;
  return jsonb_build_object('ok',true,'card_enabled',v_row.card_enabled,'sepa_enabled',v_row.sepa_enabled,'updated_at',v_row.updated_at);
end $$;
revoke all on function public.app_stripe_payment_method_toggle_r80(text,uuid,text,boolean) from public,anon;
grant execute on function public.app_stripe_payment_method_toggle_r80(text,uuid,text,boolean) to authenticated;

create or replace function public.app_stripe_payer_options_r80(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_uid uuid:=(select auth.uid());v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;
  v_mandates jsonb:='[]'::jsonb;v_authorized boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select exists(
    select 1 from public.socios s where s.club_id=p_club_id and s.perfil_id=v_uid
    union all
    select 1 from public.tutores_socios t where t.club_id=p_club_id and t.tutor_perfil_id=v_uid
  ) into v_authorized;
  if not v_authorized then raise exception 'PAYER_ACCESS_DENIED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type='club' and a.subject_id=p_club_id;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type='club' and p.subject_id=p_club_id;
  if v_account.id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('socio_id',m.socio_id,'last4',m.last4,'status',m.status) order by m.updated_at desc),'[]'::jsonb)
      into v_mandates
      from kombax_payments.sepa_mandates_r80 m
      where m.connected_account_id=v_account.id and m.payer_user_id=v_uid and m.status='active';
  end if;
  return jsonb_build_object(
    'card_available',coalesce(v_account.status='active' and v_account.payouts_enabled and coalesce(v_pref.card_enabled,true) and coalesce(v_account.card_payments_status,case when v_account.charges_enabled then 'active' end,'inactive')='active',false),
    'sepa_available',coalesce(v_account.status='active' and v_account.payouts_enabled and coalesce(v_pref.sepa_enabled,false) and coalesce(v_account.sepa_debit_payments_status,'inactive')='active',false),
    'mandates',coalesce(v_mandates,'[]'::jsonb)
  );
end $$;
revoke all on function public.app_stripe_payer_options_r80(uuid) from public,anon;
grant execute on function public.app_stripe_payer_options_r80(uuid) to authenticated;

create or replace function public.app_stripe_connect_sync_internal_r80(
  p_stripe_account_id text,p_details_submitted boolean,p_charges_enabled boolean,p_payouts_enabled boolean,
  p_requirements_due jsonb,p_requirements_eventually_due jsonb,p_requirements_pending_verification jsonb,p_disabled_reason text,p_stripe_api_version text,
  p_card_payments_status text,p_sepa_debit_payments_status text,p_payouts_status text)
returns void language plpgsql security definer set search_path='' as $$
begin
  update kombax_payments.connected_accounts set
    details_submitted=coalesce(p_details_submitted,false),charges_enabled=coalesce(p_charges_enabled,false),payouts_enabled=coalesce(p_payouts_enabled,false),
    requirements_due=coalesce(p_requirements_due,'[]'::jsonb),requirements_eventually_due=coalesce(p_requirements_eventually_due,'[]'::jsonb),
    requirements_pending_verification=coalesce(p_requirements_pending_verification,'[]'::jsonb),disabled_reason=nullif(p_disabled_reason,''),
    stripe_api_version=nullif(p_stripe_api_version,''),card_payments_status=coalesce(nullif(p_card_payments_status,''),'inactive'),
    sepa_debit_payments_status=coalesce(nullif(p_sepa_debit_payments_status,''),'inactive'),payouts_status=coalesce(nullif(p_payouts_status,''),'inactive'),
    status=case when coalesce(p_charges_enabled,false) and coalesce(p_payouts_enabled,false) then 'active'
      when jsonb_array_length(coalesce(p_requirements_due,'[]'::jsonb))>0 then 'action_required'
      when coalesce(p_disabled_reason,'')<>'' then 'restricted'
      when coalesce(p_details_submitted,false) then 'verification_pending' else 'pending' end,
    last_synced_at=now(),updated_at=now()
  where stripe_account_id=p_stripe_account_id;
end $$;

create or replace function public.app_stripe_payment_method_gate_internal_r80(p_stripe_account_id text,p_method text,p_use_case text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;
begin
  select * into strict v_account from kombax_payments.connected_accounts a where a.stripe_account_id=p_stripe_account_id;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type=v_account.subject_type and p.subject_id=v_account.subject_id;
  if v_account.status<>'active' or not v_account.payouts_enabled then raise exception 'CONNECTED_ACCOUNT_NOT_READY'; end if;
  if p_method='card' then
    if not coalesce(v_pref.card_enabled,true) or coalesce(v_account.card_payments_status,case when v_account.charges_enabled then 'active' end,'inactive')<>'active' then raise exception 'CARD_PAYMENTS_DISABLED'; end if;
  elsif p_method='sepa' then
    if not coalesce(v_pref.sepa_enabled,false) or coalesce(v_account.sepa_debit_payments_status,'inactive')<>'active' then raise exception 'SEPA_PAYMENTS_DISABLED'; end if;
    if coalesce(p_use_case,'') in('showcase_checkout','event_ticketing') then raise exception 'SEPA_NOT_AVAILABLE_FOR_IMMEDIATE_CHECKOUT'; end if;
  else raise exception 'PAYMENT_METHOD_INVALID'; end if;
  return jsonb_build_object('ok',true,'subject_type',v_account.subject_type,'subject_id',v_account.subject_id,'account_id',v_account.id);
end $$;

create or replace function public.app_stripe_connected_customer_upsert_internal_r80(p_connected_account_id uuid,p_payer_user_id uuid,p_stripe_customer_id text,p_email text,p_name text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(p_stripe_customer_id,'') !~ '^cus_[A-Za-z0-9]+$' then raise exception 'STRIPE_CUSTOMER_INVALID'; end if;
  insert into kombax_payments.connected_customers_r80(connected_account_id,payer_user_id,stripe_customer_id,payer_email,payer_name)
  values(p_connected_account_id,p_payer_user_id,p_stripe_customer_id,nullif(p_email,''),nullif(p_name,''))
  on conflict(connected_account_id,payer_user_id) do update set stripe_customer_id=excluded.stripe_customer_id,payer_email=excluded.payer_email,payer_name=excluded.payer_name,updated_at=now();
end $$;

create or replace function public.app_stripe_sepa_setup_prepare_internal_r80(p_actor_id uuid,p_fee_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_fee public.cuotas;v_socio public.socios;v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;v_customer kombax_payments.connected_customers_r80;v_attempt kombax_payments.payment_attempts;v_email text;v_name text;
begin
  if p_actor_id is null or p_fee_id is null or p_request_id is null then raise exception 'SEPA_SETUP_INVALID'; end if;
  select * into strict v_fee from public.cuotas q where q.id=p_fee_id;
  select * into strict v_socio from public.socios s where s.club_id=v_fee.club_id and s.id=v_fee.socio_id;
  if not (v_socio.perfil_id=p_actor_id or exists(select 1 from public.tutores_socios t where t.club_id=v_fee.club_id and t.socio_id=v_fee.socio_id and t.tutor_perfil_id=p_actor_id)) then raise exception 'SEPA_MANDATE_PAYER_REQUIRED'; end if;
  select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type='club' and a.subject_id=v_fee.club_id and a.status='active' and a.payouts_enabled and a.configuration_compatible;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type='club' and p.subject_id=v_fee.club_id;
  if not coalesce(v_pref.sepa_enabled,false) or coalesce(v_account.sepa_debit_payments_status,'inactive')<>'active' then raise exception 'SEPA_PAYMENTS_DISABLED'; end if;
  select * into v_attempt from kombax_payments.payment_attempts a where a.actor_user_id=p_actor_id and a.request_id=p_request_id;
  if not found then
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,currency,metadata)
    values(p_request_id,'setup_method',p_actor_id,v_account.id,v_fee.club_id,v_fee.id,0,'EUR',jsonb_build_object('payment_method','sepa_debit','socio_id',v_fee.socio_id,'fee_id',v_fee.id)) returning * into v_attempt;
  end if;
  select * into v_customer from kombax_payments.connected_customers_r80 c where c.connected_account_id=v_account.id and c.payer_user_id=p_actor_id;
  select u.email into v_email from auth.users u where u.id=p_actor_id;
  select nullif(trim(concat_ws(' ',p.nombre,p.apellidos)),'') into v_name from public.perfiles p where p.id=p_actor_id;
  v_name:=coalesce(v_name,trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos)));
  return jsonb_build_object('attempt_id',v_attempt.id,'connected_account_id',v_account.id,'stripe_account_id',v_account.stripe_account_id,
    'stripe_customer_id',v_customer.stripe_customer_id,'payer_email',v_email,'payer_name',v_name,'club_id',v_fee.club_id,'socio_id',v_fee.socio_id,'fee_id',v_fee.id);
end $$;

create or replace function public.app_stripe_sepa_setup_finalize_internal_r80(
  p_attempt_id uuid,p_setup_intent_id text,p_stripe_customer_id text,p_payment_method_id text,p_mandate_id text,p_last4 text,p_holder_name text)
returns void language plpgsql security definer set search_path='' as $$
declare v_attempt kombax_payments.payment_attempts;v_subject uuid;
begin
  select * into strict v_attempt from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.kind='setup_method' for update;
  if coalesce(p_setup_intent_id,'') !~ '^seti_' or coalesce(p_payment_method_id,'') !~ '^pm_' or coalesce(p_stripe_customer_id,'') !~ '^cus_' then raise exception 'SEPA_SETUP_REFERENCE_INVALID'; end if;
  select subject_id into strict v_subject from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
  update kombax_payments.sepa_mandates_r80 set status='revoked',revoked_at=now(),updated_at=now()
    where connected_account_id=v_attempt.connected_account_id and payer_user_id=v_attempt.actor_user_id and club_id=v_attempt.club_id
      and socio_id=nullif(v_attempt.metadata->>'socio_id','')::uuid and status='active';
  insert into kombax_payments.sepa_mandates_r80(subject_type,subject_id,connected_account_id,payer_user_id,club_id,socio_id,stripe_customer_id,stripe_payment_method_id,stripe_mandate_id,last4,holder_name,status,consented_at)
  values('club',v_subject,v_attempt.connected_account_id,v_attempt.actor_user_id,v_attempt.club_id,nullif(v_attempt.metadata->>'socio_id','')::uuid,p_stripe_customer_id,p_payment_method_id,nullif(p_mandate_id,''),nullif(p_last4,''),nullif(p_holder_name,''),'active',now());
  update kombax_payments.payment_attempts set stripe_setup_intent_id=p_setup_intent_id,status='succeeded',updated_at=now() where id=v_attempt.id;
end $$;

create or replace function public.app_stripe_sepa_charge_prepare_internal_r80(p_actor_id uuid,p_fee_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_fee public.cuotas;v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;v_mandate kombax_payments.sepa_mandates_r80;v_attempt kombax_payments.payment_attempts;v_paid numeric:=0;v_amount int;
begin
  if p_actor_id is null or p_fee_id is null or p_request_id is null then raise exception 'SEPA_CHARGE_INVALID'; end if;
  select * into strict v_fee from public.cuotas q where q.id=p_fee_id for update;
  if not exists(select 1 from public.miembros_club m where m.club_id=v_fee.club_id and m.perfil_id=p_actor_id and m.activo and m.rol in('direccion','economia')) then raise exception 'FINANCE_MANAGER_REQUIRED'; end if;
  if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta','procesando') then raise exception 'FEE_NOT_PAYABLE'; end if;
  select coalesce(sum(p.importe),0) into v_paid from public.pagos p where p.club_id=v_fee.club_id and p.cuota_id=v_fee.id and p.estado_validacion='validado';
  v_amount:=greatest(0,round((v_fee.importe-v_paid)*100)::int);if v_amount<=0 then raise exception 'FEE_NOT_PAYABLE'; end if;
  select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type='club' and a.subject_id=v_fee.club_id and a.status='active' and a.payouts_enabled and a.configuration_compatible;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type='club' and p.subject_id=v_fee.club_id;
  if not coalesce(v_pref.sepa_enabled,false) or coalesce(v_account.sepa_debit_payments_status,'inactive')<>'active' then raise exception 'SEPA_PAYMENTS_DISABLED'; end if;
  select * into strict v_mandate from kombax_payments.sepa_mandates_r80 m where m.connected_account_id=v_account.id and m.club_id=v_fee.club_id and m.socio_id=v_fee.socio_id and m.status='active' order by m.updated_at desc limit 1;
  select * into v_attempt from kombax_payments.payment_attempts a where a.actor_user_id=p_actor_id and a.request_id=p_request_id;
  if not found then
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,currency,status,metadata)
    values(p_request_id,'club_fee',p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,'EUR','created',jsonb_build_object('payment_method','sepa_debit','mandate_id',v_mandate.id,'socio_id',v_fee.socio_id)) returning * into v_attempt;
  end if;
  update public.cuotas set estado='procesando',metodo_pago='sepa',actualizado_en=now() where id=v_fee.id;
  return jsonb_build_object('attempt_id',v_attempt.id,'amount_minor',v_amount,'currency','eur','stripe_account_id',v_account.stripe_account_id,
    'stripe_customer_id',v_mandate.stripe_customer_id,'stripe_payment_method_id',v_mandate.stripe_payment_method_id,'fee_id',v_fee.id,'club_id',v_fee.club_id);
end $$;

create or replace function public.app_stripe_payment_intent_attach_internal_r80(p_attempt_id uuid,p_payment_intent_id text,p_status text default 'processing')
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(p_payment_intent_id,'') !~ '^pi_' then raise exception 'PAYMENT_INTENT_INVALID'; end if;
  update kombax_payments.payment_attempts set stripe_payment_intent_id=p_payment_intent_id,status=case when p_status in('created','processing','succeeded','failed') then p_status else 'processing' end,updated_at=now() where id=p_attempt_id;
end $$;

create or replace function public.app_stripe_sepa_due_fees_r80(p_club_id uuid,p_limit integer default 50)
returns table(fee_id uuid,socio_id uuid,socio_name text,concept text,amount numeric,due_date date,mandate_last4 text,mandate_status text) language plpgsql stable security definer set search_path='' as $$
begin
  if not exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol in('direccion','economia','secretaria')) then raise exception 'FINANCE_ACCESS_DENIED'; end if;
  return query select q.id,q.socio_id,trim(concat_ws(' ',s.nombre,s.apellidos)),q.concepto,q.importe,q.vencimiento,m.last4,m.status
    from public.cuotas q join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
    join kombax_payments.connected_accounts a on a.subject_type='club' and a.subject_id=q.club_id
    join lateral(select sm.* from kombax_payments.sepa_mandates_r80 sm where sm.connected_account_id=a.id and sm.club_id=q.club_id and sm.socio_id=q.socio_id and sm.status='active' order by sm.updated_at desc limit 1)m on true
    where q.club_id=p_club_id and q.estado in('pendiente','vencida','parcialmente_pagada') order by q.vencimiento,q.id limit greatest(1,least(coalesce(p_limit,50),200));
end $$;
revoke all on function public.app_stripe_sepa_due_fees_r80(uuid,integer) from public,anon;
grant execute on function public.app_stripe_sepa_due_fees_r80(uuid,integer) to authenticated;

create or replace function public.app_stripe_sepa_summary_r80(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_account uuid;v_active int:=0;v_processing int:=0;v_failed int:=0;v_due int:=0;
begin
  if not exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol in('direccion','economia','secretaria')) then raise exception 'FINANCE_ACCESS_DENIED'; end if;
  select a.id into v_account from kombax_payments.connected_accounts a where a.subject_type='club' and a.subject_id=p_club_id;
  if v_account is not null then select count(*) into v_active from kombax_payments.sepa_mandates_r80 m where m.connected_account_id=v_account and m.status='active'; end if;
  select count(*) filter(where q.estado='procesando' and q.metodo_pago='sepa'),count(*) filter(where q.estado='fallida' and q.metodo_pago='sepa') into v_processing,v_failed from public.cuotas q where q.club_id=p_club_id;
  select count(*) into v_due from public.cuotas q where q.club_id=p_club_id and q.estado in('pendiente','vencida','parcialmente_pagada') and exists(select 1 from kombax_payments.sepa_mandates_r80 m where m.connected_account_id=v_account and m.club_id=q.club_id and m.socio_id=q.socio_id and m.status='active');
  return jsonb_build_object('active_mandates',v_active,'processing',v_processing,'failed',v_failed,'eligible_due',v_due);
end $$;
revoke all on function public.app_stripe_sepa_summary_r80(uuid) from public,anon;
grant execute on function public.app_stripe_sepa_summary_r80(uuid) to authenticated;

-- Reconcile all existing card logic first, then apply SEPA-specific state and method corrections.
create or replace function public.app_stripe_event_apply_v266(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_attempt kombax_payments.payment_attempts;v_attempt_id uuid;v_pi text;v_setup text;v_enrich jsonb;
begin
  v_result:=public.app_stripe_event_apply_v265(p_event);
  v_attempt_id:=nullif(v_obj#>>'{metadata,attempt_id}','')::uuid;
  v_pi:=case when v_type like 'payment_intent.%' then nullif(v_obj->>'id','') else nullif(v_obj->>'payment_intent','') end;
  if v_attempt_id is not null then select * into v_attempt from kombax_payments.payment_attempts a where a.id=v_attempt_id;
  elsif v_pi is not null then select * into v_attempt from kombax_payments.payment_attempts a where a.stripe_payment_intent_id=v_pi;
  end if;

  if v_type='setup_intent.succeeded' then
    v_setup:=v_obj->>'id';v_enrich:=coalesce(v_obj->'kombax_enrichment','{}'::jsonb);
    v_attempt_id:=nullif(v_obj#>>'{metadata,attempt_id}','')::uuid;
    if v_attempt_id is not null and coalesce(v_enrich->>'payment_method_id',v_obj->>'payment_method','') ~ '^pm_' then
      perform public.app_stripe_sepa_setup_finalize_internal_r80(v_attempt_id,v_setup,coalesce(v_enrich->>'customer_id',v_obj->>'customer'),coalesce(v_enrich->>'payment_method_id',v_obj->>'payment_method'),v_enrich->>'mandate_id',v_enrich->>'last4',v_enrich->>'holder_name');
    end if;
  elsif v_attempt.id is not null and coalesce(v_attempt.metadata->>'payment_method','')='sepa_debit' then
    if v_type='payment_intent.processing' then
      update kombax_payments.payment_attempts set status='processing',updated_at=now() where id=v_attempt.id;
      update public.cuotas set estado='procesando',metodo_pago='sepa',stripe_payment_intent_id=coalesce(v_obj->>'id',stripe_payment_intent_id),actualizado_en=now() where id=v_attempt.cuota_id;
    elsif v_type='payment_intent.succeeded' then
      update public.cuotas set estado='pagada',metodo_pago='sepa',stripe_payment_intent_id=coalesce(v_obj->>'id',stripe_payment_intent_id),pagada_en=coalesce(pagada_en,now()),ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
      update public.pagos set metodo='sepa',observaciones='Stripe SEPA · webhook '||coalesce(v_obj->>'id',referencia) where cuota_id=v_attempt.cuota_id and referencia=coalesce(v_obj->>'id',referencia);
    elsif v_type='payment_intent.payment_failed' then
      update public.cuotas set estado='fallida',metodo_pago='sepa',ultimo_fallo=coalesce(v_obj#>>'{last_payment_error,code}',v_obj#>>'{last_payment_error,message}','SEPA_FAILED'),ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id;
    elsif v_type='charge.refunded' then
      update public.cuotas set estado='reembolsada',metodo_pago='sepa',ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
      update public.pagos set metodo='sepa',observaciones=coalesce(observaciones,'Stripe SEPA')||' · reembolsado' where cuota_id=v_attempt.cuota_id and referencia=v_attempt.stripe_payment_intent_id;
    elsif v_type='charge.dispute.created' then
      update public.cuotas set estado='disputada',metodo_pago='sepa',ultimo_fallo='SEPA_DISPUTE',ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id;
    end if;
  end if;

  if v_type='mandate.updated' and coalesce(v_obj->>'id','') ~ '^mandate_' then
    update kombax_payments.sepa_mandates_r80 set status=case when coalesce(v_obj->>'status','')='active' then 'active' else 'inactive' end,
      revoked_at=case when coalesce(v_obj->>'status','')='active' then null else coalesce(revoked_at,now()) end,updated_at=now()
      where stripe_mandate_id=v_obj->>'id';
  end if;
  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('r80_sepa_reconciled',true);
end $$;

revoke all on function public.app_stripe_connect_sync_internal_r80(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text,text,text,text),
  public.app_stripe_payment_method_gate_internal_r80(text,text,text),
  public.app_stripe_connected_customer_upsert_internal_r80(uuid,uuid,text,text,text),
  public.app_stripe_sepa_setup_prepare_internal_r80(uuid,uuid,uuid),
  public.app_stripe_sepa_setup_finalize_internal_r80(uuid,text,text,text,text,text,text),
  public.app_stripe_sepa_charge_prepare_internal_r80(uuid,uuid,uuid),
  public.app_stripe_payment_intent_attach_internal_r80(uuid,text,text),
  public.app_stripe_event_apply_v266(jsonb)
from public,anon,authenticated;

grant execute on function public.app_stripe_connect_sync_internal_r80(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text,text,text,text),
  public.app_stripe_payment_method_gate_internal_r80(text,text,text),
  public.app_stripe_connected_customer_upsert_internal_r80(uuid,uuid,text,text,text),
  public.app_stripe_sepa_setup_prepare_internal_r80(uuid,uuid,uuid),
  public.app_stripe_sepa_setup_finalize_internal_r80(uuid,text,text,text,text,text,text),
  public.app_stripe_sepa_charge_prepare_internal_r80(uuid,uuid,uuid),
  public.app_stripe_payment_intent_attach_internal_r80(uuid,text,text),
  public.app_stripe_event_apply_v266(jsonb)
to service_role;

commit;
