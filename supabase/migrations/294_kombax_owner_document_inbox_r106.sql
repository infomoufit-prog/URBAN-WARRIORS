-- KOMBAX build 20159 · R106 · Private Owner document inbox and agent attachments.
begin;

create table if not exists kombax_owner_ai.documents(
  id uuid primary key default gen_random_uuid(),
  uploaded_by uuid not null references public.perfiles(id) on delete restrict,
  storage_path text not null unique,
  original_name text not null,
  mime_type text not null,
  size_bytes bigint not null check(size_bytes>0 and size_bytes<=10485760),
  category text not null default 'other' check(category in ('request','verification','showcase','pilot','incident','finance','other')),
  title text,
  status text not null default 'received' check(status in ('received','analyzing','analyzed','archived','failed')),
  assigned_agent text check(assigned_agent is null or assigned_agent in ('owner_operations','pilot_intelligence')),
  created_at timestamptz not null default now(),
  analyzed_at timestamptz,
  archived_at timestamptz
);
create index if not exists idx_owner_ai_documents_queue_r106 on kombax_owner_ai.documents(status,category,created_at desc);
revoke all on kombax_owner_ai.documents from public,anon,authenticated;

create table if not exists kombax_owner_ai.turn_documents(
  turn_id uuid not null references kombax_owner_ai.agent_turns(id) on delete cascade,
  document_id uuid not null references kombax_owner_ai.documents(id) on delete restrict,
  primary key(turn_id,document_id)
);
revoke all on kombax_owner_ai.turn_documents from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-owner-inbox','kombax-owner-inbox',false,10485760,array[
  'application/pdf','text/plain','text/csv','application/csv','text/tab-separated-values',
  'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'image/jpeg','image/png','image/webp'
]::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists kombax_owner_inbox_insert_r106 on storage.objects;
create policy kombax_owner_inbox_insert_r106 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-owner-inbox' and (storage.foldername(name))[1]=(select auth.uid())::text and public.app_kombax_es_platform_admin_v055()
);
drop policy if exists kombax_owner_inbox_select_r106 on storage.objects;
create policy kombax_owner_inbox_select_r106 on storage.objects for select to authenticated using(
  bucket_id='kombax-owner-inbox' and (storage.foldername(name))[1]=(select auth.uid())::text and public.app_kombax_es_platform_admin_v055()
);
drop policy if exists kombax_owner_inbox_delete_r106 on storage.objects;
create policy kombax_owner_inbox_delete_r106 on storage.objects for delete to authenticated using(
  bucket_id='kombax-owner-inbox' and (storage.foldername(name))[1]=(select auth.uid())::text and public.app_kombax_es_platform_admin_v055()
);

