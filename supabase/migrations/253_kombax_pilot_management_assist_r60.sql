-- KOMBAX R60 final-pilot management Assist hardening
-- Purpose:
--   * KOMBAX Assist becomes direct, read-only management assistance for Club/Federation/Brand.
--   * Preserve human/email support as a separate channel.
--   * Reuse existing monthly assistance allowances and per-case turn caps.
--   * Keep KOMBAX Migrations limited to Club/Federation.
--   * Supply a compact authorized management snapshot to the AI runtime.

create or replace function kombax_ai_ops.org_assist_access_allowed(p_uid uuid, p_tenant_ref text)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_ref,''));
  v_id uuid;
  v_type text;
begin
  if p_uid is null or v_ref='' then return false; end if;

  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then return false; end;
    return exists(
      select 1
      from public.miembros_club mc
      where mc.club_id=v_id
        and mc.perfil_id=p_uid
        and mc.activo
        and mc.rol::text in ('direccion','coordinacion','secretaria','economia')
    );
  end if;

  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;

    select lower(d.tipo) into v_type
    from public.perfiles_kombax_directos d
    where d.id=v_id and d.estado='activo';
    if not found or v_type not in ('federacion','marca') then return false; end if;

    if exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=v_id and d.perfil_id=p_uid and d.estado='activo'
    ) then return true; end if;

    if v_type='federacion' and exists(
      select 1 from public.kombax_federation_team_v200 ft
      where ft.federation_profile_id=v_id
        and ft.perfil_id=p_uid
        and ft.revoked_at is null
        and lower(coalesce(ft.status,'')) in ('active','accepted','activo','aceptado')
    ) then return true; end if;

    if v_type='marca' and exists(
      select 1
      from public.kombax_showcase_marcas sm
      join public.kombax_showcase_gestores sg on sg.marca_id=sm.id
      where sm.perfil_directo_id=v_id
        and sg.perfil_id=p_uid
        and sg.activo
        and lower(coalesce(sm.estado,'activo')) not in ('inactivo','suspendido','eliminado')
    ) then return true; end if;
  end if;

  return false;
end;
$function$;

create or replace function kombax_ai_ops.migration_access_allowed(p_uid uuid, p_tenant_ref text)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_ref,''));
  v_id uuid;
begin
  if p_uid is null or v_ref='' then return false; end if;
  if v_ref like 'club:%' then
    return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref);
  end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;
    if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_id and d.estado='activo' and lower(d.tipo)='federacion') then return false; end if;
    return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref);
  end if;
  return false;
end;
$function$;

create or replace function kombax_ai_ops.resolve_context(p_uid uuid, p_tenant_hint text default null::text)
returns table(tenant_ref text, plan text, started_at timestamptz)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_hint,''));
  v_id uuid;
  v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;

  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      tenant_ref:='club:'||v_id::text;
      select coalesce(ts.plan_override,case s.modalidad when 'federacion_institucional' then 'FEDERATION' when 'competidor_premium' then 'CLUB_PREMIUM' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),
             coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now())
        into plan,started_at
      from public.clubes c
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by ks.actualizado_en desc limit 1
      ) s on true
      left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text
      where c.id=v_id;
      return next; return;
    end if;
  end if;

  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||v_id::text) then
      select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
        into v_direct
      from public.perfiles_kombax_directos d
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
      ) s on true
      where d.id=v_id and d.estado='activo' and lower(d.tipo) in ('federacion','marca');
      if found then
        tenant_ref:='profile:'||v_direct.id::text;
        select coalesce(ts.plan_override,case v_direct.modalidad when 'federacion_institucional' then 'FEDERATION' when 'marca_profesional' then 'CLUB_PREMIUM' else case when lower(v_direct.tipo)='federacion' then 'FEDERATION' when lower(v_direct.tipo)='marca' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end end),
               coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now())
          into plan,started_at
        from (values(1)) x(n)
        left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
        return next; return;
      end if;
    end if;
  end if;

  -- Backwards-compatible raw club UUID hint.
  if v_ref<>'' and v_ref not like '%:%' then
    begin v_id:=v_ref::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return;
    end if;
  end if;

  -- Prefer an accessible Federation/Brand direct profile if one exists.
  select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
    into v_direct
  from public.perfiles_kombax_directos d
  left join lateral (
    select ks.* from public.kombax_suscripciones ks
    where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
      and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
    order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
  ) s on true
  where d.estado='activo'
    and lower(d.tipo) in ('federacion','marca')
    and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||d.id::text)
  order by (lower(d.tipo)='federacion') desc,d.actualizado_en desc
  limit 1;
  if found then
    return query select * from kombax_ai_ops.resolve_context(p_uid,'profile:'||v_direct.id::text); return;
  end if;

  select mc.club_id into v_id
  from public.miembros_club mc
  where mc.perfil_id=p_uid and mc.activo
  order by (mc.rol::text='direccion') desc,mc.creado_en
  limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return; end if;

  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now()) into plan,started_at
  from public.perfiles p
  left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text
  where p.id=p_uid;
  if not found then plan:='CLUB_BASIC'; started_at:=now(); end if;
  return next;
