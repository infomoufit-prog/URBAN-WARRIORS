-- KOMBAX 20.101 R38 · Migration document metering, cached extraction summaries and safe preview

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
alter table kombax_customer_ops.migration_file_analysis enable row level security;
revoke all on kombax_customer_ops.migration_file_analysis from public,anon,authenticated,service_role;

update kombax_ai_ops.assistance_plan_entitlements
set migration_allowance=jsonb_set(jsonb_set(migration_allowance,'{file_types}','["CSV","XLS","XLSX","PDF","JPG","JPEG","PNG","WEBP"]'::jsonb,true),'{batch_processing}','true'::jsonb,true),updated_at=now()
where plan in('CLUB_BASIC','CLUB_PREMIUM','FEDERATION');

create or replace function public.app_kombax_migration_file_register_v228(p_ticket_id text,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();v_id uuid;v_path text:=btrim(coalesce(p_storage_path,''));v_name text:=left(btrim(coalesce(p_original_name,'')),255);v_mime text:=lower(btrim(coalesce(p_mime_type,'')));
  v_ticket kombax_customer_ops.tickets%rowtype;v_ctx record;v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;v_settings jsonb;v_case kombax_ai_ops.migration_allowance_cases%rowtype;v_allowance jsonb;
  v_max_docs integer;v_max_mb numeric;v_docs bigint;v_bytes numeric;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MIGRATION' for update;
  if not found then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id);
  if not coalesce((v_allowance->>'available')::boolean,false) then raise exception 'KOMBAX_MIGRATION_ALLOWANCE_EXHAUSTED'; end if;
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;v_settings:=v_ent.migration_allowance;
  v_max_docs:=coalesce((v_settings->>'max_documents_total')::integer,0);v_max_mb:=coalesce((v_settings->>'max_total_mb')::numeric,0);
  select * into strict v_case from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.contextual_case_key='ticket:'||p_ticket_id for update;
  select coalesce(sum(m.documents),0),coalesce(sum(m.size_mb),0) into v_docs,v_bytes from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_case.valid_until;
  if p_size_bytes is null or p_size_bytes<=0 or p_size_bytes>10485760 then raise exception 'KOMBAX_MIGRATION_FILE_SIZE_INVALID'; end if;
  if v_name='' then raise exception 'KOMBAX_MIGRATION_FILE_NAME_INVALID'; end if;
  if v_mime not in ('application/pdf','text/csv','application/csv','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/webp') then raise exception 'KOMBAX_MIGRATION_FILE_TYPE_INVALID'; end if;
  if v_path not like v_uid::text||'/'||p_ticket_id||'/%' then raise exception 'KOMBAX_MIGRATION_FILE_PATH_INVALID'; end if;
  if v_max_docs>0 and v_docs+1>v_max_docs then raise exception 'KOMBAX_MIGRATION_DOCUMENT_LIMIT'; end if;
  if v_max_mb>0 and v_bytes+(p_size_bytes::numeric/1048576)>v_max_mb then raise exception 'KOMBAX_MIGRATION_VOLUME_LIMIT'; end if;
  insert into kombax_customer_ops.migration_files(ticket_id,user_ref,original_name,mime_type,size_bytes,storage_path)
  values(p_ticket_id,v_uid,v_name,v_mime,p_size_bytes,v_path) returning file_id into v_id;
  update kombax_ai_ops.migration_allowance_cases set documents=documents+1,size_mb=size_mb+(p_size_bytes::numeric/1048576),file_types=(select array(select distinct x from unnest(file_types||array[upper(coalesce(nullif(split_part(v_name,'.',-1),''),'FILE'))]) x)),consumed_at=least(consumed_at,now()) where migration_case_id=v_case.migration_case_id;
  return jsonb_build_object('ok',true,'file_id',v_id,'ticket_id',p_ticket_id,'status','STAGED','documents_used',v_docs+1,'documents_max',v_max_docs,'mb_used',round(v_bytes+(p_size_bytes::numeric/1048576),2),'mb_max',v_max_mb);
end $$;

create or replace function public.app_kombax_migration_files_v228(p_ticket_id text)
returns table(file_id uuid,original_name text,mime_type text,size_bytes bigint,status text,summary text,detected_records integer,needs_review boolean,created_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$ begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=auth.uid() and t.category='MIGRATION') then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  return query select f.file_id,f.original_name,f.mime_type,f.size_bytes,f.status,a.summary,a.detected_records,a.needs_review,f.created_at from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id where f.ticket_id=p_ticket_id and f.user_ref=auth.uid() order by f.created_at;
end $$;

create or replace function public.app_kombax_migration_preview_v228(p_ticket_id text)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_files jsonb;v_total integer;v_done integer;v_review integer;v_records bigint;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MIGRATION') then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED';end if;
 select count(*),count(a.file_id),count(a.file_id) filter(where a.needs_review),coalesce(sum(a.detected_records),0) into v_total,v_done,v_review,v_records from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id where f.ticket_id=p_ticket_id and f.user_ref=v_uid;
 select coalesce(jsonb_agg(jsonb_build_object('file_id',f.file_id,'name',f.original_name,'status',f.status,'summary',a.summary,'detected_records',a.detected_records,'needs_review',a.needs_review) order by f.created_at),'[]'::jsonb) into v_files from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id where f.ticket_id=p_ticket_id and f.user_ref=v_uid;
 return jsonb_build_object('ticket_id',p_ticket_id,'files_total',v_total,'files_analyzed',v_done,'files_pending',greatest(0,v_total-v_done),'needs_review',v_review,'detected_records',v_records,'files',v_files,'import_requires_confirmation',true);
end $$;

revoke all on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) from public,anon,service_role;
revoke all on function public.app_kombax_migration_files_v228(text) from public,anon,service_role;
revoke all on function public.app_kombax_migration_preview_v228(text) from public,anon,service_role;
grant execute on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) to authenticated;
grant execute on function public.app_kombax_migration_files_v228(text) to authenticated;
grant execute on function public.app_kombax_migration_preview_v228(text) to authenticated;
notify pgrst,'reload schema';
