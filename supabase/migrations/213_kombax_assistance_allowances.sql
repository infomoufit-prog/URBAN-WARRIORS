-- KOMBAX AI assistance allowances v2.13
-- Additive migration. Customer-visible APIs expose allowances only; model, token and cost data stay private.

create schema if not exists kombax_ai_ops;
revoke all on schema kombax_ai_ops from public, anon, authenticated, service_role;
alter default privileges in schema kombax_ai_ops revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema kombax_ai_ops revoke execute on functions from public, anon, authenticated, service_role;

create table kombax_ai_ops.assistance_plan_entitlements (
  plan text primary key check (plan in ('CLUB_BASIC','CLUB_PREMIUM','FEDERATION')),
  monthly_assistance integer not null check (monthly_assistance >= 0),
  first_month_assistance integer not null check (first_month_assistance >= monthly_assistance),
  migration_allowance jsonb not null check (jsonb_typeof(migration_allowance)='object'),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  owner_editable boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from)
);

insert into kombax_ai_ops.assistance_plan_entitlements(plan,monthly_assistance,first_month_assistance,migration_allowance)
values
 ('CLUB_BASIC',10,20,'{"cases":2,"first_month_cases":4,"max_documents_total":200,"max_total_mb":500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG"],"validity_days":45}'::jsonb),
 ('CLUB_PREMIUM',25,40,'{"cases":5,"first_month_cases":8,"max_documents_total":1000,"max_total_mb":2500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG","ZIP"],"validity_days":60}'::jsonb),
 ('FEDERATION',40,60,'{"cases":8,"first_month_cases":12,"max_documents_total":3000,"max_total_mb":7500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG","ZIP"],"validity_days":90}'::jsonb)
on conflict (plan) do nothing;