end;
$function$;

create or replace function kombax_ai_ops.management_context(p_uid uuid, p_tenant_ref text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_ref,''));
  v_id uuid;
  v_type text;
  v_name text;
  v_brand_id uuid;
  v_result jsonb;
begin
  if not kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref) then
    raise exception 'org_assist_access_denied' using errcode='42501';
  end if;

  if v_ref like 'club:%' then
    v_id:=replace(v_ref,'club:','')::uuid;
    select c.nombre into v_name from public.clubes c where c.id=v_id;
    select jsonb_build_object(
      'entity_type','club',
      'entity_name',coalesce(v_name,'Club KOMBAX'),
      'scope','authorized_read_only_snapshot',
      'active_members',(select count(*) from public.socios s where s.club_id=v_id and lower(coalesce(s.estado,''))='activo'),
      'active_groups',(select count(*) from public.grupos g where g.club_id=v_id and g.activo),
      'overdue_fees_count',(select count(*) from public.cuotas q where q.club_id=v_id and lower(q.estado::text)='vencida'),
      'overdue_fees_amount',(select coalesce(sum(q.importe),0) from public.cuotas q where q.club_id=v_id and lower(q.estado::text)='vencida'),
      'overdue_fees',coalesce((select jsonb_agg(x order by x->>'vencimiento') from (
        select jsonb_build_object('member',trim(concat_ws(' ',s.nombre,s.apellidos)),'concept',coalesce(q.concepto_publico,q.concepto),'amount',q.importe,'due',q.vencimiento) x
        from public.cuotas q left join public.socios s on s.id=q.socio_id
        where q.club_id=v_id and lower(q.estado::text)='vencida'
        order by q.vencimiento nulls last limit 8
      ) z),'[]'::jsonb),
      'upcoming_events',coalesce((select jsonb_agg(x order by x->>'date') from (
        select jsonb_build_object('name',e.nombre,'date',e.fecha,'place',e.lugar) x
        from public.eventos_competicion e
        where e.club_id=v_id and e.fecha>=current_date and e.papelera_en is null
        order by e.fecha limit 5
      ) z),'[]'::jsonb)
    ) into v_result;
    return v_result;
  end if;

  v_id:=replace(v_ref,'profile:','')::uuid;
  select lower(d.tipo),d.nombre_publico into v_type,v_name
  from public.perfiles_kombax_directos d where d.id=v_id and d.estado='activo';

  if v_type='federacion' then
    select jsonb_build_object(
      'entity_type','federation',
      'entity_name',coalesce(v_name,'Federación KOMBAX'),
      'scope','authorized_read_only_snapshot',
      'linked_clubs',(select count(*) from public.kombax_federation_club_relationships_v200 r where r.federation_profile_id=v_id and lower(coalesce(r.status,'')) not in ('rejected','revoked','rechazado','revocado')),
      'licenses_total',(select count(*) from public.kombax_federation_licenses_v200 l where l.federation_profile_id=v_id),
      'licenses_expiring_30d',(select count(*) from public.kombax_federation_licenses_v200 l where l.federation_profile_id=v_id and l.expires_at between current_date and current_date+30),
      'licenses_needing_review',coalesce((select jsonb_agg(x order by x->>'expires_at') from (
        select jsonb_build_object('holder',l.holder_name,'discipline',l.discipline,'status',l.status,'verification',l.verification_status,'expires_at',l.expires_at) x
        from public.kombax_federation_licenses_v200 l
        where l.federation_profile_id=v_id and (lower(coalesce(l.verification_status,'')) not in ('verified','verificado','aprobado') or (l.expires_at is not null and l.expires_at<=current_date+30))
        order by l.expires_at nulls last limit 8
      ) z),'[]'::jsonb)
    ) into v_result;
    return v_result;
  end if;

  if v_type='marca' then
    select sm.id into v_brand_id from public.kombax_showcase_marcas sm where sm.perfil_directo_id=v_id order by sm.actualizado_en desc limit 1;
    select jsonb_build_object(
      'entity_type','brand',
      'entity_name',coalesce(v_name,(select sm.nombre from public.kombax_showcase_marcas sm where sm.id=v_brand_id),'Marca KOMBAX'),
      'scope','authorized_read_only_snapshot',
      'showcase_items_total',(select count(*) from public.kombax_showcase_elementos e where e.marca_id=v_brand_id),
      'showcase_items_published',(select count(*) from public.kombax_showcase_elementos e where e.marca_id=v_brand_id and lower(coalesce(e.estado,''))='publicado'),
      'open_inquiries',(select count(*) from public.kombax_showcase_inquiries_r58 i where i.marca_id=v_brand_id and lower(coalesce(i.estado,'abierta')) not in ('closed','cerrada','rechazada','cancelada')),
      'products',coalesce((select jsonb_agg(x order by x->>'name') from (
        select jsonb_build_object('name',e.nombre,'status',e.estado,'featured',e.destacado) x
        from public.kombax_showcase_elementos e where e.marca_id=v_brand_id
        order by e.actualizado_en desc limit 8
      ) z),'[]'::jsonb)
    ) into v_result;
    return v_result;
  end if;

  return jsonb_build_object('entity_type','unknown','scope','authorized_read_only_snapshot');
