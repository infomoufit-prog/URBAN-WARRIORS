-- KOMBAX R62.5.3 · Event ticket personalization (controlled by KOMBAX)
begin;

alter table public.kombax_eventos_publicos
  add column if not exists ticket_accent text not null default 'cyan',
  add column if not exists ticket_use_event_banner boolean not null default true,
  add column if not exists ticket_logo_entity_ids uuid[] not null default '{}'::uuid[],
  add column if not exists ticket_doors_open_text text,
  add column if not exists ticket_access_point text,
  add column if not exists ticket_instructions text;

alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_accent_r6253;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_accent_r6253
  check(ticket_accent in ('cyan','gold','red','violet'));
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_logo_count_r6253;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_logo_count_r6253
  check(cardinality(ticket_logo_entity_ids)<=6);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_doors_r6253;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_doors_r6253
  check(ticket_doors_open_text is null or char_length(ticket_doors_open_text) between 1 and 80);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_access_point_r6253;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_access_point_r6253
  check(ticket_access_point is null or char_length(ticket_access_point) between 1 and 120);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_instructions_r6253;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_instructions_r6253
  check(ticket_instructions is null or char_length(ticket_instructions) between 1 and 250);

create or replace function public.app_kombax_event_ticketing_manage_status_r6253(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb;e public.kombax_eventos_publicos;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  v_base:=public.app_kombax_event_ticketing_manage_status_r6252(p_event_id);
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id;
  return v_base||jsonb_build_object(
    'ticket_accent',e.ticket_accent,
    'ticket_use_event_banner',e.ticket_use_event_banner,
    'ticket_logo_entity_ids',to_jsonb(e.ticket_logo_entity_ids),
    'ticket_doors_open_text',e.ticket_doors_open_text,
    'ticket_access_point',e.ticket_access_point,
    'ticket_instructions',e.ticket_instructions
  );
end $$;
revoke all on function public.app_kombax_event_ticketing_manage_status_r6253(uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_manage_status_r6253(uuid) to authenticated;

create or replace function public.app_kombax_event_ticketing_mutate_r6253(p_event_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_result jsonb;e public.kombax_eventos_publicos;v_ids uuid[]:='{}'::uuid[];v_accent text;v_banner boolean;
  v_doors text;v_access text;v_instructions text;v_bad uuid;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  v_result:=public.app_kombax_event_ticketing_mutate_r6252(p_event_id,p_payload,p_request_id);
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id for update;

  v_accent:=lower(coalesce(nullif(trim(p_payload->>'accent'),''),e.ticket_accent,'cyan'));
  if v_accent not in ('cyan','gold','red','violet') then raise exception 'EVENT_TICKET_ACCENT_INVALID'; end if;
  v_banner:=case when p_payload ? 'use_event_banner' then coalesce((p_payload->>'use_event_banner')::boolean,true) else e.ticket_use_event_banner end;
  v_doors:=nullif(left(trim(coalesce(p_payload->>'doors_open','')),80),'');
  v_access:=nullif(left(trim(coalesce(p_payload->>'access_point','')),120),'');
  v_instructions:=nullif(left(trim(coalesce(p_payload->>'instructions','')),250),'');

  if p_payload ? 'logo_entity_ids' then
    if jsonb_typeof(p_payload->'logo_entity_ids')<>'array' then raise exception 'EVENT_TICKET_LOGOS_INVALID'; end if;
    select coalesce(array_agg((x.value)::uuid order by x.ordinality),'{}'::uuid[])
      into v_ids from jsonb_array_elements_text(p_payload->'logo_entity_ids') with ordinality as x(value,ordinality);
    if cardinality(v_ids)>6 then raise exception 'EVENT_TICKET_LOGOS_LIMIT'; end if;
    select u.id into v_bad
      from unnest(v_ids) as u(id)
      left join public.kombax_evento_entidades ee on ee.id=u.id
      where ee.id is null or ee.evento_id<>p_event_id or ee.estado<>'aceptada'
      limit 1;
    if v_bad is not null then raise exception 'EVENT_TICKET_LOGO_ENTITY_INVALID'; end if;
  else v_ids:=e.ticket_logo_entity_ids; end if;

  update public.kombax_eventos_publicos set
    ticket_accent=v_accent,ticket_use_event_banner=v_banner,ticket_logo_entity_ids=v_ids,
    ticket_doors_open_text=v_doors,ticket_access_point=v_access,ticket_instructions=v_instructions,actualizado_en=now()
  where id=p_event_id returning * into e;

  return v_result||jsonb_build_object('ticket_design',jsonb_build_object(
    'accent',e.ticket_accent,'use_event_banner',e.ticket_use_event_banner,'logo_entity_ids',to_jsonb(e.ticket_logo_entity_ids),
    'doors_open',e.ticket_doors_open_text,'access_point',e.ticket_access_point,'instructions',e.ticket_instructions));
end $$;
revoke all on function public.app_kombax_event_ticketing_mutate_r6253(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_mutate_r6253(uuid,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_my_event_tickets_r6253(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'order_id',o.id,'order_number',o.order_number,'event_id',o.event_id,'event_name',e.nombre,'event_slug',e.slug,'event_date',e.fecha_inicio,'event_end',e.fecha_fin,
    'venue',e.lugar_nombre,'municipio',e.municipio,'province',e.provincia,'country',e.pais,'banner_url',e.banner_url,'poster_url',e.cartel_url,
    'organizer_name',coalesce(nullif(e.organizador_nombre,''),o.seller_name),'organizer_contact_email',e.ticket_contact_email,'organizer_contact_phone',e.ticket_contact_phone,
    'ticket_accent',e.ticket_accent,'ticket_use_event_banner',e.ticket_use_event_banner,'ticket_doors_open_text',e.ticket_doors_open_text,
    'ticket_access_point',e.ticket_access_point,'ticket_instructions',e.ticket_instructions,
    'ticket_logos',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'role',x.rol,'name',x.nombre,'logo_url',x.logo_url) order by array_position(e.ticket_logo_entity_ids,x.id))
      from public.app_kombax_evento_entidades_v160(e.id) x where x.id=any(e.ticket_logo_entity_ids) and x.estado='aceptada'),'[]'::jsonb),
    'quantity',o.quantity,'unit_amount',o.unit_amount_minor/100.0,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,'seller_name',o.seller_name,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'ticket_token',t.ticket_token,'status',t.status,'ticket_index',t.ticket_index,'used_at',t.used_at) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.event_ticket_orders where buyer_user_id=auth.uid() order by created_at desc limit least(greatest(p_limit,1),200)) o
  join public.kombax_eventos_publicos e on e.id=o.event_id;
$$;
revoke all on function public.app_kombax_my_event_tickets_r6253(integer) from public,anon;
grant execute on function public.app_kombax_my_event_tickets_r6253(integer) to authenticated;

notify pgrst,'reload schema';
commit;