create table kombax_ai_ops.assistance_tenant_settings (
  tenant_ref text primary key,
  plan_override text references kombax_ai_ops.assistance_plan_entitlements(plan),
  started_at timestamptz,
  mrr_amount numeric(14,2) not null default 0 check (mrr_amount >= 0),
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index assistance_tenant_settings_plan_idx on kombax_ai_ops.assistance_tenant_settings(plan_override) where plan_override is not null;

create table kombax_ai_ops.assistance_periods (
  period_id uuid primary key default gen_random_uuid(),
  tenant_ref text not null,
  plan text not null references kombax_ai_ops.assistance_plan_entitlements(plan),
  allowance_total integer not null check (allowance_total >= 0),
  allowance_used integer not null default 0 check (allowance_used between 0 and allowance_total),
  period_start timestamptz not null,
  period_end timestamptz not null,
  first_month_bonus integer not null default 0 check (first_month_bonus >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_ref,period_start),
  check (period_end > period_start)
);
create index assistance_periods_tenant_end_idx on kombax_ai_ops.assistance_periods(tenant_ref,period_end desc);
create index assistance_periods_plan_idx on kombax_ai_ops.assistance_periods(plan);

create table kombax_ai_ops.assistance_cases (
  assistance_case_id uuid primary key default gen_random_uuid(),
  period_id uuid not null references kombax_ai_ops.assistance_periods(period_id) on delete restrict,
  tenant_ref text not null,
  user_ref uuid not null,
  contextual_case_key text not null,
  session_id uuid,
  ticket_id text,
  channel text not null check (channel in ('CHAT','GUIDED_SESSION','EMAIL','TICKET')),
  idempotency_key text not null,
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  estimated_cost numeric(14,6) not null default 0 check (estimated_cost >= 0),
  model_alias text,
  consumed_at timestamptz not null default now(),
  unique (tenant_ref,period_id,contextual_case_key),
  unique (tenant_ref,idempotency_key),
  check (session_id is not null or ticket_id is not null)
);
create index assistance_cases_tenant_time_idx on kombax_ai_ops.assistance_cases(tenant_ref,consumed_at desc);
create index assistance_cases_period_idx on kombax_ai_ops.assistance_cases(period_id);

create table kombax_ai_ops.migration_allowance_cases (
  migration_case_id uuid primary key default gen_random_uuid(),
  tenant_ref text not null,
  user_ref uuid not null,
  plan text not null references kombax_ai_ops.assistance_plan_entitlements(plan),
  contextual_case_key text not null,
  ticket_id text not null,
  idempotency_key text not null,
  documents integer not null default 0 check (documents >= 0),
  size_mb numeric(14,3) not null default 0 check (size_mb >= 0),
  file_types text[] not null default '{}',
  valid_until timestamptz not null,
  consumed_at timestamptz not null default now(),
  unique (tenant_ref,contextual_case_key),
  unique (tenant_ref,idempotency_key)
);
create index migration_allowance_tenant_time_idx on kombax_ai_ops.migration_allowance_cases(tenant_ref,consumed_at desc);
create index migration_allowance_plan_idx on kombax_ai_ops.migration_allowance_cases(plan);

create table kombax_ai_ops.faq_deflections (
  deflection_id uuid primary key default gen_random_uuid(),
  tenant_ref text not null,
  user_ref uuid,
  answer_key text not null,
  channel text not null check (channel in ('HELP_CENTER','FORM','CHAT','EMAIL','TICKET','SUGGESTION')),
  idempotency_key text not null,
  avoided_ai boolean not null default true,
  occurred_at timestamptz not null default now(),
  unique (tenant_ref,idempotency_key)
);
create index faq_deflections_tenant_time_idx on kombax_ai_ops.faq_deflections(tenant_ref,occurred_at desc);

alter table kombax_ai_ops.assistance_plan_entitlements enable row level security;
alter table kombax_ai_ops.assistance_tenant_settings enable row level security;
alter table kombax_ai_ops.assistance_periods enable row level security;
alter table kombax_ai_ops.assistance_cases enable row level security;
alter table kombax_ai_ops.migration_allowance_cases enable row level security;
alter table kombax_ai_ops.faq_deflections enable row level security;

create or replace function kombax_ai_ops.resolve_context(p_uid uuid,p_tenant_hint text default null)
returns table(tenant_ref text,plan text,started_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare
  v_hint uuid;
  v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;

  begin
    v_hint:=replace(nullif(trim(p_tenant_hint),''),'club:','')::uuid;
  exception when invalid_text_representation then v_hint:=null;
  end;

  if v_hint is not null and exists(
    select 1 from public.miembros_club mc where mc.club_id=v_hint and mc.perfil_id=p_uid and mc.activo
  ) then
    tenant_ref:='club:'||v_hint::text;
    select coalesce(ts.plan_override,
             case s.modalidad when 'federacion_institucional' then 'FEDERATION'
                               when 'competidor_premium' then 'CLUB_PREMIUM'
                               when 'marca_profesional' then 'CLUB_PREMIUM'
                               else 'CLUB_BASIC' end),
           coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now())
      into plan,started_at
    from public.clubes c
    left join lateral (
      select ks.* from public.kombax_suscripciones ks
      where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in ('prueba','activa')
        and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
      order by ks.actualizado_en desc limit 1
    ) s on true
    left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text
    where c.id=v_hint;
    return next; return;
  end if;

  select d.id,d.creado_en,s.modalidad,s.inicia_en,s.creado_en subscription_created
    into v_direct
  from public.perfiles_kombax_directos d
  left join lateral (
    select ks.* from public.kombax_suscripciones ks
    where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
      and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
    order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
  ) s on true
  where d.perfil_id=p_uid and d.estado='activo'
  order by (s.modalidad='federacion_institucional') desc,d.actualizado_en desc limit 1;
  if found then
    tenant_ref:='profile:'||v_direct.id::text;
    select coalesce(ts.plan_override,
             case v_direct.modalidad when 'federacion_institucional' then 'FEDERATION'
                                      when 'competidor_premium' then 'CLUB_PREMIUM'
                                      when 'marca_profesional' then 'CLUB_PREMIUM'
                                      else 'CLUB_BASIC' end),
           coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now())
      into plan,started_at
    from (values(1)) x(n)
    left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
    return next; return;
  end if;

  select mc.club_id into v_hint from public.miembros_club mc
  where mc.perfil_id=p_uid and mc.activo order by (mc.rol::text='direccion') desc,mc.creado_en limit 1;
  if found then
    return query select * from kombax_ai_ops.resolve_context(p_uid,v_hint::text); return;
  end if;

  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now())
    into plan,started_at
  from public.perfiles p
  left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text
  where p.id=p_uid;
  if not found then plan:='CLUB_BASIC'; started_at:=now(); end if;
  return next;
