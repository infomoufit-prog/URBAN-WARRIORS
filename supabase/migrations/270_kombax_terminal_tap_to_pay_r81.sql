-- KOMBAX R81 · Stripe Terminal / Tap to Pay + secure web POS fallback
-- Additive migration on R80. One Stripe Connect account per commercial identity.

begin;

alter table kombax_payments.payment_method_preferences_r80
  add column if not exists tap_to_pay_enabled boolean not null default false;

alter table kombax_payments.payment_attempts drop constraint if exists payment_attempts_kind_check;
alter table kombax_payments.payment_attempts
  add constraint payment_attempts_kind_check check(kind in('club_fee','showcase_order','event_ticket','setup_method','terminal_sale')) not valid;
alter table kombax_payments.payment_attempts validate constraint payment_attempts_kind_check;

alter table public.pagos drop constraint if exists pagos_metodo_check;
alter table public.pagos add constraint pagos_metodo_check check(metodo in('transferencia','bizum','efectivo','tarjeta','sepa','terminal','otro')) not valid;
alter table public.pagos validate constraint pagos_metodo_check;

create table if not exists kombax_payments.terminal_locations_r81(
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check(subject_type in('club','showcase_provider','federation','event_organizer')),
  subject_id uuid not null,
  connected_account_id uuid not null references kombax_payments.connected_accounts(id) on delete restrict,
  stripe_location_id text not null check(stripe_location_id ~ '^tml_'),
  display_name text not null,
  address_line1 text not null,
  city text not null,
  postal_code text not null,
  country text not null default 'ES' check(country ~ '^[A-Z]{2}$'),
  active boolean not null default true,
  created_by uuid not null references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_type,subject_id,stripe_location_id)
);
create unique index if not exists uq_terminal_primary_location_r81
  on kombax_payments.terminal_locations_r81(subject_type,subject_id) where active;
create index if not exists idx_terminal_location_account_r81 on kombax_payments.terminal_locations_r81(connected_account_id,active);

create table if not exists kombax_payments.terminal_sales_r81(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  attempt_id uuid not null references kombax_payments.payment_attempts(id) on delete restrict,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  connected_account_id uuid not null references kombax_payments.connected_accounts(id) on delete restrict,
  subject_type text not null check(subject_type in('club','showcase_provider','federation','event_organizer')),
  subject_id uuid not null,
  terminal_location_id uuid references kombax_payments.terminal_locations_r81(id) on delete restrict,
  source_kind text not null default 'generic' check(source_kind in('generic','club_fee','showcase','event_ticket','federation_service')),
  reference_id uuid,
  channel text not null check(channel in('tap_to_pay_android','tap_to_pay_ios','web_qr')),
  amount_minor integer not null check(amount_minor between 50 and 10000000),
  currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'),
  concept text not null check(char_length(concept) between 1 and 180),
  status text not null default 'created' check(status in('created','checkout_created','processing','succeeded','failed','refunded','cancelled','disputed')),
  stripe_payment_intent_id text,
  stripe_checkout_session_id text,
  failure_code text,
  failure_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(actor_user_id,request_id)
);
create index if not exists idx_terminal_sales_subject_r81 on kombax_payments.terminal_sales_r81(subject_type,subject_id,created_at desc);
create index if not exists idx_terminal_sales_pi_r81 on kombax_payments.terminal_sales_r81(stripe_payment_intent_id) where stripe_payment_intent_id is not null;
create index if not exists idx_terminal_sales_status_r81 on kombax_payments.terminal_sales_r81(status,updated_at desc);

alter table kombax_payments.terminal_locations_r81 enable row level security;
alter table kombax_payments.terminal_sales_r81 enable row level security;
revoke all on kombax_payments.terminal_locations_r81,kombax_payments.terminal_sales_r81 from public,anon,authenticated;
grant all on kombax_payments.terminal_locations_r81,kombax_payments.terminal_sales_r81 to service_role;

create or replace function kombax_payments.can_charge_subject_r81(p_actor uuid,p_subject_type text,p_subject_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  if p_actor is null or p_subject_id is null then return false; end if;
  if p_subject_type='club' then
    return exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor and m.activo and m.rol in('direccion','economia','secretaria'));
  end if;
  return kombax_payments.can_access_subject_r80(p_actor,p_subject_type,p_subject_id,true);
