-- R103: the existing R97 wallet becomes the common, precise runtime ledger.
begin;

create or replace function kombax_ai_ops.ai_ensure_wallet_r97(p_tenant_ref text,p_plan text,p_at timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_period timestamptz;v_next timestamptz;v_monthly integer;v_pilot boolean;v_trial boolean;
 v_phase text;v_initial integer;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;v_expired record;
 v_sub_id uuid;v_sub_start timestamptz;v_subject_id uuid;v_subject_type text;
begin
 if p_tenant_ref !~ '^(club|profile):[0-9a-f-]{36}$' then raise exception 'invalid_tenant_ref'; end if;
 insert into kombax_ai_ops.ai_wallets_r97(tenant_ref) values(p_tenant_ref) on conflict do nothing;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref for update;
 if v_wallet.reserved=0 then
  for v_expired in select grant_id,remaining from kombax_ai_ops.ai_credit_grants_r97
    where tenant_ref=p_tenant_ref and remaining>0 and expires_at is not null and expires_at<=p_at for update loop
   update kombax_ai_ops.ai_credit_grants_r97 set remaining=0 where grant_id=v_expired.grant_id;
   update kombax_ai_ops.ai_wallets_r97 set available=available-v_expired.remaining,updated_at=now() where tenant_ref=p_tenant_ref;
   insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,grant_id,event_type,amount,idempotency_key)
   values(p_tenant_ref,v_expired.grant_id,'EXPIRE',-v_expired.remaining,'expire:'||v_expired.grant_id::text) on conflict do nothing;
  end loop;
 end if;
 v_period:=date_trunc('month',p_at at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
 v_next:=((v_period at time zone 'Europe/Madrid')+interval '1 month') at time zone 'Europe/Madrid';
 v_monthly:=kombax_ai_ops.ai_monthly_amount_r97(p_plan);
 select exists(select 1 from kombax_commercial.pilot_entities_r97 e where e.tenant_ref=p_tenant_ref) into v_pilot;
 select kombax_commercial.trial_safe_r97(p_tenant_ref) into v_trial;
 v_phase:=kombax_commercial.program_phase_r97(p_at);
 if v_trial then
  perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'trial',150,'trial-initial',
    (select ends_at from kombax_commercial.trial_entities_r97 where p_tenant_ref='club:'||club_id::text),null);
 elsif v_pilot and v_phase='PILOT' then
  v_initial:=case when p_plan in ('FEDERATION','KOMBAX_PRO') then 4000 else 2000 end;
  perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'pilot',v_initial,'pilot-initial',
    (select trim(both '"' from value::text)::timestamptz from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at'),null);
 elsif not (v_pilot and v_phase='PREPARATION') then
  v_subject_type:=case when p_tenant_ref like 'club:%' then 'club' else 'perfil_directo' end;
  v_subject_id:=split_part(p_tenant_ref,':',2)::uuid;
  select s.id,coalesce(s.inicia_en,s.creado_en) into v_sub_id,v_sub_start
  from public.kombax_suscripciones s
  where s.sujeto_tipo=v_subject_type and s.sujeto_id=v_subject_id and s.estado='activa'
    and s.proveedor in ('stripe','stripe_billing','kombax_manual_paid')
    and nullif(btrim(s.referencia_externa),'') is not null
    and (s.inicia_en is null or s.inicia_en<=p_at) and (s.termina_en is null or s.termina_en>p_at)
  order by s.actualizado_en desc limit 1;
  if v_sub_id is not null and v_sub_start>=v_period and v_sub_start<v_next then
   v_initial:=case when p_plan in ('FEDERATION','KOMBAX_PRO') then 4000 else 2000 end;
   perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'onboarding',v_initial,
     'onboarding:'||v_sub_id::text,v_next,null);
  else
   perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'monthly',v_monthly,
     'monthly:'||to_char(v_period at time zone 'Europe/Madrid','YYYY-MM'),v_next,null);
  end if;
 end if;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref;
 return jsonb_build_object('available',v_wallet.available,'reserved',v_wallet.reserved,'tenant_ref',p_tenant_ref,
   'pilot',v_pilot and v_phase='PILOT','trial',v_trial,'renewal_at',
   case when v_pilot and v_phase='PILOT' then
     (select trim(both '"' from value::text)::timestamptz from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at')
   else v_next end);
end $$;

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
    where ticket_id=v_ticket and status in ('STAGED','ANALYZING') order by created_at limit 5
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

create or replace function kombax_ai_ops.ai_settle_turn_r97(p_turn_id uuid,p_cost numeric,p_failed boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare v_res kombax_ai_ops.ai_credit_reservations_r97%rowtype;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;
 v_factor numeric;v_margin numeric;v_target numeric(18,3);v_charge numeric(18,3);
 v_extra numeric(18,3);v_remaining numeric(18,3);v_take numeric(18,3);v_grant record;
begin
 select * into v_res from kombax_ai_ops.ai_credit_reservations_r97 where turn_id=p_turn_id;
 if not found or v_res.status<>'RESERVED' then return; end if;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=v_res.tenant_ref for update;
 select * into v_res from kombax_ai_ops.ai_credit_reservations_r97 where turn_id=p_turn_id for update;
 if v_res.status<>'RESERVED' then return; end if;
 select coalesce((value::text)::numeric,400) into v_factor from kombax_commercial.runtime_config_r64 where config_key='ai_credits_per_eur';
 select coalesce((value::text)::numeric,1.2) into v_margin from kombax_commercial.runtime_config_r64 where config_key='ai_credit_safety_margin';
 select charged_credits into v_target from kombax_ai_ops.ai_usage_runs_r103 where turn_id=p_turn_id;
 v_target:=case when p_failed then 0 when v_target is not null then v_target
   when coalesce(p_cost,0)>0 then greatest(0.001,round(p_cost*v_factor*v_margin,3)) else 0 end;
 v_extra:=least(greatest(0,v_target-v_res.held),v_wallet.available);
 v_charge:=least(v_target,v_res.held+v_extra);
 v_remaining:=v_charge;
 for v_grant in select grant_id,remaining from kombax_ai_ops.ai_credit_grants_r97
   where tenant_ref=v_res.tenant_ref and remaining>0
   order by case grant_type when 'promotional' then 0 when 'onboarding' then 1 when 'pilot' then 2
     when 'trial' then 3 when 'monthly' then 4 when 'compensation' then 5 else 6 end,
   expires_at nulls last,created_at for update loop
  exit when v_remaining=0;
  v_take:=least(v_grant.remaining,v_remaining);
  update kombax_ai_ops.ai_credit_grants_r97 set remaining=remaining-v_take where grant_id=v_grant.grant_id;
  v_remaining:=v_remaining-v_take;
 end loop;
 if v_remaining>0 then raise exception 'credit_grant_mismatch'; end if;
 update kombax_ai_ops.ai_wallets_r97 set available=available+v_res.held-v_charge,
   reserved=reserved-v_res.held,updated_at=now() where tenant_ref=v_res.tenant_ref;
 update kombax_ai_ops.ai_credit_reservations_r97 set status=case when p_failed then 'RELEASED' else 'SETTLED' end,
   charged=v_charge,shortfall=greatest(0,v_target-v_charge),settled_at=now() where turn_id=p_turn_id;
 insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,turn_id,event_type,amount,idempotency_key)
 values(v_res.tenant_ref,p_turn_id,case when p_failed then 'RELEASE' else 'CHARGE' end,
   v_res.held-v_charge,case when p_failed then 'release:' else 'charge:' end||p_turn_id::text) on conflict do nothing;
end $$;

revoke all on function kombax_ai_ops.ai_ensure_wallet_r97(text,text,timestamptz) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_reserve_turn_r97(uuid,text,text,text) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_settle_turn_r97(uuid,numeric,boolean) from public,anon,authenticated;
commit;
