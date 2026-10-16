-- Reviewed learning proposals. No raw chats or student data are copied here.
create schema if not exists kombax_help_knowledge;
revoke all on schema kombax_help_knowledge from public,anon,authenticated;
create table kombax_help_knowledge.guide_sources_r277(
 guide_id text primary key check(length(guide_id) between 1 and 80)
);
create table kombax_help_knowledge.observations_r277(
 id uuid primary key default gen_random_uuid(),
 turn_id uuid not null,
 channel text not null check(channel in('paid','free')),
 guide_ids text[] not null default '{}' check(cardinality(guide_ids)<=5),
 reason text not null check(reason in('faq_gap','correction')),
 review_state text not null default 'pending' check(review_state in('pending','reviewed','rejected')),
 created_at timestamptz not null default now(),
 unique(channel,turn_id)
);
create index on kombax_help_knowledge.observations_r277(review_state,created_at desc);
create table kombax_help_knowledge.lessons_r277(
 id uuid primary key default gen_random_uuid(),
 guide_id text not null references kombax_help_knowledge.guide_sources_r277(guide_id),
 question text not null check(length(question) between 5 and 240),
 answer text not null check(length(answer) between 15 and 1200),
 source_ref text not null check(length(source_ref) between 5 and 500),
 status text not null default 'draft' check(status in('draft','published','rejected')),
 revision integer not null default 1 check(revision>0),
 created_by uuid not null,
 approved_by uuid,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(status<>'published' or approved_by is not null)
);
create index on kombax_help_knowledge.lessons_r277(guide_id,status,updated_at desc);
alter table kombax_help_knowledge.guide_sources_r277 enable row level security;
alter table kombax_help_knowledge.observations_r277 enable row level security;
alter table kombax_help_knowledge.lessons_r277 enable row level security;
revoke all on all tables in schema kombax_help_knowledge from public,anon,authenticated;

create function public.app_kombax_help_knowledge_read_r277(p_guide_ids text[])
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(
  select id,guide_id,question,answer,source_ref,revision
  from kombax_help_knowledge.lessons_r277
  where status='published' and guide_id=any(p_guide_ids[1:5])
  order by updated_at desc limit 3
 ) x;
$$;
revoke all on function public.app_kombax_help_knowledge_read_r277(text[]) from public,anon,authenticated;
grant execute on function public.app_kombax_help_knowledge_read_r277(text[]) to service_role;

create function public.app_kombax_help_learning_observe_r277(p_turn_id uuid,p_channel text,p_guide_ids text[],p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_guides text[];
begin
 if p_channel='paid' then
  if not exists(select 1 from kombax_ai_ops.assistance_turns where turn_id=p_turn_id and status='COMPLETED' and category='MANAGEMENT') then raise exception 'COMPLETED_TURN_REQUIRED';end if;
 elsif p_channel='free' then
  -- Free observations use the account-scoped request id, validated in that ledger.
  if not exists(select 1 from kombax_ai_ops.usage_help_turns_r274 where id=p_turn_id and status='COMPLETED') then raise exception 'COMPLETED_TURN_REQUIRED';end if;
 else raise exception 'INVALID_CHANNEL';end if;
 if p_reason not in('faq_gap','correction') then raise exception 'INVALID_REASON';end if;
 select coalesce(array_agg(s.guide_id),'{}'::text[]) into v_guides
 from kombax_help_knowledge.guide_sources_r277 s where s.guide_id=any(p_guide_ids[1:5]);
 insert into kombax_help_knowledge.observations_r277(turn_id,channel,guide_ids,reason)
 values(p_turn_id,p_channel,v_guides,p_reason) on conflict(channel,turn_id) do nothing returning id into v_id;
 return jsonb_build_object('recorded',v_id is not null);
end;$$;
revoke all on function public.app_kombax_help_learning_observe_r277(uuid,text,text[],text) from public,anon,authenticated;
grant execute on function public.app_kombax_help_learning_observe_r277(uuid,text,text[],text) to service_role;

create function public.app_kombax_help_knowledge_owner_r277(p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not coalesce(public.app_kombax_es_platform_admin_v055(),false) then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 return jsonb_build_object(
  'observations',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select id,turn_id,channel,guide_ids,reason,review_state,created_at from kombax_help_knowledge.observations_r277 order by created_at desc limit greatest(1,least(coalesce(p_limit,30),100))) x),
  'lessons',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from(select id,guide_id,question,answer,source_ref,status,revision,updated_at from kombax_help_knowledge.lessons_r277 order by updated_at desc limit greatest(1,least(coalesce(p_limit,30),100))) x)
 );