end $$;
revoke all on function kombax_payments.can_charge_subject_r81(uuid,text,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_charge_subject_r81(uuid,text,uuid) to service_role;

create or replace function public.app_stripe_payment_methods_status_r81(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_base jsonb;v_pref kombax_payments.payment_method_preferences_r80;v_loc kombax_payments.terminal_locations_r81;
begin
  v_base:=public.app_stripe_payment_methods_status_r80(p_subject_type,p_subject_id);
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type=p_subject_type and p.subject_id=p_subject_id;
  select * into v_loc from kombax_payments.terminal_locations_r81 l where l.subject_type=p_subject_type and l.subject_id=p_subject_id and l.active order by l.updated_at desc limit 1;
  return v_base || jsonb_build_object(
    'tap_to_pay_enabled',coalesce(v_pref.tap_to_pay_enabled,false),
    'terminal_ready',coalesce((v_base->>'status')='active' and (v_base->>'payouts_enabled')::boolean and (v_base->>'card_capability_status')='active',false),
    'terminal_location_configured',v_loc.id is not null,
    'terminal_location_id',v_loc.id,
    'stripe_terminal_location_id',v_loc.stripe_location_id,
    'terminal_native_required',true,
    'terminal_web_fallback',true,
    'terminal_country',coalesce(v_loc.country,'ES')
  );
end $$;
revoke all on function public.app_stripe_payment_methods_status_r81(text,uuid) from public,anon;
grant execute on function public.app_stripe_payment_methods_status_r81(text,uuid) to authenticated;

create or replace function public.app_stripe_terminal_toggle_r81(p_subject_type text,p_subject_id uuid,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_row kombax_payments.payment_method_preferences_r80;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not kombax_payments.can_access_subject_r80(v_uid,p_subject_type,p_subject_id,true) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  insert into kombax_payments.payment_method_preferences_r80(subject_type,subject_id,card_enabled,sepa_enabled,tap_to_pay_enabled,updated_by)
  values(p_subject_type,p_subject_id,true,false,p_enabled,v_uid)
  on conflict(subject_type,subject_id) do update set tap_to_pay_enabled=excluded.tap_to_pay_enabled,updated_by=v_uid,updated_at=now()
  returning * into v_row;
  return jsonb_build_object('ok',true,'tap_to_pay_enabled',v_row.tap_to_pay_enabled,'updated_at',v_row.updated_at);
end $$;
revoke all on function public.app_stripe_terminal_toggle_r81(text,uuid,boolean) from public,anon;
grant execute on function public.app_stripe_terminal_toggle_r81(text,uuid,boolean) to authenticated;

create or replace function public.app_stripe_terminal_context_internal_r81(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_require_tap boolean default true)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_account kombax_payments.connected_accounts;v_pref kombax_payments.payment_method_preferences_r80;v_loc kombax_payments.terminal_locations_r81;
begin
  if not kombax_payments.can_charge_subject_r81(p_actor_id,p_subject_type,p_subject_id) then raise exception 'TERMINAL_ACCESS_DENIED'; end if;
  select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  select * into v_pref from kombax_payments.payment_method_preferences_r80 p where p.subject_type=p_subject_type and p.subject_id=p_subject_id;
  if v_account.status<>'active' or not v_account.payouts_enabled or coalesce(v_account.card_payments_status,case when v_account.charges_enabled then 'active' else 'inactive' end)<>'active' then raise exception 'CONNECTED_ACCOUNT_NOT_READY'; end if;
  if not coalesce(v_pref.card_enabled,true) then raise exception 'CARD_PAYMENTS_DISABLED'; end if;
  if p_require_tap and not coalesce(v_pref.tap_to_pay_enabled,false) then raise exception 'TAP_TO_PAY_DISABLED'; end if;
  select * into v_loc from kombax_payments.terminal_locations_r81 l where l.subject_type=p_subject_type and l.subject_id=p_subject_id and l.active order by l.updated_at desc limit 1;
  return jsonb_build_object('connected_account_id',v_account.id,'stripe_account_id',v_account.stripe_account_id,'location_id',v_loc.id,'stripe_location_id',v_loc.stripe_location_id,'tap_to_pay_enabled',coalesce(v_pref.tap_to_pay_enabled,false));
end $$;

create or replace function public.app_stripe_terminal_location_upsert_internal_r81(
  p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_stripe_location_id text,p_display_name text,p_address_line1 text,p_city text,p_postal_code text,p_country text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_account uuid;v_id uuid;
begin
  if not kombax_payments.can_charge_subject_r81(p_actor_id,p_subject_type,p_subject_id) then raise exception 'TERMINAL_ACCESS_DENIED'; end if;
  if coalesce(p_stripe_location_id,'') !~ '^tml_' then raise exception 'TERMINAL_LOCATION_INVALID'; end if;
  select a.id into strict v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  update kombax_payments.terminal_locations_r81 set active=false,updated_at=now() where subject_type=p_subject_type and subject_id=p_subject_id and active;
  insert into kombax_payments.terminal_locations_r81(subject_type,subject_id,connected_account_id,stripe_location_id,display_name,address_line1,city,postal_code,country,created_by)
  values(p_subject_type,p_subject_id,v_account,p_stripe_location_id,left(trim(p_display_name),100),left(trim(p_address_line1),180),left(trim(p_city),100),left(trim(p_postal_code),24),upper(coalesce(nullif(trim(p_country),''),'ES')),p_actor_id)
  returning id into v_id;
  return jsonb_build_object('ok',true,'id',v_id,'stripe_location_id',p_stripe_location_id);
end $$;

create or replace function public.app_stripe_terminal_sale_prepare_internal_r81(
  p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_request_id uuid,p_amount_minor integer,p_concept text,p_source_kind text,p_reference_id uuid,p_channel text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_ctx jsonb;v_attempt kombax_payments.payment_attempts;v_sale kombax_payments.terminal_sales_r81;v_club uuid;v_fee uuid;v_loc uuid;
begin
  if p_amount_minor<50 or p_amount_minor>10000000 then raise exception 'TERMINAL_AMOUNT_INVALID'; end if;
  if coalesce(trim(p_concept),'')='' then raise exception 'TERMINAL_CONCEPT_REQUIRED'; end if;
  if p_source_kind not in('generic','club_fee','showcase','event_ticket','federation_service') then raise exception 'TERMINAL_SOURCE_INVALID'; end if;
  if p_channel not in('tap_to_pay_android','tap_to_pay_ios','web_qr') then raise exception 'TERMINAL_CHANNEL_INVALID'; end if;
  v_ctx:=public.app_stripe_terminal_context_internal_r81(p_actor_id,p_subject_type,p_subject_id,true);
  if p_channel<>'web_qr' and coalesce(v_ctx->>'stripe_location_id','')='' then raise exception 'TERMINAL_LOCATION_REQUIRED'; end if;
  v_club:=case when p_subject_type='club' then p_subject_id else null end;
  if p_source_kind='club_fee' then
    if p_subject_type<>'club' or p_reference_id is null or not exists(select 1 from public.cuotas q where q.id=p_reference_id and q.club_id=p_subject_id and q.estado not in('pagada','reembolsada','cancelada','anulada','exenta')) then raise exception 'TERMINAL_FEE_INVALID'; end if;
    v_fee:=p_reference_id;
  end if;
  select * into v_sale from kombax_payments.terminal_sales_r81 s where s.actor_user_id=p_actor_id and s.request_id=p_request_id;
  if found then return jsonb_build_object('sale_id',v_sale.id,'attempt_id',v_sale.attempt_id,'stripe_account_id',v_ctx->>'stripe_account_id','stripe_location_id',v_ctx->>'stripe_location_id','amount_minor',v_sale.amount_minor,'currency',lower(v_sale.currency),'concept',v_sale.concept); end if;
  insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,platform_fee_minor,currency,status,metadata,seller_amount_minor,buyer_service_fee_minor,platform_percentage_fee_minor)
  values(p_request_id,'terminal_sale',p_actor_id,(v_ctx->>'connected_account_id')::uuid,v_club,v_fee,p_amount_minor,0,'EUR','created',jsonb_build_object('payment_method','card_present','subject_type',p_subject_type,'subject_id',p_subject_id,'source_kind',p_source_kind,'reference_id',p_reference_id,'channel',p_channel),p_amount_minor,0,0)
  returning * into v_attempt;
  v_loc:=nullif(v_ctx->>'location_id','')::uuid;
  insert into kombax_payments.terminal_sales_r81(request_id,attempt_id,actor_user_id,connected_account_id,subject_type,subject_id,terminal_location_id,source_kind,reference_id,channel,amount_minor,concept,metadata)
  values(p_request_id,v_attempt.id,p_actor_id,(v_ctx->>'connected_account_id')::uuid,p_subject_type,p_subject_id,v_loc,p_source_kind,p_reference_id,p_channel,p_amount_minor,left(trim(p_concept),180),jsonb_build_object('direct_charge',true)) returning * into v_sale;
  return jsonb_build_object('sale_id',v_sale.id,'attempt_id',v_attempt.id,'stripe_account_id',v_ctx->>'stripe_account_id','stripe_location_id',v_ctx->>'stripe_location_id','amount_minor',p_amount_minor,'currency','eur','concept',v_sale.concept);
end $$;

create or replace function public.app_stripe_terminal_sale_attach_internal_r81(p_sale_id uuid,p_payment_intent_id text,p_checkout_session_id text,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_attempt uuid;
begin
  if p_payment_intent_id is not null and p_payment_intent_id !~ '^pi_' then raise exception 'PAYMENT_INTENT_INVALID'; end if;
  if p_checkout_session_id is not null and p_checkout_session_id !~ '^cs_' then raise exception 'CHECKOUT_SESSION_INVALID'; end if;
  update kombax_payments.terminal_sales_r81 set stripe_payment_intent_id=coalesce(p_payment_intent_id,stripe_payment_intent_id),stripe_checkout_session_id=coalesce(p_checkout_session_id,stripe_checkout_session_id),status=coalesce(nullif(p_status,''),status),updated_at=now() where id=p_sale_id returning attempt_id into v_attempt;
  update kombax_payments.payment_attempts set stripe_payment_intent_id=coalesce(p_payment_intent_id,stripe_payment_intent_id),stripe_checkout_session_id=coalesce(p_checkout_session_id,stripe_checkout_session_id),status=case when p_status in('created','checkout_created','processing','succeeded','failed','refunded','cancelled','disputed') then p_status else status end,updated_at=now() where id=v_attempt;
end $$;

create or replace function public.app_stripe_terminal_sales_r81(p_subject_type text,p_subject_id uuid,p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_rows jsonb;
begin
  if v_uid is null or not kombax_payments.can_access_subject_r80(v_uid,p_subject_type,p_subject_id,false) then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_rows from (
    select id,source_kind,reference_id,channel,amount_minor,currency,concept,status,created_at,updated_at from kombax_payments.terminal_sales_r81 where subject_type=p_subject_type and subject_id=p_subject_id order by created_at desc limit greatest(1,least(coalesce(p_limit,50),200))
  ) x;
  return v_rows;
end $$;
revoke all on function public.app_stripe_terminal_sales_r81(text,uuid,integer) from public,anon;
grant execute on function public.app_stripe_terminal_sales_r81(text,uuid,integer) to authenticated;

create or replace function public.app_stripe_event_apply_v267(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_sale kombax_payments.terminal_sales_r81;v_sale_id uuid;v_pi text;v_failure text;
begin
  v_result:=public.app_stripe_event_apply_v266(p_event);
  begin v_sale_id:=nullif(v_obj#>>'{metadata,terminal_sale_id}','')::uuid; exception when others then v_sale_id:=null; end;
  v_pi:=case when v_type like 'payment_intent.%' then nullif(v_obj->>'id','') else nullif(v_obj->>'payment_intent','') end;
  if v_sale_id is not null then select * into v_sale from kombax_payments.terminal_sales_r81 s where s.id=v_sale_id;
  elsif v_pi is not null then select * into v_sale from kombax_payments.terminal_sales_r81 s where s.stripe_payment_intent_id=v_pi;
  end if;
  if v_sale.id is not null then
    if v_type='payment_intent.processing' then
      update kombax_payments.terminal_sales_r81 set status='processing',stripe_payment_intent_id=coalesce(v_pi,stripe_payment_intent_id),updated_at=now() where id=v_sale.id;
      update kombax_payments.payment_attempts set status='processing',stripe_payment_intent_id=coalesce(v_pi,stripe_payment_intent_id),updated_at=now() where id=v_sale.attempt_id;
    elsif v_type='payment_intent.succeeded' then
      update kombax_payments.terminal_sales_r81 set status='succeeded',stripe_payment_intent_id=coalesce(v_pi,stripe_payment_intent_id),failure_code=null,failure_message=null,updated_at=now() where id=v_sale.id;
      update kombax_payments.payment_attempts set status='succeeded',stripe_payment_intent_id=coalesce(v_pi,stripe_payment_intent_id),failure_code=null,failure_message=null,updated_at=now() where id=v_sale.attempt_id;
      if v_sale.source_kind='club_fee' and v_sale.reference_id is not null then update public.cuotas set estado='pagada',metodo_pago='terminal',stripe_payment_intent_id=coalesce(v_pi,stripe_payment_intent_id),pagada_en=coalesce(pagada_en,now()),ultimo_fallo=null,actualizado_en=now() where id=v_sale.reference_id; end if;
    elsif v_type='payment_intent.payment_failed' then
      v_failure:=coalesce(v_obj#>>'{last_payment_error,code}',v_obj#>>'{last_payment_error,message}','TERMINAL_PAYMENT_FAILED');
      update kombax_payments.terminal_sales_r81 set status='failed',failure_code=left(v_failure,80),failure_message=left(coalesce(v_obj#>>'{last_payment_error,message}',v_failure),240),updated_at=now() where id=v_sale.id;
      update kombax_payments.payment_attempts set status='failed',failure_code=left(v_failure,80),failure_message=left(coalesce(v_obj#>>'{last_payment_error,message}',v_failure),240),updated_at=now() where id=v_sale.attempt_id;
    elsif v_type='charge.refunded' then
      update kombax_payments.terminal_sales_r81 set status='refunded',updated_at=now() where id=v_sale.id;update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_sale.attempt_id;
      if v_sale.source_kind='club_fee' and v_sale.reference_id is not null then update public.cuotas set estado='reembolsada',metodo_pago='terminal',actualizado_en=now() where id=v_sale.reference_id; end if;
    elsif v_type='charge.dispute.created' then
      update kombax_payments.terminal_sales_r81 set status='disputed',updated_at=now() where id=v_sale.id;update kombax_payments.payment_attempts set status='disputed',updated_at=now() where id=v_sale.attempt_id;
      if v_sale.source_kind='club_fee' and v_sale.reference_id is not null then update public.cuotas set estado='disputada',metodo_pago='terminal',ultimo_fallo='TERMINAL_DISPUTE',ultimo_fallo_en=now(),actualizado_en=now() where id=v_sale.reference_id; end if;
    end if;
  end if;
  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('r81_terminal_reconciled',true);
end $$;

revoke all on function public.app_stripe_terminal_context_internal_r81(uuid,text,uuid,boolean),public.app_stripe_terminal_location_upsert_internal_r81(uuid,text,uuid,text,text,text,text,text,text),public.app_stripe_terminal_sale_prepare_internal_r81(uuid,text,uuid,uuid,integer,text,text,uuid,text),public.app_stripe_terminal_sale_attach_internal_r81(uuid,text,text,text),public.app_stripe_event_apply_v267(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_terminal_context_internal_r81(uuid,text,uuid,boolean),public.app_stripe_terminal_location_upsert_internal_r81(uuid,text,uuid,text,text,text,text,text,text),public.app_stripe_terminal_sale_prepare_internal_r81(uuid,text,uuid,uuid,integer,text,text,uuid,text),public.app_stripe_terminal_sale_attach_internal_r81(uuid,text,text,text),public.app_stripe_event_apply_v267(jsonb) to service_role;

commit;