end;
$function$;

create or replace function kombax_ai_ops.reserve_migration_for_ticket(p_uid uuid, p_ticket_id text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_ticket kombax_customer_ops.tickets%rowtype;
  v_ctx record;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype;
  v_settings jsonb;
  v_total integer;
  v_used integer;
  v_valid_until timestamptz;
begin
  select * into v_ticket from kombax_customer_ops.tickets t
  where t.ticket_id=p_ticket_id and t.user_ref=p_uid and t.category='MIGRATION' for update;
  if not found then raise exception 'migration_ticket_not_found' using errcode='P0002'; end if;
  if not kombax_ai_ops.migration_access_allowed(p_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('available',false,'consumed',false,'reason','MIGRATION_ORG_ACCESS_REQUIRED');
  end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(p_uid,v_ticket.tenant_ref);
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;
  v_settings:=v_ent.migration_allowance;
  v_valid_until:=v_ctx.started_at+((v_settings->>'validity_days')::integer*interval '1 day');
  v_total:=case when now()<v_ctx.started_at+interval '1 month' then (v_settings->>'first_month_cases')::integer else (v_settings->>'cases')::integer end;

  if exists(select 1 from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.contextual_case_key='ticket:'||p_ticket_id) then
    select count(*) into v_used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
    return jsonb_build_object('available',true,'consumed',false,'reason','EXISTING_MIGRATION_CASE','migration_total',v_total,'migration_remaining',greatest(0,v_total-v_used),'valid_until',v_valid_until);
  end if;
  select count(*) into v_used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  if now()>v_valid_until or v_used>=v_total then
    return jsonb_build_object('available',false,'consumed',false,'reason','MIGRATION_ALLOWANCE_EXHAUSTED','migration_total',v_total,'migration_remaining',0,'valid_until',v_valid_until);
  end if;
  insert into kombax_ai_ops.migration_allowance_cases(tenant_ref,user_ref,plan,contextual_case_key,ticket_id,idempotency_key,valid_until)
  values(v_ctx.tenant_ref,p_uid,v_ctx.plan,'ticket:'||p_ticket_id,p_ticket_id,'migration:'||p_ticket_id,v_valid_until);
  return jsonb_build_object('available',true,'consumed',true,'reason','NEW_MIGRATION_CASE','migration_total',v_total,'migration_remaining',greatest(0,v_total-v_used-1),'valid_until',v_valid_until);
end;
$function$;

create or replace function public.app_kombax_assist_turn_reserve_v227(p_ticket_id text, p_message text, p_client_request_id text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid(); v_ticket kombax_customer_ops.tickets%rowtype; v_ctx record; v_period kombax_ai_ops.assistance_periods%rowtype;
  v_policy kombax_ai_ops.assistance_cost_policies%rowtype; v_allowance jsonb; v_turn kombax_ai_ops.assistance_turns%rowtype;
  v_msg text:=left(btrim(coalesce(p_message,'')),4000); v_req text:=left(btrim(coalesce(p_client_request_id,'')),120);
  v_turns integer; v_period_cost numeric:=0; v_case_cost numeric:=0; v_period_cap numeric; v_case_cap numeric; v_max_turns integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if v_msg='' then raise exception 'message_required' using errcode='22023'; end if;
  if v_req='' then raise exception 'client_request_id_required' using errcode='22023'; end if;
  select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid for update;
  if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('ok',false,'reason','ORG_ASSIST_ONLY');
  end if;
  if v_ticket.category not in ('MIGRATION','MANAGEMENT') and not exists(
    select 1 from kombax_customer_ops.guided_sessions s
    where s.ticket_id=p_ticket_id and s.user_ref=v_uid and s.status='ACTIVE' and s.expires_at>now()
  ) then
    return jsonb_build_object('ok',false,'reason','ASSIST_CHAT_NOT_ACTIVATED');
  end if;
  if v_ticket.category='MIGRATION' and not kombax_ai_ops.migration_access_allowed(v_uid,v_ticket.tenant_ref) then
    return jsonb_build_object('ok',false,'reason','MIGRATION_ORG_ACCESS_REQUIRED');
  end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,v_ticket.tenant_ref);
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  if v_ticket.category='MIGRATION' then v_allowance:=kombax_ai_ops.reserve_migration_for_ticket(v_uid,p_ticket_id); else v_allowance:=kombax_ai_ops.reserve_assistance_for_ticket(v_uid,p_ticket_id); end if;
  if not coalesce((v_allowance->>'available')::boolean,false) then return jsonb_build_object('ok',false,'reason',v_allowance->>'reason','allowance',v_allowance); end if;
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  v_period_cap:=case when v_period.first_month_bonus>0 then v_policy.first_month_hard_cost else v_policy.monthly_hard_cost end;
  v_case_cap:=case when v_ticket.category='MIGRATION' then v_policy.migration_case_hard_cost else v_policy.general_case_hard_cost end;
  v_max_turns:=case when v_ticket.category='MIGRATION' then v_policy.max_turns_per_migration_case else v_policy.max_turns_per_general_case end;
  select coalesce(sum(t.estimated_cost),0) into v_period_cost from kombax_ai_ops.assistance_turns t where t.tenant_ref=v_ctx.tenant_ref and t.requested_at>=v_period.period_start and t.requested_at<v_period.period_end and t.status='COMPLETED';
  select coalesce(sum(t.estimated_cost),0),count(*) into v_case_cost,v_turns from kombax_ai_ops.assistance_turns t where t.ticket_id=p_ticket_id and t.status in('RESERVED','COMPLETED');
  if v_period_cost>=v_period_cap then return jsonb_build_object('ok',false,'reason','AI_MONTHLY_ECONOMY_GUARD'); end if;
  if v_case_cost>=v_case_cap then return jsonb_build_object('ok',false,'reason','AI_CASE_ECONOMY_GUARD'); end if;
  if v_turns>=v_max_turns then return jsonb_build_object('ok',false,'reason','CASE_TURN_LIMIT','turns_remaining',0); end if;
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.tenant_ref=v_ctx.tenant_ref and t.client_request_id=v_req;
  if found then return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',true,'category',v_turn.category,'turns_remaining',greatest(0,v_max_turns-v_turns),'allowance',v_allowance); end if;
  insert into kombax_ai_ops.assistance_turns(tenant_ref,user_ref,ticket_id,session_id,category,client_request_id)
  values(v_ctx.tenant_ref,v_uid,p_ticket_id,(select s.session_id from kombax_customer_ops.guided_sessions s where s.ticket_id=p_ticket_id and s.status='ACTIVE' and s.expires_at>now()),v_ticket.category,v_req)
  returning * into v_turn;
  insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text) values(p_ticket_id,v_uid,v_turn.turn_id,'USER',v_msg);
  update kombax_customer_ops.tickets set status='GUIDED_SESSION',updated_at=now() where ticket_id=p_ticket_id;
  return jsonb_build_object('ok',true,'turn_id',v_turn.turn_id,'reused',false,'category',v_ticket.category,'turns_remaining',greatest(0,v_max_turns-v_turns-1),'allowance',v_allowance);
end;
$function$;

create or replace function public.app_kombax_assist_dashboard_v227(p_tenant_ref text default null::text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid:=auth.uid(); v_ctx record; v_period kombax_ai_ops.assistance_periods%rowtype;
  v_ent kombax_ai_ops.assistance_plan_entitlements%rowtype; v_policy kombax_ai_ops.assistance_cost_policies%rowtype; v_settings jsonb;
  v_remaining integer; v_migration_total integer; v_migration_used integer; v_valid_until timestamptz;
  v_docs bigint:=0; v_bytes bigint:=0; v_max_docs integer; v_max_mb numeric;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501'; end if;
  v_period:=kombax_ai_ops.ensure_current_period(v_ctx.tenant_ref,v_ctx.plan,v_ctx.started_at,now());
  select * into strict v_ent from kombax_ai_ops.assistance_plan_entitlements e where e.plan=v_ctx.plan and e.effective_to is null;
  select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  v_settings:=v_ent.migration_allowance;
  v_remaining:=greatest(0,v_period.allowance_total-v_period.allowance_used);
  v_valid_until:=v_ctx.started_at+((v_settings->>'validity_days')::integer*interval '1 day');
  v_migration_total:=case when now()<v_ctx.started_at+interval '1 month' then (v_settings->>'first_month_cases')::integer else (v_settings->>'cases')::integer end;
  select count(*) into v_migration_used from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  select coalesce(sum(m.documents),0),coalesce(sum(m.size_mb*1048576),0) into v_docs,v_bytes
    from kombax_ai_ops.migration_allowance_cases m where m.tenant_ref=v_ctx.tenant_ref and m.consumed_at>=v_ctx.started_at and m.consumed_at<v_valid_until;
  v_max_docs:=coalesce((v_settings->>'max_documents_total')::integer,0); v_max_mb:=coalesce((v_settings->>'max_total_mb')::numeric,0);
  return jsonb_build_object(
    'plan',v_ctx.plan,
    'assistance',jsonb_build_object(
      'total',v_period.allowance_total,'remaining',v_remaining,'used',v_period.allowance_used,'period_end',v_period.period_end,
      'messages_per_conversation',v_policy.max_turns_per_general_case
    ),
    'migration',jsonb_build_object(
      'total',v_migration_total,'remaining',case when now()>v_valid_until then 0 else greatest(0,v_migration_total-v_migration_used) end,'used',v_migration_used,
      'valid_until',v_valid_until,'documents_used',v_docs,'documents_max',v_max_docs,'mb_used',round(v_bytes::numeric/1048576,2),'mb_max',v_max_mb,
      'file_types',v_settings->'file_types','case_continuity',true,'messages_per_conversation',v_policy.max_turns_per_migration_case
    ),
    'message',v_remaining||' de '||v_period.allowance_total||' conversaciones de KOMBAX Assist disponibles este mes · '||v_policy.max_turns_per_general_case||' mensajes por conversación.'
  );
end;
$function$;

create or replace function public.app_kombax_assist_turn_internal_v227(p_turn_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_turn kombax_ai_ops.assistance_turns%rowtype;v_ctx record;v_policy kombax_ai_ops.assistance_cost_policies%rowtype;v_messages jsonb;v_files jsonb;v_file_count integer;v_visual integer;v_bytes bigint;v_management jsonb:='{}'::jsonb;
begin
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id and t.status='RESERVED'; if not found then raise exception 'turn_not_reserved' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_turn.user_ref,v_turn.tenant_ref); select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  select coalesce(jsonb_agg(jsonb_build_object('turn_id',m.turn_id,'role',lower(m.role),'content',left(m.content_text,4000)) order by m.created_at),'[]'::jsonb) into v_messages
  from (select * from kombax_customer_ops.assist_chat_messages m where m.ticket_id=v_turn.ticket_id order by m.created_at desc limit 10) m;
  if v_turn.category='MIGRATION' then
    select coalesce(jsonb_agg(jsonb_build_object('file_id',x.file_id,'original_name',x.original_name,'mime_type',x.mime_type,'size_bytes',x.size_bytes,'storage_path',x.storage_path) order by x.created_at),'[]'::jsonb),count(*),count(*) filter(where x.mime_type like 'image/%'),coalesce(sum(x.size_bytes),0)
      into v_files,v_file_count,v_visual,v_bytes
    from (select f.* from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id
          where f.ticket_id=v_turn.ticket_id and f.user_ref=v_turn.user_ref and a.file_id is null and f.status in('STAGED','FAILED')
          order by f.created_at limit v_policy.max_files_per_batch) x;
  else v_files:='[]'::jsonb;v_file_count:=0;v_visual:=0;v_bytes:=0; end if;
  if v_turn.category='MANAGEMENT' then
    v_management:=kombax_ai_ops.management_context(v_turn.user_ref,v_turn.tenant_ref);
  end if;
  if v_visual>v_policy.max_visual_files_per_batch then
    select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord from jsonb_array_elements(v_files) with ordinality a(value,ord) where ord<=v_policy.max_visual_files_per_batch) z;
    v_file_count:=jsonb_array_length(v_files);v_visual:=v_file_count;
  end if;
  if v_bytes::numeric/1048576>v_policy.max_batch_mb then
    select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord,sum(coalesce((value->>'size_bytes')::bigint,0)) over(order by ord) running from jsonb_array_elements(v_files) with ordinality a(value,ord)) z where z.running<=v_policy.max_batch_mb*1048576;
    v_file_count:=jsonb_array_length(v_files);v_visual:=(select count(*) from jsonb_array_elements(v_files) e where e->>'mime_type' like 'image/%');
  end if;
  update kombax_ai_ops.assistance_turns set file_count=v_file_count,visual_file_count=v_visual where turn_id=p_turn_id;
  return jsonb_build_object('turn_id',v_turn.turn_id,'ticket_id',v_turn.ticket_id,'category',v_turn.category,'model_alias',v_policy.default_model,'max_output_tokens',v_policy.max_output_tokens,'image_detail',v_policy.image_detail,'messages',v_messages,'files',v_files,'management_context',v_management);
