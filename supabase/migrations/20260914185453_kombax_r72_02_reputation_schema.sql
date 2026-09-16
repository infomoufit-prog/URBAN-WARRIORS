-- KOMBAX R72 / build 20123 live section 02
begin;
-- 2. Reputation data. Private schema: never exposed directly through Data API.
-- ---------------------------------------------------------------------------
create schema if not exists kombax_reputation;
revoke all on schema kombax_reputation from public,anon,authenticated;
grant usage on schema kombax_reputation to service_role;

create table if not exists kombax_reputation.product_reviews(
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.kombax_showcase_elementos(id) on delete restrict,
 reviewer_user_id uuid not null references public.perfiles(id) on delete restrict,
 rating smallint not null check(rating between 1 and 5),
 body text not null default '' check(char_length(body)<=4000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_purchase boolean not null default false,
 verified_order_id uuid references kombax_payments.showcase_orders(id) on delete set null,
 seller_response text check(seller_response is null or char_length(seller_response)<=3000),
 seller_response_by uuid references public.perfiles(id) on delete set null,
 seller_response_at timestamptz,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(product_id,reviewer_user_id)
);

create table if not exists kombax_reputation.event_comments(
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
 user_id uuid not null references public.perfiles(id) on delete restrict,
 parent_id uuid references kombax_reputation.event_comments(id) on delete set null,
 body text not null default '' check(char_length(body)<=3000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_attendance boolean not null default false,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists kombax_reputation.event_reviews(
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
 user_id uuid not null references public.perfiles(id) on delete restrict,
 rating smallint not null check(rating between 1 and 5),
 body text not null default '' check(char_length(body)<=4000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_attendance boolean not null default false,
 organizer_response text check(organizer_response is null or char_length(organizer_response)<=3000),
 organizer_response_by uuid references public.perfiles(id) on delete set null,
 organizer_response_at timestamptz,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(event_id,user_id)
);

create table if not exists kombax_reputation.reputation_reports(
 id uuid primary key default gen_random_uuid(),
 reporter_user_id uuid not null references public.perfiles(id) on delete restrict,
 target_type text not null check(target_type in('product_review','event_comment','event_review')),
 target_id uuid not null,
 reason text not null check(char_length(reason) between 2 and 80),
 detail text not null default '' check(char_length(detail)<=1500),
 status text not null default 'pending' check(status in('pending','reviewing','dismissed','actioned')),
 resolution text,
 resolved_by uuid references public.perfiles(id) on delete set null,
 resolved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table kombax_reputation.product_reviews enable row level security;
alter table kombax_reputation.event_comments enable row level security;
alter table kombax_reputation.event_reviews enable row level security;
alter table kombax_reputation.reputation_reports enable row level security;
revoke all on all tables in schema kombax_reputation from public,anon,authenticated;
grant select,insert,update,delete on all tables in schema kombax_reputation to service_role;

create index if not exists idx_r72_product_reviews_product on kombax_reputation.product_reviews(product_id,status,created_at desc);
create index if not exists idx_r72_product_reviews_user on kombax_reputation.product_reviews(reviewer_user_id,updated_at desc);
create index if not exists idx_r72_event_comments_event on kombax_reputation.event_comments(event_id,status,created_at desc);
create index if not exists idx_r72_event_comments_parent on kombax_reputation.event_comments(parent_id) where parent_id is not null;
create index if not exists idx_r72_event_reviews_event on kombax_reputation.event_reviews(event_id,status,created_at desc);
create index if not exists idx_r72_reports_pending on kombax_reputation.reputation_reports(status,created_at desc);
create unique index if not exists uq_r72_report_open on kombax_reputation.reputation_reports(reporter_user_id,target_type,target_id) where status in('pending','reviewing');

-- ---------------------------------------------------------------------------
commit;