end;
$$;

create or replace function kombax_ai_ops.ensure_current_period(p_tenant_ref text,p_plan text,p_started_at timestamptz,p_now timestamptz default now())
returns kombax_ai_ops.assistance_periods
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_months integer;
  v_start timestamptz;
  v_end timestamptz;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;
  v_period kombax_ai_ops.assistance_periods%rowtype;
  v_total integer;
  v_bonus integer;
begin
  if p_started_at is null or p_started_at>p_now then p_started_at:=p_now; end if;
  v_months:=(extract(year from age(p_now,p_started_at))::integer*12)+extract(month from age(p_now,p_started_at))::integer;
  v_months:=greatest(0,v_months);
  v_start:=p_started_at+(v_months*interval '1 month');
  if v_start>p_now then v_months:=greatest(0,v_months-1); v_start:=p_started_at+(v_months*interval '1 month'); end if;
  v_end:=p_started_at+((v_months+1)*interval '1 month');

  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e
  where e.plan=p_plan and e.effective_from<=p_now and (e.effective_to is null or e.effective_to>p_now);
  v_total:=case when v_months=0 then v_ent.first_month_assistance else v_ent.monthly_assistance end;
  v_bonus:=case when v_months=0 then v_ent.first_month_assistance-v_ent.monthly_assistance else 0 end;

  insert into kombax_ai_ops.assistance_periods(tenant_ref,plan,allowance_total,period_start,period_end,first_month_bonus)
  values(p_tenant_ref,p_plan,v_total,v_start,v_end,v_bonus)
  on conflict(tenant_ref,period_start) do update
    set plan=excluded.plan,
        allowance_total=greatest(kombax_ai_ops.assistance_periods.allowance_used,excluded.allowance_total),
        period_end=excluded.period_end,
        first_month_bonus=excluded.first_month_bonus,
        updated_at=now()
  returning * into v_period;
  return v_period;
end;
$$;

create or replace function kombax_ai_ops.reserve_assistance_for_ticket(p_uid uuid,p_ticket_id text)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_ctx record;
  v_period kombax_ai_ops.assistance_periods%rowtype;
  v_existing kombax_ai_ops.assistance_cases%rowtype;
  v_key text;
begin
  select * into v_ticket from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=p_uid for update;
  if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(p_uid,v_ticket.tenant_ref);
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  select * into v_period from kombax_ai_ops.assistance_periods p where p.period_id=v_period.period_id for update;
  v_key:='guided-start:'||p_ticket_id||':'||v_period.period_start::text;

  select * into v_existing from kombax_ai_ops.assistance_cases c
  where c.tenant_ref=v_ctx.tenant_ref and (c.idempotency_key=v_key or (c.period_id=v_period.period_id and c.contextual_case_key='ticket:'||p_ticket_id)) limit 1;
  if found then
    return jsonb_build_object('available',true,'consumed',false,'reason','EXISTING_CONTEXTUAL_CASE','allowance_total',v_period.allowance_total,'allowance_remaining',v_period.allowance_total-v_period.allowance_used,'period_end',v_period.period_end);
  end if;
  if v_period.allowance_used>=v_period.allowance_total then
    return jsonb_build_object('available',false,'consumed',false,'reason','MONTHLY_ALLOWANCE_EXHAUSTED','allowance_total',v_period.allowance_total,'allowance_remaining',0,'period_end',v_period.period_end);
  end if;
  insert into kombax_ai_ops.assistance_cases(period_id,tenant_ref,user_ref,contextual_case_key,ticket_id,channel,idempotency_key)
  values(v_period.period_id,v_ctx.tenant_ref,p_uid,'ticket:'||p_ticket_id,p_ticket_id,'GUIDED_SESSION',v_key);
  update kombax_ai_ops.assistance_periods set allowance_used=allowance_used+1,updated_at=now()
  where period_id=v_period.period_id returning * into v_period;
  return jsonb_build_object('available',true,'consumed',true,'reason','NEW_CONTEXTUAL_CASE','allowance_total',v_period.allowance_total,'allowance_remaining',v_period.allowance_total-v_period.allowance_used,'period_end',v_period.period_end);
