-- KOMBAX build 20158 · R105 · Owner Operations + Pilot Intelligence.
-- Private persistence; the browser only sees owner-scoped RPC projections.
begin;

create schema if not exists kombax_owner_ai;
revoke all on schema kombax_owner_ai from public,anon,authenticated;

create table if not exists kombax_owner_ai.agent_turns(
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null default gen_random_uuid(),
  agent text not null check(agent in ('owner_operations','pilot_intelligence')),
  requested_by uuid not null references public.perfiles(id) on delete restrict,
  client_request_id uuid not null,
  user_message text not null check(char_length(btrim(user_message)) between 1 and 4000),
  context_type text check(context_type is null or context_type in ('platform_application','seller_application','pilot_summary','platform_summary')),
  context_id uuid,
  reasoning_effort text not null default 'low' check(reasoning_effort in ('low','medium')),
  model_alias text not null default 'gpt-6-luna',
  status text not null default 'queued' check(status in ('queued','processing','completed','failed')),
  assistant_message text,
  risk_level text check(risk_level is null or risk_level in ('low','medium','high','critical')),
  confidence numeric(5,4) check(confidence is null or confidence between 0 and 1),
  proposed_action jsonb not null default '{}'::jsonb check(jsonb_typeof(proposed_action)='object'),
  findings jsonb not null default '[]'::jsonb check(jsonb_typeof(findings)='array'),
  next_steps jsonb not null default '[]'::jsonb check(jsonb_typeof(next_steps)='array'),
  response_id text,
  usage_private jsonb not null default '{}'::jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(requested_by,client_request_id)
);
create index if not exists idx_owner_ai_turns_agent_created_r105 on kombax_owner_ai.agent_turns(agent,created_at desc);
create index if not exists idx_owner_ai_turns_context_r105 on kombax_owner_ai.agent_turns(context_type,context_id,created_at desc);
revoke all on kombax_owner_ai.agent_turns from public,anon,authenticated;

create table if not exists kombax_owner_ai.pilot_reports(
  id uuid primary key default gen_random_uuid(),
  report_type text not null check(report_type in ('daily','weekly','incident','release_gate')),
  period_start date not null,
  period_end date not null,
  status text not null default 'draft' check(status in ('draft','ready','published','failed')),
  title text not null,
  executive_summary text,
  sections jsonb not null default '[]'::jsonb check(jsonb_typeof(sections)='array'),
  source_snapshot jsonb not null default '{}'::jsonb check(jsonb_typeof(source_snapshot)='object'),
  pdf_storage_path text,
  generated_by_turn_id uuid references kombax_owner_ai.agent_turns(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(period_end>=period_start)
);
create index if not exists idx_owner_ai_reports_period_r105 on kombax_owner_ai.pilot_reports(period_end desc,report_type);
revoke all on kombax_owner_ai.pilot_reports from public,anon,authenticated;

create or replace function public.app_kombax_owner_agents_dashboard_r105()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_turns jsonb;v_reports jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',t.id,'conversation_id',t.conversation_id,'agent',t.agent,'message',t.user_message,
    'assistant_message',t.assistant_message,'status',t.status,'risk_level',t.risk_level,
    'confidence',t.confidence,'proposed_action',t.proposed_action,'findings',t.findings,
    'next_steps',t.next_steps,'context_type',t.context_type,'context_id',t.context_id,
    'reasoning_effort',t.reasoning_effort,'created_at',t.created_at,'completed_at',t.completed_at
  ) order by t.created_at),'[]'::jsonb) into v_turns
  from (select * from kombax_owner_ai.agent_turns where requested_by=v_uid order by created_at desc limit 40) t;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'report_type',r.report_type,'period_start',r.period_start,'period_end',r.period_end,
    'status',r.status,'title',r.title,'executive_summary',r.executive_summary,
    'pdf_ready',r.pdf_storage_path is not null,'created_at',r.created_at
  ) order by r.period_end desc,r.created_at desc),'[]'::jsonb) into v_reports
  from (select * from kombax_owner_ai.pilot_reports order by period_end desc,created_at desc limit 20) r;
  return jsonb_build_object('ok',true,'agents',jsonb_build_array(
    jsonb_build_object('code','owner_operations','name','Owner Operations','model','gpt-6-luna','efforts',jsonb_build_array('low','medium'),'autonomy','bounded'),
    jsonb_build_object('code','pilot_intelligence','name','Pilot Intelligence','model','gpt-6-luna','efforts',jsonb_build_array('low','medium'),'autonomy','read_only')
  ),'turns',v_turns,'reports',v_reports);
