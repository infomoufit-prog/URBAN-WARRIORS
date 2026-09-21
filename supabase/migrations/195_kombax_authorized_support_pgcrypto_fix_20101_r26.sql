begin;

create or replace function public.app_kombax_support_authorization_mutate_v194(
  p_operation text,
  p_payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_subject_type text := nullif(trim(p_payload->>'subject_type'),'');
  v_subject_id uuid := nullif(p_payload->>'subject_id','')::uuid;
  v_id uuid;
  v_minutes integer;
  v_ticket text;
  v_scopes text[];
  v_code text;
  v_hash text;
  v_row public.kombax_support_authorizations_v194%rowtype;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_operation='support.authorization.create' then
    if not public.app_kombax_support_can_manage_subject_v194(v_subject_type,v_subject_id,v_actor) then raise exception 'SUPPORT_SUBJECT_FORBIDDEN'; end if;
    v_minutes := least(1440,greatest(15,coalesce((p_payload->>'duration_minutes')::integer,120)));
    v_ticket := nullif(left(trim(coalesce(p_payload->>'ticket_ref','')),120),'');
    select coalesce(array_agg(distinct s),array['support.read']::text[]) into v_scopes
      from jsonb_array_elements_text(coalesce(p_payload->'scopes','["support.read"]'::jsonb)) s
      where s in ('support.read','support.write','finance.read','documents.read','minors.read');
    if cardinality(v_scopes)=0 then v_scopes:=array['support.read']::text[]; end if;
    v_code := lpad((floor(random()*1000000))::integer::text,6,'0');
    v_hash := encode(extensions.digest(v_code,'sha256'),'hex');
    while exists(select 1 from public.kombax_support_authorizations_v194 where code_hash=v_hash and expires_at>now()) loop
      v_code := lpad((floor(random()*1000000))::integer::text,6,'0');
      v_hash := encode(extensions.digest(v_code,'sha256'),'hex');
    end loop;
    insert into public.kombax_support_authorizations_v194(subject_type,subject_id,requested_by,ticket_ref,scopes,code_hash,expires_at)
      values(v_subject_type,v_subject_id,v_actor,v_ticket,v_scopes,v_hash,now()+make_interval(mins=>v_minutes)) returning * into v_row;
    insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,actor_profile_id,action,detail)
      values(v_row.id,v_subject_type,v_subject_id,'customer',v_actor,'support.authorization.created',jsonb_build_object('scopes',v_scopes,'expires_at',v_row.expires_at,'ticket_ref',v_ticket));
    return jsonb_build_object('id',v_row.id,'code',v_code,'expires_at',v_row.expires_at,'scopes',v_scopes,'ticket_ref',v_ticket,'status','active');
  elsif p_operation='support.authorization.revoke' then
    v_id := nullif(p_payload->>'authorization_id','')::uuid;
    select * into v_row from public.kombax_support_authorizations_v194 where id=v_id for update;
    if not found then raise exception 'SUPPORT_AUTHORIZATION_NOT_FOUND'; end if;
    if not public.app_kombax_support_can_manage_subject_v194(v_row.subject_type,v_row.subject_id,v_actor) then raise exception 'SUPPORT_SUBJECT_FORBIDDEN'; end if;
    update public.kombax_support_authorizations_v194 set status='revoked',revoked_at=now(),updated_at=now() where id=v_id and status in ('active','claimed');
    insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,actor_profile_id,action,detail)
      values(v_id,v_row.subject_type,v_row.subject_id,'customer',v_actor,'support.authorization.revoked','{}');
    return jsonb_build_object('id',v_id,'status','revoked');
  else raise exception 'SUPPORT_OPERATION_INVALID'; end if;
end;
$$;

create or replace function public.app_kombax_support_authorization_claim_v194(
  p_code text,
  p_ticket_ref text default null,
  p_agent_label text default 'KOMBAX AI Support'
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_role text := coalesce(current_setting('request.jwt.claim.role',true),'');
  v_hash text := encode(extensions.digest(trim(coalesce(p_code,'')),'sha256'),'hex');
  v_row public.kombax_support_authorizations_v194%rowtype;
begin
  if v_role <> 'service_role' then raise exception 'SUPPORT_SERVICE_ROLE_REQUIRED'; end if;
  select * into v_row from public.kombax_support_authorizations_v194 where code_hash=v_hash and status='active' and expires_at>now() for update;
  if not found then raise exception 'SUPPORT_CODE_INVALID_OR_EXPIRED'; end if;
  if v_row.ticket_ref is not null and coalesce(trim(p_ticket_ref),'')<>v_row.ticket_ref then raise exception 'SUPPORT_TICKET_MISMATCH'; end if;
  update public.kombax_support_authorizations_v194 set status='claimed',claimed_at=now(),claimed_by=left(coalesce(nullif(trim(p_agent_label),''),'KOMBAX AI Support'),120),updated_at=now() where id=v_row.id;
  insert into public.kombax_support_access_audit_v194(authorization_id,subject_type,subject_id,actor_type,action,detail)
    values(v_row.id,v_row.subject_type,v_row.subject_id,'ai_support','support.authorization.claimed',jsonb_build_object('agent',left(coalesce(p_agent_label,'KOMBAX AI Support'),120),'ticket_ref',p_ticket_ref));
  return jsonb_build_object('authorization_id',v_row.id,'subject_type',v_row.subject_type,'subject_id',v_row.subject_id,'scopes',v_row.scopes,'expires_at',v_row.expires_at,'ticket_ref',v_row.ticket_ref);
end;
$$;

commit;
