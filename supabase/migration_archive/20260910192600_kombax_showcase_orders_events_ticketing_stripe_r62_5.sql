-- KOMBAX R62.5 · Showcase orders + KOMBAX Events ticketing + Stripe Connect.
-- Incremental sobre R62.4. Mantiene Direct Charges y platform fee = 0.
-- No activa cobros por sí sola: requiere Connected Account activa en Stripe TEST/LIVE.

begin;

-- ---------------------------------------------------------------------------
-- 1) CONNECT PARA ORGANIZADORES DIRECTOS DE EVENTS (profesional/competidor)
-- Federación reutiliza subject_type=federation; Club reutiliza club; Marca reutiliza
-- showcase_provider. Evitamos una segunda cuenta Stripe para la misma entidad.
-- ---------------------------------------------------------------------------
alter table kombax_payments.connected_accounts
  add column if not exists event_organizer_profile_id uuid references public.perfiles_kombax_directos(id) on delete restrict;

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_subject_type_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_subject_type_check
  check(subject_type in('club','showcase_provider','federation','event_organizer'));

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_check check(
    (subject_type='club' and club_id=subject_id and showcase_provider_id is null and federation_profile_id is null and event_organizer_profile_id is null)
    or (subject_type='showcase_provider' and showcase_provider_id=subject_id and club_id is null and federation_profile_id is null and event_organizer_profile_id is null)
    or (subject_type='federation' and federation_profile_id=subject_id and club_id is null and showcase_provider_id is null and event_organizer_profile_id is null)
    or (subject_type='event_organizer' and event_organizer_profile_id=subject_id and club_id is null and showcase_provider_id is null and federation_profile_id is null)
  );

create index if not exists idx_connected_accounts_event_organizer_r625
  on kombax_payments.connected_accounts(event_organizer_profile_id)
  where event_organizer_profile_id is not null;

create or replace function kombax_payments.can_manage_event_organizer_connect_r625(p_actor uuid,p_profile uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_actor is not null and exists(
    select 1
    from public.perfiles_kombax_directos d
    where d.id=p_profile
      and d.tipo in('profesional','competidor')
      and d.estado='activo'
      and d.verificacion_estado='verificado'
      and (
        d.perfil_id=p_actor
        or exists(
          select 1 from public.kombax_perfil_gestores g
          where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo' and g.rol in('owner','admin')
        )
        or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo)
      )
      and exists(
        select 1 from public.kombax_entitlements e
        where e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id
          and e.capacidad_clave='events.public.organize' and e.activa
          and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
      )
  );
$$;

create or replace function public.app_stripe_connect_status_v259(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_ok boolean:=false;v_row kombax_payments.connected_accounts;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=v_uid and m.activo and m.rol in('direccion','secretaria','economia'));
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(v_uid,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_view_federation_connect_r624(v_uid,p_subject_id);
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(v_uid,p_subject_id);
  end if;
  if not v_ok then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_row from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  if not found then return jsonb_build_object(
    'subject_type',p_subject_type,'subject_id',p_subject_id,'status','not_configured','charges_enabled',false,'payouts_enabled',false,'details_submitted',false,
    'requirements_due','[]'::jsonb,'requirements_eventually_due','[]'::jsonb,'requirements_pending_verification','[]'::jsonb,
    'charge_model','direct','stripe_fees_payer','account','losses_responsibility','stripe','stripe_dashboard_type','full','configuration_compatible',true
  ); end if;
  return jsonb_build_object(
    'subject_type',v_row.subject_type,'subject_id',v_row.subject_id,'status',v_row.status,'charges_enabled',v_row.charges_enabled,'payouts_enabled',v_row.payouts_enabled,
    'details_submitted',v_row.details_submitted,'requirements_due',v_row.requirements_due,'requirements_eventually_due',v_row.requirements_eventually_due,
    'requirements_pending_verification',v_row.requirements_pending_verification,'disabled_reason',v_row.disabled_reason,'updated_at',v_row.updated_at,'last_synced_at',v_row.last_synced_at,
    'stripe_api_version',v_row.stripe_api_version,'charge_model',v_row.charge_model,'stripe_fees_payer',v_row.stripe_fees_payer,
    'losses_responsibility',v_row.losses_responsibility,'stripe_dashboard_type',v_row.stripe_dashboard_type,'configuration_compatible',v_row.configuration_compatible
  );
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
    select m.nombre,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email from public.kombax_showcase_marcas m where m.id=p_subject_id;
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id);
    select d.nombre_publico,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email
      from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado';
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
    select d.nombre_publico,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email
      from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo in('profesional','competidor') and d.estado='activo' and d.verificacion_estado='verificado';
  else
    raise exception 'CONNECTED_SUBJECT_INVALID';
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'display_name',v_name,'email',v_email,
    'stripe_account_id',v_account.stripe_account_id,'status',coalesce(v_account.status,'not_configured'),
    'configuration_compatible',coalesce(v_account.configuration_compatible,true),'charge_model',coalesce(v_account.charge_model,'direct'));
end $$;

create or replace function public.app_stripe_connect_runtime_internal_v261(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_manage boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_ok boolean:=false;v_row kombax_payments.connected_accounts;
begin
  if p_actor_id is null then raise exception 'ACTOR_REQUIRED'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol in('direccion','secretaria','economia') and (not p_manage or m.rol='direccion'));
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=case when p_manage then kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id) else kombax_payments.can_view_federation_connect_r624(p_actor_id,p_subject_id) end;
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_row from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('stripe_account_id',v_row.stripe_account_id,'status',coalesce(v_row.status,'not_configured'),
    'configuration_compatible',coalesce(v_row.configuration_compatible,true));
end $$;