end $$;
revoke all on function public.app_kombax_owner_agents_dashboard_r105() from public,anon;
grant execute on function public.app_kombax_owner_agents_dashboard_r105() to authenticated;

create or replace function public.app_kombax_owner_agent_turn_start_r105(
  p_agent text,p_message text,p_context_type text default null,p_context_id uuid default null,
  p_reasoning_effort text default 'low',p_conversation_id uuid default null,p_client_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v kombax_owner_ai.agent_turns;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if p_agent not in ('owner_operations','pilot_intelligence') then raise exception 'OWNER_AGENT_INVALID'; end if;
  if p_reasoning_effort not in ('low','medium') then raise exception 'OWNER_AGENT_EFFORT_INVALID'; end if;
  if p_context_type is not null and p_context_type not in ('platform_application','seller_application','pilot_summary','platform_summary') then raise exception 'OWNER_AGENT_CONTEXT_INVALID'; end if;
  insert into kombax_owner_ai.agent_turns(conversation_id,agent,requested_by,client_request_id,user_message,context_type,context_id,reasoning_effort)
  values(coalesce(p_conversation_id,gen_random_uuid()),p_agent,v_uid,p_client_request_id,left(btrim(p_message),4000),p_context_type,p_context_id,p_reasoning_effort)
  on conflict(requested_by,client_request_id) do update set client_request_id=excluded.client_request_id
  returning * into v;
  return jsonb_build_object('ok',true,'turn_id',v.id,'conversation_id',v.conversation_id,'status',v.status,'reused',v.created_at<now()-interval '1 second');
end $$;
revoke all on function public.app_kombax_owner_agent_turn_start_r105(text,text,text,uuid,text,uuid,uuid) from public,anon;
grant execute on function public.app_kombax_owner_agent_turn_start_r105(text,text,text,uuid,text,uuid,uuid) to authenticated;

create or replace function public.app_kombax_owner_agent_turn_context_r105(p_turn_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());t kombax_owner_ai.agent_turns;v_context jsonb:='{}'::jsonb;v_history jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select * into t from kombax_owner_ai.agent_turns where id=p_turn_id and requested_by=v_uid;
  if t.id is null then raise exception 'OWNER_AGENT_TURN_NOT_FOUND'; end if;
  if t.context_type='platform_application' and t.context_id is not null then
    select jsonb_build_object(
      'kind','platform_application','id',a.id,'type',a.tipo,'name',a.nombre_publico,'status',a.estado,
      'public_data',a.datos_publicos,'verification_fields',coalesce((select jsonb_agg(k order by k) from jsonb_object_keys(a.datos_verificacion) k),'[]'::jsonb),
      'active_documents',(select count(*) from public.kombax_verificacion_documentos d where d.solicitud_id=a.id and d.estado='active'),
      'submitted_at',a.enviado_en,'updated_at',a.actualizado_en
    ) into v_context from public.kombax_solicitudes_alta a where a.id=t.context_id;
  elsif t.context_type='seller_application' and t.context_id is not null then
    select jsonb_build_object(
      'kind','seller_application','id',a.id,'provider_id',a.provider_id,'provider_name',p.nombre,
      'seller_type',a.seller_type,'legal_name_present',nullif(btrim(a.legal_name),'') is not null,
      'tax_id_present',nullif(btrim(a.tax_id),'') is not null,'country',a.country,
      'address_present',nullif(btrim(a.registered_address),'') is not null,
      'support_email_present',nullif(btrim(a.support_email),'') is not null,
      'support_phone_present',nullif(btrim(a.support_phone),'') is not null,
      'compliance_statement',a.compliance_statement,'marketplace_statement',a.marketplace_statement,
      'identity_verified',coalesce((kombax_marketplace.base_verification_r627(a.provider_id)->>'verified')::boolean,false),
      'policies_ready',kombax_marketplace.seller_policies_ready_r627(a.provider_id),'status',a.status,'updated_at',a.updated_at
    ) into v_context from kombax_marketplace.seller_applications a join public.kombax_showcase_marcas p on p.id=a.provider_id where a.id=t.context_id;
  elsif t.context_type='pilot_summary' then
    select public.app_kombax_pilot_metrics_r97() into v_context;
  else
    v_context:=jsonb_build_object('kind',coalesce(t.context_type,'platform_summary'),'generated_at',now(),
      'counts',jsonb_build_object(
        'clubs',(select count(*) from public.clubes where activo),
        'accounts',(select count(*) from public.perfiles),
        'active_memberships',(select count(*) from public.miembros_club where activo),
        'pending_profiles',(select count(*) from public.kombax_solicitudes_alta where estado in ('submitted','under_review','needs_information')),
        'pending_sellers',(select count(*) from kombax_marketplace.seller_applications where status in ('submitted','under_review','needs_information')),
        'open_reports',(select count(*) from public.kombax_social_reportes where estado in ('pendiente','en_revision'))
      ));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('role',x.role,'content',x.content,'created_at',x.created_at) order by x.created_at),'[]'::jsonb) into v_history
  from (
    select 'user'::text role,h.user_message content,h.created_at from kombax_owner_ai.agent_turns h where h.conversation_id=t.conversation_id and h.id<>t.id
    union all
    select 'assistant',h.assistant_message,h.completed_at from kombax_owner_ai.agent_turns h where h.conversation_id=t.conversation_id and h.id<>t.id and h.assistant_message is not null
    order by created_at desc limit 12
  ) x;
  return jsonb_build_object('ok',true,'turn_id',t.id,'conversation_id',t.conversation_id,'agent',t.agent,'message',t.user_message,'reasoning_effort',t.reasoning_effort,'context',coalesce(v_context,'{}'::jsonb),'history',v_history);
