-- KOMBAX R61 · Stripe Connect, cuotas online y Showcase Commerce
-- Migracion aditiva. No activa cobros ni crea cargos por si sola.

alter type public.estado_cuota add value if not exists 'procesando';
alter type public.estado_cuota add value if not exists 'fallida';
alter type public.estado_cuota add value if not exists 'reembolsada';
alter type public.estado_cuota add value if not exists 'cancelada';

begin;

create schema if not exists kombax_payments;
revoke all on schema kombax_payments from public,anon,authenticated;
grant usage on schema kombax_payments to service_role;

alter table public.cuotas add column if not exists metodo_pago text;
alter table public.cuotas add column if not exists stripe_payment_intent_id text;
alter table public.cuotas add column if not exists pagada_en timestamptz;
alter table public.cuotas add column if not exists ultimo_fallo text;
alter table public.cuotas add column if not exists ultimo_fallo_en timestamptz;
create unique index if not exists uq_cuotas_stripe_payment_intent_v259
  on public.cuotas(stripe_payment_intent_id) where stripe_payment_intent_id is not null;

alter table public.kombax_showcase_elementos add column if not exists commerce_enabled boolean not null default false;
alter table public.kombax_showcase_elementos add column if not exists precio_venta numeric(12,2) check(precio_venta is null or precio_venta>=0);
alter table public.kombax_showcase_elementos add column if not exists stock integer check(stock is null or stock>=0);
alter table public.kombax_showcase_elementos add column if not exists variantes jsonb not null default '[]'::jsonb;
alter table public.kombax_showcase_elementos add column if not exists fulfillment text not null default 'seller_shipping'
  check(fulfillment in('seller_shipping','seller_pickup','seller_shipping_or_pickup','digital'));
alter table public.kombax_showcase_elementos add column if not exists shipping_policy text;
alter table public.kombax_showcase_elementos add column if not exists returns_policy text;
alter table public.kombax_showcase_elementos add constraint showcase_variantes_array_v259
  check(jsonb_typeof(variantes)='array' and jsonb_array_length(variantes)<=50) not valid;
alter table public.kombax_showcase_elementos validate constraint showcase_variantes_array_v259;
create index if not exists idx_showcase_commerce_stock_v259
  on public.kombax_showcase_elementos(marca_id,commerce_enabled,estado) where commerce_enabled;

create table if not exists kombax_payments.connected_accounts(
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check(subject_type in('club','showcase_provider')),
  subject_id uuid not null,
  club_id uuid references public.clubes(id) on delete restrict,
  showcase_provider_id uuid references public.kombax_showcase_marcas(id) on delete restrict,
  stripe_account_id text not null unique check(stripe_account_id ~ '^acct_'),
  country text not null default 'ES',
  status text not null default 'pending' check(status in('not_configured','pending','verification_pending','active','action_required','restricted')),
  details_submitted boolean not null default false,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  requirements_due jsonb not null default '[]'::jsonb,
  requirements_eventually_due jsonb not null default '[]'::jsonb,
  disabled_reason text,
  created_by uuid not null references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(subject_type,subject_id),
  check((subject_type='club' and club_id=subject_id and showcase_provider_id is null)
    or (subject_type='showcase_provider' and showcase_provider_id=subject_id and club_id is null))
);

create table if not exists kombax_payments.customers(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.perfiles(id) on delete restrict,
  stripe_customer_id text not null unique check(stripe_customer_id ~ '^cus_'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id)
);

create table if not exists kombax_payments.payment_authorizations(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  socio_id uuid not null,
  user_id uuid not null references public.perfiles(id) on delete restrict,
  stripe_customer_id text not null check(stripe_customer_id ~ '^cus_'),
  stripe_payment_method_id text not null check(stripe_payment_method_id ~ '^pm_'),
  stripe_mandate_id text,
  scope text not null default 'registered_fees' check(scope in('registered_fees','single_fee')),
  consent_version text not null,
  consent_text text not null check(char_length(consent_text) between 10 and 2000),
  consented_at timestamptz not null,
  consent_ip inet,
  consent_user_agent text,
  active boolean not null default true,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete restrict
);
create unique index if not exists uq_payment_authorization_active_v259
  on kombax_payments.payment_authorizations(club_id,socio_id,user_id,stripe_payment_method_id) where active;

