-- KOMBAX R72 / build 20123 live section 05
begin;
-- 5. Verified purchase / attendance helpers.
-- ---------------------------------------------------------------------------
create or replace function kombax_reputation.verified_purchase_order_r72(p_user_id uuid,p_product_id uuid)
returns uuid language sql stable security definer set search_path='' as $$
 select o.id from kombax_payments.showcase_orders o join kombax_payments.showcase_order_items i on i.order_id=o.id
 where o.buyer_user_id=p_user_id and i.product_id=p_product_id and o.status='delivered'
 order by coalesce(o.delivered_at,o.updated_at) desc limit 1;
$$;
revoke all on function kombax_reputation.verified_purchase_order_r72(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_reputation.verified_purchase_order_r72(uuid,uuid) to service_role;

create or replace function kombax_reputation.has_verified_attendance_r72(p_user_id uuid,p_event_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from kombax_payments.event_tickets t join kombax_payments.event_ticket_orders o on o.id=t.order_id
 where t.event_id=p_event_id and t.used_at is not null and t.status='used' and (t.holder_user_id=p_user_id or o.buyer_user_id=p_user_id));
$$;
revoke all on function kombax_reputation.has_verified_attendance_r72(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_reputation.has_verified_attendance_r72(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------------
commit;
