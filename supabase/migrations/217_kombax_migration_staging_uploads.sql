-- KOMBAX 20.101 R34 · Secure migration file staging for KOMBAX Assist
-- Additive. Files are private and ticket-scoped. No automatic import is performed.

create table if not exists kombax_customer_ops.migration_files(
  file_id uuid primary key default gen_random_uuid(),
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete restrict,
  user_ref uuid not null references auth.users(id) on delete restrict,
  original_name text not null,
  mime_type text not null,
  size_bytes bigint not null check(size_bytes>0 and size_bytes<=10485760),
  storage_path text not null unique,
  status text not null default 'STAGED' check(status in('STAGED','ANALYZING','NEEDS_REVIEW','READY_CONFIRM','IMPORTING','COMPLETED','FAILED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists migration_files_ticket_time_idx on kombax_customer_ops.migration_files(ticket_id,created_at);
create index if not exists migration_files_user_time_idx on kombax_customer_ops.migration_files(user_ref,created_at desc);
alter table kombax_customer_ops.migration_files enable row level security;
revoke all on kombax_customer_ops.migration_files from public,anon,authenticated,service_role;

create or replace function public.app_kombax_migration_ticket_owned_v217(p_ticket_id text)
returns boolean language sql stable security definer set search_path=''
as $$ select auth.uid() is not null and exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=auth.uid() and t.category='MIGRATION') $$;
revoke all on function public.app_kombax_migration_ticket_owned_v217(text) from public,anon,service_role;
grant execute on function public.app_kombax_migration_ticket_owned_v217(text) to authenticated;

create or replace function public.app_kombax_migration_file_register_v217(p_ticket_id text,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_path text:=btrim(coalesce(p_storage_path,''));v_name text:=left(btrim(coalesce(p_original_name,'')),255);v_mime text:=lower(btrim(coalesce(p_mime_type,'')));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_migration_ticket_owned_v217(p_ticket_id) then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  if p_size_bytes is null or p_size_bytes<=0 or p_size_bytes>10485760 then raise exception 'KOMBAX_MIGRATION_FILE_SIZE_INVALID'; end if;
  if v_name='' or length(v_name)>255 then raise exception 'KOMBAX_MIGRATION_FILE_NAME_INVALID'; end if;
  if v_mime not in ('application/pdf','text/csv','application/csv','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/webp') then raise exception 'KOMBAX_MIGRATION_FILE_TYPE_INVALID'; end if;
  if v_path not like v_uid::text||'/'||p_ticket_id||'/%' then raise exception 'KOMBAX_MIGRATION_FILE_PATH_INVALID'; end if;
  insert into kombax_customer_ops.migration_files(ticket_id,user_ref,original_name,mime_type,size_bytes,storage_path)
  values(p_ticket_id,v_uid,v_name,v_mime,p_size_bytes,v_path) returning file_id into v_id;
  return jsonb_build_object('ok',true,'file_id',v_id,'ticket_id',p_ticket_id,'status','STAGED');
end $$;
revoke all on function public.app_kombax_migration_file_register_v217(text,text,text,text,bigint) from public,anon,service_role;
grant execute on function public.app_kombax_migration_file_register_v217(text,text,text,text,bigint) to authenticated;

create or replace function public.app_kombax_migration_files_v217(p_ticket_id text)
returns table(file_id uuid,original_name text,mime_type text,size_bytes bigint,status text,created_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$ begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_kombax_migration_ticket_owned_v217(p_ticket_id) then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  return query select f.file_id,f.original_name,f.mime_type,f.size_bytes,f.status,f.created_at from kombax_customer_ops.migration_files f where f.ticket_id=p_ticket_id and f.user_ref=auth.uid() order by f.created_at;
end $$;
revoke all on function public.app_kombax_migration_files_v217(text) from public,anon,service_role;
grant execute on function public.app_kombax_migration_files_v217(text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-migration-staging','kombax-migration-staging',false,10485760,array['application/pdf','text/csv','application/csv','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists kombax_migration_staging_insert_v217 on storage.objects;
create policy kombax_migration_staging_insert_v217 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-migration-staging' and (storage.foldername(name))[1]=auth.uid()::text and public.app_kombax_migration_ticket_owned_v217((storage.foldername(name))[2])
);
drop policy if exists kombax_migration_staging_select_v217 on storage.objects;
create policy kombax_migration_staging_select_v217 on storage.objects for select to authenticated using(
  bucket_id='kombax-migration-staging' and (storage.foldername(name))[1]=auth.uid()::text and public.app_kombax_migration_ticket_owned_v217((storage.foldername(name))[2])
);
drop policy if exists kombax_migration_staging_delete_v217 on storage.objects;
create policy kombax_migration_staging_delete_v217 on storage.objects for delete to authenticated using(
  bucket_id='kombax-migration-staging' and (storage.foldername(name))[1]=auth.uid()::text and public.app_kombax_migration_ticket_owned_v217((storage.foldername(name))[2])
);
notify pgrst,'reload schema';
