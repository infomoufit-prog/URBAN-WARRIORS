begin;
CREATE OR REPLACE FUNCTION public.app_kombax_report_payload_range_r77(p_scope text, p_subject_id uuid, p_report_type text, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_scope text := lower(coalesce(p_scope,''));
  v_type text := lower(coalesce(p_report_type,'general'));
  v_days integer;
  v_analytics jsonb;
  v_entity jsonb;
  v_extra jsonb := '{}'::jsonb;
  v_event public.kombax_eventos_publicos;
  v_provider public.kombax_showcase_marcas;
  v_current jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_from is null or p_to is null or p_from>=p_to or p_to-p_from>interval '366 days' then raise exception 'REPORT_RANGE_INVALID'; end if;
  v_days:=greatest(1,ceil(extract(epoch from (p_to-p_from))/86400.0)::integer);

  if v_scope='showcase' then
    if not kombax_payments.can_manage_provider(v_uid,p_subject_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','products','stock','orders','performance') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=p_subject_id;
    v_analytics:=public.app_kombax_showcase_analytics_range_r77(p_subject_id,p_from,p_to);
    v_current:=coalesce(v_analytics->'current','{}'::jsonb);
    v_entity:=jsonb_build_object(
      'id',v_provider.id,'name',v_provider.nombre,'type',v_provider.sujeto_tipo,
      'logo_url',coalesce(v_provider.logo_url,(select c.logo_url from public.clubes c where c.id=v_provider.club_id)),
      'club_id',v_provider.club_id
    );
    v_extra:=jsonb_build_object(
      'finance',jsonb_build_object(
        'currency','EUR',
        'gross_minor',coalesce((v_current->>'gross_minor')::bigint,0),
        'seller_refunds_minor',coalesce((v_current->>'refunds_minor')::bigint,0),
        'buyer_refunds_minor',coalesce((v_current->>'refunds_minor')::bigint,0),
        'platform_fee_minor',coalesce((v_current->>'platform_fee_minor')::bigint,0),
        'estimated_seller_net_before_stripe_minor',greatest(0,coalesce((v_current->>'gross_minor')::bigint,0)-coalesce((v_current->>'refunds_minor')::bigint,0)-coalesce((v_current->>'platform_fee_minor')::bigint,0)),
        'orders',coalesce((v_current->>'orders')::integer,0),
        'note','El neto es estimado antes de las tarifas de procesamiento de Stripe.'
      ),
      'inventory',(select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'name',e.nombre,'image_url',e.imagen_url,'status',e.estado,'stock',e.stock,'stock_alert_threshold',e.stock_alert_threshold,'product_type',e.product_type,'price',e.precio_venta) order by e.nombre),'[]'::jsonb) from public.kombax_showcase_elementos e where e.marca_id=p_subject_id and e.listing_kind='product'),
      'orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
        select o.id,o.order_number,o.amount_total_minor,o.currency,o.status,o.created_at,o.shipped_at,o.delivered_at,
          (select coalesce(sum(i.quantity),0)::int from kombax_payments.showcase_order_items i where i.order_id=o.id) units
        from kombax_payments.showcase_orders o
        where o.seller_provider_id=p_subject_id and o.created_at>=p_from and o.created_at<p_to
        order by o.created_at desc limit 200
      ) x)
    );
  elsif v_scope='event' then
    if not kombax_payments.can_manage_event_r65(v_uid,p_subject_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','tickets','attendance','participants','fights','results','executive') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_event from public.kombax_eventos_publicos where id=p_subject_id;
    v_analytics:=public.app_kombax_event_analytics_range_r77(p_subject_id,p_from,p_to);
    v_current:=coalesce(v_analytics->'current','{}'::jsonb);
    v_entity:=jsonb_build_object(
      'id',v_event.id,'name',v_event.nombre,'type','event','organizer',v_event.organizador_nombre,
      'logo_url',kombax_documents.event_logo(v_event.id),
      'poster_url',v_event.cartel_url,'date',v_event.fecha_inicio,'venue',v_event.lugar_nombre,'city',v_event.municipio,'country',v_event.pais
    );
    v_extra:=jsonb_build_object(
      'finance',jsonb_build_object(
        'currency','EUR',
        'gross_minor',coalesce((v_current->>'gross_minor')::bigint,0),
        'buyer_refunds_minor',coalesce((v_current->>'refunds_minor')::bigint,0),
        'platform_fee_minor',coalesce((select sum(a.platform_fee_minor) from kombax_payments.payment_attempts a join kombax_payments.event_ticket_orders o on o.id=a.event_ticket_order_id where o.event_id=p_subject_id and a.status in('succeeded','refunded') and coalesce(o.paid_at,o.created_at)>=p_from and coalesce(o.paid_at,o.created_at)<p_to),0),
        'estimated_organizer_net_before_stripe_minor',greatest(0,coalesce((v_current->>'gross_minor')::bigint,0)-coalesce((v_current->>'refunds_minor')::bigint,0)-coalesce((select sum(a.platform_fee_minor) from kombax_payments.payment_attempts a join kombax_payments.event_ticket_orders o on o.id=a.event_ticket_order_id where o.event_id=p_subject_id and a.status in('succeeded','refunded') and coalesce(o.paid_at,o.created_at)>=p_from and coalesce(o.paid_at,o.created_at)<p_to),0)),
        'orders',coalesce((v_current->>'orders')::integer,0),
        'note','El neto es estimado antes de las tarifas de procesamiento de Stripe.'
      ),
      'results',(select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('co_estelar',f.co_estelar) order by r.destacado desc,f.co_estelar desc,r.orden nulls last),'[]'::jsonb) from public.app_kombax_evento_resultados_v164(p_subject_id) r join public.kombax_evento_combates_publicos f on f.id=r.id),
      'participants',(select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) from public.app_kombax_evento_participantes_v161(p_subject_id) p),
      'ticket_orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
        select o.id,o.order_number,o.quantity,o.amount_total_minor,o.currency,o.status,o.paid_at,o.refunded_at,o.created_at,o.refund_state
        from kombax_payments.event_ticket_orders o
        where o.event_id=p_subject_id and o.created_at>=p_from and o.created_at<p_to
        order by o.created_at desc limit 250
      ) x),
      'attendance',jsonb_build_object(
        'issued_all',(select count(*) from kombax_payments.event_tickets where event_id=p_subject_id),
        'active_all',(select count(*) from kombax_payments.event_tickets where event_id=p_subject_id and status='active'),
        'used_all',(select count(*) from kombax_payments.event_tickets where event_id=p_subject_id and status='used'),
        'refunded_all',(select count(*) from kombax_payments.event_tickets where event_id=p_subject_id and status='refunded'),
        'cancelled_all',(select count(*) from kombax_payments.event_tickets where event_id=p_subject_id and status='cancelled'),
        'checkins_period',(select count(*) from kombax_payments.event_ticket_checkin_audit where event_id=p_subject_id and outcome='valid' and created_at>=p_from and created_at<p_to)
      )
    );
  else
    raise exception 'REPORT_SCOPE_INVALID';
  end if;

  return jsonb_build_object('ok',true,'scope',v_scope,'report_type',v_type,'days',v_days,'from',p_from,'to',p_to,'generated_at',now(),'entity',v_entity,'analytics',v_analytics,'extra',v_extra);
end $function$
;
commit;
