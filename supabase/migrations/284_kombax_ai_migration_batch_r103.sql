-- R103: process up to 80 ordinary image fichas in ten 8-file batches within the 12-turn conversation cap.
begin;
alter table kombax_ai_ops.assistance_cost_policies drop constraint assistance_cost_policies_max_visual_files_per_batch_check;
alter table kombax_ai_ops.assistance_cost_policies add constraint assistance_cost_policies_max_visual_files_per_batch_check check(max_visual_files_per_batch between 1 and 8);
update kombax_ai_ops.assistance_cost_policies set max_files_per_batch=8,max_visual_files_per_batch=8,max_batch_mb=32 where plan in ('CLUB_BASIC','CLUB_PREMIUM','FEDERATION','KOMBAX_PRO');
create or replace function kombax_ai_ops.ai_reserve_turn_r97(p_turn_id uuid,p_tenant_ref text,p_plan text,p_category text)
returns void language plpgsql security definer set search_path='' as $$
declare v_hold numeric(18,3);v_enforce boolean;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;
 v_ticket text;v_files integer:=0;v_bytes bigint:=0;
begin
 perform kombax_ai_ops.ai_ensure_wallet_r97(p_tenant_ref,p_plan,now());
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref for update;
 select coalesce(value::text='true',false) into v_enforce from kombax_commercial.runtime_config_r64 where config_key='ai_credits_enforcement';
 if p_category='MIGRATION' then
  select ticket_id into v_ticket from kombax_ai_ops.assistance_turns where turn_id=p_turn_id;
  select count(*),coalesce(sum(size_bytes),0) into v_files,v_bytes from (
    select size_bytes from kombax_customer_ops.migration_files
    where ticket_id=v_ticket and status in ('STAGED','ANALYZING') order by created_at limit 8
  ) pending;
  v_hold:=least(300,20+greatest(v_files,1)*20+ceil(v_bytes::numeric/1048576)*5);
 else
  v_hold:=10;
 end if;
 if v_wallet.available<v_hold then
  if v_enforce then raise exception 'AI_CREDITS_RESERVATION_REQUIRED' using errcode='P0001'; end if;
  v_hold:=greatest(0,v_wallet.available);
 end if;
 insert into kombax_ai_ops.ai_credit_reservations_r97(turn_id,tenant_ref,held)
 values(p_turn_id,p_tenant_ref,v_hold) on conflict do nothing;
 if not found then return; end if;
 update kombax_ai_ops.ai_wallets_r97 set available=available-v_hold,reserved=reserved+v_hold,updated_at=now()
 where tenant_ref=p_tenant_ref;
 insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,turn_id,event_type,amount,idempotency_key)
 values(p_tenant_ref,p_turn_id,'RESERVE',-v_hold,'reserve:'||p_turn_id::text) on conflict do nothing;
end $$;

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
  where ticket_id=p_ticket_id and status in ('STAGED','ANALYZING') order by created_at limit 8
 ) pending;
 select coalesce(sum(r.charged),0) into v_used from kombax_ai_ops.ai_credit_reservations_r97 r
 join kombax_ai_ops.assistance_turns t on t.turn_id=r.turn_id
 where t.ticket_id=p_ticket_id and t.tenant_ref=v_ticket.tenant_ref and r.status='SETTLED';
 v_hold:=least(300,20+greatest(least(v_pending,8),1)*20+ceil(v_bytes::numeric/1048576)*5);
 return jsonb_build_object('files',v_files,'ready',v_ready,'needs_review',v_review,
   'pending',v_pending,'credits_used',v_used,'next_reservation_max',case when v_pending>0 then v_hold else 0 end);
end $$;
revoke all on function kombax_ai_ops.ai_reserve_turn_r97(uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.app_kombax_ai_migration_job_r103(text) from public,anon,service_role;
grant execute on function public.app_kombax_ai_migration_job_r103(text) to authenticated;
commit;
