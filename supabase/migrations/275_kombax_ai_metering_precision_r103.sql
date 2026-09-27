-- R103: precise entity-scoped credits on the existing R97 wallet.
begin;

-- One thousandth of a visible credit is stored without creating another wallet.
alter table kombax_ai_ops.ai_wallets_r97
  alter column available type numeric(18,3) using available::numeric,
  alter column reserved type numeric(18,3) using reserved::numeric;
alter table kombax_ai_ops.ai_credit_grants_r97
  alter column total type numeric(18,3) using total::numeric,
  alter column remaining type numeric(18,3) using remaining::numeric;
alter table kombax_ai_ops.ai_credit_reservations_r97
  alter column held type numeric(18,3) using held::numeric,
  alter column charged type numeric(18,3) using charged::numeric,
  alter column shortfall type numeric(18,3) using shortfall::numeric;
alter table kombax_ai_ops.ai_credit_ledger_r97
  alter column amount type numeric(18,3) using amount::numeric;

insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('ai_credit_micro_units','1000','Internal precision per visible credit'),
 ('ai_credits_per_eur','400','Internal calibration; not a customer price'),
 ('ai_eur_per_usd','1.0','Conservative configurable conversion until invoice reconciliation'),
 ('ai_credit_safety_margin','1.20','Internal reserve against variable API costs')
on conflict(config_key) do nothing;

alter table kombax_ai_ops.model_cost_rates
  add column if not exists cached_input_per_million numeric(12,6),
  add column if not exists cache_write_per_million numeric(12,6);
update kombax_ai_ops.model_cost_rates
set cached_input_per_million=coalesce(cached_input_per_million,input_per_million*0.1),
    cache_write_per_million=coalesce(cache_write_per_million,input_per_million*1.25);
update kombax_ai_ops.model_cost_rates
set input_per_million=0.10,output_per_million=0.50,
    cached_input_per_million=0.01,cache_write_per_million=0.125,updated_at=now()
where model_alias='gpt-6-luna';

create table if not exists kombax_ai_ops.ai_tool_cost_rates_r103(
  tool_name text primary key,
  usd_per_call numeric(14,8) not null check(usd_per_call>=0),
  updated_at timestamptz not null default now()
);
alter table kombax_ai_ops.ai_tool_cost_rates_r103 enable row level security;
revoke all on kombax_ai_ops.ai_tool_cost_rates_r103 from public,anon,authenticated;
grant all on kombax_ai_ops.ai_tool_cost_rates_r103 to service_role;

create table if not exists kombax_ai_ops.ai_usage_runs_r103(
  run_id text primary key,
  turn_id uuid not null unique references kombax_ai_ops.assistance_turns(turn_id) on delete restrict,
  tenant_ref text not null references kombax_ai_ops.ai_wallets_r97(tenant_ref),
  user_ref uuid not null references auth.users(id) on delete restrict,
  conversation_id text not null,
  agent text not null,
  model_alias text not null,
  input_tokens integer not null check(input_tokens>=0),
  cached_input_tokens integer not null default 0 check(cached_input_tokens>=0),
  cache_write_tokens integer not null default 0 check(cache_write_tokens>=0),
  output_tokens integer not null check(output_tokens>=0),
  reasoning_tokens integer not null default 0 check(reasoning_tokens>=0),
  image_input_tokens integer not null default 0 check(image_input_tokens>=0),
  tool_calls jsonb not null default '[]'::jsonb,
  total_tokens integer not null check(total_tokens>=0),
  api_cost_usd numeric(18,9) not null check(api_cost_usd>=0),
  api_cost_eur numeric(18,9) not null check(api_cost_eur>=0),
  charged_credits numeric(18,3) not null check(charged_credits>=0),
  usage_source text not null default 'OPENAI_RESPONSE',
  created_at timestamptz not null default now(),
  check(cached_input_tokens+cache_write_tokens<=input_tokens),
  check(reasoning_tokens<=output_tokens)
);
create index if not exists ai_usage_tenant_time_r103 on kombax_ai_ops.ai_usage_runs_r103(tenant_ref,created_at desc);
create index if not exists ai_usage_agent_time_r103 on kombax_ai_ops.ai_usage_runs_r103(agent,created_at desc);
alter table kombax_ai_ops.ai_usage_runs_r103 enable row level security;
revoke all on kombax_ai_ops.ai_usage_runs_r103 from public,anon,authenticated;
grant all on kombax_ai_ops.ai_usage_runs_r103 to service_role;

