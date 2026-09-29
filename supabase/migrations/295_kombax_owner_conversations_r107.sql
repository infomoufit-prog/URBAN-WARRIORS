-- KOMBAX build 20160 · R107 · Owner conversation workspace.
begin;

create table if not exists kombax_owner_ai.conversations(
  id uuid primary key,
  owner_id uuid not null references public.perfiles(id) on delete restrict,
  agent text not null check(agent in ('owner_operations','pilot_intelligence')),
  title text not null default 'Nueva conversación' check(char_length(btrim(title)) between 1 and 180),
  status text not null default 'active' check(status in ('active','saved','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id,id)
);
create index if not exists idx_owner_ai_conversations_owner_r107 on kombax_owner_ai.conversations(owner_id,status,updated_at desc);
revoke all on kombax_owner_ai.conversations from public,anon,authenticated;

insert into kombax_owner_ai.conversations(id,owner_id,agent,title,status,created_at,updated_at)
select t.conversation_id,t.requested_by,min(t.agent),left(min(t.user_message),180),'saved',min(t.created_at),max(coalesce(t.completed_at,t.created_at))
from kombax_owner_ai.agent_turns t group by t.conversation_id,t.requested_by on conflict(id) do nothing;

create or replace function public.app_kombax_owner_agent_conversation_mutate_r107(p_operation text,p_agent text default null,p_conversation_id uuid default null,p_title text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v kombax_owner_ai.conversations;v_id uuid:=coalesce(p_conversation_id,gen_random_uuid());
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if p_operation='create' then
    if p_agent not in ('owner_operations','pilot_intelligence') then raise exception 'OWNER_AGENT_INVALID'; end if;
    insert into kombax_owner_ai.conversations(id,owner_id,agent,title) values(v_id,v_uid,p_agent,left(coalesce(nullif(btrim(p_title),''),'Nueva conversación'),180)) returning * into v;
  elsif p_operation in ('save','rename','archive','reopen') then
    update kombax_owner_ai.conversations set title=case when p_operation in ('save','rename') then left(coalesce(nullif(btrim(p_title),''),title),180) else title end,status=case when p_operation='save' then 'saved' when p_operation='archive' then 'archived' when p_operation='reopen' then 'active' else status end,updated_at=now() where id=p_conversation_id and owner_id=v_uid returning * into v;
  else raise exception 'OWNER_CONVERSATION_OPERATION_INVALID'; end if;
  if v.id is null then raise exception 'OWNER_CONVERSATION_NOT_FOUND'; end if;
  return jsonb_build_object('ok',true,'conversation',jsonb_build_object('id',v.id,'agent',v.agent,'title',v.title,'status',v.status,'created_at',v.created_at,'updated_at',v.updated_at));
end $$;
revoke all on function public.app_kombax_owner_agent_conversation_mutate_r107(text,text,uuid,text) from public,anon;
grant execute on function public.app_kombax_owner_agent_conversation_mutate_r107(text,text,uuid,text) to authenticated;

create or replace function public.app_kombax_owner_agent_turn_start_r105(
  p_agent text,p_message text,p_context_type text default null,p_context_id uuid default null,
  p_reasoning_effort text default 'low',p_conversation_id uuid default null,p_client_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v kombax_owner_ai.agent_turns;v_conversation_id uuid:=coalesce(p_conversation_id,gen_random_uuid());
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if p_agent not in ('owner_operations','pilot_intelligence') then raise exception 'OWNER_AGENT_INVALID'; end if;
  if p_reasoning_effort not in ('low','medium') then raise exception 'OWNER_AGENT_EFFORT_INVALID'; end if;
  if p_context_type is not null and p_context_type not in ('platform_application','seller_application','pilot_summary','platform_summary') then raise exception 'OWNER_AGENT_CONTEXT_INVALID'; end if;
  if p_conversation_id is not null and not exists(select 1 from kombax_owner_ai.conversations where id=p_conversation_id and owner_id=v_uid and agent=p_agent and status<>'archived') then raise exception 'OWNER_CONVERSATION_NOT_AVAILABLE'; end if;
  insert into kombax_owner_ai.conversations(id,owner_id,agent,title,status) values(v_conversation_id,v_uid,p_agent,left(btrim(p_message),180),'active') on conflict(id) do update set updated_at=now(),status=case when kombax_owner_ai.conversations.status='saved' then 'saved' else 'active' end;
  insert into kombax_owner_ai.agent_turns(conversation_id,agent,requested_by,client_request_id,user_message,context_type,context_id,reasoning_effort)
  values(v_conversation_id,p_agent,v_uid,p_client_request_id,left(btrim(p_message),4000),p_context_type,p_context_id,p_reasoning_effort)
  on conflict(requested_by,client_request_id) do update set client_request_id=excluded.client_request_id returning * into v;
  return jsonb_build_object('ok',true,'turn_id',v.id,'conversation_id',v.conversation_id,'status',v.status,'reused',v.created_at<now()-interval '1 second');
end $$;
revoke all on function public.app_kombax_owner_agent_turn_start_r105(text,text,text,uuid,text,uuid,uuid) from public,anon;
grant execute on function public.app_kombax_owner_agent_turn_start_r105(text,text,text,uuid,text,uuid,uuid) to authenticated;

create or replace function public.app_kombax_owner_agent_conversations_r107()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_rows jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'agent',c.agent,'title',c.title,'status',c.status,'turns',(select count(*) from kombax_owner_ai.agent_turns t where t.conversation_id=c.id),'last_message',(select left(t.user_message,220) from kombax_owner_ai.agent_turns t where t.conversation_id=c.id order by t.created_at desc limit 1),'created_at',c.created_at,'updated_at',c.updated_at) order by c.updated_at desc),'[]'::jsonb) into v_rows from (select * from kombax_owner_ai.conversations where owner_id=v_uid order by updated_at desc limit 100) c;
  return jsonb_build_object('ok',true,'conversations',v_rows);
end $$;
revoke all on function public.app_kombax_owner_agent_conversations_r107() from public,anon;
grant execute on function public.app_kombax_owner_agent_conversations_r107() to authenticated;

notify pgrst,'reload schema';
commit;
