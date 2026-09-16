-- KOMBAX R62.5 · ticketing RPCs (remote history aligned)

begin;
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
commit;
