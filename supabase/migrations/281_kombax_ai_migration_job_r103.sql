-- R103: customer-safe job summary. Detailed token and cost data stay private.
begin;
create or replace function public.app_kombax_ai_migration_job_r103(p_ticket_id text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_ticket kombax_customer_ops.tickets%rowtype;
 v_files integer;v_ready integer;v_review integer;v_pending integer;v_bytes bigint;
 v_used numeric;v_hold numeric;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 select * into v_ticket from kombax_customer_ops.tickets
 where ticket_id=p_ticket_id and user_ref=auth.uid() and category='MIGRATION';
 if not found then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED' using errcode='42501'; end if;
 select count(*),count(*) filter(where status in ('READY_CONFIRM','COMPLETED')),
   count(*) filter(where status in ('NEEDS_REVIEW','FAILED')),
   count(*) filter(where status in ('STAGED','ANALYZING'))
 into v_files,v_ready,v_review,v_pending
 from kombax_customer_ops.migration_files where ticket_id=p_ticket_id;
 select coalesce(sum(size_bytes),0) into v_bytes from (
  select size_bytes from kombax_customer_ops.migration_files
  where ticket_id=p_ticket_id and status in ('STAGED','ANALYZING') order by created_at limit 5
 ) pending;
 select coalesce(sum(r.charged),0) into v_used from kombax_ai_ops.ai_credit_reservations_r97 r
 join kombax_ai_ops.assistance_turns t on t.turn_id=r.turn_id
 where t.ticket_id=p_ticket_id and t.tenant_ref=v_ticket.tenant_ref and r.status='SETTLED';
 v_hold:=least(300,20+greatest(least(v_pending,5),1)*20+ceil(v_bytes::numeric/1048576)*5);
 return jsonb_build_object('files',v_files,'ready',v_ready,'needs_review',v_review,
   'pending',v_pending,'credits_used',v_used,'next_reservation_max',case when v_pending>0 then v_hold else 0 end);
end $$;
revoke all on function public.app_kombax_ai_migration_job_r103(text) from public,anon,service_role;
grant execute on function public.app_kombax_ai_migration_job_r103(text) to authenticated;
commit;