create or replace function public.app_stripe_connect_attach_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_stripe_account_id text)
returns void language plpgsql security definer set search_path='' as $$
declare v_ok boolean:=false;v_existing kombax_payments.connected_accounts;
begin
  if p_actor_id is null or coalesce(p_stripe_account_id,'') !~ '^acct_[A-Za-z0-9]+$' then raise exception 'CONNECTED_ACCOUNT_INVALID'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol='direccion');
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id);
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;

  select * into v_existing from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id for update;
  if found then
    if v_existing.stripe_account_id<>p_stripe_account_id then raise exception 'CONNECTED_ACCOUNT_REASSIGNMENT_FORBIDDEN'; end if;
    update kombax_payments.connected_accounts set charge_model='direct',stripe_fees_payer='account',losses_responsibility='stripe',
      stripe_dashboard_type='full',configuration_compatible=true,updated_at=now() where id=v_existing.id;
    return;
  end if;

  insert into kombax_payments.connected_accounts(subject_type,subject_id,club_id,showcase_provider_id,federation_profile_id,event_organizer_profile_id,stripe_account_id,created_by,
    charge_model,stripe_fees_payer,losses_responsibility,stripe_dashboard_type,configuration_compatible)
  values(p_subject_type,p_subject_id,case when p_subject_type='club' then p_subject_id end,
    case when p_subject_type='showcase_provider' then p_subject_id end,case when p_subject_type='federation' then p_subject_id end,
    case when p_subject_type='event_organizer' then p_subject_id end,p_stripe_account_id,p_actor_id,'direct','account','stripe','full',true);
end $$;

-- ---------------------------------------------------------------------------
-- 2) SHOWCASE · datos operativos del pedido y transiciones seguras
-- ---------------------------------------------------------------------------
alter table kombax_payments.showcase_orders
  add column if not exists buyer_email text,
  add column if not exists shipping_name text,
  add column if not exists shipping_phone text,
  add column if not exists shipping_address jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 3) EVENTS · configuración de venta interna KOMBAX
-- ---------------------------------------------------------------------------
alter table public.kombax_eventos_publicos
  add column if not exists ticketing_enabled boolean not null default false,
  add column if not exists ticketing_mode text not null default 'none',
  add column if not exists ticket_currency text not null default 'EUR',
  add column if not exists ticket_price_minor integer,
  add column if not exists ticket_capacity integer,
  add column if not exists ticket_limit_per_order integer not null default 6;

alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticketing_mode_r625;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticketing_mode_r625 check(ticketing_mode in('none','external','kombax'));
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_currency_r625;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_currency_r625 check(ticket_currency ~ '^[A-Z]{3}$');
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_price_r625;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_price_r625 check(ticket_price_minor is null or ticket_price_minor>0);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_capacity_r625;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_capacity_r625 check(ticket_capacity is null or ticket_capacity between 1 and 1000000);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_limit_r625;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_limit_r625 check(ticket_limit_per_order between 1 and 20);

-- Los eventos existentes con URL de tickets conservan explícitamente su modo externo.
update public.kombax_eventos_publicos
set ticketing_enabled=true,ticketing_mode='external',actualizado_en=now()
where tickets_url is not null and ticketing_mode='none' and ticketing_enabled=false;

create table if not exists kombax_payments.event_ticket_orders(
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  buyer_user_id uuid not null references public.perfiles(id) on delete restrict,
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
  seller_subject_type text not null check(seller_subject_type in('club','showcase_provider','federation','event_organizer')),
  seller_subject_id uuid not null,
  seller_name text not null,
  quantity integer not null check(quantity between 1 and 20),
  unit_amount_minor integer not null check(unit_amount_minor>0),
  amount_total_minor integer not null check(amount_total_minor>0),
  currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'),
  status text not null default 'pending_payment' check(status in('pending_payment','paid','payment_failed','cancelled','refunded','disputed')),
  buyer_email text,
  stripe_checkout_session_id text unique,
  stripe_payment_intent_id text unique,
  expires_at timestamptz not null default (now()+interval '35 minutes'),
  paid_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_event_ticket_orders_buyer_r625 on kombax_payments.event_ticket_orders(buyer_user_id,created_at desc);
create index if not exists idx_event_ticket_orders_event_r625 on kombax_payments.event_ticket_orders(event_id,created_at desc);
create index if not exists idx_event_ticket_orders_reservations_r625 on kombax_payments.event_ticket_orders(event_id,status,expires_at);

create table if not exists kombax_payments.event_tickets(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references kombax_payments.event_ticket_orders(id) on delete restrict,
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
  holder_user_id uuid not null references public.perfiles(id) on delete restrict,
  ticket_index integer not null check(ticket_index between 1 and 20),
  ticket_code text not null unique,
  ticket_token uuid not null default gen_random_uuid() unique,
  status text not null default 'active' check(status in('active','used','refunded','cancelled')),
  used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id,ticket_index)
);
create index if not exists idx_event_tickets_holder_r625 on kombax_payments.event_tickets(holder_user_id,created_at desc);
create index if not exists idx_event_tickets_event_r625 on kombax_payments.event_tickets(event_id,status);