create table if not exists kombax_payments.platform_fee_rules(
  id uuid primary key default gen_random_uuid(),
  scope text not null check(scope in('club_fee','showcase')),
  plan_code text,
  seller_subject_type text,
  seller_subject_id uuid,
  percentage numeric(7,4) not null default 0 check(percentage between 0 and 100),
  fixed_amount_minor integer not null default 0 check(fixed_amount_minor>=0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  priority integer not null default 0,
  active boolean not null default true,
  created_by uuid references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check(ends_at is null or ends_at>starts_at)
);
create index if not exists idx_fee_rules_resolve_v259 on kombax_payments.platform_fee_rules(scope,active,priority desc,starts_at desc);

create table if not exists public.kombax_commerce_entitlements(
  plan_code text primary key references public.kombax_planes(codigo) on delete cascade,
  max_products integer not null default 0 check(max_products between 0 and 10000),
  commerce_enabled boolean not null default false,
  advanced_stock boolean not null default false,
  analytics boolean not null default false,
  promotions boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.kombax_commerce_entitlements enable row level security;
revoke all on public.kombax_commerce_entitlements from public,anon,authenticated;
insert into public.kombax_planes(codigo,perfil_tipo,nombre,modalidad,requiere_checkout,descripcion) values
  ('club_pro','club','KOMBAX Club Pro','subscription',true,'Club con catálogo y capacidades comerciales avanzadas.')
on conflict(codigo) do update set nombre=excluded.nombre,descripcion=excluded.descripcion,activo=true,actualizado_en=now();
insert into public.kombax_commerce_entitlements(plan_code,max_products,commerce_enabled,advanced_stock,analytics,promotions) values
  ('club_saas',10,true,false,false,false),('club_pro',100,true,true,true,true),('marca_profesional',500,true,true,true,true)
on conflict(plan_code) do update set max_products=excluded.max_products,commerce_enabled=excluded.commerce_enabled,advanced_stock=excluded.advanced_stock,analytics=excluded.analytics,promotions=excluded.promotions,updated_at=now();

create table if not exists kombax_payments.showcase_orders(
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  buyer_user_id uuid not null references public.perfiles(id) on delete restrict,
  seller_provider_id uuid not null references public.kombax_showcase_marcas(id) on delete restrict,
  seller_name text not null,
  amount_total_minor integer not null check(amount_total_minor>=0),
  currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'),
  status text not null default 'received' check(status in('received','payment_confirmed','preparing','shipped','delivered','cancelled','refunded','incident')),
  carrier text,
  tracking_number text,
  tracking_url text check(tracking_url is null or tracking_url ~* '^https://[^[:space:]]+$'),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_orders_buyer_v259 on kombax_payments.showcase_orders(buyer_user_id,created_at desc);
create index if not exists idx_orders_seller_v259 on kombax_payments.showcase_orders(seller_provider_id,created_at desc);

create table if not exists kombax_payments.showcase_order_items(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references kombax_payments.showcase_orders(id) on delete restrict,
  product_id uuid not null references public.kombax_showcase_elementos(id) on delete restrict,
  product_name text not null,
  quantity integer not null check(quantity between 1 and 100),
  unit_amount_minor integer not null check(unit_amount_minor>=0),
  variant jsonb not null default '{}'::jsonb,
  unique(order_id,product_id)
);

create table if not exists kombax_payments.showcase_order_history(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references kombax_payments.showcase_orders(id) on delete restrict,
  from_status text,
  to_status text not null,
  actor_user_id uuid references public.perfiles(id) on delete restrict,
  source text not null check(source in('buyer','seller','platform','stripe','system')),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists kombax_payments.showcase_incidents(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references kombax_payments.showcase_orders(id) on delete restrict,
  buyer_user_id uuid not null references public.perfiles(id) on delete restrict,
  seller_provider_id uuid not null references public.kombax_showcase_marcas(id) on delete restrict,
  reason text not null check(char_length(reason) between 3 and 120),
  status text not null default 'open' check(status in('open','seller_review','platform_review','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists kombax_payments.showcase_incident_messages(
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references kombax_payments.showcase_incidents(id) on delete restrict,
  author_user_id uuid not null references public.perfiles(id) on delete restrict,
  message text not null check(char_length(message) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists kombax_payments.payment_attempts(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  kind text not null check(kind in('club_fee','showcase_order','setup_method')),
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  connected_account_id uuid references kombax_payments.connected_accounts(id) on delete restrict,
  club_id uuid references public.clubes(id) on delete restrict,
  cuota_id uuid references public.cuotas(id) on delete restrict,
  order_id uuid references kombax_payments.showcase_orders(id) on delete restrict,
  amount_minor integer not null default 0 check(amount_minor>=0),
  platform_fee_minor integer not null default 0 check(platform_fee_minor>=0 and platform_fee_minor<=amount_minor),
  currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'),
  status text not null default 'created' check(status in('created','checkout_created','processing','succeeded','failed','refunded','cancelled','disputed')),
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  stripe_setup_intent_id text unique,
  failure_code text,
  failure_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(actor_user_id,request_id)
);

create table if not exists kombax_payments.webhook_events(
  stripe_event_id text primary key check(stripe_event_id ~ '^evt_'),
  event_type text not null,
  stripe_account_id text,
  livemode boolean not null,
  api_version text,
  payload jsonb not null,
  status text not null default 'processing' check(status in('processing','processed','ignored','failed')),
  error_message text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

do $$ declare t regclass; begin
  foreach t in array array[
    'kombax_payments.connected_accounts'::regclass,'kombax_payments.customers'::regclass,
    'kombax_payments.payment_authorizations'::regclass,'kombax_payments.platform_fee_rules'::regclass,
    'kombax_payments.showcase_orders'::regclass,'kombax_payments.showcase_order_items'::regclass,
    'kombax_payments.showcase_order_history'::regclass,'kombax_payments.showcase_incidents'::regclass,
    'kombax_payments.showcase_incident_messages'::regclass,'kombax_payments.payment_attempts'::regclass,
    'kombax_payments.webhook_events'::regclass
  ] loop execute format('alter table %s enable row level security',t); end loop;
end $$;
revoke all on all tables in schema kombax_payments from public,anon,authenticated;
grant all on all tables in schema kombax_payments to service_role;

create or replace function kombax_payments.can_manage_provider(p_actor uuid,p_provider uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_provider and g.perfil_id=p_actor and g.activo)
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id
      where m.id=p_provider and mc.perfil_id=p_actor and mc.activo and mc.rol in('direccion','secretaria','economia'))
    or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo);
$$;

create or replace function kombax_payments.can_pay_fee(p_actor uuid,p_fee uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.cuotas q join public.socios s on s.id=q.socio_id and s.club_id=q.club_id
    where q.id=p_fee and (s.perfil_id=p_actor or exists(select 1 from public.tutores_socios t where t.club_id=q.club_id and t.socio_id=q.socio_id and t.tutor_perfil_id=p_actor)))
    or exists(select 1 from public.cuotas q join public.miembros_club m on m.club_id=q.club_id
      where q.id=p_fee and m.perfil_id=p_actor and m.activo and m.rol in('direccion','secretaria','economia'));
$$;

create or replace function kombax_payments.resolve_fee_minor(p_scope text,p_amount_minor integer,p_subject_type text,p_subject_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  select least(p_amount_minor,greatest(0,coalesce((select round(p_amount_minor*(r.percentage/100.0))::int+r.fixed_amount_minor
    from kombax_payments.platform_fee_rules r where r.scope=p_scope and r.active and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
      and (r.seller_subject_type is null or (r.seller_subject_type=p_subject_type and r.seller_subject_id=p_subject_id))
    order by (r.seller_subject_id is not null) desc,r.priority desc,r.starts_at desc limit 1),0)));
$$;

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
  if not found then return jsonb_build_object('status','not_configured','charges_enabled',false,'payouts_enabled',false,'details_submitted',false); end if;
  return jsonb_build_object('status',v_row.status,'charges_enabled',v_row.charges_enabled,'payouts_enabled',v_row.payouts_enabled,
    'details_submitted',v_row.details_submitted,'requirements_due',v_row.requirements_due,'updated_at',v_row.updated_at);
end $$;
revoke all on function public.app_stripe_connect_status_v259(text,uuid) from public,anon;
grant execute on function public.app_stripe_connect_status_v259(text,uuid) to authenticated;

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
    'stripe_account_id',v_account.stripe_account_id,'status',coalesce(v_account.status,'not_configured'));
end $$;

create or replace function public.app_stripe_connect_attach_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_stripe_account_id text)
returns void language plpgsql security definer set search_path='' as $$
begin
  insert into kombax_payments.connected_accounts(subject_type,subject_id,club_id,showcase_provider_id,stripe_account_id,created_by)
  values(p_subject_type,p_subject_id,case when p_subject_type='club' then p_subject_id end,case when p_subject_type='showcase_provider' then p_subject_id end,p_stripe_account_id,p_actor_id)
  on conflict(subject_type,subject_id) do update set stripe_account_id=excluded.stripe_account_id,updated_at=now();
end $$;

create or replace function public.app_stripe_checkout_prepare_internal_v259(p_actor_id uuid,p_kind text,p_reference_id uuid,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_fee public.cuotas;v_item public.kombax_showcase_elementos;v_provider public.kombax_showcase_marcas;v_order kombax_payments.showcase_orders;v_amount int;v_platform int;v_qty int:=greatest(1,least(coalesce(p_quantity,1),100));
begin
  select * into v_attempt from kombax_payments.payment_attempts where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then return jsonb_build_object('attempt_id',v_attempt.id,'status',v_attempt.status,'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id); end if;
  if p_kind='club_fee' then
    if not kombax_payments.can_pay_fee(p_actor_id,p_reference_id) then raise exception 'FEE_PAYMENT_DENIED'; end if;
    select * into strict v_fee from public.cuotas where id=p_reference_id for update;
    if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta') then raise exception 'FEE_NOT_PAYABLE'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='club' and subject_id=v_fee.club_id and status='active' and charges_enabled and payouts_enabled;
    v_amount:=round(v_fee.importe*100)::int;v_platform:=kombax_payments.resolve_fee_minor('club_fee',v_amount,'club',v_fee.club_id);
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,v_platform,'EUR',jsonb_build_object('concept',v_fee.concepto)) returning * into v_attempt;
    update public.cuotas set estado='procesando',metodo_pago='stripe_checkout',actualizado_en=now() where id=v_fee.id;
    return jsonb_build_object('attempt_id',v_attempt.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_fee.concepto,'stripe_account_id',v_account.stripe_account_id);
  elsif p_kind='showcase_order' then
    select * into strict v_item from public.kombax_showcase_elementos where id=p_reference_id and estado='publicado' and commerce_enabled for update;
    if v_item.precio_venta is null or v_item.precio_venta<=0 or (v_item.stock is not null and v_item.stock<v_qty) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=v_item.marca_id and estado='publicada';
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=v_provider.id and status='active' and charges_enabled and payouts_enabled;
    v_amount:=round(v_item.precio_venta*100)::int*v_qty;v_platform:=kombax_payments.resolve_fee_minor('showcase',v_amount,'showcase_provider',v_provider.id);
    insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,v_amount,'EUR') returning * into v_order;
    insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor) values(v_order.id,v_item.id,v_item.nombre,v_qty,round(v_item.precio_venta*100)::int);
    insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source) values(v_order.id,'received',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_order.id,v_amount,v_platform,'EUR',jsonb_build_object('product_id',v_item.id,'seller',v_provider.nombre)) returning * into v_attempt;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_item.nombre,'seller_name',v_provider.nombre,'stripe_account_id',v_account.stripe_account_id);
  else raise exception 'CHECKOUT_KIND_INVALID'; end if;
end $$;

create or replace function public.app_stripe_attempt_attach_internal_v259(p_attempt_id uuid,p_checkout_session_id text,p_payment_intent_id text default null,p_setup_intent_id text default null)
returns void language plpgsql security definer set search_path='' as $$
begin update kombax_payments.payment_attempts set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,stripe_setup_intent_id=p_setup_intent_id,status='checkout_created',updated_at=now() where id=p_attempt_id;
update kombax_payments.showcase_orders o set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,updated_at=now() from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.order_id=o.id;end $$;

create or replace function public.app_showcase_my_orders_v259(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'order_number',o.order_number,'seller',o.seller_name,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,'status',o.status,'carrier',o.carrier,'tracking_number',o.tracking_number,'tracking_url',o.tracking_url,'created_at',o.created_at,'items',(select jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount',i.unit_amount_minor/100.0)) from kombax_payments.showcase_order_items i where i.order_id=o.id)) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.showcase_orders where buyer_user_id=(select auth.uid()) order by created_at desc limit least(greatest(p_limit,1),200)) o;
$$;
revoke all on function public.app_showcase_my_orders_v259(integer) from public,anon;
grant execute on function public.app_showcase_my_orders_v259(integer) to authenticated;

create or replace function public.app_showcase_seller_orders_v259(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not kombax_payments.can_manage_provider((select auth.uid()),p_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at desc),'[]'::jsonb) from (select id,order_number,seller_provider_id,amount_total_minor/100.0 as amount_total,currency,status,carrier,tracking_number,tracking_url,created_at,updated_at from kombax_payments.showcase_orders where seller_provider_id=p_provider_id order by created_at desc limit least(greatest(p_limit,1),200)) o);
end $$;
revoke all on function public.app_showcase_seller_orders_v259(uuid,integer) from public,anon;
grant execute on function public.app_showcase_seller_orders_v259(uuid,integer) to authenticated;

create or replace function public.app_showcase_order_mutate_v259(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_order kombax_payments.showcase_orders;v_incident kombax_payments.showcase_incidents;v_status text;v_message text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_order from kombax_payments.showcase_orders where id=(p_payload->>'order_id')::uuid for update;
  if p_operation='showcase.order.status' then
    if not kombax_payments.can_manage_provider(v_uid,v_order.seller_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
    v_status:=p_payload->>'status';if v_status not in('preparing','shipped','delivered','cancelled','incident') then raise exception 'ORDER_STATUS_INVALID'; end if;
    if v_status='shipped' and nullif(btrim(p_payload->>'tracking_number'),'') is null then raise exception 'TRACKING_REQUIRED'; end if;
    update kombax_payments.showcase_orders set status=v_status,carrier=nullif(btrim(p_payload->>'carrier'),''),tracking_number=nullif(btrim(p_payload->>'tracking_number'),''),tracking_url=nullif(btrim(p_payload->>'tracking_url'),''),updated_at=now() where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail) values(v_order.id,v_order.status,v_status,v_uid,'seller',jsonb_build_object('carrier',p_payload->>'carrier','tracking_number',p_payload->>'tracking_number'));
  elsif p_operation='showcase.incident.open' then
    if v_order.buyer_user_id<>v_uid then raise exception 'BUYER_ACCESS_DENIED'; end if;
    v_message:=btrim(coalesce(p_payload->>'message',''));if char_length(v_message)<3 then raise exception 'INCIDENT_MESSAGE_REQUIRED'; end if;
    insert into kombax_payments.showcase_incidents(order_id,buyer_user_id,seller_provider_id,reason) values(v_order.id,v_uid,v_order.seller_provider_id,left(v_message,120)) returning * into v_incident;
    insert into kombax_payments.showcase_incident_messages(incident_id,author_user_id,message) values(v_incident.id,v_uid,v_message);
    update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_order.id;
    v_status:='incident';
  else raise exception 'ORDER_OPERATION_INVALID'; end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('order_id',v_order.id,'status',v_status,'incident_id',v_incident.id));
end $$;
revoke all on function public.app_showcase_order_mutate_v259(text,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_order_mutate_v259(text,jsonb,uuid) to authenticated;

create or replace function public.app_showcase_commerce_details_v259(p_ids uuid[])
returns table(id uuid,commerce_enabled boolean,precio_venta numeric,stock integer,variantes jsonb,fulfillment text,shipping_policy text,returns_policy text,seller_payments_active boolean)
language sql stable security definer set search_path='' as $$
  select e.id,e.commerce_enabled,e.precio_venta,e.stock,e.variantes,e.fulfillment,e.shipping_policy,e.returns_policy,
    exists(select 1 from kombax_payments.connected_accounts a where a.subject_type='showcase_provider' and a.subject_id=e.marca_id and a.status='active' and a.charges_enabled and a.payouts_enabled)
  from public.kombax_showcase_elementos e where e.id=any(coalesce(p_ids,'{}'::uuid[]));
$$;
revoke all on function public.app_showcase_commerce_details_v259(uuid[]) from public,anon;
grant execute on function public.app_showcase_commerce_details_v259(uuid[]) to authenticated;

create or replace function public.app_showcase_commerce_mutate_v259(p_item_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_item public.kombax_showcase_elementos;v_enabled boolean:=coalesce((p_payload->>'commerce_enabled')::boolean,false);v_price numeric;v_stock integer;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_item_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_price:=nullif(p_payload->>'precio_venta','')::numeric;v_stock:=nullif(p_payload->>'stock','')::integer;
  if v_enabled and (v_price is null or v_price<=0) then raise exception 'COMMERCE_PRICE_REQUIRED'; end if;
  if v_enabled and not exists(select 1 from public.kombax_showcase_marcas m where m.id=v_item.marca_id and m.verificada and m.estado='publicada') then raise exception 'KOMBAX_SELLER_VERIFICATION_REQUIRED'; end if;
  update public.kombax_showcase_elementos set commerce_enabled=v_enabled,precio_venta=v_price,stock=v_stock,
    variantes=coalesce(p_payload->'variantes','[]'::jsonb),fulfillment=coalesce(nullif(p_payload->>'fulfillment',''),'seller_shipping'),
    shipping_policy=nullif(btrim(p_payload->>'shipping_policy'),''),returns_policy=nullif(btrim(p_payload->>'returns_policy'),''),actualizado_por=v_uid,actualizado_en=now()
  where id=p_item_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('id',p_item_id,'commerce_enabled',v_enabled));
end $$;
revoke all on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) to authenticated;

create or replace function public.app_stripe_event_apply_v259(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id text:=p_event->>'id';v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_attempt kombax_payments.payment_attempts;v_status text;v_due jsonb;v_payment_intent text;
begin
  insert into kombax_payments.webhook_events(stripe_event_id,event_type,stripe_account_id,livemode,api_version,payload)
  values(v_id,v_type,p_event->>'account',coalesce((p_event->>'livemode')::boolean,false),p_event->>'api_version',p_event)
  on conflict(stripe_event_id) do nothing;
  if not found then return jsonb_build_object('ok',true,'duplicate',true,'event_id',v_id); end if;
  if v_type='account.updated' then
    v_due:=coalesce(v_obj#>'{requirements,currently_due}','[]'::jsonb);
    update kombax_payments.connected_accounts set details_submitted=coalesce((v_obj->>'details_submitted')::boolean,false),charges_enabled=coalesce((v_obj->>'charges_enabled')::boolean,false),payouts_enabled=coalesce((v_obj->>'payouts_enabled')::boolean,false),requirements_due=v_due,requirements_eventually_due=coalesce(v_obj#>'{requirements,eventually_due}','[]'::jsonb),disabled_reason=v_obj#>>'{requirements,disabled_reason}',status=case when coalesce((v_obj->>'charges_enabled')::boolean,false) and coalesce((v_obj->>'payouts_enabled')::boolean,false) then 'active' when v_obj#>>'{requirements,disabled_reason}' is not null then 'restricted' when jsonb_array_length(v_due)>0 then 'action_required' when coalesce((v_obj->>'details_submitted')::boolean,false) then 'verification_pending' else 'pending' end,updated_at=now() where stripe_account_id=v_obj->>'id';
  else
    v_payment_intent:=case when v_type like 'payment_intent.%' then v_obj->>'id' else v_obj->>'payment_intent' end;
    select * into v_attempt from kombax_payments.payment_attempts a where a.id=nullif(v_obj#>>'{metadata,attempt_id}','')::uuid or (v_payment_intent is not null and a.stripe_payment_intent_id=v_payment_intent) order by a.created_at desc limit 1 for update;
    if found then
      if v_type in('payment_intent.succeeded','checkout.session.completed') and coalesce(v_obj->>'payment_status','paid') in('paid','no_payment_required') then
        update kombax_payments.payment_attempts set status='succeeded',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),updated_at=now() where id=v_attempt.id;
        if v_attempt.cuota_id is not null then
          update public.cuotas set estado='pagada',metodo_pago='tarjeta',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),pagada_en=now(),ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
          insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_en,observaciones)
          select q.club_id,q.id,q.socio_id,v_attempt.amount_minor/100.0,current_date,'tarjeta',coalesce(v_payment_intent,v_id),'validado',now(),'Stripe Checkout · webhook '||v_id from public.cuotas q where q.id=v_attempt.cuota_id and not exists(select 1 from public.pagos p where p.cuota_id=q.id and p.referencia=coalesce(v_payment_intent,v_id));
        elsif v_attempt.order_id is not null then
          update kombax_payments.showcase_orders set status='payment_confirmed',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),updated_at=now() where id=v_attempt.order_id;
          update public.kombax_showcase_elementos e set stock=case when e.stock is null then null else greatest(0,e.stock-i.quantity) end,actualizado_en=now() from kombax_payments.showcase_order_items i where i.order_id=v_attempt.order_id and i.product_id=e.id;
          insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,source,detail) values(v_attempt.order_id,'received','payment_confirmed','stripe',jsonb_build_object('event_id',v_id));
        end if;
      elsif v_type='payment_intent.payment_failed' then
        update kombax_payments.payment_attempts set status='failed',failure_code=v_obj#>>'{last_payment_error,code}',failure_message=left(v_obj#>>'{last_payment_error,message}',500),updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='fallida',ultimo_fallo=left(v_obj#>>'{last_payment_error,message}',500),ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id;
      elsif v_type in('charge.refunded','refund.updated') then
        update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='reembolsada',actualizado_en=now() where id=v_attempt.cuota_id;
        update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_attempt.order_id;
      elsif v_type='charge.dispute.created' then
        update kombax_payments.payment_attempts set status='disputed',updated_at=now() where id=v_attempt.id;
        update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_attempt.order_id;
      end if;
    end if;
  end if;
  update kombax_payments.webhook_events set status=case when v_type in('account.updated','checkout.session.completed','payment_intent.succeeded','payment_intent.payment_failed','charge.refunded','refund.updated','charge.dispute.created','payout.paid','payout.failed','setup_intent.succeeded') then 'processed' else 'ignored' end,processed_at=now() where stripe_event_id=v_id;
  return jsonb_build_object('ok',true,'duplicate',false,'event_id',v_id,'event_type',v_type);
exception when others then
  update kombax_payments.webhook_events set status='failed',error_message=left(sqlerrm,500),processed_at=now() where stripe_event_id=v_id;
  raise;
end $$;

revoke all on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v259(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v259(jsonb) to service_role;
revoke all on function kombax_payments.can_manage_provider(uuid,uuid),kombax_payments.can_pay_fee(uuid,uuid),kombax_payments.resolve_fee_minor(text,integer,text,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_manage_provider(uuid,uuid) to authenticated,service_role;
grant execute on function kombax_payments.can_pay_fee(uuid,uuid) to authenticated,service_role;
grant execute on function kombax_payments.resolve_fee_minor(text,integer,text,uuid) to service_role;

notify pgrst,'reload schema';
commit;