end;
$$;

create or replace function kombax_ai_ops.reserve_migration_for_ticket(p_uid uuid,p_ticket_id text)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_ctx record;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;
  v_settings jsonb;
  v_total integer;
  v_used integer;
  v_valid_until timestamptz;
begin
  select * into v_ticket from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=p_uid and t.category='MIGRATION' for update;
  if not found then raise exception 'migration_ticket_not_found' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(p_uid,v_ticket.tenant_ref);
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;
  v_settings:=v_ent.migration_allowance;
  v_valid_until:=v_ctx.started_at+((v_settings->>'validity_days')::integer*interval '1 day');
  v_total:=case when now()<v_ctx.started_at+interval '1 month' then (v_settings->>'first_month_cases')::integer else (v_settings->>'cases')::integer end;

  if exists(select 1 from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.contextual_case_key='ticket:'||p_ticket_id) then
    select count(*) into v_used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref;
    return jsonb_build_object('available',true,'consumed',false,'reason','EXISTING_MIGRATION_CASE','migration_total',v_total,'migration_remaining',greatest(0,v_total-v_used),'valid_until',v_valid_until);
  end if;
  select count(*) into v_used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref;
  if now()>v_valid_until or v_used>=v_total then
    return jsonb_build_object('available',false,'consumed',false,'reason','MIGRATION_ALLOWANCE_EXHAUSTED','migration_total',v_total,'migration_remaining',0,'valid_until',v_valid_until);
  end if;
  insert into kombax_ai_ops.migration_allowance_cases(tenant_ref,user_ref,plan,contextual_case_key,ticket_id,idempotency_key,valid_until)
  values(v_ctx.tenant_ref,p_uid,v_ctx.plan,'ticket:'||p_ticket_id,p_ticket_id,'migration:'||p_ticket_id,v_valid_until);
  return jsonb_build_object('available',true,'consumed',true,'reason','NEW_MIGRATION_CASE','migration_total',v_total,'migration_remaining',greatest(0,v_total-v_used-1),'valid_until',v_valid_until);
end;
$$;

create or replace function public.app_kombax_assistance_allowance_v213(p_tenant_ref text default null)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_ctx record; v_period kombax_ai_ops.assistance_periods%rowtype; v_remaining integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  v_remaining:=greatest(0,v_period.allowance_total-v_period.allowance_used);
  return jsonb_build_object(
    'allowance_total',v_period.allowance_total,
    'allowance_remaining',v_remaining,
    'period_end',v_period.period_end,
    'exhausted',v_remaining=0,
    'message',case when v_remaining=0 then 'Has utilizado las asistencias virtuales incluidas este mes. Puedes seguir utilizando el Centro de ayuda o enviar una solicitud a soporte.' else v_remaining||' de '||v_period.allowance_total||' asistencias disponibles este mes.' end
  );
end;
$$;