create or replace function public.app_kombax_owner_document_register_r106(
  p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint,p_category text default 'other',p_title text default null
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v kombax_owner_ai.documents;v_size bigint;v_mime text;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if split_part(p_storage_path,'/',1)<>v_uid::text then raise exception 'OWNER_DOCUMENT_PATH_INVALID'; end if;
  if p_category not in ('request','verification','showcase','pilot','incident','finance','other') then raise exception 'OWNER_DOCUMENT_CATEGORY_INVALID'; end if;
  select coalesce((metadata->>'size')::bigint,0),coalesce(metadata->>'mimetype','') into v_size,v_mime
  from storage.objects where bucket_id='kombax-owner-inbox' and name=p_storage_path;
  if v_size<=0 or v_size>10485760 then raise exception 'OWNER_DOCUMENT_STORAGE_INVALID'; end if;
  if v_size<>p_size_bytes then raise exception 'OWNER_DOCUMENT_SIZE_MISMATCH'; end if;
  insert into kombax_owner_ai.documents(uploaded_by,storage_path,original_name,mime_type,size_bytes,category,title)
  values(v_uid,p_storage_path,left(p_original_name,255),coalesce(nullif(v_mime,''),p_mime_type),p_size_bytes,p_category,left(nullif(btrim(p_title),''),180))
  returning * into v;
  return jsonb_build_object('ok',true,'document',jsonb_build_object('id',v.id,'name',v.original_name,'mime_type',v.mime_type,'size_bytes',v.size_bytes,'category',v.category,'title',v.title,'status',v.status,'created_at',v.created_at));
end $$;
revoke all on function public.app_kombax_owner_document_register_r106(text,text,text,bigint,text,text) from public,anon;
grant execute on function public.app_kombax_owner_document_register_r106(text,text,text,bigint,text,text) to authenticated;

create or replace function public.app_kombax_owner_agent_turn_attach_documents_r106(p_turn_id uuid,p_document_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_count int;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if not exists(select 1 from kombax_owner_ai.agent_turns where id=p_turn_id and requested_by=v_uid) then raise exception 'OWNER_AGENT_TURN_NOT_FOUND'; end if;
  if coalesce(cardinality(p_document_ids),0)>3 then raise exception 'OWNER_AGENT_DOCUMENT_LIMIT'; end if;
  if exists(select 1 from unnest(coalesce(p_document_ids,'{}'::uuid[])) id left join kombax_owner_ai.documents d on d.id=id and d.uploaded_by=v_uid and d.status<>'archived' where d.id is null) then raise exception 'OWNER_DOCUMENT_NOT_AVAILABLE'; end if;
  insert into kombax_owner_ai.turn_documents(turn_id,document_id) select p_turn_id,id from unnest(coalesce(p_document_ids,'{}'::uuid[])) id on conflict do nothing;
  update kombax_owner_ai.documents d set status='analyzing',assigned_agent=t.agent
  from kombax_owner_ai.agent_turns t where t.id=p_turn_id and d.id=any(coalesce(p_document_ids,'{}'::uuid[]));
  select count(*) into v_count from kombax_owner_ai.turn_documents where turn_id=p_turn_id;
  return jsonb_build_object('ok',true,'attached',v_count);
end $$;
revoke all on function public.app_kombax_owner_agent_turn_attach_documents_r106(uuid,uuid[]) from public,anon;
grant execute on function public.app_kombax_owner_agent_turn_attach_documents_r106(uuid,uuid[]) to authenticated;

create or replace function public.app_kombax_owner_agent_documents_finish_r106(p_turn_id uuid,p_success boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  update kombax_owner_ai.documents d set status=case when p_success then 'analyzed' else 'failed' end,analyzed_at=case when p_success then now() else analyzed_at end
  from kombax_owner_ai.turn_documents td where td.turn_id=p_turn_id and d.id=td.document_id;
end $$;
revoke all on function public.app_kombax_owner_agent_documents_finish_r106(uuid,boolean) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_agent_documents_finish_r106(uuid,boolean) to service_role;

create or replace function public.app_kombax_owner_pilot_report_from_turn_r106(p_turn_id uuid,p_report_type text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t kombax_owner_ai.agent_turns;v_report kombax_owner_ai.pilot_reports;
begin
  if coalesce(current_setting('request.jwt.claim.role',true),'')<>'service_role' then raise exception 'SERVICE_ROLE_REQUIRED'; end if;
  if p_report_type not in ('daily','weekly','incident','release_gate') then raise exception 'OWNER_REPORT_TYPE_INVALID'; end if;
  select * into t from kombax_owner_ai.agent_turns where id=p_turn_id and agent='pilot_intelligence' and status='completed';
  if t.id is null then raise exception 'OWNER_PILOT_TURN_NOT_READY'; end if;
  insert into kombax_owner_ai.pilot_reports(report_type,period_start,period_end,status,title,executive_summary,sections,source_snapshot,generated_by_turn_id)
  values(p_report_type,case when p_report_type='weekly' then current_date-6 else current_date end,current_date,'draft',
    case p_report_type when 'daily' then 'Seguimiento diario del piloto' when 'weekly' then 'Informe semanal del piloto' when 'incident' then 'Informe de incidencia del piloto' else 'Pilot Release Gate' end,
    t.assistant_message,coalesce(t.findings,'[]'::jsonb),jsonb_build_object('turn_id',t.id,'generated_at',now(),'agent',t.agent),t.id)
  returning * into v_report;
  return jsonb_build_object('ok',true,'report_id',v_report.id,'status',v_report.status,'report_type',v_report.report_type);
end $$;
revoke all on function public.app_kombax_owner_pilot_report_from_turn_r106(uuid,text) from public,anon,authenticated;
grant execute on function public.app_kombax_owner_pilot_report_from_turn_r106(uuid,text) to service_role;

create or replace function public.app_kombax_owner_agents_dashboard_r105()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_turns jsonb;v_reports jsonb;v_documents jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',t.id,'conversation_id',t.conversation_id,'agent',t.agent,'message',t.user_message,
    'assistant_message',t.assistant_message,'status',t.status,'risk_level',t.risk_level,
    'confidence',t.confidence,'proposed_action',t.proposed_action,'findings',t.findings,
    'next_steps',t.next_steps,'context_type',t.context_type,'context_id',t.context_id,
    'reasoning_effort',t.reasoning_effort,'document_ids',(select coalesce(jsonb_agg(td.document_id),'[]'::jsonb) from kombax_owner_ai.turn_documents td where td.turn_id=t.id),
    'created_at',t.created_at,'completed_at',t.completed_at
  ) order by t.created_at),'[]'::jsonb) into v_turns
  from (select * from kombax_owner_ai.agent_turns where requested_by=v_uid order by created_at desc limit 40) t;
  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'report_type',r.report_type,'period_start',r.period_start,'period_end',r.period_end,'status',r.status,'title',r.title,'executive_summary',r.executive_summary,'pdf_ready',r.pdf_storage_path is not null,'created_at',r.created_at) order by r.period_end desc,r.created_at desc),'[]'::jsonb) into v_reports from (select * from kombax_owner_ai.pilot_reports order by period_end desc,created_at desc limit 20) r;
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.original_name,'mime_type',d.mime_type,'size_bytes',d.size_bytes,'category',d.category,'title',d.title,'status',d.status,'assigned_agent',d.assigned_agent,'created_at',d.created_at,'analyzed_at',d.analyzed_at) order by d.created_at desc),'[]'::jsonb) into v_documents from (select * from kombax_owner_ai.documents where uploaded_by=v_uid and status<>'archived' order by created_at desc limit 100) d;
  return jsonb_build_object('ok',true,'agents',jsonb_build_array(
    jsonb_build_object('code','owner_operations','name','Owner Operations','model','gpt-6-luna','efforts',jsonb_build_array('low','medium'),'autonomy','bounded'),
    jsonb_build_object('code','pilot_intelligence','name','Pilot Intelligence','model','gpt-6-luna','efforts',jsonb_build_array('low','medium'),'autonomy','read_only')
  ),'turns',v_turns,'reports',v_reports,'documents',v_documents);
