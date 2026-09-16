create or replace function public.app_kombax_customer_ops_tickets_v211(p_limit integer default 50)
returns table(ticket_id text,status text,category text,priority text,module text,subject_redacted text,opened_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path=''
as $$
  select t.ticket_id,t.status,t.category,t.priority,t.module,t.subject_redacted,t.opened_at,t.updated_at
  from kombax_customer_ops.tickets t
  where t.user_ref=auth.uid()
  order by t.updated_at desc
  limit least(100,greatest(1,coalesce(p_limit,50)));
$$;

create or replace function public.app_kombax_customer_ops_mutate_v211(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ticket_id text; v_ticket kombax_customer_ops.tickets%rowtype;
  v_now timestamptz:=clock_timestamp(); v_category text; v_priority text; v_subject text; v_tenant text;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_operation='ticket.create' then
    v_category:=left(coalesce(nullif(trim(p_payload->>'category'),''),'GENERAL'),64);
    v_priority:=case when v_category in ('SECURITY','DATA_LOSS','CRITICAL_PERMISSIONS') then 'URGENT' else 'MEDIUM' end;
    v_subject:=left(regexp_replace(coalesce(p_payload->>'subject','Solicitud de soporte'),E'[\n\r\t]+',' ','g'),180);
    v_tenant:=left(nullif(trim(p_payload->>'tenant_ref'),''),120);
    loop
      v_ticket_id:='KMX-'||to_char(v_now,'YYYY')||'-'||lpad((floor(random()*1000000))::int::text,6,'0');
      exit when not exists(select 1 from kombax_customer_ops.tickets where tickets.ticket_id=v_ticket_id);
    end loop;
    insert into kombax_customer_ops.tickets(ticket_id,tenant_ref,user_ref,requester_email_hash,status,category,priority,module,subject_redacted,opened_at,updated_at)
    values(v_ticket_id,v_tenant,v_uid,encode(extensions.digest(lower(coalesce(auth.jwt()->>'email',v_uid::text)),'sha256'),'hex'),'OPEN',v_category,v_priority,left(nullif(trim(p_payload->>'module'),''),64),v_subject,v_now,v_now)
    returning * into v_ticket;
    insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,to_status,detail,occurred_at)
    values(gen_random_uuid(),v_ticket_id,'TICKET_CREATED','USER',v_uid::text,'OPEN',jsonb_build_object('channel','PWA'),v_now);
  elsif p_operation in ('ticket.human_review','ticket.guided_start') then
    v_ticket_id:=p_payload->>'ticket_id';
    select * into v_ticket from kombax_customer_ops.tickets where tickets.ticket_id=v_ticket_id and user_ref=v_uid for update;
    if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
    if p_operation='ticket.human_review' then
      update kombax_customer_ops.tickets set status='HUMAN_REVIEW',updated_at=v_now where tickets.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'HUMAN_REVIEW_REQUESTED','USER',v_uid::text,'OPEN','HUMAN_REVIEW','{}',v_now);
    else
      insert into kombax_customer_ops.guided_sessions(session_id,ticket_id,tenant_ref,user_ref,status,accepted_at,permissions,max_interactions,max_input_tokens,max_output_tokens,max_duration_minutes,inactivity_minutes,max_estimated_cost,started_at,expires_at)
      values(gen_random_uuid(),v_ticket_id,coalesce(v_ticket.tenant_ref,'account'),v_uid,'ACTIVE',v_now,'{}',12,12000,1200,30,10,0.10,v_now,v_now+interval '30 minutes')
      on conflict(ticket_id) do update set status='ACTIVE',accepted_at=v_now,started_at=v_now,expires_at=v_now+interval '30 minutes',closed_at=null;
      update kombax_customer_ops.tickets set status='GUIDED_SESSION',updated_at=v_now where tickets.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'GUIDED_SESSION_STARTED','USER',v_uid::text,'OPEN','GUIDED_SESSION',jsonb_build_object('expires_at',v_now+interval '30 minutes'),v_now);
    end if;
  else raise exception 'unsupported_operation' using errcode='22023';
  end if;
  return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'updated_at',v_ticket.updated_at);
end;
$$;

revoke all on function public.app_kombax_customer_ops_tickets_v211(integer) from public,anon,service_role;
revoke all on function public.app_kombax_customer_ops_mutate_v211(text,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_customer_ops_tickets_v211(integer) to authenticated;
grant execute on function public.app_kombax_customer_ops_mutate_v211(text,jsonb) to authenticated;