create table if not exists kombax_payments.event_ticket_order_history(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references kombax_payments.event_ticket_orders(id) on delete restrict,
  from_status text,
  to_status text not null,
  actor_user_id uuid references public.perfiles(id) on delete restrict,
  source text not null check(source in('buyer','organizer','stripe','system')),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_event_ticket_history_order_r625 on kombax_payments.event_ticket_order_history(order_id,created_at);

alter table kombax_payments.event_ticket_orders enable row level security;
alter table kombax_payments.event_tickets enable row level security;
alter table kombax_payments.event_ticket_order_history enable row level security;
revoke all on kombax_payments.event_ticket_orders,kombax_payments.event_tickets,kombax_payments.event_ticket_order_history from public,anon,authenticated;
grant all on kombax_payments.event_ticket_orders,kombax_payments.event_tickets,kombax_payments.event_ticket_order_history to service_role;

alter table kombax_payments.payment_attempts
  add column if not exists event_ticket_order_id uuid references kombax_payments.event_ticket_orders(id) on delete restrict;
alter table kombax_payments.payment_attempts drop constraint if exists payment_attempts_kind_check;
alter table kombax_payments.payment_attempts add constraint payment_attempts_kind_check check(kind in('club_fee','showcase_order','event_ticket','setup_method'));

-- Resuelve SIEMPRE el beneficiario desde el organizador principal del evento.
-- Ningún subject/account Stripe llega desde el navegador.
create or replace function kombax_payments.event_seller_r625(p_event uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_eventos_publicos;d public.perfiles_kombax_directos;m public.kombax_showcase_marcas;v_type text;v_id uuid;v_name text;
begin
  select * into strict e from public.kombax_eventos_publicos where id=p_event;
  if e.creador_tipo='club' then
    v_type:='club';v_id:=e.creador_club_id;
    select c.nombre into v_name from public.clubes c where c.id=v_id;
  elsif e.creador_tipo='perfil_directo' then
    select * into strict d from public.perfiles_kombax_directos where id=e.creador_perfil_directo_id and estado='activo' and verificacion_estado='verificado';
    v_name:=d.nombre_publico;
    if d.tipo='federacion' then
      v_type:='federation';v_id:=d.id;
    elsif d.tipo='marca' then
      select * into m from public.kombax_showcase_marcas where perfil_directo_id=d.id and estado='publicada' order by creado_en limit 1;
      if m.id is null then raise exception 'EVENT_BRAND_SHOWCASE_PROVIDER_REQUIRED'; end if;
      v_type:='showcase_provider';v_id:=m.id;v_name:=m.nombre;
    elsif d.tipo in('profesional','competidor') then
      v_type:='event_organizer';v_id:=d.id;
    else
      raise exception 'EVENT_SELLER_PROFILE_NOT_SUPPORTED';
    end if;
  else
    raise exception 'EVENT_SELLER_NOT_RESOLVED';
  end if;
  return jsonb_build_object('subject_type',v_type,'subject_id',v_id,'seller_name',coalesce(nullif(e.organizador_nombre,''),v_name,'KOMBAX Event'));
end $$;

create or replace function public.app_kombax_event_ticketing_manage_status_r625(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_eventos_publicos;v_seller jsonb;v_account kombax_payments.connected_accounts;v_reserved int:=0;v_paid int:=0;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id;
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  select * into v_account from kombax_payments.connected_accounts a
    where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid;
  select coalesce(sum(quantity),0)::int into v_reserved from kombax_payments.event_ticket_orders o
    where o.event_id=p_event_id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()));
  select coalesce(sum(quantity),0)::int into v_paid from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.status='paid';
  return jsonb_build_object(
    'event_id',e.id,'ticketing_enabled',e.ticketing_enabled,'ticketing_mode',e.ticketing_mode,'ticket_currency',e.ticket_currency,
    'ticket_price',case when e.ticket_price_minor is null then null else e.ticket_price_minor/100.0 end,'ticket_capacity',e.ticket_capacity,
    'ticket_limit_per_order',e.ticket_limit_per_order,'tickets_paid',v_paid,'tickets_reserved',v_reserved,
    'tickets_available',case when e.ticket_capacity is null then null else greatest(0,e.ticket_capacity-v_reserved) end,
    'tickets_abren_en',e.tickets_abren_en,'tickets_cierran_en',e.tickets_cierran_en,'tickets_url',e.tickets_url,'tickets_proveedor',e.tickets_proveedor,
    'seller_subject_type',v_seller->>'subject_type','seller_subject_id',v_seller->>'subject_id','seller_name',v_seller->>'seller_name',
    'connect_status',coalesce(v_account.status,'not_configured'),'charges_enabled',coalesce(v_account.charges_enabled,false),'payouts_enabled',coalesce(v_account.payouts_enabled,false)
  );
end $$;

create or replace function public.app_kombax_event_ticketing_mutate_r625(p_event_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.kombax_eventos_publicos;v_mode text:=lower(coalesce(nullif(p_payload->>'mode',''),'none'));v_enabled boolean;v_price numeric;v_minor int;v_capacity int;v_limit int;v_open timestamptz;v_close timestamptz;v_url text;v_provider text;v_seller jsonb;v_account kombax_payments.connected_accounts;
begin
  if auth.uid() is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id for update;
  if v_mode not in('none','external','kombax') then raise exception 'EVENT_TICKETING_MODE_INVALID'; end if;
  v_enabled:=v_mode<>'none';
  v_open:=nullif(p_payload->>'opens_at','')::timestamptz;v_close:=nullif(p_payload->>'closes_at','')::timestamptz;
  if v_open is not null and v_close is not null and v_close<=v_open then raise exception 'EVENT_TICKET_WINDOW_INVALID'; end if;
  v_limit:=greatest(1,least(coalesce(nullif(p_payload->>'limit_per_order','')::int,e.ticket_limit_per_order,6),20));
  v_price:=nullif(p_payload->>'price','')::numeric;
  v_capacity:=nullif(p_payload->>'capacity','')::int;
  v_url:=nullif(btrim(coalesce(p_payload->>'external_url','')),'');v_provider:=nullif(left(btrim(coalesce(p_payload->>'provider','')),120),'');

  if v_mode='kombax' then
    if v_price is null or v_price<=0 then raise exception 'EVENT_TICKET_PRICE_REQUIRED'; end if;
    if v_capacity is null or v_capacity<1 then raise exception 'EVENT_TICKET_CAPACITY_REQUIRED'; end if;
    v_minor:=round(v_price*100)::int;
    v_seller:=kombax_payments.event_seller_r625(p_event_id);
    update public.kombax_eventos_publicos set ticketing_enabled=true,ticketing_mode='kombax',ticket_currency='EUR',ticket_price_minor=v_minor,
      ticket_capacity=v_capacity,ticket_limit_per_order=v_limit,ticket_precio_desde=v_price,tickets_abren_en=v_open,tickets_cierran_en=v_close,
      tickets_proveedor='KOMBAX · Stripe',tickets_url=null,entradas_info=left(coalesce(p_payload->>'info',entradas_info,''),700),actualizado_en=now()
    where id=p_event_id returning * into e;
  elsif v_mode='external' then
    if v_url is null or v_url !~* '^https://[^[:space:]]+$' then raise exception 'EVENT_TICKET_EXTERNAL_URL_REQUIRED'; end if;
    update public.kombax_eventos_publicos set ticketing_enabled=true,ticketing_mode='external',ticket_price_minor=null,ticket_capacity=null,
      ticket_limit_per_order=v_limit,ticket_precio_desde=v_price,tickets_abren_en=v_open,tickets_cierran_en=v_close,tickets_proveedor=coalesce(v_provider,'Proveedor externo'),
      tickets_url=v_url,entradas_info=left(coalesce(p_payload->>'info',entradas_info,''),700),actualizado_en=now()
    where id=p_event_id returning * into e;
    v_seller:=kombax_payments.event_seller_r625(p_event_id);
  else
    update public.kombax_eventos_publicos set ticketing_enabled=false,ticketing_mode='none',ticket_price_minor=null,ticket_capacity=null,
      ticket_precio_desde=null,tickets_abren_en=null,tickets_cierran_en=null,tickets_proveedor='',tickets_url=null,
      entradas_info=left(coalesce(p_payload->>'info',entradas_info,''),700),actualizado_en=now()
    where id=p_event_id returning * into e;
    v_seller:=kombax_payments.event_seller_r625(p_event_id);
  end if;

  select * into v_account from kombax_payments.connected_accounts a
    where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object(
    'event_id',p_event_id,'ticketing_enabled',e.ticketing_enabled,'ticketing_mode',e.ticketing_mode,'seller_subject_type',v_seller->>'subject_type',
    'seller_subject_id',v_seller->>'subject_id','connect_status',coalesce(v_account.status,'not_configured')));
end $$;

-- Estado de entradas: venta KOMBAX o enlace externo conservan el mismo contrato de UI.
create or replace function public.app_kombax_evento_entradas_estado_v173(p_evento_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case
    when e.id is null then null
    when e.estado in ('cancelado','finalizado') then 'cerradas'
    when not e.ticketing_enabled or e.ticketing_mode='none' then 'no_disponible'
    when e.ticketing_mode='external' and e.tickets_url is null then 'no_disponible'
    when e.ticketing_mode='kombax' and (e.ticket_price_minor is null or e.ticket_capacity is null) then 'no_disponible'
    when e.tickets_abren_en is not null and now()<e.tickets_abren_en then 'proximamente'
    when e.tickets_cierran_en is not null and now()>e.tickets_cierran_en then 'cerradas'
    when e.ticketing_mode='kombax' and e.ticket_capacity <= coalesce((select sum(o.quantity)::int from kombax_payments.event_ticket_orders o where o.event_id=e.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()))),0) then 'agotadas'
    else 'venta'
  end
  from public.kombax_eventos_publicos e where e.id=p_evento_id limit 1;
