-- KOMBAX 20.112 R64 · Events commercial quotas + Assist/Migrations tiers
begin;

-- ---------------------------------------------------------------------------
-- 1) Plan capabilities: reuse the existing entitlement engine where applicable.
-- ---------------------------------------------------------------------------
insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select p.plan_code,p.capability
from (values
  ('brand_start','showcase.publish'),('brand_start','social.read'),('brand_start','social.publish'),
  ('brand_growth','showcase.publish'),('brand_growth','social.read'),('brand_growth','social.publish'),('brand_growth','events.public.organize'),('brand_growth','events.public.partners.manage'),('brand_growth','events.public.share'),
  ('brand_enterprise','showcase.publish'),('brand_enterprise','social.read'),('brand_enterprise','social.publish'),('brand_enterprise','events.public.organize'),('brand_enterprise','events.public.partners.manage'),('brand_enterprise','events.public.share'),
  ('federation','social.read'),('federation','social.publish'),('federation','events.public.organize'),('federation','events.public.partners.manage'),('federation','events.public.share'),
  ('federation_partner','social.read'),('federation_partner','social.publish'),('federation_partner','events.public.organize'),('federation_partner','events.public.partners.manage'),('federation_partner','events.public.share')
) p(plan_code,capability)
join public.kombax_capacidades c on c.clave=p.capability
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2) Events monthly usage. Deletion never restores a recorded publication.
-- ---------------------------------------------------------------------------
create table if not exists kombax_commercial.event_publication_usage_r64(
  event_id uuid primary key references public.kombax_eventos_publicos(id) on delete restrict,
  organizer_subject_type text not null check(organizer_subject_type in('club','direct_profile')),
  organizer_subject_id uuid not null,
  plan_code text,
  usage_month date not null,
  source text not null check(source in('plan_quota','punctual_entitlement','legacy_compat')),
  entitlement_id uuid references kombax_commercial.entitlements_r64(id) on delete restrict,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_pub_usage_subject_r64 on kombax_commercial.event_publication_usage_r64(organizer_subject_type,organizer_subject_id,usage_month);
alter table kombax_commercial.event_publication_usage_r64 enable row level security;
revoke all on kombax_commercial.event_publication_usage_r64 from public,anon,authenticated;
grant all on kombax_commercial.event_publication_usage_r64 to service_role;

create or replace function kombax_commercial.unconsumed_event_publication_entitlement_r64(p_subject_type text,p_subject_id uuid)
returns uuid language sql stable security definer set search_path='' as $$
  select e.id from kombax_commercial.entitlements_r64 e
  where e.subject_type=p_subject_type and e.subject_id=p_subject_id and e.entitlement_code='EVENT_PUBLICATION' and e.status='active'
    and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or e.ends_at>now())
    and nullif(e.detail->>'consumed_event_id','') is null
  order by e.ends_at nulls last,e.created_at limit 1;