create or replace function public.app_kombax_customer_ops_mutate_v213(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ticket_id text; v_ticket kombax_customer_ops.tickets%rowtype;
  v_now timestamptz:=clock_timestamp(); v_category text; v_priority text; v_subject text; v_ctx record;
  v_from_status text; v_allowance jsonb;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_operation='ticket.create' then
    select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_payload->>'tenant_ref');
    v_category:=left(coalesce(nullif(trim(p_payload->>'category'),''),'GENERAL'),64);
    v_priority:=case when v_category in ('SECURITY','DATA_LOSS','CRITICAL_PERMISSIONS') then 'URGENT' else 'MEDIUM' end;
    v_subject:=left(regexp_replace(coalesce(p_payload->>'subject','Solicitud de soporte'),E'[\n\r\t]+',' ','g'),180);
    loop
      v_ticket_id:='KMX-'||to_char(v_now,'YYYY')||'-'||lpad((floor(random()*1000000))::int::text,6,'0');
      exit when not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id);
    end loop;
    insert into kombax_customer_ops.tickets(ticket_id,tenant_ref,user_ref,requester_email_hash,status,category,priority,module,subject_redacted,opened_at,updated_at)
    values(v_ticket_id,v_ctx.tenant_ref,v_uid,encode(extensions.digest(lower(coalesce(auth.jwt()->>'email',v_uid::text)),'sha256'),'hex'),'OPEN',v_category,v_priority,left(nullif(trim(p_payload->>'module'),''),64),v_subject,v_now,v_now)
    returning * into v_ticket;
    insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,to_status,detail,occurred_at)
    values(gen_random_uuid(),v_ticket_id,'TICKET_CREATED','USER',v_uid::text,'OPEN',jsonb_build_object('channel','PWA'),v_now);
  elsif p_operation in ('ticket.human_review','ticket.guided_start') then
    v_ticket_id:=p_payload->>'ticket_id';
    select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id and t.user_ref=v_uid for update;
    if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
    v_from_status:=v_ticket.status;
    if p_operation='ticket.human_review' then
      update kombax_customer_ops.tickets as t set status='HUMAN_REVIEW',updated_at=v_now where t.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'HUMAN_REVIEW_REQUESTED','USER',v_uid::text,v_from_status,'HUMAN_REVIEW','{}',v_now);
    else
      if v_ticket.category='MIGRATION' then v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,v_ticket_id);
      else v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,v_ticket_id); end if;
      if not coalesce((v_allowance->>'available')::boolean,false) then
        return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'assistance_available',false,'allowance',v_allowance,'updated_at',v_ticket.updated_at);
      end if;
      insert into kombax_customer_ops.guided_sessions(session_id,ticket_id,tenant_ref,user_ref,status,accepted_at,permissions,max_interactions,max_input_tokens,max_output_tokens,max_duration_minutes,inactivity_minutes,max_estimated_cost,started_at,expires_at)
      values(gen_random_uuid(),v_ticket_id,v_ticket.tenant_ref,v_uid,'ACTIVE',v_now,'{}',12,12000,1200,30,10,0.10,v_now,v_now+interval '30 minutes')
      on conflict(ticket_id) do update set status='ACTIVE',accepted_at=v_now,started_at=v_now,expires_at=v_now+interval '30 minutes',closed_at=null;
      update kombax_customer_ops.tickets as t set status='GUIDED_SESSION',updated_at=v_now where t.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'GUIDED_SESSION_STARTED','USER',v_uid::text,v_from_status,'GUIDED_SESSION',jsonb_build_object('expires_at',v_now+interval '30 minutes','allowance_reason',v_allowance->>'reason'),v_now);
    end if;
  else raise exception 'unsupported_operation' using errcode='22023';
  end if;
  return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'assistance_available',true,'allowance',v_allowance,'updated_at',v_ticket.updated_at);
end;
$$;

