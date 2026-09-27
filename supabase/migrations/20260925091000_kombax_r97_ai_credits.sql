-- R97 · One entity wallet for Assist and Migrations. Existing turns remain the usage source.
begin;

create table if not exists kombax_ai_ops.ai_wallets_r97(
 tenant_ref text primary key,
 available integer not null default 0 check(available>=0),
 reserved integer not null default 0 check(reserved>=0),
 updated_at timestamptz not null default now()
);
create table if not exists kombax_ai_ops.ai_credit_grants_r97(
 grant_id uuid primary key default gen_random_uuid(),
 tenant_ref text not null references kombax_ai_ops.ai_wallets_r97(tenant_ref),
 grant_type text not null check(grant_type in ('monthly','onboarding','pilot','promotional','purchased','compensation','trial')),
 total integer not null check(total>0),
 remaining integer not null check(remaining>=0),
 expires_at timestamptz,
 idempotency_key text not null,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(tenant_ref,idempotency_key),
 check(remaining<=total)
);
create index if not exists ai_grants_spend_r97 on kombax_ai_ops.ai_credit_grants_r97(tenant_ref,expires_at,created_at) where remaining>0;
create table if not exists kombax_ai_ops.ai_credit_reservations_r97(
 turn_id uuid primary key references kombax_ai_ops.assistance_turns(turn_id) on delete restrict,
 tenant_ref text not null references kombax_ai_ops.ai_wallets_r97(tenant_ref),
 held integer not null check(held>=0),
 charged integer,
 shortfall integer not null default 0 check(shortfall>=0),
 status text not null default 'RESERVED' check(status in ('RESERVED','SETTLED','RELEASED')),
 created_at timestamptz not null default now(),
 settled_at timestamptz
);
create table if not exists kombax_ai_ops.ai_credit_ledger_r97(
 entry_id uuid primary key default gen_random_uuid(),
 tenant_ref text not null references kombax_ai_ops.ai_wallets_r97(tenant_ref),
 grant_id uuid references kombax_ai_ops.ai_credit_grants_r97(grant_id),
 turn_id uuid references kombax_ai_ops.assistance_turns(turn_id),
 event_type text not null check(event_type in ('GRANT','RESERVE','CHARGE','RELEASE','EXPIRE')),
 amount integer not null,
 idempotency_key text not null,
 created_at timestamptz not null default now(),
 unique(tenant_ref,idempotency_key)
);
create index if not exists ai_ledger_tenant_time_r97 on kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,created_at desc);

alter table kombax_ai_ops.ai_wallets_r97 enable row level security;
alter table kombax_ai_ops.ai_credit_grants_r97 enable row level security;
alter table kombax_ai_ops.ai_credit_reservations_r97 enable row level security;
alter table kombax_ai_ops.ai_credit_ledger_r97 enable row level security;
revoke all on kombax_ai_ops.ai_wallets_r97,kombax_ai_ops.ai_credit_grants_r97,kombax_ai_ops.ai_credit_reservations_r97,kombax_ai_ops.ai_credit_ledger_r97 from public,anon,authenticated;
grant all on kombax_ai_ops.ai_wallets_r97,kombax_ai_ops.ai_credit_grants_r97,kombax_ai_ops.ai_credit_reservations_r97,kombax_ai_ops.ai_credit_ledger_r97 to service_role;

create or replace function kombax_ai_ops.ai_monthly_amount_r97(p_plan text)
returns integer language sql immutable as $$
 select case p_plan when 'CLUB_BASIC' then 500 when 'CLUB_PREMIUM' then 1000 when 'FEDERATION' then 2000 when 'KOMBAX_PRO' then 2000 else 500 end;
$$;