$$;
revoke all on function kombax_commercial.unconsumed_event_publication_entitlement_r64(text,uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.unconsumed_event_publication_entitlement_r64(text,uuid) to service_role;

-- Extend native organizer rights from current commercial plans/temporary entitlements without removing historical entitlements.
create or replace function public.app_kombax_eventos_sujeto_puede_organizar_v160(p_sujeto_tipo text,p_sujeto_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_plan text;v_direct public.perfiles_kombax_directos;v_existing boolean:=false;
begin
  if v_uid is null or p_sujeto_id is null then return false; end if;
  if p_sujeto_tipo='club' then
    if not exists(select 1 from public.miembros_club m where m.club_id=p_sujeto_id and m.perfil_id=v_uid and m.activo and (m.rol in('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))) then return false; end if;
    select exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='club' and e.sujeto_id=p_sujeto_id and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())) into v_existing;
    if v_existing then return true; end if;
    v_plan:=kombax_commercial.active_plan_r64('club',p_sujeto_id);
    if v_plan in('premium','enterprise','club_saas','club_pro') then return true; end if;
    return kombax_commercial.unconsumed_event_publication_entitlement_r64('club',p_sujeto_id) is not null;
  elsif p_sujeto_tipo='perfil_directo' then
    select * into v_direct from public.perfiles_kombax_directos d where d.id=p_sujeto_id and d.perfil_id=v_uid and d.estado='activo';
    if not found then return false; end if;
    select exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='perfil_directo' and e.sujeto_id=p_sujeto_id and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())) into v_existing;
    if v_existing then return true; end if;
    if v_direct.verificacion_estado<>'verificado' then return false; end if;
    v_plan:=kombax_commercial.active_plan_r64('direct_profile',p_sujeto_id);
    if v_direct.tipo='federacion' and v_plan in('federation','federation_partner','federacion_institucional') then return true; end if;
    if v_direct.tipo='marca' and v_plan in('brand_growth','brand_enterprise','marca_profesional') then return true; end if;
    -- Professional organizer and other compatible historical personal profiles require a punctual active publication entitlement.
    if v_direct.tipo in('profesional','competidor','marca') then
      return kombax_commercial.unconsumed_event_publication_entitlement_r64('direct_profile',p_sujeto_id) is not null;
    end if;
  end if;
  return false;
end $$;
revoke all on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) to authenticated;