create or replace function public.app_kombax_assistance_owner_dashboard_v213()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_out jsonb;
begin
  if auth.uid() is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
  select jsonb_build_object(
    'by_tenant',coalesce((select jsonb_agg(jsonb_build_object(
      'tenant_id',p.tenant_ref,'plan',p.plan,'allowance_total',p.allowance_total,'allowance_used',p.allowance_used,
      'allowance_remaining',p.allowance_total-p.allowance_used,'period_start',p.period_start,'period_end',p.period_end,
      'ai_cost',coalesce(c.ai_cost,0),'ai_cost_per_assistance',case when p.allowance_used>0 then round(coalesce(c.ai_cost,0)/p.allowance_used,6) else 0 end,
      'faq_avoided_consumption',coalesce(f.avoided,0),'migrations_consumed',coalesce(m.used,0),
      'ai_cost_mrr_ratio',case when coalesce(s.mrr_amount,0)>0 then round(coalesce(c.ai_cost,0)/s.mrr_amount,6) else null end
    ) order by p.allowance_used::numeric/nullif(p.allowance_total,0) desc)
    from kombax_ai_ops.assistance_periods p
    left join lateral (select sum(estimated_cost) ai_cost from kombax_ai_ops.assistance_cases c where c.period_id=p.period_id) c on true
    left join lateral (select count(*) avoided from kombax_ai_ops.faq_deflections f where f.tenant_ref=p.tenant_ref and f.occurred_at>=p.period_start and f.occurred_at<p.period_end and f.avoided_ai) f on true
    left join lateral (select count(*) used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=p.tenant_ref and m.consumed_at>=p.period_start and m.consumed_at<p.period_end) m on true
    left join kombax_ai_ops.assistance_tenant_settings s on s.tenant_ref=p.tenant_ref
    where now()>=p.period_start and now()<p.period_end),'[]'::jsonb),
    'by_plan',coalesce((select jsonb_agg(jsonb_build_object('plan',plan,'tenant_count',tenant_count,'average_used',average_used,'at_limit',at_limit,'near_limit',near_limit) order by plan)
      from (select plan,count(*) tenant_count,round(avg(allowance_used),2) average_used,count(*) filter(where allowance_used>=allowance_total) at_limit,count(*) filter(where allowance_total>0 and allowance_used>=allowance_total*0.8) near_limit from kombax_ai_ops.assistance_periods where now()>=period_start and now()<period_end group by plan) x),'[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$$;

create or replace function public.app_kombax_assistance_owner_config_v213(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_plan text; v_tenant text;
begin
  if auth.uid() is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
  if p_operation='plan.set' then
    v_plan:=upper(trim(p_payload->>'plan'));
    update kombax_ai_ops.assistance_plan_entitlements
    set monthly_assistance=coalesce((p_payload->>'monthly_assistance')::integer,monthly_assistance),
        first_month_assistance=coalesce((p_payload->>'first_month_assistance')::integer,first_month_assistance),
        migration_allowance=coalesce(p_payload->'migration_allowance',migration_allowance),updated_at=now()
    where plan=v_plan and owner_editable;
    if not found then raise exception 'editable_plan_not_found' using errcode='P0002'; end if;
  elsif p_operation='tenant.override' then
    v_tenant:=left(trim(p_payload->>'tenant_ref'),160); v_plan:=upper(nullif(trim(p_payload->>'plan'),''));
    if v_tenant is null or v_tenant='' then raise exception 'tenant_ref_required' using errcode='22023'; end if;
    insert into kombax_ai_ops.assistance_tenant_settings(tenant_ref,plan_override,started_at,mrr_amount,updated_by)
    values(v_tenant,v_plan,(p_payload->>'started_at')::timestamptz,coalesce((p_payload->>'mrr_amount')::numeric,0),auth.uid())
    on conflict(tenant_ref) do update set plan_override=excluded.plan_override,started_at=coalesce(excluded.started_at,kombax_ai_ops.assistance_tenant_settings.started_at),mrr_amount=excluded.mrr_amount,updated_by=auth.uid(),updated_at=now();
  else raise exception 'unsupported_operation' using errcode='22023'; end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'plan',v_plan,'tenant_ref',v_tenant);
end;
$$;

revoke all on function kombax_ai_ops.resolve_context(uuid,text) from public,anon,authenticated,service_role;
revoke all on function kombax_ai_ops.ensure_current_period(text,text,timestamptz,timestamptz) from public,anon,authenticated,service_role;
revoke all on function kombax_ai_ops.reserve_assistance_for_ticket(uuid,text) from public,anon,authenticated,service_role;
revoke all on function kombax_ai_ops.reserve_migration_for_ticket(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.app_kombax_assistance_allowance_v213(text) from public,anon,service_role;
revoke all on function public.app_kombax_customer_ops_mutate_v213(text,jsonb) from public,anon,service_role;
revoke all on function public.app_kombax_assistance_owner_dashboard_v213() from public,anon,authenticated,service_role;
revoke all on function public.app_kombax_assistance_owner_config_v213(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.app_kombax_assistance_allowance_v213(text) to authenticated;
grant execute on function public.app_kombax_customer_ops_mutate_v213(text,jsonb) to authenticated;
grant execute on function public.app_kombax_assistance_owner_dashboard_v213() to authenticated;
grant execute on function public.app_kombax_assistance_owner_config_v213(text,jsonb) to authenticated;

comment on schema kombax_ai_ops is 'Private KOMBAX AI assistance, migration allowance and support economy ledger.';
comment on function public.app_kombax_assistance_allowance_v213(text) is 'Customer-safe monthly allowance view. Never returns model, tokens, API cost or internal routing.';
