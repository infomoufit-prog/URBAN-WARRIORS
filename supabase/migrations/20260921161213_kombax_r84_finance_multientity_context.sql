begin;
create or replace function public.app_kombax_finance_context_r84(p_subject_type text,p_subject_id uuid,p_limit integer default 200)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid := (select auth.uid());v_limit integer := least(500,greatest(20,coalesce(p_limit,200)));
  v_account kombax_payments.connected_accounts;v_transactions jsonb := '[]'::jsonb;v_orders jsonb := '[]'::jsonb;v_ticketing jsonb := '[]'::jsonb;
  v_debt jsonb := '[]'::jsonb;v_receipts jsonb := '[]'::jsonb;v_summary jsonb := '{}'::jsonb;v_methods jsonb := '{}'::jsonb;v_account_id uuid;v_stripe_account text;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_subject_type not in ('club','showcase_provider','federation','event_organizer') or p_subject_id is null then raise exception 'FINANCE_SUBJECT_INVALID'; end if;
  if not kombax_payments.can_access_subject_r80(v_actor,p_subject_type,p_subject_id,false) then raise exception 'FINANCE_SUBJECT_FORBIDDEN'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id order by a.updated_at desc limit 1;
  if found then v_account_id:=v_account.id;v_stripe_account:=v_account.stripe_account_id; end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.occurred_at desc),'[]'::jsonb) into v_transactions from (
    select * from (
      select a.created_at occurred_at,'stripe_checkout'::text source,a.kind::text category,a.id::text reference,a.amount_minor::bigint amount_minor,upper(a.currency)::text currency,a.status::text status,
        case when a.metadata->>'payment_method' is not null then a.metadata->>'payment_method' when a.kind in ('club_fee','showcase_order','event_ticket') then 'card_online' else 'stripe' end::text payment_method,
        a.order_id,a.event_ticket_order_id,a.cuota_id,a.metadata from kombax_payments.payment_attempts a where v_account_id is not null and a.connected_account_id=v_account_id
      union all
      select s.created_at,'terminal'::text,s.source_kind::text,s.id::text,s.amount_minor::bigint,upper(s.currency)::text,s.status::text,coalesce(nullif(s.channel,''),'card_present')::text,
        case when s.source_kind='showcase_order' then s.reference_id else null end,case when s.source_kind='event_ticket' then s.reference_id else null end,case when s.source_kind='club_fee' then s.reference_id else null end,s.metadata
      from kombax_payments.terminal_sales_r81 s where s.subject_type=p_subject_type and s.subject_id=p_subject_id
      union all
      select p.creado_en,'club_manual'::text,'club_fee'::text,p.id::text,round(p.importe*100)::bigint,'EUR'::text,p.estado_validacion::text,coalesce(nullif(p.metodo,''),'manual')::text,
        null::uuid,null::uuid,p.cuota_id,jsonb_build_object('referencia',p.referencia,'observaciones',p.observaciones)
      from public.pagos p where p_subject_type='club' and p.club_id=p_subject_id
    ) u order by occurred_at desc limit v_limit
  ) q;
  if p_subject_type='showcase_provider' then
    select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at desc),'[]'::jsonb) into v_orders from (
      select id,order_number,seller_name,amount_total_minor,currency,status,created_at,updated_at,stripe_payment_intent_id from kombax_payments.showcase_orders where seller_provider_id=p_subject_id order by created_at desc limit v_limit
    ) o;
  end if;
  if p_subject_type in ('event_organizer','federation') then
    select coalesce(jsonb_agg(to_jsonb(o) order by o.created_at desc),'[]'::jsonb) into v_ticketing from (
      select id,order_number,event_id,seller_name,quantity,amount_total_minor,buyer_service_fee_minor,checkout_total_minor,currency,status,paid_at,refunded_at,created_at from kombax_payments.event_ticket_orders where seller_subject_type=p_subject_type and seller_subject_id=p_subject_id order by created_at desc limit v_limit
    ) o;
  end if;
  if p_subject_type='club' then
    select coalesce(jsonb_agg(to_jsonb(d) order by d.vencimiento asc nulls last),'[]'::jsonb) into v_debt from (
      select q.id,q.socio_id,q.concepto,q.importe,q.vencimiento,q.estado,q.metodo_pago,q.stripe_payment_intent_id,q.pagada_en from public.cuotas q where q.club_id=p_subject_id and q.estado::text in ('pendiente','vencida','parcialmente_pagada','fallida','disputada') order by q.vencimiento asc nulls last limit v_limit
    ) d;
    select coalesce(jsonb_agg(to_jsonb(r) order by r.emitido_en desc),'[]'::jsonb) into v_receipts from (
      select r.id,r.numero,r.importe,r.fecha_pago,r.emitido_en,r.anulado_en,r.metodo,null::text as referencia,r.socio_nombre,r.actividad as concepto from public.recibos_cuota r where r.club_id=p_subject_id order by r.emitido_en desc limit v_limit
    ) r;
  end if;
  select jsonb_build_object('transaction_count',coalesce(jsonb_array_length(v_transactions),0),'order_count',coalesce(jsonb_array_length(v_orders),0),'ticket_order_count',coalesce(jsonb_array_length(v_ticketing),0),
    'debt_count',coalesce(jsonb_array_length(v_debt),0),'receipt_count',coalesce(jsonb_array_length(v_receipts),0),
    'gross_minor',coalesce((select sum((x->>'amount_minor')::bigint) from jsonb_array_elements(v_transactions) x where coalesce(x->>'status','') in ('succeeded','paid','validado','payment_confirmed','requires_capture')),0),
    'refunded_minor',coalesce((select sum(coalesce(r.amount_succeeded_minor,0)) from kombax_payments.commerce_refunds_r65 r where v_account_id is not null and r.connected_account_id=v_account_id and r.status='succeeded'),0)) into v_summary;
  v_methods:=jsonb_build_object('stripe_account_connected',v_account_id is not null,'stripe_account_id_masked',case when v_stripe_account is null then null else left(v_stripe_account,8)||'…'||right(v_stripe_account,4) end,
    'card_online',coalesce(v_account.card_payments_status='active',v_account.charges_enabled,false),'sepa',coalesce(v_account.sepa_debit_payments_status='active',false),
    'tap_to_pay_android',coalesce(v_account.charges_enabled,false),'tap_to_pay_ios_source_ready',coalesce(v_account.charges_enabled,false),'web_qr_checkout',coalesce(v_account.charges_enabled,false),
    'payouts_enabled',coalesce(v_account.payouts_enabled,false),'account_status',coalesce(v_account.status,'not_configured'));
  return jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'summary',v_summary,'methods',v_methods,'transactions',v_transactions,'orders',v_orders,'ticketing',v_ticketing,'debt',v_debt,'receipts',v_receipts,
    'sections',jsonb_build_array('summary','payments','receipts','history','reports','debt','orders','sales','ticketing'));
end $$;
revoke all on function public.app_kombax_finance_context_r84(text,uuid,integer) from public,anon;
grant execute on function public.app_kombax_finance_context_r84(text,uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