create or replace function kombax_commercial.assert_event_publication_allowed_r64(p_subject_type text,p_subject_id uuid,p_existing_event uuid,p_new_state text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_plan text;v_current_publicado timestamptz;v_count integer;v_ent uuid;v_month date:=date_trunc('month',current_date)::date;
begin
  if coalesce(p_new_state,'borrador')='borrador' then return jsonb_build_object('consume',false); end if;
  if p_existing_event is not null then
    select publicado_en into v_current_publicado from public.kombax_eventos_publicos where id=p_existing_event;
    if v_current_publicado is not null then return jsonb_build_object('consume',false); end if;
  end if;
  v_plan:=kombax_commercial.active_plan_r64(p_subject_type,p_subject_id);
  if v_plan in('enterprise','brand_enterprise','federation','federation_partner','federacion_institucional') then
    return jsonb_build_object('consume',true,'source','plan_quota','plan_code',v_plan,'unlimited',true);
  end if;
  if v_plan in('premium','brand_growth') then
    select count(*)::integer into v_count from kombax_commercial.event_publication_usage_r64 u
    where u.organizer_subject_type=p_subject_type and u.organizer_subject_id=p_subject_id and u.usage_month=v_month and u.source='plan_quota';
    if v_count>=2 then raise exception 'EVENT_MONTHLY_PUBLICATION_LIMIT_REACHED'; end if;
    return jsonb_build_object('consume',true,'source','plan_quota','plan_code',v_plan,'usage',v_count,'limit',2);
  end if;
  if v_plan in('club_saas','club_pro','marca_profesional') then
    return jsonb_build_object('consume',true,'source','legacy_compat','plan_code',v_plan);
  end if;
  v_ent:=kombax_commercial.unconsumed_event_publication_entitlement_r64(p_subject_type,p_subject_id);
  if v_ent is null then raise exception 'EVENT_PUBLICATION_PLAN_OR_ACTIVATION_REQUIRED'; end if;
  return jsonb_build_object('consume',true,'source','punctual_entitlement','plan_code',v_plan,'entitlement_id',v_ent);
end $$;
revoke all on function kombax_commercial.assert_event_publication_allowed_r64(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function kombax_commercial.assert_event_publication_allowed_r64(text,uuid,uuid,text) to service_role;

-- Preserve the R55 media wrapper and add first-publication accounting around event.save.
create or replace function public.app_kombax_eventos_mutate_v253(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_event uuid;v_existing public.app_mutation_requests;v_count integer:=0;
  v_subject_type text;v_subject_id uuid;v_new_state text;v_gate jsonb;v_result jsonb;v_usage_event uuid;v_ent uuid;v_source text;v_plan text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null and v_existing.result is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    return v_existing.result;
  end if;

  if p_operation='event.save' then
    v_event:=nullif(v_payload->>'id','')::uuid;v_subject_type:=lower(nullif(v_payload->>'sujeto_tipo',''));v_subject_id:=nullif(v_payload->>'sujeto_id','')::uuid;
    if v_event is not null then
      select case e.creador_tipo when 'club' then 'club' else 'direct_profile' end,coalesce(e.creador_club_id,e.creador_perfil_directo_id),coalesce(nullif(v_payload->>'estado',''),e.estado)
        into v_subject_type,v_subject_id,v_new_state from public.kombax_eventos_publicos e where e.id=v_event;
    else
      if v_subject_type='perfil_directo' then v_subject_type:='direct_profile'; end if;
      v_new_state:=coalesce(nullif(v_payload->>'estado',''),'borrador');
    end if;
    v_gate:=kombax_commercial.assert_event_publication_allowed_r64(v_subject_type,v_subject_id,v_event,v_new_state);
  end if;

  if p_operation='event.media.register' and lower(coalesce(v_payload->>'tipo',''))='video_externo' then
    v_event:=nullif(v_payload->>'evento_id','')::uuid;
    if v_event is null then raise exception 'EVENT_MEDIA_ID_REQUIRED'; end if;
    if not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN'; end if;
    perform pg_advisory_xact_lock(hashtextextended(v_event::text,2010156));
    select count(*)::integer into v_count from public.kombax_evento_media m where m.evento_id=v_event and m.estado<>'retirado' and m.tipo='video_externo';
    if v_count>=5 then raise exception 'EVENT_EXTERNAL_VIDEO_LIMIT_REACHED'; end if;
  end if;

  v_result:=public.app_kombax_eventos_mutate_v191(p_operation,v_payload,p_request_id);

  if p_operation='event.save' and coalesce((v_gate->>'consume')::boolean,false) then
    v_usage_event:=nullif(v_result#>>'{data,id}','')::uuid;v_source:=v_gate->>'source';v_plan:=nullif(v_gate->>'plan_code','');v_ent:=nullif(v_gate->>'entitlement_id','')::uuid;
    if v_usage_event is not null and not exists(select 1 from kombax_commercial.event_publication_usage_r64 where event_id=v_usage_event) then
      insert into kombax_commercial.event_publication_usage_r64(event_id,organizer_subject_type,organizer_subject_id,plan_code,usage_month,source,entitlement_id)
      values(v_usage_event,v_subject_type,v_subject_id,v_plan,date_trunc('month',current_date)::date,v_source,v_ent);
      if v_ent is not null then update kombax_commercial.entitlements_r64 set detail=detail||jsonb_build_object('consumed_event_id',v_usage_event,'consumed_at',now()),updated_at=now() where id=v_ent; end if;
    end if;
  end if;
  return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v253(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v253(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Single promotion engine data + frequency-cap helper.
-- ---------------------------------------------------------------------------
create table if not exists kombax_commercial.promotion_campaigns_r64(
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null unique references kombax_commercial.entitlements_r64(id) on delete cascade,
  content_type text not null check(content_type in('event','showcase_product')),
  content_id uuid not null,
  social_distribution boolean not null default true,
  status text not null default 'active' check(status in('active','paused','ended','cancelled')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check(ends_at>starts_at)
);
create table if not exists kombax_commercial.promotion_impressions_r64(
  id bigint generated always as identity primary key,
  campaign_id uuid not null references kombax_commercial.promotion_campaigns_r64(id) on delete cascade,
  viewer_user_id uuid not null references public.perfiles(id) on delete cascade,
  shown_at timestamptz not null default now()
);
create index if not exists idx_promo_impressions_viewer_r64 on kombax_commercial.promotion_impressions_r64(viewer_user_id,shown_at desc);
alter table kombax_commercial.promotion_campaigns_r64 enable row level security;
alter table kombax_commercial.promotion_impressions_r64 enable row level security;
revoke all on kombax_commercial.promotion_campaigns_r64,kombax_commercial.promotion_impressions_r64 from public,anon,authenticated;
grant all on kombax_commercial.promotion_campaigns_r64,kombax_commercial.promotion_impressions_r64 to service_role;

create or replace function kombax_commercial.promotion_can_serve_r64(p_campaign_id uuid,p_viewer uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_campaign kombax_commercial.promotion_campaigns_r64;v_daily integer;v_same_recent boolean;
begin
  select * into v_campaign from kombax_commercial.promotion_campaigns_r64 c where c.id=p_campaign_id and c.status='active' and c.starts_at<=now() and c.ends_at>now();
  if not found then return false; end if;
  select count(*)::integer into v_daily from kombax_commercial.promotion_impressions_r64 i join kombax_commercial.promotion_campaigns_r64 c on c.id=i.campaign_id where i.viewer_user_id=p_viewer and i.shown_at>=date_trunc('day',now()) and c.content_type='event';
  if v_campaign.content_type='event' and v_daily>=2 then return false; end if;
  select exists(select 1 from kombax_commercial.promotion_impressions_r64 i join kombax_commercial.promotion_campaigns_r64 c on c.id=i.campaign_id where i.viewer_user_id=p_viewer and c.content_type=v_campaign.content_type and c.content_id=v_campaign.content_id and i.shown_at>=now()-interval '72 hours') into v_same_recent;
  return not v_same_recent;
end $$;
revoke all on function kombax_commercial.promotion_can_serve_r64(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.promotion_can_serve_r64(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4) Assist/Migrations tiers: Base 10/2, Plus 30/10, Pro 100/30.
-- ---------------------------------------------------------------------------
alter table kombax_ai_ops.assistance_plan_entitlements drop constraint if exists assistance_plan_entitlements_plan_check;
alter table kombax_ai_ops.assistance_plan_entitlements add constraint assistance_plan_entitlements_plan_check check(plan in('CLUB_BASIC','CLUB_PREMIUM','FEDERATION','KOMBAX_PRO'));

insert into kombax_ai_ops.assistance_plan_entitlements(plan,monthly_assistance,first_month_assistance,migration_allowance,effective_from,owner_editable)
values
 ('CLUB_BASIC',10,10,'{"cases":2,"first_month_cases":2,"max_documents_total":200,"max_total_mb":500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG"],"validity_days":45}'::jsonb,now(),true),
 ('CLUB_PREMIUM',30,30,'{"cases":10,"first_month_cases":10,"max_documents_total":1000,"max_total_mb":2500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG","ZIP"],"validity_days":60}'::jsonb,now(),true),
 ('FEDERATION',30,30,'{"cases":10,"first_month_cases":10,"max_documents_total":3000,"max_total_mb":7500,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG","ZIP"],"validity_days":90}'::jsonb,now(),true),
 ('KOMBAX_PRO',100,100,'{"cases":30,"first_month_cases":30,"max_documents_total":5000,"max_total_mb":10000,"file_types":["CSV","XLSX","PDF","JPG","JPEG","PNG","ZIP"],"validity_days":90}'::jsonb,now(),true)
on conflict(plan) do update set monthly_assistance=excluded.monthly_assistance,first_month_assistance=excluded.first_month_assistance,migration_allowance=excluded.migration_allowance,effective_to=null,owner_editable=true,updated_at=now();

insert into kombax_ai_ops.assistance_cost_policies(plan,monthly_hard_cost,first_month_hard_cost,general_case_hard_cost,migration_case_hard_cost,default_model,escalation_model,max_output_tokens,max_turns_per_general_case,max_turns_per_migration_case,max_files_per_batch,max_visual_files_per_batch,max_batch_mb,image_detail)
values ('KOMBAX_PRO',7.50,7.50,0.15,1.50,'gpt-5.6-luna','gpt-5.6-terra',900,16,40,8,6,40,'low')
on conflict(plan) do update set monthly_hard_cost=excluded.monthly_hard_cost,first_month_hard_cost=excluded.first_month_hard_cost,general_case_hard_cost=excluded.general_case_hard_cost,migration_case_hard_cost=excluded.migration_case_hard_cost,default_model=excluded.default_model,escalation_model=excluded.escalation_model,max_output_tokens=excluded.max_output_tokens,max_turns_per_general_case=excluded.max_turns_per_general_case,max_turns_per_migration_case=excluded.max_turns_per_migration_case,max_files_per_batch=excluded.max_files_per_batch,max_visual_files_per_batch=excluded.max_visual_files_per_batch,max_batch_mb=excluded.max_batch_mb,image_detail=excluded.image_detail,updated_at=now();

-- Brands now have Migrations according to the commercial plan, reusing the existing org-access guard.
create or replace function kombax_ai_ops.migration_access_allowed(p_uid uuid,p_tenant_ref text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_ref text:=btrim(coalesce(p_tenant_ref,''));v_id uuid;v_type text;
begin
  if p_uid is null or v_ref='' then return false; end if;
  if v_ref like 'club:%' then return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref); end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;
    select lower(d.tipo) into v_type from public.perfiles_kombax_directos d where d.id=v_id and d.estado='activo';
    if v_type not in('federacion','marca') then return false; end if;
    return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref);
  end if;
  return false;
end $$;

-- Keep the R60 access model, changing only plan-to-assistance tier mapping.
create or replace function kombax_ai_ops.resolve_context(p_uid uuid,p_tenant_hint text default null::text)
returns table(tenant_ref text,plan text,started_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare v_ref text:=btrim(coalesce(p_tenant_hint,''));v_id uuid;v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      tenant_ref:='club:'||v_id::text;
      select coalesce(ts.plan_override,case s.modalidad when 'premium' then 'CLUB_PREMIUM' when 'enterprise' then 'KOMBAX_PRO' when 'club_pro' then 'CLUB_PREMIUM' when 'federacion_institucional' then 'FEDERATION' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now()) into plan,started_at
      from public.clubes c
      left join lateral (select ks.* from public.kombax_suscripciones ks where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in('prueba','activa') and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now()) order by ks.actualizado_en desc limit 1) s on true
      left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text where c.id=v_id;
      return next;return;
    end if;
  end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||v_id::text) then
      select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created into v_direct
      from public.perfiles_kombax_directos d left join lateral (select ks.* from public.kombax_suscripciones ks where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in('prueba','activa') and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now()) order by ks.actualizado_en desc limit 1) s on true
      where d.id=v_id and d.estado='activo' and lower(d.tipo) in('federacion','marca');
      if found then
        tenant_ref:='profile:'||v_direct.id::text;
        select coalesce(ts.plan_override,case v_direct.modalidad when 'brand_enterprise' then 'KOMBAX_PRO' when 'brand_growth' then 'CLUB_PREMIUM' when 'brand_start' then 'CLUB_BASIC' when 'federation' then 'FEDERATION' when 'federation_partner' then 'FEDERATION' when 'federacion_institucional' then 'FEDERATION' when 'marca_profesional' then 'CLUB_PREMIUM' else case when lower(v_direct.tipo)='federacion' then 'FEDERATION' else 'CLUB_BASIC' end end),coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now()) into plan,started_at
        from (values(1)) x(n) left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
        return next;return;
      end if;
    end if;
  end if;
  if v_ref<>'' and v_ref not like '%:%' then
    begin v_id:=v_ref::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text);return;end if;
  end if;
  select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created into v_direct
  from public.perfiles_kombax_directos d left join lateral (select ks.* from public.kombax_suscripciones ks where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in('prueba','activa') and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now()) order by ks.actualizado_en desc limit 1) s on true
  where d.estado='activo' and lower(d.tipo) in('federacion','marca') and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||d.id::text)
  order by (lower(d.tipo)='federacion') desc,d.actualizado_en desc limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,'profile:'||v_direct.id::text);return;end if;
  select mc.club_id into v_id from public.miembros_club mc where mc.perfil_id=p_uid and mc.activo order by (mc.rol::text='direccion') desc,mc.creado_en limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text);return;end if;
  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now()) into plan,started_at from public.perfiles p left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text where p.id=p_uid;
  if not found then plan:='CLUB_BASIC';started_at:=now();end if;return next;
end $$;

notify pgrst,'reload schema';
commit;