-- Caller locks ai_wallets_r97 before invoking this function. Grant key is a natural idempotency key.
create or replace function kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref text,p_type text,p_amount integer,p_key text,p_expires timestamptz default null,p_actor uuid default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if p_amount<=0 or p_key is null then raise exception 'invalid_grant'; end if;
 insert into kombax_ai_ops.ai_credit_grants_r97(tenant_ref,grant_type,total,remaining,expires_at,idempotency_key,created_by)
 values(p_tenant_ref,p_type,p_amount,p_amount,p_expires,p_key,p_actor)
 on conflict(tenant_ref,idempotency_key) do nothing returning grant_id into v_id;
 if v_id is null then return false; end if;
 update kombax_ai_ops.ai_wallets_r97 set available=available+p_amount,updated_at=now() where tenant_ref=p_tenant_ref;
 insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,grant_id,event_type,amount,idempotency_key)
 values(p_tenant_ref,v_id,'GRANT',p_amount,'grant:'||p_key);
 return true;
end $$;

create or replace function kombax_ai_ops.ai_ensure_wallet_r97(p_tenant_ref text,p_plan text,p_at timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_period timestamptz;v_next timestamptz;v_monthly integer;v_pilot boolean;v_initial integer;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;v_expired record;
begin
 if p_tenant_ref !~ '^(club|profile):[0-9a-f-]{36}$' then raise exception 'invalid_tenant_ref'; end if;
 insert into kombax_ai_ops.ai_wallets_r97(tenant_ref) values(p_tenant_ref) on conflict do nothing;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref for update;
 -- Expire only when no interaction is in flight; purchased credits have no expiry.
 if v_wallet.reserved=0 then
  for v_expired in select grant_id,remaining from kombax_ai_ops.ai_credit_grants_r97
    where tenant_ref=p_tenant_ref and remaining>0 and expires_at is not null and expires_at<=p_at for update loop
   update kombax_ai_ops.ai_credit_grants_r97 set remaining=0 where grant_id=v_expired.grant_id;
   update kombax_ai_ops.ai_wallets_r97 set available=available-v_expired.remaining,updated_at=now() where tenant_ref=p_tenant_ref;
   insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,grant_id,event_type,amount,idempotency_key)
   values(p_tenant_ref,v_expired.grant_id,'EXPIRE',-v_expired.remaining,'expire:'||v_expired.grant_id::text);
  end loop;
 end if;
 v_period:=date_trunc('month',p_at at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
 v_next:=((v_period at time zone 'Europe/Madrid')+interval '1 month') at time zone 'Europe/Madrid';
 v_monthly:=kombax_ai_ops.ai_monthly_amount_r97(p_plan);
 select exists(select 1 from kombax_commercial.pilot_entities_r97 e where e.tenant_ref=p_tenant_ref) into v_pilot;
 -- The first enrolled month totals 2000/4000; later months use plan allocation.
 if v_pilot and not exists(select 1 from kombax_ai_ops.ai_credit_grants_r97 g where g.tenant_ref=p_tenant_ref) then
  v_initial:=case when p_plan in ('FEDERATION','KOMBAX_PRO') then 4000 else 2000 end;
  perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'pilot',v_initial,'pilot-initial',null,null);
 elsif not (v_pilot and exists(select 1 from kombax_ai_ops.ai_credit_grants_r97 g where g.tenant_ref=p_tenant_ref and g.grant_type='pilot' and g.created_at>=v_period and g.created_at<v_next)) then
  perform kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,'monthly',v_monthly,'monthly:'||to_char(v_period at time zone 'Europe/Madrid','YYYY-MM'),v_next,null);
 end if;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref;
 return jsonb_build_object('available',v_wallet.available,'reserved',v_wallet.reserved,'tenant_ref',p_tenant_ref,'pilot',v_pilot);
end $$;