$$;

create or replace function public.app_kombax_event_ticketing_public_r625(p_event_ids uuid[])
returns table(event_id uuid,ticketing_enabled boolean,ticketing_mode text,ticket_price numeric,ticket_currency text,ticket_capacity integer,tickets_paid integer,tickets_available integer,ticket_limit_per_order integer,entradas_estado text)
language sql stable security definer set search_path='' as $$
  select e.id,e.ticketing_enabled,e.ticketing_mode,
    case when e.ticketing_mode='kombax' and e.ticket_price_minor is not null then e.ticket_price_minor/100.0 else e.ticket_precio_desde end,
    e.ticket_currency,e.ticket_capacity,
    coalesce((select sum(o.quantity)::int from kombax_payments.event_ticket_orders o where o.event_id=e.id and o.status='paid'),0),
    case when e.ticket_capacity is null then null else greatest(0,e.ticket_capacity-coalesce((select sum(o.quantity)::int from kombax_payments.event_ticket_orders o where o.event_id=e.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()))),0)) end,
    e.ticket_limit_per_order,public.app_kombax_evento_entradas_estado_v173(e.id)
  from public.kombax_eventos_publicos e
  where e.id=any(coalesce(p_event_ids,'{}'::uuid[]))
    and (public.app_kombax_event_can_view_v236(e.id) or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)));
$$;

create or replace function public.app_kombax_my_event_tickets_r625(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'order_id',o.id,'order_number',o.order_number,'event_id',o.event_id,'event_name',e.nombre,'event_slug',e.slug,'event_date',e.fecha_inicio,
    'venue',e.lugar_nombre,'quantity',o.quantity,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,'seller_name',o.seller_name,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'status',t.status,'ticket_index',t.ticket_index) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.event_ticket_orders where buyer_user_id=auth.uid() order by created_at desc limit least(greatest(p_limit,1),200)) o
  join public.kombax_eventos_publicos e on e.id=o.event_id;
$$;

create or replace function public.app_kombax_event_ticket_sales_r625(p_event_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_orders jsonb;v_paid int;v_revenue bigint;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select coalesce(sum(quantity),0)::int,coalesce(sum(amount_total_minor),0)::bigint into v_paid,v_revenue from kombax_payments.event_ticket_orders where event_id=p_event_id and status='paid';
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'order_number',o.order_number,'quantity',o.quantity,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,'buyer_email',o.buyer_email,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'status',t.status) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb) into v_orders
  from (select * from kombax_payments.event_ticket_orders where event_id=p_event_id order by created_at desc limit least(greatest(p_limit,1),500)) o;
  return jsonb_build_object('event_id',p_event_id,'tickets_paid',v_paid,'revenue_total',v_revenue/100.0,'orders',v_orders);
end $$;

create or replace function public.app_kombax_event_ticket_mutate_r625(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_ticket kombax_payments.event_tickets;v_event uuid;
begin
  if auth.uid() is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if p_operation<>'event.ticket.use' then raise exception 'EVENT_TICKET_OPERATION_INVALID'; end if;
  select * into strict v_ticket from kombax_payments.event_tickets where id=(p_payload->>'ticket_id')::uuid for update;
  v_event:=v_ticket.event_id;
  if not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if v_ticket.status<>'active' then raise exception 'EVENT_TICKET_NOT_ACTIVE'; end if;
  update kombax_payments.event_tickets set status='used',used_at=now(),updated_at=now() where id=v_ticket.id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('ticket_id',v_ticket.id,'status','used'));
end $$;