create or replace function kombax_ai_ops.ai_usage_to_credits_r103(p_model text,p_usage jsonb,p_tools jsonb default '[]'::jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rate kombax_ai_ops.model_cost_rates%rowtype;
 v_input integer;v_cached integer;v_writes integer;v_output integer;v_reasoning integer;v_image integer;
 v_tool jsonb;v_tool_cost numeric:=0;v_usd numeric;v_eur numeric;v_credits numeric;
 v_fx numeric;v_margin numeric;v_factor numeric;
begin
 if jsonb_typeof(p_usage)<>'object' or not (p_usage ? 'input_tokens') or not (p_usage ? 'output_tokens') then
   raise exception 'AI_OFFICIAL_USAGE_REQUIRED';
 end if;
 select * into v_rate from kombax_ai_ops.model_cost_rates
 where model_alias=p_model and effective_from<=now() and (effective_to is null or effective_to>now());
 if not found then raise exception 'AI_MODEL_RATE_MISSING'; end if;
 v_input:=greatest(0,coalesce((p_usage->>'input_tokens')::integer,0));
 v_output:=greatest(0,coalesce((p_usage->>'output_tokens')::integer,0));
 v_cached:=greatest(0,coalesce((p_usage#>>'{input_tokens_details,cached_tokens}')::integer,0));
 v_writes:=greatest(0,coalesce((p_usage#>>'{input_tokens_details,cache_write_tokens}')::integer,(p_usage#>>'{input_tokens_details,cache_creation_tokens}')::integer,0));
 v_reasoning:=greatest(0,coalesce((p_usage#>>'{output_tokens_details,reasoning_tokens}')::integer,0));
 v_image:=greatest(0,coalesce((p_usage#>>'{input_tokens_details,image_tokens}')::integer,0));
 if v_cached+v_writes>v_input or v_reasoning>v_output then raise exception 'AI_USAGE_DETAILS_INVALID'; end if;
 if jsonb_typeof(p_tools)='array' then
   for v_tool in select value from jsonb_array_elements(p_tools) loop
     select v_tool_cost+coalesce((select usd_per_call from kombax_ai_ops.ai_tool_cost_rates_r103 where tool_name=v_tool->>'type'),0)
     into v_tool_cost;
   end loop;
 end if;
 v_usd:=round((((v_input-v_cached-v_writes)*v_rate.input_per_million
   +v_cached*coalesce(v_rate.cached_input_per_million,v_rate.input_per_million)
   +v_writes*coalesce(v_rate.cache_write_per_million,v_rate.input_per_million)
   +v_output*v_rate.output_per_million)/1000000)+v_tool_cost,9);
 select coalesce((value::text)::numeric,1) into v_fx from kombax_commercial.runtime_config_r64 where config_key='ai_eur_per_usd';
 select coalesce((value::text)::numeric,1.2) into v_margin from kombax_commercial.runtime_config_r64 where config_key='ai_credit_safety_margin';
 select coalesce((value::text)::numeric,400) into v_factor from kombax_commercial.runtime_config_r64 where config_key='ai_credits_per_eur';
 v_eur:=round(v_usd*v_fx,9);
 v_credits:=case when v_usd=0 then 0 else greatest(0.001,round(v_eur*v_margin*v_factor,3)) end;
 return jsonb_build_object('input_tokens',v_input,'cached_input_tokens',v_cached,'cache_write_tokens',v_writes,
   'output_tokens',v_output,'reasoning_tokens',v_reasoning,'image_input_tokens',v_image,
   'total_tokens',coalesce((p_usage->>'total_tokens')::integer,v_input+v_output),
   'api_cost_usd',v_usd,'api_cost_eur',v_eur,'credits',v_credits);
end $$;
revoke all on function kombax_ai_ops.ai_usage_to_credits_r103(text,jsonb,jsonb) from public,anon,authenticated;

commit;