end;$$;
revoke all on function public.app_kombax_help_knowledge_owner_r277(integer) from public,anon;
grant execute on function public.app_kombax_help_knowledge_owner_r277(integer) to authenticated;

create function public.app_kombax_help_knowledge_review_r277(p_operation text,p_id uuid default null,p_payload jsonb default '{}'::jsonb,p_confirmation text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_id uuid;v_lesson kombax_help_knowledge.lessons_r277%rowtype;
begin
 if v_actor is null or not coalesce(public.app_kombax_es_platform_admin_v055(),false) then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 if p_operation='draft' then
  if p_id is null then
   insert into kombax_help_knowledge.lessons_r277(guide_id,question,answer,source_ref,created_by)
   values(p_payload->>'guide_id',p_payload->>'question',p_payload->>'answer',p_payload->>'source_ref',v_actor) returning id into v_id;
  else
   update kombax_help_knowledge.lessons_r277 set guide_id=p_payload->>'guide_id',question=p_payload->>'question',answer=p_payload->>'answer',source_ref=p_payload->>'source_ref',status='draft',approved_by=null,revision=revision+1,updated_at=now() where id=p_id returning id into v_id;
   if v_id is null then raise exception 'LESSON_NOT_FOUND';end if;
  end if;
 elsif p_operation='publish' then
  if p_confirmation is distinct from 'PUBLICAR CONOCIMIENTO GENERAL SIN DATOS PERSONALES' then raise exception 'EXPLICIT_REVIEW_REQUIRED';end if;
  update kombax_help_knowledge.lessons_r277 set status='published',approved_by=v_actor,updated_at=now() where id=p_id and status='draft' returning id into v_id;
  if v_id is null then raise exception 'DRAFT_REQUIRED';end if;
 elsif p_operation='reject' then
  update kombax_help_knowledge.lessons_r277 set status='rejected',updated_at=now() where id=p_id returning id into v_id;
  if v_id is null then raise exception 'LESSON_NOT_FOUND';end if;
 elsif p_operation in('reviewed','dismiss') then
  update kombax_help_knowledge.observations_r277 set review_state=case when p_operation='reviewed' then 'reviewed' else 'rejected' end where id=p_id returning id into v_id;
  if v_id is null then raise exception 'OBSERVATION_NOT_FOUND';end if;
 else raise exception 'INVALID_OPERATION';end if;
 return jsonb_build_object('ok',true,'id',v_id);
end;$$;
revoke all on function public.app_kombax_help_knowledge_review_r277(text,uuid,jsonb,text) from public,anon;
grant execute on function public.app_kombax_help_knowledge_review_r277(text,uuid,jsonb,text) to authenticated;

insert into kombax_help_knowledge.guide_sources_r277(guide_id) values
('start'),
('profile'),
('access'),
('enrollments'),
('students'),
('team'),
('scopes'),
('catalog'),
('groups'),
('sessions'),
('attendance'),
('tracking'),
('progress'),
('finance'),
('receipts'),
('reminders'),
('communications'),
('events'),
('community'),
('social'),
('showcase'),
('material'),
('documents'),
('archive'),
('notifications'),
('settings'),
('install'),
('privacy'),
('member-start'),
('member-schedule'),
('member-finance'),
('member-comms'),
('member-events'),
('member-material'),
('member-community'),
('member-social'),
('member-showcase'),
('member-notifications'),
('member-requests'),
('member-profile'),
('member-install'),
('account-create'),
('account-login'),
('identity-choose'),
('service-activate'),
('profile-public'),
('profile-showcase'),
('profile-events'),
('profile-brand'),
('profile-federation'),
('profile-documents'),
('charge-create'),
('payment-record'),
('tariff-change'),
('payment-validate'),
('finance-report'),
('automation-prepare'),
('social-explore'),
('social-publish'),
('social-media'),
('showcase-explore'),
('showcase-publish'),
('events-explore'),
('events-create'),
('assist-data'),
('migrations-import'),
('identity-create');
