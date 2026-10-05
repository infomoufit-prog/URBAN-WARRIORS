-- An explicit public copy is separate from the private verification evidence.
begin;
alter table public.kombax_professional_credentials_v198 add column public_document_path text;
alter table public.kombax_professional_credentials_v198 add column public_document_authorized_at timestamptz;
create or replace function public.app_kombax_credential_change_reset_r120()
returns trigger language plpgsql set search_path=public as $$
begin
 if row(new.professional_profile_id,new.specialty_code,new.credential_type,new.issuer,new.reference_public,new.verification_url,new.expires_on)
 is distinct from row(old.professional_profile_id,old.specialty_code,old.credential_type,old.issuer,old.reference_public,old.verification_url,old.expires_on) then
   new.estado:='declarada';new.public_visible:=false;new.verified_by:=null;new.verified_at:=null;new.review_note:=null;
   new.public_document_path:=null;new.public_document_authorized_at:=null;
 end if;
 return new;
end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-credential-public-copies','kombax-credential-public-copies',false,15728640,array['application/pdf','image/jpeg','image/png','image/webp']);

create or replace function public.app_kombax_public_copy_upload_allowed_r120(p_path text)
returns boolean language sql stable security definer set search_path=public,auth as $$
 select auth.uid() is not null and split_part(p_path,'/',1)=auth.uid()::text
 and p_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png|webp)$'
 and exists(select 1 from public.kombax_professional_credentials_v198 c
   where c.id=public.app_kombax_uuid_or_null_v070(split_part(p_path,'/',2))
   and c.estado='verificada' and (c.expires_on is null or c.expires_on>=current_date)
   and public.app_kombax_puede_gestionar_perfil_v070(c.professional_profile_id,'edit'));
$$;
revoke all on function public.app_kombax_public_copy_upload_allowed_r120(text) from public,anon;
grant execute on function public.app_kombax_public_copy_upload_allowed_r120(text) to authenticated;
create policy credential_copy_insert_r120 on storage.objects for insert to authenticated
with check(bucket_id='kombax-credential-public-copies' and public.app_kombax_public_copy_upload_allowed_r120(name));
-- SELECT/DELETE are limited to the uploader for preview and failed-upload cleanup.
create policy credential_copy_owner_read_r120 on storage.objects for select to authenticated
using(bucket_id='kombax-credential-public-copies' and split_part(name,'/',1)=auth.uid()::text);
create policy credential_copy_owner_delete_r120 on storage.objects for delete to authenticated
using(bucket_id='kombax-credential-public-copies' and split_part(name,'/',1)=auth.uid()::text);

create or replace function public.app_kombax_public_copy_mutate_r120(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare c public.kombax_professional_credentials_v198;r public.app_mutation_requests;v_result jsonb;v_path text;v_hash text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 if p_operation<>'professional.credential.public_copy.publish' then raise exception 'KOMBAX_OPERATION_NOT_ALLOWED';end if;
 select * into c from public.kombax_professional_credentials_v198
 where id=public.app_kombax_uuid_or_null_v070(p_payload->>'credential_id') for update;
 if c.id is null or not public.app_kombax_puede_gestionar_perfil_v070(c.professional_profile_id,'edit') then raise exception 'KOMBAX_CREDENTIAL_FORBIDDEN';end if;
 if c.estado<>'verificada' or (c.expires_on is not null and c.expires_on<current_date) then raise exception 'KOMBAX_VERIFIED_CURRENT_CREDENTIAL_REQUIRED';end if;
 if p_payload->>'publication_authorized'<>'true' or p_payload->>'publication_authorized' is null then raise exception 'KOMBAX_EXPLICIT_PUBLICATION_REQUIRED';end if;
 v_path:=p_payload->>'storage_path';
 if not public.app_kombax_public_copy_upload_allowed_r120(v_path) or split_part(v_path,'/',2)<>c.id::text then raise exception 'KOMBAX_PUBLIC_COPY_PATH_INVALID';end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='kombax-credential-public-copies' and o.name=v_path) then raise exception 'KOMBAX_PUBLIC_COPY_NOT_UPLOADED';end if;
 v_hash:=md5(p_payload::text);
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,121));
 select * into r from public.app_mutation_requests where request_id=p_request_id;
 if found then
   if r.user_id<>auth.uid() or r.operation<>p_operation or r.result->>'payload_hash'<>v_hash then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
   return r.result;
 end if;
 update public.kombax_professional_credentials_v198 set public_document_path=v_path,
 public_document_authorized_at=now(),public_visible=true where id=c.id;
 insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
 values(c.professional_profile_id,auth.uid(),'credential.public_copy.publish',jsonb_build_object('credential_id',c.id));
 v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'payload_hash',v_hash,'data',jsonb_build_object('credential_id',c.id,'public_copy_available',true));
 insert into public.app_mutation_requests(request_id,user_id,operation,result,completed_at) values(p_request_id,auth.uid(),p_operation,v_result,now());
 return v_result;
end $$;

create or replace function public.app_kombax_public_documents_r120(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 select coalesce(jsonb_agg(jsonb_build_object('credential_id',c.id,'title',c.credential_type,'issuer',c.issuer) order by c.verified_at desc),'[]'::jsonb)
 from public.kombax_professional_credentials_v198 c join public.perfiles_kombax_directos d on d.id=c.professional_profile_id
 where d.id=p_profile_id and d.tipo='profesional' and d.estado='activo' and d.publico
 and c.estado='verificada' and c.public_visible and c.public_document_path is not null
 and c.public_document_authorized_at is not null and (c.expires_on is null or c.expires_on>=current_date);
$$;
create or replace function public.app_kombax_public_document_asset_r120(p_credential_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('bucket','kombax-credential-public-copies','path',c.public_document_path)
 from public.kombax_professional_credentials_v198 c join public.perfiles_kombax_directos d on d.id=c.professional_profile_id
 where c.id=p_credential_id and d.tipo='profesional' and d.estado='activo' and d.publico
 and c.estado='verificada' and c.public_visible and c.public_document_authorized_at is not null
 and c.public_document_path is not null and (c.expires_on is null or c.expires_on>=current_date);
$$;
revoke all on function public.app_kombax_public_copy_mutate_r120(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_public_copy_mutate_r120(text,jsonb,uuid) to authenticated;
revoke all on function public.app_kombax_public_documents_r120(uuid) from public;
grant execute on function public.app_kombax_public_documents_r120(uuid) to anon,authenticated;
revoke all on function public.app_kombax_public_document_asset_r120(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_public_document_asset_r120(uuid) to service_role;
commit;
