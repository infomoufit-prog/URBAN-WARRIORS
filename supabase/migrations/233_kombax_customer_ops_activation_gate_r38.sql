-- KOMBAX 20.101 R38 · Customer support activation gate
-- Customer-facing mutations may create a case or ask for human review.
-- A customer may NOT self-activate a standard KOMBAX Assist guided chat.
-- KOMBAX Migrations remains direct through its MIGRATION ticket + R38 turn reservation path.

create or replace function public.app_kombax_customer_ops_mutate_v233(
  p_operation text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ticket_id text;
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_now timestamptz:=clock_timestamp();
  v_category text;
  v_priority text;
  v_subject text;
  v_ctx record;
  v_from_status text;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  if p_operation='ticket.create' then
    select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_payload->>'tenant_ref');
    v_category:=left(coalesce(nullif(trim(p_payload->>'category'),''),'GENERAL'),64);
    v_priority:=case when v_category in ('SECURITY','DATA_LOSS','CRITICAL_PERMISSIONS') then 'URGENT' else 'MEDIUM' end;
    v_subject:=left(regexp_replace(coalesce(p_payload->>'subject','Solicitud de soporte'),E'[\n\r\t]+',' ','g'),180);

    loop
      v_ticket_id:='KMX-'||to_char(v_now,'YYYY')||'-'||lpad((floor(random()*1000000))::int::text,6,'0');
      exit when not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id);
    end loop;

    insert into kombax_customer_ops.tickets(
      ticket_id,tenant_ref,user_ref,requester_email_hash,status,category,priority,module,subject_redacted,opened_at,updated_at
    ) values(
      v_ticket_id,
      v_ctx.tenant_ref,
      v_uid,
      encode(extensions.digest(lower(coalesce(auth.jwt()->>'email',v_uid::text)),'sha256'),'hex'),
      'OPEN',v_category,v_priority,left(nullif(trim(p_payload->>'module'),''),64),v_subject,v_now,v_now
    ) returning * into v_ticket;

    insert into kombax_customer_ops.ticket_events(
      event_id,ticket_id,event_type,actor_type,actor_ref,to_status,detail,occurred_at
    ) values(
      gen_random_uuid(),v_ticket_id,'TICKET_CREATED','USER',v_uid::text,'OPEN',jsonb_build_object('channel','PWA'),v_now
    );

  elsif p_operation='ticket.human_review' then
    v_ticket_id:=p_payload->>'ticket_id';
    select * into v_ticket
    from kombax_customer_ops.tickets t
    where t.ticket_id=v_ticket_id and t.user_ref=v_uid
    for update;

    if not found then
      raise exception 'ticket_not_found' using errcode='P0002';
    end if;

    v_from_status:=v_ticket.status;
    update kombax_customer_ops.tickets as t
    set status='HUMAN_REVIEW',updated_at=v_now
    where t.ticket_id=v_ticket_id
    returning * into v_ticket;

    insert into kombax_customer_ops.ticket_events(
      event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at
    ) values(
      gen_random_uuid(),v_ticket_id,'HUMAN_REVIEW_REQUESTED','USER',v_uid::text,v_from_status,'HUMAN_REVIEW','{}',v_now
    );

  elsif p_operation='ticket.guided_start' then
    raise exception 'SUPPORT_CHAT_ACTIVATION_REQUIRED' using errcode='42501';
  else
    raise exception 'unsupported_operation' using errcode='22023';
  end if;

  return jsonb_build_object(
    'ok',true,
    'ticket_id',v_ticket.ticket_id,
    'status',v_ticket.status,
    'category',v_ticket.category,
    'priority',v_ticket.priority,
    'updated_at',v_ticket.updated_at
  );
end;
$$;

-- Retire the historical customer RPC that allowed self-activation.
revoke execute on function public.app_kombax_customer_ops_mutate_v213(text,jsonb) from authenticated;
revoke all on function public.app_kombax_customer_ops_mutate_v233(text,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_customer_ops_mutate_v233(text,jsonb) to authenticated;

comment on function public.app_kombax_customer_ops_mutate_v233(text,jsonb)
is 'R38 customer-safe support mutations. Standard KOMBAX Assist chat activation is support-side only; KOMBAX Migrations stays direct.';

notify pgrst,'reload schema';
