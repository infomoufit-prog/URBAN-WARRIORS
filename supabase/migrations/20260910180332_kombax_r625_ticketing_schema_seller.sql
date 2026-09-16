-- KOMBAX R62.5 split migration aligned with remote Supabase history.
-- Derived without semantic changes from original 20260910192600 migration.

begin;
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

commit;
