-- Applied to Supabase project poggsobhtutbuagjiydc on 2026-09-01.
-- Live migration version: 20260901070443.

create schema if not exists kombax_customer_ops;
revoke all on schema kombax_customer_ops from public, anon, authenticated, service_role;
revoke all on all tables in schema kombax_customer_ops from public, anon, authenticated, service_role;
alter default privileges in schema kombax_customer_ops revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema kombax_customer_ops revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges in schema kombax_customer_ops revoke execute on functions from public, anon, authenticated, service_role;

create table if not exists kombax_customer_ops.tickets (
  ticket_id text primary key check (ticket_id ~ '^KMX-[0-9]{4}-[0-9]{6}$'),
  tenant_ref text null,
  user_ref uuid null references auth.users(id) on delete set null,
  requester_email_hash text not null check (requester_email_hash ~ '^[0-9a-f]{64}$'),
  status text not null check (status in ('OPEN','AI_REVIEW','WAITING_USER','AI_RESOLVED','GUIDED_SESSION','ESCALATED','HUMAN_REVIEW','RESOLVED','CLOSED')),
  category text not null,
  priority text not null check (priority in ('LOW','MEDIUM','HIGH','URGENT')),
  module text null,
  assigned_agent text not null default 'KOMBAX-SUPPORT',
  subject_redacted text not null,
  opened_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz null,
  closed_at timestamptz null
);
create index if not exists tickets_tenant_updated_idx on kombax_customer_ops.tickets (tenant_ref, updated_at desc);
create index if not exists tickets_status_priority_idx on kombax_customer_ops.tickets (status, priority, updated_at);

create table if not exists kombax_customer_ops.ticket_messages (
  message_id uuid primary key,
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  provider_message_hash text not null unique check (provider_message_hash ~ '^[0-9a-f]{64}$'),
  direction text not null check (direction in ('INBOUND','OUTBOUND_DRAFT','OUTBOUND_SENT')),
  sender_ref text not null,
  content_ciphertext bytea not null,
  content_key_ref text not null,
  content_sha256 text not null check (content_sha256 ~ '^[0-9a-f]{64}$'),
  attachment_count integer not null default 0 check (attachment_count between 0 and 10),
  created_at timestamptz not null default now()
);
create index if not exists ticket_messages_ticket_created_idx on kombax_customer_ops.ticket_messages (ticket_id, created_at);

create table if not exists kombax_customer_ops.ticket_events (
  event_id uuid primary key,
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  event_type text not null,
  actor_type text not null check (actor_type in ('SYSTEM','AGENT','HUMAN','USER')),
  actor_ref text null,
  from_status text null,
  to_status text null,
  detail jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists ticket_events_ticket_time_idx on kombax_customer_ops.ticket_events (ticket_id, occurred_at);

create table if not exists kombax_customer_ops.email_outbox (
  outbox_id uuid primary key,
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  draft_message_id uuid not null references kombax_customer_ops.ticket_messages(message_id) on delete restrict,
  disposition text not null check (disposition in ('DRAFT','AWAITING_HUMAN','APPROVED','SENDING','SENT','FAILED','CANCELLED')),
  idempotency_key text not null unique,
  approved_by uuid null references auth.users(id) on delete set null,
  approved_at timestamptz null,
  sent_at timestamptz null,
  provider_receipt_hash text null,
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  created_at timestamptz not null default now()
);
create index if not exists email_outbox_disposition_created_idx on kombax_customer_ops.email_outbox (disposition, created_at);

create table if not exists kombax_customer_ops.guided_sessions (
  session_id uuid primary key,
  ticket_id text not null unique references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  tenant_ref text not null,
  user_ref uuid not null references auth.users(id) on delete restrict,
  status text not null check (status in ('PENDING','ACTIVE','CLOSED','EXPIRED','ESCALATED')),
  accepted_at timestamptz not null,
  permissions text[] not null default '{}',
  max_interactions integer not null check (max_interactions between 1 and 12),
  max_input_tokens integer not null check (max_input_tokens between 1 and 12000),
  max_output_tokens integer not null check (max_output_tokens between 1 and 4000),
  max_duration_minutes integer not null check (max_duration_minutes between 1 and 30),
  inactivity_minutes integer not null check (inactivity_minutes between 1 and 10),
  max_estimated_cost numeric(8,4) not null check (max_estimated_cost between 0 and 0.75),
  started_at timestamptz null,
  expires_at timestamptz not null,
  closed_at timestamptz null
);

create table if not exists kombax_customer_ops.support_metrics_daily (
  metric_date date not null,
  tenant_ref text not null,
  first_response_ms bigint null check (first_response_ms >= 0),
  tickets_opened integer not null default 0 check (tickets_opened >= 0),
  ai_resolved integer not null default 0 check (ai_resolved >= 0),
  human_escalated integer not null default 0 check (human_escalated >= 0),
  guided_sessions integer not null default 0 check (guided_sessions >= 0),
  failed_resolutions integer not null default 0 check (failed_resolutions >= 0),
  reopened integer not null default 0 check (reopened >= 0),
  input_tokens bigint not null default 0 check (input_tokens >= 0),
  output_tokens bigint not null default 0 check (output_tokens >= 0),
  estimated_cost numeric(14,6) not null default 0 check (estimated_cost >= 0),
  primary key (metric_date, tenant_ref)
);

alter table kombax_customer_ops.tickets enable row level security;
alter table kombax_customer_ops.ticket_messages enable row level security;
alter table kombax_customer_ops.ticket_events enable row level security;
alter table kombax_customer_ops.email_outbox enable row level security;
alter table kombax_customer_ops.guided_sessions enable row level security;
alter table kombax_customer_ops.support_metrics_daily enable row level security;

-- No policies or API grants are intentionally provided. Access is server-to-server
-- through a narrowly scoped database role to be created during reviewed deployment.

