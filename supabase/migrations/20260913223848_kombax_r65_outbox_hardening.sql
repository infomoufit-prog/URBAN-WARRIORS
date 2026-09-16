-- KOMBAX R65 live-aligned migration · 20260913223848_kombax_r65_outbox_hardening
-- This file matches a migration version already recorded in the live Supabase project.
begin;
-- 11) Outbox claim/finalize service functions
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commerce_outbox_claim_internal_r65(p_limit integer default 40)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_rows jsonb;
begin
  with picked as (
    select id from kombax_payments.commerce_communications_r65
    where status in('queued','failed') and scheduled_for<=now() and attempts<5
    order by scheduled_for,created_at limit least(greatest(coalesce(p_limit,40),1),100) for update skip locked
  ), upd as (
    update kombax_payments.commerce_communications_r65 c set status='processing',attempts=attempts+1,updated_at=now()
    from picked p where c.id=p.id
    returning c.id,c.recipient_email,c.recipient_user_id,c.subject,c.body_text,c.template_code,c.payload,c.attempts
  ) select coalesce(jsonb_agg(to_jsonb(upd)),'[]'::jsonb) into v_rows from upd;
  return v_rows;
end $$;
revoke all on function public.app_kombax_commerce_outbox_claim_internal_r65(integer) from public,anon,authenticated;
grant execute on function public.app_kombax_commerce_outbox_claim_internal_r65(integer) to service_role;

create or replace function public.app_kombax_commerce_outbox_finalize_internal_r65(p_id uuid,p_ok boolean,p_error text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  update kombax_payments.commerce_communications_r65 set status=case when p_ok then 'sent' else 'failed' end,sent_at=case when p_ok then now() else sent_at end,
    last_error=case when p_ok then null else left(coalesce(p_error,'SEND_FAILED'),500) end,scheduled_for=case when p_ok then scheduled_for else now()+interval '15 minutes' end,updated_at=now() where id=p_id;
end $$;
revoke all on function public.app_kombax_commerce_outbox_finalize_internal_r65(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.app_kombax_commerce_outbox_finalize_internal_r65(uuid,boolean,text) to service_role;

-- Explicitly remove PUBLIC execution from every new SECURITY DEFINER endpoint, including internal helpers.
revoke execute on function public.app_kombax_commerce_communications_r65(text,uuid,integer),
  public.app_kombax_event_attendee_message_r65(uuid,text,text,uuid),
  public.app_kombax_showcase_stock_movements_r65(uuid,uuid,integer),
  public.app_kombax_showcase_stock_adjust_r65(uuid,integer,text,uuid),
  public.app_kombax_showcase_finance_r65(uuid),public.app_kombax_event_finance_r65(uuid),public.app_kombax_event_ticket_sales_r65(uuid,integer),
  public.app_kombax_commerce_track_r65(text,uuid,uuid,uuid,uuid,text,integer,jsonb),
  public.app_kombax_showcase_bi_r65(uuid,integer),public.app_kombax_event_bi_r65(uuid,integer),
  public.app_kombax_event_checkin_history_r65(uuid,integer),public.app_showcase_order_mutate_v259(text,jsonb,uuid)
from public;

commit;