end $$;
revoke all on function public.app_kombax_owner_agent_turn_context_r105(uuid) from public,anon;
grant execute on function public.app_kombax_owner_agent_turn_context_r105(uuid) to authenticated;

create or replace function public.app_kombax_owner_agent_turn_complete_r105(
  p_turn_id uuid,p_response_id text,p_assistant_message text,p_risk_level text,p_confidence numeric,
  p_proposed_action jsonb,p_findings jsonb,p_next_steps jsonb,p_usage jsonb
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v kombax_owner_ai.agent_turns;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if p_risk_level not in ('low','medium','high','critical') then raise exception 'OWNER_AGENT_RISK_INVALID'; end if;
  update kombax_owner_ai.agent_turns set status='completed',response_id=left(p_response_id,180),assistant_message=left(p_assistant_message,12000),risk_level=p_risk_level,
    confidence=least(1,greatest(0,p_confidence)),proposed_action=coalesce(p_proposed_action,'{}'::jsonb),findings=coalesce(p_findings,'[]'::jsonb),
    next_steps=coalesce(p_next_steps,'[]'::jsonb),usage_private=coalesce(p_usage,'{}'::jsonb),completed_at=now()
  where id=p_turn_id and status in ('queued','processing') returning * into v;
  if v.id is null then raise exception 'OWNER_AGENT_TURN_NOT_COMPLETABLE'; end if;
  return jsonb_build_object('ok',true,'turn_id',v.id,'status',v.status);
end $$;
revoke all on function public.app_kombax_owner_agent_turn_complete_r105(uuid,text,text,text,numeric,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_agent_turn_complete_r105(uuid,text,text,text,numeric,jsonb,jsonb,jsonb,jsonb) to service_role;

create or replace function public.app_kombax_owner_agent_turn_fail_r105(p_turn_id uuid,p_error_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  update kombax_owner_ai.agent_turns set status='failed',error_code=left(coalesce(p_error_code,'UNKNOWN'),100),completed_at=now() where id=p_turn_id and status<>'completed';
end $$;
revoke all on function public.app_kombax_owner_agent_turn_fail_r105(uuid,text) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_agent_turn_fail_r105(uuid,text) to service_role;

notify pgrst,'reload schema';
commit;
