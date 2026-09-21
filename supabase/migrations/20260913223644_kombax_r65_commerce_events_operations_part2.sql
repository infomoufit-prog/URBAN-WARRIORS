-- KOMBAX R65 live-aligned migration · 20260913223644_kombax_r65_commerce_events_operations_part2
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- ---------------------------------------------------------------------------
-- 2) Permission helpers
-- ---------------------------------------------------------------------------
create or replace function kombax_payments.can_manage_event_r65(p_actor uuid,p_event uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_seller jsonb;v_type text;v_id uuid;
begin
  if p_actor is null or p_event is null then return false; end if;
  if exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo) then return true; end if;
  begin v_seller:=kombax_payments.event_seller_r625(p_event); exception when others then return false; end;
  v_type:=v_seller->>'subject_type';v_id:=(v_seller->>'subject_id')::uuid;
  if v_type='club' then
    return exists(select 1 from public.miembros_club m where m.club_id=v_id and m.perfil_id=p_actor and m.activo and m.rol in('direccion','secretaria','economia'));
  elsif v_type='showcase_provider' then
    return kombax_payments.can_manage_provider(p_actor,v_id);
  elsif v_type='federation' then
    return kombax_payments.can_manage_federation_connect_r624(p_actor,v_id);
  elsif v_type='event_organizer' then
    return kombax_payments.can_manage_event_organizer_connect_r625(p_actor,v_id);
  end if;
  return false;
end $$;
revoke all on function kombax_payments.can_manage_event_r65(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_manage_event_r65(uuid,uuid) to service_role;

create or replace function kombax_payments.connected_account_for_event_r65(p_event uuid)
returns kombax_payments.connected_accounts language plpgsql stable security definer set search_path='' as $$
declare v_seller jsonb;v_row kombax_payments.connected_accounts;
begin
  v_seller:=kombax_payments.event_seller_r625(p_event);
  select * into strict v_row from kombax_payments.connected_accounts a
  where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid
    and a.status='active' and a.charges_enabled and a.charge_model='direct'
  order by a.updated_at desc limit 1;
  return v_row;
end $$;
revoke all on function kombax_payments.connected_account_for_event_r65(uuid) from public,anon,authenticated;
grant execute on function kombax_payments.connected_account_for_event_r65(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3) Communication helper and queue
-- ---------------------------------------------------------------------------
create or replace function kombax_payments.queue_communication_r65(
  p_scope text,p_provider uuid,p_event uuid,p_showcase_order uuid,p_event_order uuid,
  p_recipient_user uuid,p_recipient_email text,p_template text,p_subject text,p_body text,
  p_source text,p_actor uuid,p_key text,p_payload jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into kombax_payments.commerce_communications_r65(
    scope,provider_id,event_id,showcase_order_id,event_ticket_order_id,recipient_user_id,recipient_email,
    template_code,subject,body_text,payload,source,actor_user_id,idempotency_key
  ) values(p_scope,p_provider,p_event,p_showcase_order,p_event_order,p_recipient_user,nullif(lower(btrim(p_recipient_email)),''),
    p_template,left(p_subject,240),left(p_body,10000),coalesce(p_payload,'{}'::jsonb),coalesce(p_source,'system'),p_actor,left(p_key,240))
  on conflict(idempotency_key) do update set updated_at=now()
  returning id into v_id;
  return v_id;
end $$;
revoke all on function kombax_payments.queue_communication_r65(text,uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function kombax_payments.queue_communication_r65(text,uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,uuid,text,jsonb) to service_role;

create or replace function public.app_kombax_commerce_communications_r65(p_scope text,p_subject_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_allowed boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_scope='showcase' then v_allowed:=kombax_payments.can_manage_provider(v_uid,p_subject_id);
  elsif p_scope='event' then v_allowed:=kombax_payments.can_manage_event_r65(v_uid,p_subject_id); end if;
  if not v_allowed then raise exception 'COMMERCE_MANAGE_REQUIRED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
    select c.id,c.template_code,c.subject,c.body_text,c.status,c.attempts,c.sent_at,c.last_error,c.created_at,c.source,
      c.recipient_email,c.showcase_order_id,c.event_ticket_order_id
    from kombax_payments.commerce_communications_r65 c
    where (p_scope='showcase' and c.provider_id=p_subject_id) or (p_scope='event' and c.event_id=p_subject_id)
    order by c.created_at desc limit least(greatest(coalesce(p_limit,100),1),300)
  ) x);
end $$;
revoke all on function public.app_kombax_commerce_communications_r65(text,uuid,integer) from public,anon;
grant execute on function public.app_kombax_commerce_communications_r65(text,uuid,integer) to authenticated;

create or replace function public.app_kombax_event_attendee_message_r65(p_event_id uuid,p_subject text,p_message text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_count integer:=0;r record;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_payments.can_manage_event_r65(v_uid,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if char_length(btrim(coalesce(p_subject,''))) not between 3 and 160 or char_length(btrim(coalesce(p_message,''))) not between 3 and 4000 then raise exception 'MESSAGE_INVALID'; end if;
  for r in select o.id,o.buyer_user_id,o.buyer_email,o.order_number from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.status='paid'
  loop
    perform kombax_payments.queue_communication_r65('event',null,p_event_id,null,r.id,r.buyer_user_id,r.buyer_email,'event_organizer_message',p_subject,p_message,'organizer',v_uid,
      'event-message:'||p_request_id::text||':'||r.id::text,jsonb_build_object('order_number',r.order_number));
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'queued',v_count,'request_id',p_request_id);
end $$;
revoke all on function public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Seller Center Pro: stock ledger + safe manual adjustment
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_stock_movements_r65(p_provider_id uuid,p_product_id uuid default null,p_limit integer default 150)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) from (
    select m.id,m.product_id,e.nombre as product_name,m.order_id,m.refund_id,m.movement_type,m.quantity_delta,m.stock_before,m.stock_after,m.note,m.created_at
    from kombax_payments.showcase_stock_movements_r65 m join public.kombax_showcase_elementos e on e.id=m.product_id
    where m.provider_id=p_provider_id and (p_product_id is null or m.product_id=p_product_id)
    order by m.created_at desc limit least(greatest(coalesce(p_limit,150),1),500)
  ) x);
end $$;
revoke all on function public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer) to authenticated;

create or replace function public.app_kombax_showcase_stock_adjust_r65(p_product_id uuid,p_new_stock integer,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_item public.kombax_showcase_elementos;v_before integer;v_delta integer;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if p_new_stock is null or p_new_stock<0 then raise exception 'STOCK_INVALID'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_product_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_before:=coalesce(v_item.stock,0);v_delta:=p_new_stock-v_before;
  if v_delta=0 then return jsonb_build_object('ok',true,'product_id',p_product_id,'stock',p_new_stock,'changed',false); end if;
  update public.kombax_showcase_elementos set stock=p_new_stock,actualizado_en=now(),actualizado_por=v_uid where id=p_product_id;
  insert into kombax_payments.showcase_stock_movements_r65(provider_id,product_id,movement_type,quantity_delta,stock_before,stock_after,actor_user_id,note,idempotency_key)
  values(v_item.marca_id,p_product_id,'manual_adjustment',v_delta,v_before,p_new_stock,v_uid,left(nullif(btrim(p_note),''),500),'manual:'||v_uid::text||':'||p_request_id::text)
  on conflict(idempotency_key) do nothing;
  return jsonb_build_object('ok',true,'product_id',p_product_id,'stock',p_new_stock,'previous_stock',v_before,'changed',true);
end $$;
revoke all on function public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid) to authenticated;

commit;