-- ---------------------------------------------------------------------------
-- 4) CHECKOUT · nuevo kind event_ticket + shipping para Showcase
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_checkout_prepare_internal_v259(p_actor_id uuid,p_kind text,p_reference_id uuid,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_fee public.cuotas;v_item public.kombax_showcase_elementos;
  v_provider public.kombax_showcase_marcas;v_order kombax_payments.showcase_orders;v_ticket_order kombax_payments.event_ticket_orders;
  v_event public.kombax_eventos_publicos;v_seller jsonb;v_amount int;v_platform int;v_qty int:=greatest(1,least(coalesce(p_quantity,1),100));
  v_name text;v_seller_name text;v_reserved int:=0;v_collect_shipping boolean:=false;
begin
  select * into v_attempt from kombax_payments.payment_attempts where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then
    if v_attempt.kind<>p_kind
      or (p_kind='club_fee' and v_attempt.cuota_id is distinct from p_reference_id)
      or (p_kind='showcase_order' and nullif(v_attempt.metadata->>'product_id','')::uuid is distinct from p_reference_id)
      or (p_kind='event_ticket' and nullif(v_attempt.metadata->>'event_id','')::uuid is distinct from p_reference_id) then
      raise exception 'CHECKOUT_REQUEST_ID_REUSED';
    end if;
    select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
    if v_attempt.cuota_id is not null then
      select q.concepto into v_name from public.cuotas q where q.id=v_attempt.cuota_id;
    elsif v_attempt.order_id is not null then
      select o.seller_name,i.product_name,(e.fulfillment in('seller_shipping','seller_shipping_or_pickup')) into v_seller_name,v_name,v_collect_shipping
      from kombax_payments.showcase_orders o left join kombax_payments.showcase_order_items i on i.order_id=o.id
      left join public.kombax_showcase_elementos e on e.id=i.product_id where o.id=v_attempt.order_id limit 1;
    elsif v_attempt.event_ticket_order_id is not null then
      select o.seller_name,e.nombre||' · '||o.quantity||case when o.quantity=1 then ' entrada' else ' entradas' end into v_seller_name,v_name
      from kombax_payments.event_ticket_orders o join public.kombax_eventos_publicos e on e.id=o.event_id where o.id=v_attempt.event_ticket_order_id;
    end if;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_attempt.order_id,'event_ticket_order_id',v_attempt.event_ticket_order_id,'kind',v_attempt.kind,'status',v_attempt.status,
      'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id,'stripe_account_id',v_account.stripe_account_id,
      'amount_minor',v_attempt.amount_minor,'platform_fee_minor',v_attempt.platform_fee_minor,'currency',lower(v_attempt.currency),
      'name',coalesce(v_name,'Pago KOMBAX'),'seller_name',v_seller_name,'collect_shipping',v_collect_shipping);
  end if;

  if p_kind='club_fee' then
    if not kombax_payments.can_pay_fee(p_actor_id,p_reference_id) then raise exception 'FEE_PAYMENT_DENIED'; end if;
    select * into strict v_fee from public.cuotas where id=p_reference_id for update;
    if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta') then raise exception 'FEE_NOT_PAYABLE'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='club' and subject_id=v_fee.club_id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_fee.importe*100)::int;v_platform:=kombax_payments.resolve_fee_minor('club_fee',v_amount,'club',v_fee.club_id);
    if v_platform<>0 then raise exception 'PLATFORM_TRANSACTION_FEE_DISABLED'; end if;
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,v_platform,'EUR',jsonb_build_object('concept',v_fee.concepto)) returning * into v_attempt;
    update public.cuotas set estado='procesando',metodo_pago='stripe_checkout',actualizado_en=now() where id=v_fee.id;
    return jsonb_build_object('attempt_id',v_attempt.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_fee.concepto,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);

  elsif p_kind='showcase_order' then
    v_qty:=greatest(1,least(coalesce(p_quantity,1),100));
    select * into strict v_item from public.kombax_showcase_elementos where id=p_reference_id and estado='publicado' and commerce_enabled for update;
    if v_item.precio_venta is null or v_item.precio_venta<=0 or (v_item.stock is not null and v_item.stock<v_qty) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=v_item.marca_id and estado='publicada';
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=v_provider.id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_item.precio_venta*100)::int*v_qty;v_platform:=kombax_payments.resolve_fee_minor('showcase',v_amount,'showcase_provider',v_provider.id);
    if v_platform<>0 then raise exception 'PLATFORM_TRANSACTION_FEE_DISABLED'; end if;
    insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,buyer_email,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,(select u.email from auth.users u where u.id=p_actor_id),v_amount,'EUR') returning * into v_order;
    insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor) values(v_order.id,v_item.id,v_item.nombre,v_qty,round(v_item.precio_venta*100)::int);
    insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source) values(v_order.id,'received',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_order.id,v_amount,v_platform,'EUR',jsonb_build_object('product_id',v_item.id,'seller',v_provider.nombre)) returning * into v_attempt;
    v_collect_shipping:=v_item.fulfillment in('seller_shipping','seller_shipping_or_pickup');
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_item.nombre,'seller_name',v_provider.nombre,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',v_collect_shipping);

  elsif p_kind='event_ticket' then
    select * into strict v_event from public.kombax_eventos_publicos where id=p_reference_id for update;
    if not v_event.ticketing_enabled or v_event.ticketing_mode<>'kombax' then raise exception 'EVENT_TICKETING_NOT_ENABLED'; end if;
    if v_event.estado in('borrador','cancelado','finalizado') then raise exception 'EVENT_TICKET_NOT_ON_SALE'; end if;
    if v_event.tickets_abren_en is not null and now()<v_event.tickets_abren_en then raise exception 'EVENT_TICKET_SALE_NOT_OPEN'; end if;
    if v_event.tickets_cierran_en is not null and now()>v_event.tickets_cierran_en then raise exception 'EVENT_TICKET_SALE_CLOSED'; end if;
    if v_event.ticket_price_minor is null or v_event.ticket_capacity is null then raise exception 'EVENT_TICKETING_CONFIGURATION_REQUIRED'; end if;
    v_qty:=greatest(1,least(coalesce(p_quantity,1),v_event.ticket_limit_per_order,20));
    select coalesce(sum(o.quantity),0)::int into v_reserved from kombax_payments.event_ticket_orders o
      where o.event_id=v_event.id and (o.status='paid' or (o.status='pending_payment' and o.expires_at>now()));
    if v_reserved+v_qty>v_event.ticket_capacity then raise exception 'EVENT_TICKETS_SOLD_OUT'; end if;
    v_seller:=kombax_payments.event_seller_r625(v_event.id);
    select * into strict v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid
      and a.status='active' and a.charges_enabled and a.payouts_enabled and a.configuration_compatible and a.charge_model='direct';
    v_amount:=v_event.ticket_price_minor*v_qty;v_platform:=0;v_seller_name:=v_seller->>'seller_name';
    insert into kombax_payments.event_ticket_orders(order_number,buyer_user_id,event_id,seller_subject_type,seller_subject_id,seller_name,quantity,unit_amount_minor,amount_total_minor,currency,buyer_email)
    values('KXT-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_event.id,v_seller->>'subject_type',(v_seller->>'subject_id')::uuid,v_seller_name,v_qty,v_event.ticket_price_minor,v_amount,v_event.ticket_currency,(select u.email from auth.users u where u.id=p_actor_id)) returning * into v_ticket_order;
    insert into kombax_payments.event_ticket_order_history(order_id,to_status,actor_user_id,source) values(v_ticket_order.id,'pending_payment',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,event_ticket_order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_ticket_order.id,v_amount,0,v_event.ticket_currency,jsonb_build_object('event_id',v_event.id,'ticket_order_id',v_ticket_order.id,'quantity',v_qty,'seller',v_seller_name)) returning * into v_attempt;
    return jsonb_build_object('attempt_id',v_attempt.id,'event_ticket_order_id',v_ticket_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',0,
      'currency',lower(v_event.ticket_currency),'name',v_event.nombre||' · '||v_qty||case when v_qty=1 then ' entrada' else ' entradas' end,'seller_name',v_seller_name,'stripe_account_id',v_account.stripe_account_id,'collect_shipping',false);
  else
    raise exception 'CHECKOUT_KIND_INVALID';
  end if;
end $$;

create or replace function public.app_stripe_attempt_attach_internal_v259(p_attempt_id uuid,p_checkout_session_id text,p_payment_intent_id text default null,p_setup_intent_id text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  update kombax_payments.payment_attempts set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,stripe_setup_intent_id=p_setup_intent_id,status='checkout_created',updated_at=now() where id=p_attempt_id;
  update kombax_payments.showcase_orders o set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,updated_at=now()
    from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.order_id=o.id;
  update kombax_payments.event_ticket_orders o set stripe_checkout_session_id=p_checkout_session_id,stripe_payment_intent_id=p_payment_intent_id,updated_at=now()
    from kombax_payments.payment_attempts a where a.id=p_attempt_id and a.event_ticket_order_id=o.id;
end $$;

-- ---------------------------------------------------------------------------
-- 5) SHOWCASE · RPC de pedidos enriquecido + transiciones
-- ---------------------------------------------------------------------------
create or replace function public.app_showcase_my_orders_v259(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'seller',o.seller_name,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,'status',o.status,
    'carrier',o.carrier,'tracking_number',o.tracking_number,'tracking_url',o.tracking_url,'created_at',o.created_at,'updated_at',o.updated_at,
    'items',coalesce((select jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount',i.unit_amount_minor/100.0) order by i.product_name) from kombax_payments.showcase_order_items i where i.order_id=o.id),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,'to_status',h.to_status,'source',h.source,'created_at',h.created_at) order by h.created_at) from kombax_payments.showcase_order_history h where h.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.showcase_orders where buyer_user_id=auth.uid() order by created_at desc limit least(greatest(p_limit,1),200)) o;
$$;

create or replace function public.app_showcase_seller_orders_v259(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not kombax_payments.can_manage_provider(auth.uid(),p_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'order_number',o.order_number,'seller_provider_id',o.seller_provider_id,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,'status',o.status,
    'buyer_email',o.buyer_email,'shipping_name',o.shipping_name,'shipping_phone',o.shipping_phone,'shipping_address',o.shipping_address,
    'carrier',o.carrier,'tracking_number',o.tracking_number,'tracking_url',o.tracking_url,'created_at',o.created_at,'updated_at',o.updated_at,
    'items',coalesce((select jsonb_agg(jsonb_build_object('product_id',i.product_id,'name',i.product_name,'quantity',i.quantity,'unit_amount',i.unit_amount_minor/100.0) order by i.product_name) from kombax_payments.showcase_order_items i where i.order_id=o.id),'[]'::jsonb),
    'history',coalesce((select jsonb_agg(jsonb_build_object('from_status',h.from_status,'to_status',h.to_status,'source',h.source,'created_at',h.created_at) order by h.created_at) from kombax_payments.showcase_order_history h where h.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.showcase_orders where seller_provider_id=p_provider_id order by created_at desc limit least(greatest(p_limit,1),200)) o);
end $$;

create or replace function public.app_showcase_order_mutate_v259(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_order kombax_payments.showcase_orders;v_incident kombax_payments.showcase_incidents;v_status text;v_message text;v_allowed boolean:=false;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_order from kombax_payments.showcase_orders where id=(p_payload->>'order_id')::uuid for update;
  if p_operation='showcase.order.status' then
    if not kombax_payments.can_manage_provider(v_uid,v_order.seller_provider_id) then raise exception 'SELLER_ACCESS_DENIED'; end if;
    v_status:=p_payload->>'status';
    v_allowed:=case
      when v_order.status='received' then v_status in('cancelled','incident')
      when v_order.status='payment_confirmed' then v_status in('preparing','delivered','cancelled','incident')
      when v_order.status='preparing' then v_status in('shipped','delivered','cancelled','incident')
      when v_order.status='shipped' then v_status in('delivered','incident')
      when v_order.status='delivered' then v_status='incident'
      else false end;
    if not v_allowed then raise exception 'ORDER_STATUS_TRANSITION_INVALID'; end if;
    if v_status='shipped' and nullif(btrim(p_payload->>'tracking_number'),'') is null then raise exception 'TRACKING_REQUIRED'; end if;
    update kombax_payments.showcase_orders set status=v_status,
      carrier=case when v_status='shipped' then nullif(btrim(p_payload->>'carrier'),'') else carrier end,
      tracking_number=case when v_status='shipped' then nullif(btrim(p_payload->>'tracking_number'),'') else tracking_number end,
      tracking_url=case when v_status='shipped' then nullif(btrim(p_payload->>'tracking_url'),'') else tracking_url end,updated_at=now()
    where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
      values(v_order.id,v_order.status,v_status,v_uid,'seller',jsonb_build_object('carrier',p_payload->>'carrier','tracking_number',p_payload->>'tracking_number'));
  elsif p_operation='showcase.incident.open' then
    if v_order.buyer_user_id<>v_uid then raise exception 'BUYER_ACCESS_DENIED'; end if;
    v_message:=btrim(coalesce(p_payload->>'message',''));if char_length(v_message)<3 then raise exception 'INCIDENT_MESSAGE_REQUIRED'; end if;
    insert into kombax_payments.showcase_incidents(order_id,buyer_user_id,seller_provider_id,reason) values(v_order.id,v_uid,v_order.seller_provider_id,left(v_message,120)) returning * into v_incident;
    insert into kombax_payments.showcase_incident_messages(incident_id,author_user_id,message) values(v_incident.id,v_uid,v_message);
    update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_order.id;
    insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,actor_user_id,source) values(v_order.id,v_order.status,'incident',v_uid,'buyer');
    v_status:='incident';
  else raise exception 'ORDER_OPERATION_INVALID'; end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('order_id',v_order.id,'status',v_status,'incident_id',v_incident.id));
end $$;

-- ---------------------------------------------------------------------------
-- 6) WEBHOOK · cuotas + Showcase + ticketing con idempotencia común
-- ---------------------------------------------------------------------------
create or replace function public.app_stripe_event_apply_v260(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_id text:=p_event->>'id';v_type text:=p_event->>'type';v_obj jsonb:=p_event#>'{data,object}';v_attempt kombax_payments.payment_attempts;
  v_due jsonb;v_payment_intent text;v_attempt_id uuid;v_expected text;v_actual text:=p_event->>'account';v_ticket_order kombax_payments.event_ticket_orders;
  v_shipping jsonb;v_buyer_email text;
begin
  if coalesce(v_actual,'')='' and v_type<>'account.updated' then raise exception 'CONNECTED_ACCOUNT_EVENT_REQUIRED'; end if;
  if coalesce(v_obj#>>'{metadata,attempt_id}','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then v_attempt_id:=(v_obj#>>'{metadata,attempt_id}')::uuid; end if;
  v_payment_intent:=case when v_type like 'payment_intent.%' then v_obj->>'id' else v_obj->>'payment_intent' end;
  select a.stripe_account_id into v_expected from kombax_payments.payment_attempts p join kombax_payments.connected_accounts a on a.id=p.connected_account_id
    where (v_attempt_id is not null and p.id=v_attempt_id) or (v_payment_intent is not null and p.stripe_payment_intent_id=v_payment_intent) order by p.created_at desc limit 1;
  if v_expected is not null and v_actual is distinct from v_expected then raise exception 'STRIPE_CONNECTED_ACCOUNT_MISMATCH'; end if;

  insert into kombax_payments.webhook_events(stripe_event_id,event_type,stripe_account_id,livemode,api_version,payload)
  values(v_id,v_type,v_actual,coalesce((p_event->>'livemode')::boolean,false),p_event->>'api_version',p_event)
  on conflict(stripe_event_id) do nothing;
  if not found then return jsonb_build_object('ok',true,'duplicate',true,'event_id',v_id); end if;

  if v_type='account.updated' then
    v_due:=coalesce(v_obj#>'{requirements,currently_due}','[]'::jsonb);
    update kombax_payments.connected_accounts set details_submitted=coalesce((v_obj->>'details_submitted')::boolean,false),charges_enabled=coalesce((v_obj->>'charges_enabled')::boolean,false),payouts_enabled=coalesce((v_obj->>'payouts_enabled')::boolean,false),requirements_due=v_due,requirements_eventually_due=coalesce(v_obj#>'{requirements,eventually_due}','[]'::jsonb),disabled_reason=v_obj#>>'{requirements,disabled_reason}',status=case when coalesce((v_obj->>'charges_enabled')::boolean,false) and coalesce((v_obj->>'payouts_enabled')::boolean,false) then 'active' when v_obj#>>'{requirements,disabled_reason}' is not null then 'restricted' when jsonb_array_length(v_due)>0 then 'action_required' when coalesce((v_obj->>'details_submitted')::boolean,false) then 'verification_pending' else 'pending' end,updated_at=now() where stripe_account_id=v_obj->>'id';
  else
    select * into v_attempt from kombax_payments.payment_attempts a where (v_attempt_id is not null and a.id=v_attempt_id) or (v_payment_intent is not null and a.stripe_payment_intent_id=v_payment_intent) order by a.created_at desc limit 1 for update;
    if found then
      if v_type in('payment_intent.succeeded','checkout.session.completed') and coalesce(v_obj->>'payment_status','paid') in('paid','no_payment_required') then
        update kombax_payments.payment_attempts set status='succeeded',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),updated_at=now() where id=v_attempt.id;
        if v_attempt.cuota_id is not null then
          update public.cuotas set estado='pagada',metodo_pago='tarjeta',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),pagada_en=now(),ultimo_fallo=null,actualizado_en=now() where id=v_attempt.cuota_id;
          insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,validado_en,observaciones)
          select q.club_id,q.id,q.socio_id,v_attempt.amount_minor/100.0,current_date,'tarjeta',coalesce(v_payment_intent,v_id),'validado',now(),'Stripe Checkout · webhook '||v_id from public.cuotas q where q.id=v_attempt.cuota_id and not exists(select 1 from public.pagos p where p.cuota_id=q.id and p.referencia=coalesce(v_payment_intent,v_id));
        elsif v_attempt.order_id is not null then
          v_shipping:=coalesce(v_obj#>'{collected_information,shipping_details}',v_obj->'shipping_details',v_obj#>'{customer_details,address}','{}'::jsonb);
          v_buyer_email:=coalesce(v_obj#>>'{customer_details,email}',v_obj->>'customer_email');
          update kombax_payments.showcase_orders set status='payment_confirmed',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),
            buyer_email=coalesce(v_buyer_email,buyer_email),shipping_name=coalesce(v_obj#>>'{collected_information,shipping_details,name}',v_obj#>>'{shipping_details,name}',v_obj#>>'{customer_details,name}',shipping_name),
            shipping_phone=coalesce(v_obj#>>'{customer_details,phone}',shipping_phone),
            shipping_address=case when jsonb_typeof(v_shipping)='object' then v_shipping else shipping_address end,updated_at=now()
          where id=v_attempt.order_id and status='received';
          if found then
            update public.kombax_showcase_elementos e set stock=case when e.stock is null then null else greatest(0,e.stock-i.quantity) end,actualizado_en=now() from kombax_payments.showcase_order_items i where i.order_id=v_attempt.order_id and i.product_id=e.id;
            insert into kombax_payments.showcase_order_history(order_id,from_status,to_status,source,detail) values(v_attempt.order_id,'received','payment_confirmed','stripe',jsonb_build_object('event_id',v_id));
          end if;
        elsif v_attempt.event_ticket_order_id is not null then
          v_buyer_email:=coalesce(v_obj#>>'{customer_details,email}',v_obj->>'customer_email');
          update kombax_payments.event_ticket_orders set status='paid',stripe_payment_intent_id=coalesce(v_payment_intent,stripe_payment_intent_id),buyer_email=coalesce(v_buyer_email,buyer_email),paid_at=coalesce(paid_at,now()),updated_at=now()
            where id=v_attempt.event_ticket_order_id and status in('pending_payment','payment_failed') returning * into v_ticket_order;
          if found then
            insert into kombax_payments.event_ticket_order_history(order_id,from_status,to_status,source,detail) values(v_ticket_order.id,'pending_payment','paid','stripe',jsonb_build_object('event_id',v_id));
            insert into kombax_payments.event_tickets(order_id,event_id,holder_user_id,ticket_index,ticket_code)
            select v_ticket_order.id,v_ticket_order.event_id,v_ticket_order.buyer_user_id,g,
              'KXT-'||upper(substr(replace(v_ticket_order.id::text,'-',''),1,8))||'-'||lpad(g::text,2,'0')
            from generate_series(1,v_ticket_order.quantity) g on conflict(order_id,ticket_index) do nothing;
          end if;
        end if;
      elsif v_type='payment_intent.payment_failed' then
        update kombax_payments.payment_attempts set status='failed',failure_code=v_obj#>>'{last_payment_error,code}',failure_message=left(v_obj#>>'{last_payment_error,message}',500),updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='fallida',ultimo_fallo=left(v_obj#>>'{last_payment_error,message}',500),ultimo_fallo_en=now(),actualizado_en=now() where id=v_attempt.cuota_id;
        update kombax_payments.event_ticket_orders set status='payment_failed',updated_at=now() where id=v_attempt.event_ticket_order_id and status='pending_payment';
      elsif v_type in('charge.refunded','refund.updated') then
        update kombax_payments.payment_attempts set status='refunded',updated_at=now() where id=v_attempt.id;
        update public.cuotas set estado='reembolsada',actualizado_en=now() where id=v_attempt.cuota_id;
        update kombax_payments.showcase_orders set status='refunded',updated_at=now() where id=v_attempt.order_id;
        update kombax_payments.event_ticket_orders set status='refunded',refunded_at=now(),updated_at=now() where id=v_attempt.event_ticket_order_id;
        update kombax_payments.event_tickets set status='refunded',updated_at=now() where order_id=v_attempt.event_ticket_order_id and status<>'refunded';
      elsif v_type='charge.dispute.created' then
        update kombax_payments.payment_attempts set status='disputed',updated_at=now() where id=v_attempt.id;
        update kombax_payments.showcase_orders set status='incident',updated_at=now() where id=v_attempt.order_id;
        update kombax_payments.event_ticket_orders set status='disputed',updated_at=now() where id=v_attempt.event_ticket_order_id;
      end if;
    end if;
  end if;
  update kombax_payments.webhook_events set status=case when v_type in('account.updated','checkout.session.completed','payment_intent.succeeded','payment_intent.payment_failed','charge.refunded','refund.updated','charge.dispute.created','payout.paid','payout.failed','setup_intent.succeeded') then 'processed' else 'ignored' end,processed_at=now() where stripe_event_id=v_id;
  return jsonb_build_object('ok',true,'duplicate',false,'event_id',v_id,'event_type',v_type);
exception when others then
  update kombax_payments.webhook_events set status='failed',error_message=left(sqlerrm,500),processed_at=now() where stripe_event_id=v_id;
  raise;
end $$;

-- ---------------------------------------------------------------------------
-- Privilegios
-- ---------------------------------------------------------------------------
revoke all on function kombax_payments.can_manage_event_organizer_connect_r625(uuid,uuid),kombax_payments.event_seller_r625(uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_manage_event_organizer_connect_r625(uuid,uuid),kombax_payments.event_seller_r625(uuid) to service_role;

revoke all on function public.app_kombax_event_ticketing_manage_status_r625(uuid),public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid),public.app_kombax_my_event_tickets_r625(integer),public.app_kombax_event_ticket_sales_r625(uuid,integer),public.app_kombax_event_ticket_mutate_r625(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_manage_status_r625(uuid),public.app_kombax_event_ticketing_mutate_r625(uuid,jsonb,uuid),public.app_kombax_my_event_tickets_r625(integer),public.app_kombax_event_ticket_sales_r625(uuid,integer),public.app_kombax_event_ticket_mutate_r625(text,jsonb,uuid) to authenticated;

revoke all on function public.app_kombax_event_ticketing_public_r625(uuid[]),public.app_kombax_evento_entradas_estado_v173(uuid) from public;
grant execute on function public.app_kombax_event_ticketing_public_r625(uuid[]),public.app_kombax_evento_entradas_estado_v173(uuid) to anon,authenticated;

revoke all on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v260(jsonb) from public,anon,authenticated;
grant execute on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid),public.app_stripe_attempt_attach_internal_v259(uuid,text,text,text),public.app_stripe_event_apply_v260(jsonb) to service_role;

revoke all on function public.app_showcase_my_orders_v259(integer),public.app_showcase_seller_orders_v259(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid),public.app_stripe_connect_status_v259(text,uuid) from public,anon;
grant execute on function public.app_showcase_my_orders_v259(integer),public.app_showcase_seller_orders_v259(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid),public.app_stripe_connect_status_v259(text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
