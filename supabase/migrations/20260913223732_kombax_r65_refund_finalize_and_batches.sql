-- KOMBAX R65 live-aligned migration · 20260913223732_kombax_r65_refund_finalize_and_batches
-- This file matches a migration version already recorded in the live Supabase project.
begin;
create or replace function public.app_stripe_refund_finalize_internal_r65(p_refund_id uuid,p_status text,p_stripe_refund jsonb,p_error text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_r kombax_payments.commerce_refunds_r65;
begin
  select * into strict v_r from kombax_payments.commerce_refunds_r65 where id=p_refund_id for update;
  if p_status='succeeded' then return kombax_payments.apply_refund_success_r65(p_refund_id,p_stripe_refund); end if;
  if p_status='processing' then
    update kombax_payments.commerce_refunds_r65 set status='processing',failure_message=null,
      stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),stripe_payload=coalesce(p_stripe_refund,'{}'::jsonb),updated_at=now() where id=p_refund_id;
    return jsonb_build_object('ok',true,'refund_id',p_refund_id,'status','processing');
  end if;
  update kombax_payments.commerce_refunds_r65 set status='failed',failure_message=left(coalesce(p_error,p_stripe_refund#>>'{failure_reason}','REFUND_FAILED'),500),
    stripe_refund_id=coalesce(nullif(p_stripe_refund->>'id',''),stripe_refund_id),stripe_payload=coalesce(p_stripe_refund,'{}'::jsonb),updated_at=now() where id=p_refund_id;
  if v_r.scope='event' then update kombax_payments.event_ticket_orders set refund_state='refund_failed',updated_at=now() where id=v_r.event_ticket_order_id and refund_state='refund_processing'; end if;
  return jsonb_build_object('ok',false,'refund_id',p_refund_id,'status','failed');
end $$;
revoke all on function public.app_stripe_refund_finalize_internal_r65(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.app_stripe_refund_finalize_internal_r65(uuid,text,jsonb,text) to service_role;

-- Cancellation queue: returns order ids only after actor authorization.
create or replace function public.app_kombax_event_refund_batch_internal_r65(p_actor_id uuid,p_event_id uuid,p_reason text,p_request_id uuid,p_limit integer default 25)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch kombax_payments.event_refund_batches_r65;v_orders jsonb;v_pending integer;
begin
  if not kombax_payments.can_manage_event_r65(p_actor_id,p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  insert into kombax_payments.event_refund_batches_r65(request_id,event_id,actor_user_id,reason)
  values(p_request_id,p_event_id,p_actor_id,left(nullif(btrim(p_reason),''),1000))
  on conflict(actor_user_id,request_id) do update set updated_at=now() returning * into v_batch;
  select coalesce(jsonb_agg(id order by created_at),'[]'::jsonb) into v_orders from (
    select o.id from kombax_payments.event_ticket_orders o
    where o.event_id=p_event_id and o.status='paid' and o.refund_state in('refund_pending','refund_failed','manual_review')
    order by o.created_at limit least(greatest(coalesce(p_limit,25),1),25)
  ) q;
  select count(*) into v_pending from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.status='paid' and o.refund_state in('refund_pending','refund_processing','refund_failed','manual_review');
  update kombax_payments.event_refund_batches_r65 set requested_orders=greatest(requested_orders,jsonb_array_length(v_orders)),updated_at=now() where id=v_batch.id;
  return jsonb_build_object('batch_id',v_batch.id,'orders',v_orders,'pending',v_pending,'reason',coalesce(v_batch.reason,p_reason));
end $$;
revoke all on function public.app_kombax_event_refund_batch_internal_r65(uuid,uuid,text,uuid,integer) from public,anon,authenticated;
grant execute on function public.app_kombax_event_refund_batch_internal_r65(uuid,uuid,text,uuid,integer) to service_role;

create or replace function public.app_kombax_event_refund_batch_finalize_internal_r65(p_batch_id uuid,p_succeeded integer,p_failed integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_batch kombax_payments.event_refund_batches_r65;v_pending integer;v_status text;
begin
  select * into strict v_batch from kombax_payments.event_refund_batches_r65 where id=p_batch_id for update;
  select count(*) into v_pending from kombax_payments.event_ticket_orders where event_id=v_batch.event_id and status='paid' and refund_state in('refund_pending','refund_processing','refund_failed','manual_review');
  v_status:=case when v_pending=0 and coalesce(p_failed,0)=0 then 'completed' when v_pending=0 then 'completed_with_errors' else 'processing' end;
  update kombax_payments.event_refund_batches_r65 set succeeded_orders=succeeded_orders+greatest(coalesce(p_succeeded,0),0),failed_orders=failed_orders+greatest(coalesce(p_failed,0),0),status=v_status,
    completed_at=case when v_status like 'completed%' then now() else completed_at end,updated_at=now() where id=p_batch_id;
  return jsonb_build_object('ok',true,'batch_id',p_batch_id,'status',v_status,'remaining',v_pending);
end $$;
revoke all on function public.app_kombax_event_refund_batch_finalize_internal_r65(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.app_kombax_event_refund_batch_finalize_internal_r65(uuid,integer,integer) to service_role;

commit;