end $$;
revoke all on function public.app_kombax_owner_agents_dashboard_r105() from public,anon;
grant execute on function public.app_kombax_owner_agents_dashboard_r105() to authenticated;

create or replace function public.app_kombax_owner_agent_turn_context_r105(p_turn_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());t kombax_owner_ai.agent_turns;v_context jsonb:='{}'::jsonb;v_history jsonb;v_documents jsonb;
begin
  if v_uid is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select * into t from kombax_owner_ai.agent_turns where id=p_turn_id and requested_by=v_uid;
  if t.id is null then raise exception 'OWNER_AGENT_TURN_NOT_FOUND'; end if;
  if t.context_type='platform_application' and t.context_id is not null then
    select jsonb_build_object('kind','platform_application','id',a.id,'type',a.tipo,'name',a.nombre_publico,'status',a.estado,'public_data',a.datos_publicos,'verification_fields',coalesce((select jsonb_agg(k order by k) from jsonb_object_keys(a.datos_verificacion) k),'[]'::jsonb),'active_documents',(select count(*) from public.kombax_verificacion_documentos d where d.solicitud_id=a.id and d.estado='active'),'submitted_at',a.enviado_en,'updated_at',a.actualizado_en) into v_context from public.kombax_solicitudes_alta a where a.id=t.context_id;
  elsif t.context_type='seller_application' and t.context_id is not null then
    select jsonb_build_object('kind','seller_application','id',a.id,'provider_id',a.provider_id,'provider_name',p.nombre,'seller_type',a.seller_type,'legal_name_present',nullif(btrim(a.legal_name),'') is not null,'tax_id_present',nullif(btrim(a.tax_id),'') is not null,'country',a.country,'address_present',nullif(btrim(a.registered_address),'') is not null,'support_email_present',nullif(btrim(a.support_email),'') is not null,'support_phone_present',nullif(btrim(a.support_phone),'') is not null,'compliance_statement',a.compliance_statement,'marketplace_statement',a.marketplace_statement,'identity_verified',coalesce((kombax_marketplace.base_verification_r627(a.provider_id)->>'verified')::boolean,false),'policies_ready',kombax_marketplace.seller_policies_ready_r627(a.provider_id),'status',a.status,'updated_at',a.updated_at) into v_context from kombax_marketplace.seller_applications a join public.kombax_showcase_marcas p on p.id=a.provider_id where a.id=t.context_id;
  elsif t.context_type='pilot_summary' then select public.app_kombax_pilot_metrics_r97() into v_context;
  else
    v_context:=jsonb_build_object('kind',coalesce(t.context_type,'platform_summary'),'generated_at',now(),'counts',jsonb_build_object('clubs',(select count(*) from public.clubes where activo),'accounts',(select count(*) from public.perfiles),'active_memberships',(select count(*) from public.miembros_club where activo),'pending_profiles',(select count(*) from public.kombax_solicitudes_alta where estado in ('submitted','under_review','needs_information')),'pending_sellers',(select count(*) from kombax_marketplace.seller_applications where status in ('submitted','under_review','needs_information')),'open_reports',(select count(*) from public.kombax_social_reportes where estado in ('pendiente','en_revision'))));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('role',x.role,'content',x.content,'created_at',x.created_at) order by x.created_at),'[]'::jsonb) into v_history from (select 'user'::text role,h.user_message content,h.created_at from kombax_owner_ai.agent_turns h where h.conversation_id=t.conversation_id and h.id<>t.id union all select 'assistant',h.assistant_message,h.completed_at from kombax_owner_ai.agent_turns h where h.conversation_id=t.conversation_id and h.id<>t.id and h.assistant_message is not null order by created_at desc limit 12) x;
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'storage_path',d.storage_path,'filename',d.original_name,'mime_type',d.mime_type,'size_bytes',d.size_bytes,'category',d.category,'title',d.title) order by d.created_at),'[]'::jsonb) into v_documents from kombax_owner_ai.turn_documents td join kombax_owner_ai.documents d on d.id=td.document_id where td.turn_id=t.id and d.uploaded_by=v_uid;
  return jsonb_build_object('ok',true,'turn_id',t.id,'conversation_id',t.conversation_id,'agent',t.agent,'message',t.user_message,'reasoning_effort',t.reasoning_effort,'context',coalesce(v_context,'{}'::jsonb),'history',v_history,'documents',v_documents);
end $$;
revoke all on function public.app_kombax_owner_agent_turn_context_r105(uuid) from public,anon;
grant execute on function public.app_kombax_owner_agent_turn_context_r105(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
