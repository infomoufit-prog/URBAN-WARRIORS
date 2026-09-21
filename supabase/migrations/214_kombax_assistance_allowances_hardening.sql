-- Runtime hardening after v2.13: qualify PL/pgSQL column references and add explicit deny policies.

create policy assistance_plan_entitlements_no_direct_access on kombax_ai_ops.assistance_plan_entitlements
  for all to public using (false) with check (false);
create policy assistance_tenant_settings_no_direct_access on kombax_ai_ops.assistance_tenant_settings
  for all to public using (false) with check (false);
create policy assistance_periods_no_direct_access on kombax_ai_ops.assistance_periods
  for all to public using (false) with check (false);
create policy assistance_cases_no_direct_access on kombax_ai_ops.assistance_cases
  for all to public using (false) with check (false);
create policy migration_allowance_cases_no_direct_access on kombax_ai_ops.migration_allowance_cases
  for all to public using (false) with check (false);
create policy faq_deflections_no_direct_access on kombax_ai_ops.faq_deflections
  for all to public using (false) with check (false);

create or replace function kombax_ai_ops.resolve_context(p_uid uuid,p_tenant_hint text default null)
returns table(tenant_ref text,plan text,started_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare
  v_hint uuid;
  v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  begin
    v_hint:=replace(nullif(trim(p_tenant_hint),''),'club:','')::uuid;
  exception when invalid_text_representation then v_hint:=null;
  end;
  if v_hint is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_hint and mc.perfil_id=p_uid and mc.activo) then
    tenant_ref:='club:'||v_hint::text;
    select coalesce(ts.plan_override,case s.modalidad when 'federacion_institucional' then 'FEDERATION' when 'competidor_premium' then 'CLUB_PREMIUM' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),
           coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now())
      into plan,started_at
    from public.clubes c
    left join lateral (select ks.* from public.kombax_suscripciones ks where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in ('prueba','activa') and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now()) order by ks.actualizado_en desc limit 1) s on true
    left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text
    where c.id=v_hint;
    return next; return;
  end if;
  select d.id,d.creado_en,s.modalidad,s.inicia_en,s.creado_en subscription_created into v_direct
  from public.perfiles_kombax_directos d
  left join lateral (select ks.* from public.kombax_suscripciones ks where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa') and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now()) order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1) s on true
  where d.perfil_id=p_uid and d.estado='activo' order by (s.modalidad='federacion_institucional') desc,d.actualizado_en desc limit 1;
  if found then
    tenant_ref:='profile:'||v_direct.id::text;
    select coalesce(ts.plan_override,case v_direct.modalidad when 'federacion_institucional' then 'FEDERATION' when 'competidor_premium' then 'CLUB_PREMIUM' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),
           coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now())
      into plan,started_at
    from (values(1)) x(n)
    left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
    return next; return;
  end if;
  select mc.club_id into v_hint from public.miembros_club mc where mc.perfil_id=p_uid and mc.activo order by (mc.rol::text='direccion') desc,mc.creado_en limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,v_hint::text); return; end if;
  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now()) into plan,started_at
  from public.perfiles p left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text where p.id=p_uid;
  if not found then plan:='CLUB_BASIC'; started_at:=now(); end if;
  return next;
end;
$$;

create or replace function public.app_kombax_customer_ops_mutate_v213(p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ticket_id text; v_ticket kombax_customer_ops.tickets%rowtype;
  v_now timestamptz:=clock_timestamp(); v_category text; v_priority text; v_subject text; v_ctx record;
  v_from_status text; v_allowance jsonb;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_operation='ticket.create' then
    select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_payload->>'tenant_ref');
    v_category:=left(coalesce(nullif(trim(p_payload->>'category'),''),'GENERAL'),64);
    v_priority:=case when v_category in ('SECURITY','DATA_LOSS','CRITICAL_PERMISSIONS') then 'URGENT' else 'MEDIUM' end;
    v_subject:=left(regexp_replace(coalesce(p_payload->>'subject','Solicitud de soporte'),E'[\n\r\t]+',' ','g'),180);
    loop
      v_ticket_id:='KMX-'||to_char(v_now,'YYYY')||'-'||lpad((floor(random()*1000000))::int::text,6,'0');
      exit when not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id);
    end loop;
    insert into kombax_customer_ops.tickets(ticket_id,tenant_ref,user_ref,requester_email_hash,status,category,priority,module,subject_redacted,opened_at,updated_at)
    values(v_ticket_id,v_ctx.tenant_ref,v_uid,encode(extensions.digest(lower(coalesce(auth.jwt()->>'email',v_uid::text)),'sha256'),'hex'),'OPEN',v_category,v_priority,left(nullif(trim(p_payload->>'module'),''),64),v_subject,v_now,v_now)
    returning * into v_ticket;
    insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,to_status,detail,occurred_at)
    values(gen_random_uuid(),v_ticket_id,'TICKET_CREATED','USER',v_uid::text,'OPEN',jsonb_build_object('channel','PWA'),v_now);
  elsif p_operation in ('ticket.human_review','ticket.guided_start') then
    v_ticket_id:=p_payload->>'ticket_id';
    select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id and t.user_ref=v_uid for update;
    if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
    v_from_status:=v_ticket.status;
    if p_operation='ticket.human_review' then
      update kombax_customer_ops.tickets as t set status='HUMAN_REVIEW',updated_at=v_now where t.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'HUMAN_REVIEW_REQUESTED','USER',v_uid::text,v_from_status,'HUMAN_REVIEW','{}',v_now);
    else
      if v_ticket.category='MIGRATION' then v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,v_ticket_id); else v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,v_ticket_id); end if;
      if not coalesce((v_allowance->>'available')::boolean,false) then
        return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'assistance_available',false,'allowance',v_allowance,'updated_at',v_ticket.updated_at);
      end if;
      insert into kombax_customer_ops.guided_sessions(session_id,ticket_id,tenant_ref,user_ref,status,accepted_at,permissions,max_interactions,max_input_tokens,max_output_tokens,max_duration_minutes,inactivity_minutes,max_estimated_cost,started_at,expires_at)
      values(gen_random_uuid(),v_ticket_id,v_ticket.tenant_ref,v_uid,'ACTIVE',v_now,'{}',12,12000,1200,30,10,0.10,v_now,v_now+interval '30 minutes')
      on conflict(ticket_id) do update set status='ACTIVE',accepted_at=v_now,started_at=v_now,expires_at=v_now+interval '30 minutes',closed_at=null;
      update kombax_customer_ops.tickets as t set status='GUIDED_SESSION',updated_at=v_now where t.ticket_id=v_ticket_id returning * into v_ticket;
      insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
      values(gen_random_uuid(),v_ticket_id,'GUIDED_SESSION_STARTED','USER',v_uid::text,v_from_status,'GUIDED_SESSION',jsonb_build_object('expires_at',v_now+interval '30 minutes','allowance_reason',v_allowance->>'reason'),v_now);
    end if;
  else raise exception 'unsupported_operation' using errcode='22023'; end if;
  return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'assistance_available',true,'allowance',v_allowance,'updated_at',v_ticket.updated_at);
end;
$$;

revoke all on function kombax_ai_ops.resolve_context(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.app_kombax_customer_ops_mutate_v213(text,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_customer_ops_mutate_v213(text,jsonb) to authenticated;
