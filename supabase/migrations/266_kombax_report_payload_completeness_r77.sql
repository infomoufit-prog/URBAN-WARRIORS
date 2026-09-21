-- KOMBAX R77 report payload completeness: non-PII operational rows for orders/tickets/attendance.
create or replace function public.app_kombax_report_payload_r77(
  p_scope text,
  p_subject_id uuid,
  p_report_type text,
  p_days integer default 30
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := auth.uid();
  v_scope text := lower(coalesce(p_scope,''));
  v_type text := lower(coalesce(p_report_type,'general'));
  v_analytics jsonb;
  v_entity jsonb;
  v_extra jsonb := '{}'::jsonb;
  v_event public.kombax_eventos_publicos;
  v_provider public.kombax_showcase_marcas;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_scope='showcase' then
    if not kombax_payments.can_manage_provider(v_uid,p_subject_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','products','stock','orders','performance') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=p_subject_id;
    v_analytics:=public.app_kombax_showcase_analytics_r77(p_subject_id,p_days);
    v_entity:=jsonb_build_object(
      'id',v_provider.id,'name',v_provider.nombre,'type',v_provider.sujeto_tipo,
      'logo_url',coalesce(v_provider.logo_url,(select c.logo_url from public.clubes c where c.id=v_provider.club_id)),
      'club_id',v_provider.club_id
    );
    v_extra:=jsonb_build_object(
      'finance',public.app_kombax_showcase_finance_r65(p_subject_id),
      'inventory',(select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'name',e.nombre,'image_url',e.imagen_url,'status',e.estado,'stock',e.stock,'stock_alert_threshold',e.stock_alert_threshold,'product_type',e.product_type,'price',e.precio_venta) order by e.nombre),'[]'::jsonb) from public.kombax_showcase_elementos e where e.marca_id=p_subject_id and e.listing_kind='product'),
      'orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select o.id,o.order_number,o.amount_total_minor,o.currency,o.status,o.created_at,o.shipped_at,o.delivered_at,(select coalesce(sum(i.quantity),0)::int from kombax_payments.showcase_order_items i where i.order_id=o.id) units from kombax_payments.showcase_orders o where o.seller_provider_id=p_subject_id order by o.created_at desc limit 200) x)
    );
  elsif v_scope='event' then
    if not kombax_payments.can_manage_event_r65(v_uid,p_subject_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    if v_type not in ('general','sales','finance','tickets','attendance','participants','fights','results','executive') then raise exception 'REPORT_TYPE_INVALID'; end if;
    select * into strict v_event from public.kombax_eventos_publicos where id=p_subject_id;
    v_analytics:=public.app_kombax_event_analytics_r77(p_subject_id,p_days);
    v_entity:=jsonb_build_object(
      'id',v_event.id,'name',v_event.nombre,'type','event','organizer',v_event.organizador_nombre,
      'logo_url',coalesce((select c.logo_url from public.clubes c where c.id=v_event.creador_club_id),(select m.logo_url from public.kombax_showcase_marcas m where m.perfil_directo_id=v_event.creador_perfil_directo_id order by m.actualizado_en desc limit 1)),
      'poster_url',v_event.cartel_url,'date',v_event.fecha_inicio,'venue',v_event.lugar_nombre,'city',v_event.municipio,'country',v_event.pais
    );
    v_extra:=jsonb_build_object(
      'finance',public.app_kombax_event_finance_r65(p_subject_id),
      'results',(select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('co_estelar',f.co_estelar) order by r.destacado desc,f.co_estelar desc,r.orden nulls last),'[]'::jsonb) from public.app_kombax_evento_resultados_v164(p_subject_id) r join public.kombax_evento_combates_publicos f on f.id=r.id),
      'participants',(select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) from public.app_kombax_evento_participantes_v161(p_subject_id) p),
      'ticket_orders',(select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (select o.id,o.order_number,o.quantity,o.amount_total_minor,o.currency,o.status,o.paid_at,o.refunded_at,o.created_at,o.refund_state from kombax_payments.event_ticket_orders o where o.event_id=p_subject_id order by o.created_at desc limit 250) x),
      'attendance',(select jsonb_build_object('issued',count(*),'active',count(*) filter(where status='active'),'used',count(*) filter(where status='used'),'refunded',count(*) filter(where status='refunded'),'cancelled',count(*) filter(where status='cancelled')) from kombax_payments.event_tickets where event_id=p_subject_id)
    );
  else
    raise exception 'REPORT_SCOPE_INVALID';
  end if;
  return jsonb_build_object('ok',true,'scope',v_scope,'report_type',v_type,'days',least(greatest(coalesce(p_days,30),1),365),'generated_at',now(),'entity',v_entity,'analytics',v_analytics,'extra',v_extra);
end $$;

revoke all on function public.app_kombax_report_payload_r77(text,uuid,text,integer) from public,anon;
grant execute on function public.app_kombax_report_payload_r77(text,uuid,text,integer) to authenticated;

-- Private storage for generated report snapshots. Only the Edge Function service role writes/reads.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-reports','kombax-reports',false,20971520,array['application/pdf']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

notify pgrst,'reload schema';
