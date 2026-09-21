-- KOMBAX 20.101 R38 · In-app KOMBAX Assist chat + private AI economy guardrails
-- Additive. Customer-safe APIs never expose model names, token counts or API cost.

create table if not exists kombax_ai_ops.assistance_cost_policies(
  plan text primary key references kombax_ai_ops.assistance_plan_entitlements(plan) on delete restrict,
  monthly_hard_cost numeric(10,4) not null check(monthly_hard_cost>0),
  first_month_hard_cost numeric(10,4) not null check(first_month_hard_cost>=monthly_hard_cost),
  general_case_hard_cost numeric(10,4) not null check(general_case_hard_cost>0),
  migration_case_hard_cost numeric(10,4) not null check(migration_case_hard_cost>=general_case_hard_cost),
  default_model text not null,
  escalation_model text not null,
  max_output_tokens integer not null check(max_output_tokens between 128 and 2000),
  max_turns_per_general_case integer not null check(max_turns_per_general_case between 2 and 20),
  max_turns_per_migration_case integer not null check(max_turns_per_migration_case between 4 and 40),
  max_files_per_batch integer not null check(max_files_per_batch between 1 and 8),
  max_visual_files_per_batch integer not null check(max_visual_files_per_batch between 1 and 6),
  max_batch_mb numeric(8,2) not null check(max_batch_mb between 1 and 40),
  image_detail text not null check(image_detail in('low','auto')),
  owner_editable boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into kombax_ai_ops.assistance_cost_policies(plan,monthly_hard_cost,first_month_hard_cost,general_case_hard_cost,migration_case_hard_cost,default_model,escalation_model,max_output_tokens,max_turns_per_general_case,max_turns_per_migration_case,max_files_per_batch,max_visual_files_per_batch,max_batch_mb,image_detail)
values
 ('CLUB_BASIC',0.60,1.20,0.05,0.35,'gpt-5.6-luna','gpt-5.6-terra',500,10,24,4,4,16,'low'),
 ('CLUB_PREMIUM',1.75,3.50,0.08,0.65,'gpt-5.6-luna','gpt-5.6-terra',650,12,30,5,4,22,'low'),
 ('FEDERATION',4.50,9.00,0.12,1.20,'gpt-5.6-luna','gpt-5.6-terra',800,14,36,6,4,28,'low')
on conflict(plan) do update set
 monthly_hard_cost=excluded.monthly_hard_cost,first_month_hard_cost=excluded.first_month_hard_cost,
 general_case_hard_cost=excluded.general_case_hard_cost,migration_case_hard_cost=excluded.migration_case_hard_cost,
 default_model=excluded.default_model,escalation_model=excluded.escalation_model,max_output_tokens=excluded.max_output_tokens,
 max_turns_per_general_case=excluded.max_turns_per_general_case,max_turns_per_migration_case=excluded.max_turns_per_migration_case,
 max_files_per_batch=excluded.max_files_per_batch,max_visual_files_per_batch=excluded.max_visual_files_per_batch,
 max_batch_mb=excluded.max_batch_mb,image_detail=excluded.image_detail,updated_at=now();

create table if not exists kombax_ai_ops.model_cost_rates(
  model_alias text primary key,
  input_per_million numeric(10,4) not null check(input_per_million>=0),
  output_per_million numeric(10,4) not null check(output_per_million>=0),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  updated_at timestamptz not null default now(),
  check(effective_to is null or effective_to>effective_from)
);
insert into kombax_ai_ops.model_cost_rates(model_alias,input_per_million,output_per_million,effective_from)
values
 ('gpt-5.6-luna',0.20,1.20,'2026-09-04T00:00:00Z'),
 ('gpt-5.6-terra',2.00,12.00,'2026-09-04T00:00:00Z')
on conflict(model_alias) do update set input_per_million=excluded.input_per_million,output_per_million=excluded.output_per_million,updated_at=now();

create table if not exists kombax_ai_ops.assistance_turns(
  turn_id uuid primary key default gen_random_uuid(),
  tenant_ref text not null,
  user_ref uuid not null references auth.users(id) on delete restrict,
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  session_id uuid references kombax_customer_ops.guided_sessions(session_id) on delete restrict,
  category text not null,
  client_request_id text not null,
  status text not null default 'RESERVED' check(status in('RESERVED','COMPLETED','FAILED','BLOCKED')),
  model_alias text,
  input_tokens integer not null default 0 check(input_tokens>=0),
  output_tokens integer not null default 0 check(output_tokens>=0),
  estimated_cost numeric(14,6) not null default 0 check(estimated_cost>=0),
  file_count integer not null default 0 check(file_count>=0),
  visual_file_count integer not null default 0 check(visual_file_count>=0),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  error_code text,
  unique(tenant_ref,client_request_id)
);
create index if not exists assistance_turns_tenant_time_idx on kombax_ai_ops.assistance_turns(tenant_ref,requested_at desc);
create index if not exists assistance_turns_ticket_time_idx on kombax_ai_ops.assistance_turns(ticket_id,requested_at);

create table if not exists kombax_customer_ops.assist_chat_messages(
  message_id uuid primary key default gen_random_uuid(),
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  user_ref uuid not null references auth.users(id) on delete restrict,
  turn_id uuid references kombax_ai_ops.assistance_turns(turn_id) on delete restrict,
  role text not null check(role in('USER','ASSISTANT','SYSTEM')),
  content_text text not null check(length(content_text) between 1 and 12000),
  created_at timestamptz not null default now(),
  unique(turn_id,role)
);
create index if not exists assist_chat_messages_ticket_time_idx on kombax_customer_ops.assist_chat_messages(ticket_id,created_at);

create table if not exists kombax_customer_ops.migration_file_analysis(
  file_id uuid primary key references kombax_customer_ops.migration_files(file_id) on delete restrict,
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  user_ref uuid not null references auth.users(id) on delete restrict,
  turn_id uuid references kombax_ai_ops.assistance_turns(turn_id) on delete restrict,
  summary text not null check(length(summary) between 1 and 4000),
  structured_preview jsonb not null default '{}'::jsonb,
  detected_records integer not null default 0 check(detected_records>=0),
  confidence numeric(4,3) not null default 0.700 check(confidence between 0 and 1),
  needs_review boolean not null default true,
  analyzed_at timestamptz not null default now()
);
create index if not exists migration_file_analysis_ticket_idx on kombax_customer_ops.migration_file_analysis(ticket_id,analyzed_at);

alter table kombax_ai_ops.assistance_cost_policies enable row level security;
alter table kombax_ai_ops.model_cost_rates enable row level security;
alter table kombax_ai_ops.assistance_turns enable row level security;
alter table kombax_customer_ops.assist_chat_messages enable row level security;
alter table kombax_customer_ops.migration_file_analysis enable row level security;
revoke all on kombax_ai_ops.assistance_cost_policies from public,anon,authenticated,service_role;
revoke all on kombax_ai_ops.model_cost_rates from public,anon,authenticated,service_role;
revoke all on kombax_ai_ops.assistance_turns from public,anon,authenticated,service_role;
revoke all on kombax_customer_ops.assist_chat_messages from public,anon,authenticated,service_role;
revoke all on kombax_customer_ops.migration_file_analysis from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