-- Atomic reservation serializes on the wallet row. In shadow mode only a pilot enrollment is metered.
create or replace function kombax_ai_ops.ai_reserve_turn_r97(p_turn_id uuid,p_tenant_ref text,p_plan text,p_category text)
returns void language plpgsql security definer set search_path='' as $$
declare v_hold integer:=case when p_category='MIGRATION' then 100 else 20 end;v_enforce boolean;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;
begin
 if not exists(select 1 from kombax_commercial.pilot_entities_r97 where tenant_ref=p_tenant_ref) then return; end if;
 perform kombax_ai_ops.ai_ensure_wallet_r97(p_tenant_ref,p_plan,now());
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref for update;
 select coalesce(value::text='true',false) into v_enforce from kombax_commercial.runtime_config_r64 where config_key='ai_credits_enforcement';
 if v_wallet.available<v_hold then
  if v_enforce then raise exception 'AI_CREDITS_EXHAUSTED' using errcode='P0001'; end if;
  v_hold:=v_wallet.available;
 end if;
 insert into kombax_ai_ops.ai_credit_reservations_r97(turn_id,tenant_ref,held) values(p_turn_id,p_tenant_ref,v_hold) on conflict do nothing;
 if not found then return; end if;
 update kombax_ai_ops.ai_wallets_r97 set available=available-v_hold,reserved=reserved+v_hold,updated_at=now() where tenant_ref=p_tenant_ref;
 insert into kombax_ai_ops.ai_credit_ledger_r97(tenant_ref,turn_id,event_type,amount,idempotency_key)
 values(p_tenant_ref,p_turn_id,'RESERVE',-v_hold,'reserve:'||p_turn_id::text);
end $$;