end;
$function$;

create or replace function public.app_kombax_customer_ops_mutate_v233(p_operation text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;

  if p_operation='ticket.create' then
    select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_payload->>'tenant_ref');
    v_category:=upper(left(coalesce(nullif(trim(p_payload->>'category'),''),'GENERAL'),64));
    if v_category='MANAGEMENT' and not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then raise exception 'KOMBAX_MANAGEMENT_ACCESS_REQUIRED' using errcode='42501'; end if;
    if v_category='MIGRATION' and not kombax_ai_ops.migration_access_allowed(v_uid,v_ctx.tenant_ref) then raise exception 'KOMBAX_MIGRATION_ACCESS_REQUIRED' using errcode='42501'; end if;
    v_priority:=case when v_category in ('SECURITY','DATA_LOSS','CRITICAL_PERMISSIONS') then 'URGENT' else 'MEDIUM' end;
    v_subject:=left(regexp_replace(coalesce(p_payload->>'subject',case when v_category='MANAGEMENT' then 'Asistencia de gestión KOMBAX' else 'Solicitud de soporte' end),E'[\\n\\r\\t]+',' ','g'),180);

    loop
      v_ticket_id:='KMX-'||to_char(v_now,'YYYY')||'-'||lpad((floor(random()*1000000))::int::text,6,'0');
      exit when not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id);
    end loop;

    insert into kombax_customer_ops.tickets(ticket_id,tenant_ref,user_ref,requester_email_hash,status,category,priority,module,subject_redacted,opened_at,updated_at)
    values(v_ticket_id,v_ctx.tenant_ref,v_uid,encode(extensions.digest(lower(coalesce(auth.jwt()->>'email',v_uid::text)),'sha256'),'hex'),'OPEN',v_category,v_priority,left(nullif(trim(p_payload->>'module'),''),64),v_subject,v_now,v_now)
    returning * into v_ticket;

    insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,to_status,detail,occurred_at)
    values(gen_random_uuid(),v_ticket_id,'TICKET_CREATED','USER',v_uid::text,'OPEN',jsonb_build_object('channel','PWA'),v_now);

  elsif p_operation='ticket.human_review' then
    v_ticket_id:=p_payload->>'ticket_id';
    select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=v_ticket_id and t.user_ref=v_uid for update;
    if not found then raise exception 'ticket_not_found' using errcode='P0002'; end if;
    v_from_status:=v_ticket.status;
    update kombax_customer_ops.tickets as t set status='HUMAN_REVIEW',updated_at=v_now where t.ticket_id=v_ticket_id returning * into v_ticket;
    insert into kombax_customer_ops.ticket_events(event_id,ticket_id,event_type,actor_type,actor_ref,from_status,to_status,detail,occurred_at)
    values(gen_random_uuid(),v_ticket_id,'HUMAN_REVIEW_REQUESTED','USER',v_uid::text,v_from_status,'HUMAN_REVIEW','{}',v_now);
  elsif p_operation='ticket.guided_start' then
    raise exception 'SUPPORT_CHAT_ACTIVATION_REQUIRED' using errcode='42501';
  else
    raise exception 'unsupported_operation' using errcode='22023';
  end if;

  return jsonb_build_object('ok',true,'ticket_id',v_ticket.ticket_id,'status',v_ticket.status,'category',v_ticket.category,'priority',v_ticket.priority,'updated_at',v_ticket.updated_at);
end;
$function$;

-- Keep grants explicit and least-privilege compatible with the existing app RPC model.
grant execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) to authenticated;
grant execute on function public.app_kombax_assist_dashboard_v227(text) to authenticated;
grant execute on function public.app_kombax_customer_ops_mutate_v233(text,jsonb) to authenticated;