create or replace function kombax_ai_ops.ai_settle_turn_r97(p_turn_id uuid,p_cost numeric,p_failed boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare v_res kombax_ai_ops.ai_credit_reservations_r97%rowtype;v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;v_factor integer;v_target integer;v_charge integer;v_extra integer;v_remaining integer;v_take integer;v_grant record;
begin
 select * into v_res from kombax_ai_ops.ai_credit_reservations_r97 where turn_id=p_turn_id;
 if not found or v_res.status<>'RESERVED' then return; end if;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=v_res.tenant_ref for update;
 select * into v_res from kombax_ai_ops.ai_credit_reservations_r97 where turn_id=p_turn_id for update;
 if v_res.status<>'RESERVED' then return; end if;
 select coalesce((value::text)::integer,400) into v_factor from kombax_commercial.runtime_config_r64 where config_key='ai_credits_per_cost_unit';
 v_target:=case when p_failed or coalesce(p_cost,0)<=0 then 0 else greatest(1,ceil(p_cost*v_factor)::integer) end;
 v_extra:=least(greatest(0,v_target-v_res.held),v_wallet.available);
 v_charge:=least(v_target,v_res.held+v_extra);
 v_remaining:=v_charge;
 for v_grant in select grant_id,remaining from kombax_ai_ops.ai_credit_grants_r97 where tenant_ref=v_res.tenant_ref and remaining>0
   order by case grant_type when 'promotional' then 0 when 'onboarding' then 1 when 'pilot' then 2 when 'trial' then 3 when 'monthly' then 4 when 'compensation' then 5 else 6 end,
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
 values(v_res.tenant_ref,p_turn_id,case when p_failed then 'RELEASE' else 'CHARGE' end,v_res.held-v_charge,case when p_failed then 'release:' else 'charge:' end||p_turn_id::text);
end $$;

create or replace function kombax_ai_ops.ai_turn_insert_r97() returns trigger language plpgsql security definer set search_path='' as $$
declare v_plan text;
begin
 select r.plan into v_plan from kombax_ai_ops.resolve_context(new.user_ref,new.tenant_ref) r;
 perform kombax_ai_ops.ai_reserve_turn_r97(new.turn_id,new.tenant_ref,coalesce(v_plan,'CLUB_BASIC'),new.category);
 return new;
end $$;
create or replace function kombax_ai_ops.ai_turn_finish_r97() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='RESERVED' and new.status in ('COMPLETED','FAILED','BLOCKED') then
  perform kombax_ai_ops.ai_settle_turn_r97(new.turn_id,new.estimated_cost,new.status<>'COMPLETED');
 end if;
 return new;
end $$;
drop trigger if exists ai_turn_insert_r97 on kombax_ai_ops.assistance_turns;
create trigger ai_turn_insert_r97 after insert on kombax_ai_ops.assistance_turns for each row execute function kombax_ai_ops.ai_turn_insert_r97();
drop trigger if exists ai_turn_finish_r97 on kombax_ai_ops.assistance_turns;
create trigger ai_turn_finish_r97 after update of status on kombax_ai_ops.assistance_turns for each row execute function kombax_ai_ops.ai_turn_finish_r97();

create or replace function public.app_kombax_ai_credits_r97(p_tenant_ref text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_ctx record;v_data jsonb;v_total integer;v_used integer;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
 if v_ctx.tenant_ref not like 'club:%' and v_ctx.tenant_ref not like 'profile:%' then raise exception 'organization_required' using errcode='42501'; end if;
 if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then raise exception 'organization_access_required' using errcode='42501'; end if;
 if not exists(select 1 from kombax_commercial.pilot_entities_r97 where tenant_ref=v_ctx.tenant_ref) then return jsonb_build_object('pilot',false,'tenant_ref',v_ctx.tenant_ref); end if;
 v_data:=kombax_ai_ops.ai_ensure_wallet_r97(v_ctx.tenant_ref,v_ctx.plan,now());
 select coalesce(sum(total),0) into v_total from kombax_ai_ops.ai_credit_grants_r97 where tenant_ref=v_ctx.tenant_ref;
 select coalesce(sum(charged),0) into v_used from kombax_ai_ops.ai_credit_reservations_r97 where tenant_ref=v_ctx.tenant_ref and status='SETTLED';
 return v_data||jsonb_build_object('granted_total',v_total,'used_total',v_used,'plan',v_ctx.plan,'shared_between',jsonb_build_array('Assist','Migrations'));
end $$;
revoke all on function public.app_kombax_ai_credits_r97(text) from public,anon,service_role;
grant execute on function public.app_kombax_ai_credits_r97(text) to authenticated;

create or replace function public.app_kombax_ai_grant_r97(p_tenant_ref text,p_amount integer,p_type text,p_key text,p_expires timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_wallet kombax_ai_ops.ai_wallets_r97%rowtype;v_created boolean;
begin
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
 if p_amount not between 1 and 100000 or p_type not in ('promotional','purchased','compensation','onboarding') or length(p_key) not between 6 and 120 then raise exception 'invalid_grant'; end if;
 if not exists(select 1 from kombax_commercial.pilot_entities_r97 where tenant_ref=p_tenant_ref) then raise exception 'pilot_entity_required'; end if;
 insert into kombax_ai_ops.ai_wallets_r97(tenant_ref) values(p_tenant_ref) on conflict do nothing;
 select * into v_wallet from kombax_ai_ops.ai_wallets_r97 where tenant_ref=p_tenant_ref for update;
 v_created:=kombax_ai_ops.ai_grant_locked_r97(p_tenant_ref,p_type,p_amount,p_key,p_expires,auth.uid());
 return jsonb_build_object('ok',true,'created',v_created,'tenant_ref',p_tenant_ref);
end $$;
revoke all on function public.app_kombax_ai_grant_r97(text,integer,text,text,timestamptz) from public,anon,service_role;
grant execute on function public.app_kombax_ai_grant_r97(text,integer,text,text,timestamptz) to authenticated;

revoke all on function kombax_ai_ops.ai_monthly_amount_r97(text) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_grant_locked_r97(text,text,integer,text,timestamptz,uuid) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_ensure_wallet_r97(text,text,timestamptz) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_reserve_turn_r97(uuid,text,text,text) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_settle_turn_r97(uuid,numeric,boolean) from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_turn_insert_r97() from public,anon,authenticated;
revoke all on function kombax_ai_ops.ai_turn_finish_r97() from public,anon,authenticated;

commit;
