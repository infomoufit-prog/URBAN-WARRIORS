-- KOMBAX 20.111 R63 · SHOWCASE + EVENTS commercial compliance hardening
-- Conservative additive migration. No destructive data operations.
begin;

create schema if not exists kombax_compliance;
revoke all on schema kombax_compliance from public,anon,authenticated;
grant usage on schema kombax_compliance to service_role;

-- ---------------------------------------------------------------------------
-- 1. Commercial age eligibility. Existing identity rules remain untouched.
--    A user explicitly identified as <18 cannot buy Showcase products/tickets.
-- ---------------------------------------------------------------------------
create or replace function kombax_compliance.commercial_age_status_r63(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_dob date;v_source text;v_age integer;
begin
  if p_user_id is null or not exists(select 1 from public.perfiles p where p.id=p_user_id) then
    return jsonb_build_object('known',false,'adult',false,'minor',false,'reason','PROFILE_NOT_FOUND');
  end if;
  select s.fecha_nacimiento,'club_member' into v_dob,v_source
  from public.socios s where s.perfil_id=p_user_id and s.fecha_nacimiento is not null
  order by (s.estado='activo') desc,s.actualizado_en desc limit 1;
  if v_dob is null then
    select d.fecha_nacimiento_verificada,'verified_direct_profile' into v_dob,v_source
    from public.perfiles_kombax_directos d
    where d.perfil_id=p_user_id and d.fecha_nacimiento_verificada is not null
    order by (d.verificacion_estado='verificado') desc,d.actualizado_en desc limit 1;
  end if;
  if v_dob is null then return jsonb_build_object('known',false,'adult',null,'minor',false,'reason','DOB_NOT_AVAILABLE'); end if;
  v_age:=extract(year from age(current_date,v_dob))::integer;
  return jsonb_build_object('known',true,'adult',v_age>=18,'minor',v_age<18,'age',v_age,'source',v_source,'dob',v_dob);
end $$;
revoke all on function kombax_compliance.commercial_age_status_r63(uuid) from public,anon,authenticated;
grant execute on function kombax_compliance.commercial_age_status_r63(uuid) to service_role;

create or replace function public.app_kombax_commercial_purchase_eligibility_r63()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_age jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_age:=kombax_compliance.commercial_age_status_r63(v_uid);
  return jsonb_build_object('eligible',not coalesce((v_age->>'minor')::boolean,false),'age_status',v_age,'rule','KOMBAX_PURCHASE_18_PLUS_R63');
end $$;
revoke all on function public.app_kombax_commercial_purchase_eligibility_r63() from public,anon;
grant execute on function public.app_kombax_commercial_purchase_eligibility_r63() to authenticated;

create or replace function public.app_showcase_checkout_gate_r627(p_actor_id uuid,p_product_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare e public.kombax_showcase_elementos;v_missing int;v_age jsonb;
begin
  if p_actor_id is null then raise exception 'AUTH_REQUIRED'; end if;
  v_age:=kombax_compliance.commercial_age_status_r63(p_actor_id);
  if coalesce((v_age->>'minor')::boolean,false) then raise exception 'KOMBAX_PURCHASE_REQUIRES_18_PLUS'; end if;
  select * into e from public.kombax_showcase_elementos where id=p_product_id;
  if e.id is null or e.estado<>'publicado' or not e.commerce_enabled then raise exception 'SHOWCASE_PRODUCT_NOT_FOR_SALE'; end if;
  if not kombax_marketplace.seller_ready_r627(e.marca_id) then raise exception 'SHOWCASE_SELLER_NOT_READY'; end if;
  select count(*) into v_missing from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_buyer and not exists(select 1 from kombax_marketplace.policy_acceptances a where a.user_id=p_actor_id and a.provider_id is null and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='buyer');
  if v_missing>0 then raise exception 'BUYER_MARKETPLACE_TERMS_REQUIRED'; end if;
  return jsonb_build_object('ok',true,'provider_id',e.marca_id,'seller_ready',true,'buyer_terms_ready',true,'age_status',v_age);
end $$;
revoke all on function public.app_showcase_checkout_gate_r627(uuid,uuid) from public,anon,authenticated;
grant execute on function public.app_showcase_checkout_gate_r627(uuid,uuid) to service_role;

create or replace function public.app_event_ticket_checkout_gate_r628(p_actor_id uuid,p_event_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.kombax_eventos_publicos;v_seller jsonb;v_account kombax_payments.connected_accounts;v_age jsonb;
begin
  if p_actor_id is null or not exists(select 1 from public.perfiles p where p.id=p_actor_id) then raise exception 'BUYER_REQUIRED'; end if;
  v_age:=kombax_compliance.commercial_age_status_r63(p_actor_id);
  if coalesce((v_age->>'minor')::boolean,false) then raise exception 'KOMBAX_PURCHASE_REQUIRES_18_PLUS'; end if;
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id;
  if e.estado='cancelado' then raise exception 'EVENT_CANCELLED'; end if;
  if not e.ticketing_enabled or e.ticketing_mode<>'kombax' then raise exception 'EVENT_KOMBAX_TICKETING_NOT_ENABLED'; end if;
  if not kombax_commercial.event_ticketing_active_r628(p_event_id) then raise exception 'EVENT_TICKETING_ADDON_REQUIRED'; end if;
  if not kombax_commercial.event_contracts_ready_r628(p_event_id) then raise exception 'EVENT_TICKETING_CONTRACTS_REQUIRED'; end if;
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid;
  if v_account.id is null or v_account.status<>'active' or not v_account.charges_enabled or not v_account.payouts_enabled then raise exception 'EVENT_SELLER_STRIPE_NOT_READY'; end if;
  return jsonb_build_object('ok',true,'event_id',p_event_id,'seller_subject_type',v_seller->>'subject_type','seller_subject_id',v_seller->>'subject_id','age_status',v_age);
end $$;
revoke all on function public.app_event_ticket_checkout_gate_r628(uuid,uuid) from public,anon,authenticated;
grant execute on function public.app_event_ticket_checkout_gate_r628(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 2. Canonical legal-document evidence layer. It supplements existing engines
--    and preserves every accepted version/hash without overwriting history.
-- ---------------------------------------------------------------------------
create table if not exists kombax_compliance.legal_documents(
  id uuid primary key default gen_random_uuid(),
  document_code text not null,
  version text not null,
  locale text not null default 'es-ES',
  title text not null,
  relationship text not null,
  content_sha256 text not null check(content_sha256 ~ '^[0-9a-f]{64}$'),
  effective_at timestamptz not null,
  status text not null default 'active' check(status in('draft','active','deprecated')),
  source_path text,
  created_at timestamptz not null default now(),
  unique(document_code,version,locale)
);
create table if not exists kombax_compliance.legal_acceptances(
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references kombax_compliance.legal_documents(id) on delete restrict,
  user_id uuid not null references public.perfiles(id) on delete restrict,
  professional_profile_id uuid references public.perfiles_kombax_directos(id) on delete restrict,
  provider_id uuid references public.kombax_showcase_marcas(id) on delete restrict,
  event_id uuid references public.kombax_eventos_publicos(id) on delete restrict,
  accepted_at timestamptz not null default now(),
  locale text not null default 'es-ES',
  evidence jsonb not null default '{}'::jsonb,
  request_id uuid not null,
  unique(user_id,document_id,professional_profile_id,provider_id,event_id),
  unique(request_id)
);
alter table kombax_compliance.legal_documents enable row level security;
alter table kombax_compliance.legal_acceptances enable row level security;
revoke all on kombax_compliance.legal_documents,kombax_compliance.legal_acceptances from public,anon,authenticated;
grant all on kombax_compliance.legal_documents,kombax_compliance.legal_acceptances to service_role;

-- ---------------------------------------------------------------------------
-- 3. GPSR-oriented product data. Fields are category/risk dependent; CE is
--    never required universally. Existing product records remain valid.
-- ---------------------------------------------------------------------------
alter table public.kombax_showcase_elementos
  add column if not exists manufacturer_name text,
  add column if not exists manufacturer_contact text,
  add column if not exists eu_responsible_person text,
  add column if not exists model_reference text,
  add column if not exists product_identifier text,
  add column if not exists safety_warnings text,
  add column if not exists safety_information_url text,
  add column if not exists regulatory_documents jsonb not null default '[]'::jsonb,
  add column if not exists ce_marking_applicable boolean,
  add column if not exists ce_marking_declared boolean,
  add column if not exists safety_status text not null default 'allowed';
alter table public.kombax_showcase_elementos drop constraint if exists showcase_safety_status_r63;
alter table public.kombax_showcase_elementos add constraint showcase_safety_status_r63 check(safety_status in('allowed','restricted','requires_review','prohibited','removed_illegal','removed_safety'));

-- ---------------------------------------------------------------------------
-- 4. Unified commercial notice/action cases for products and events.
-- ---------------------------------------------------------------------------
create table if not exists kombax_compliance.commercial_cases(
  id uuid primary key default gen_random_uuid(),
  target_type text not null check(target_type in('product','event','seller','organizer')),
  target_id uuid not null,
  reporter_user_id uuid references public.perfiles(id) on delete set null,
  reason text not null check(reason in('dangerous_product','illegal_product','counterfeit','intellectual_property','fraud','misleading_information','prohibited_product','event_safety','event_legality','other')),
  detail text check(char_length(coalesce(detail,''))<=4000),
  status text not null default 'open' check(status in('open','triage','information_requested','under_review','temporarily_suspended','removed','restored','resolved','rejected')),
  priority text not null default 'normal' check(priority in('normal','high','urgent')),
  legal_or_policy_basis text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);
create table if not exists kombax_compliance.commercial_case_events(
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references kombax_compliance.commercial_cases(id) on delete restrict,
  actor_user_id uuid references public.perfiles(id) on delete set null,
  action text not null check(action in('reported','triaged','request_information','approve','limit_visibility','temporarily_suspend','remove','restore','escalate','resolve','reject','appeal_requested')),
  from_status text,
  to_status text,
  reason text,
  evidence jsonb not null default '{}'::jsonb,
  legal_or_policy_basis text,
  communication jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_commercial_cases_target_r63 on kombax_compliance.commercial_cases(target_type,target_id,status,created_at desc);
create index if not exists idx_commercial_cases_queue_r63 on kombax_compliance.commercial_cases(status,priority,created_at);
create index if not exists idx_commercial_case_events_r63 on kombax_compliance.commercial_case_events(case_id,created_at);
alter table kombax_compliance.commercial_cases enable row level security;
alter table kombax_compliance.commercial_case_events enable row level security;
revoke all on kombax_compliance.commercial_cases,kombax_compliance.commercial_case_events from public,anon,authenticated;
grant all on kombax_compliance.commercial_cases,kombax_compliance.commercial_case_events to service_role;

create or replace function public.app_kombax_commercial_report_r63(p_target_type text,p_target_id uuid,p_reason text,p_detail text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_case uuid;v_type text:=lower(coalesce(p_target_type,''));v_reason text:=lower(coalesce(p_reason,''));
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if v_type not in('product','event') then raise exception 'COMMERCIAL_REPORT_TARGET_INVALID'; end if;
  if v_reason not in('dangerous_product','illegal_product','counterfeit','intellectual_property','fraud','misleading_information','prohibited_product','event_safety','event_legality','other') then raise exception 'COMMERCIAL_REPORT_REASON_INVALID'; end if;
  if v_type='product' and not exists(select 1 from public.kombax_showcase_elementos e where e.id=p_target_id) then raise exception 'SHOWCASE_PRODUCT_NOT_FOUND'; end if;
  if v_type='event' and not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_target_id) then raise exception 'EVENT_NOT_FOUND'; end if;
  insert into kombax_compliance.commercial_cases(target_type,target_id,reporter_user_id,reason,detail,priority)
  values(v_type,p_target_id,v_uid,v_reason,left(nullif(btrim(p_detail),''),4000),case when v_reason in('dangerous_product','illegal_product','event_safety','event_legality') then 'high' else 'normal' end) returning id into v_case;
  insert into kombax_compliance.commercial_case_events(case_id,actor_user_id,action,to_status,reason,evidence)
  values(v_case,v_uid,'reported','open',v_reason,jsonb_build_object('request_id',p_request_id));
  return jsonb_build_object('ok',true,'case_id',v_case,'status','open');
end $$;
revoke all on function public.app_kombax_commercial_report_r63(text,uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_report_r63(text,uuid,text,text,uuid) to authenticated;

create or replace function public.app_kombax_commercial_moderation_queue_r63(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());
begin
  if v_uid is null or not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by case x.priority when 'urgent' then 0 when 'high' then 1 else 2 end,x.created_at)
    from (select c.id,c.target_type,c.target_id,c.reason,c.detail,c.status,c.priority,c.created_at,
      case when c.target_type='product' then (select e.nombre from public.kombax_showcase_elementos e where e.id=c.target_id)
           when c.target_type='event' then (select e.nombre from public.kombax_eventos_publicos e where e.id=c.target_id) else null end as target_name
      from kombax_compliance.commercial_cases c where c.status not in('resolved','rejected') order by c.created_at limit least(greatest(coalesce(p_limit,100),1),200)) x),'[]'::jsonb);
end $$;
revoke all on function public.app_kombax_commercial_moderation_queue_r63(integer) from public,anon;
grant execute on function public.app_kombax_commercial_moderation_queue_r63(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Event cancellation/refund tracking. Stripe execution remains explicit;
--    the system never silently moves money during migration.
-- ---------------------------------------------------------------------------
alter table kombax_payments.event_ticket_orders
  add column if not exists refund_state text not null default 'not_required',
  add column if not exists refund_reason text,
  add column if not exists refund_requested_at timestamptz,
  add column if not exists refund_completed_at timestamptz,
  add column if not exists stripe_refund_id text;
alter table kombax_payments.event_ticket_orders drop constraint if exists event_ticket_refund_state_r63;
alter table kombax_payments.event_ticket_orders add constraint event_ticket_refund_state_r63 check(refund_state in('not_required','refund_pending','refund_processing','refunded','refund_failed','manual_review'));
create index if not exists idx_event_ticket_refund_state_r63 on kombax_payments.event_ticket_orders(event_id,refund_state,created_at);

create or replace function public.app_kombax_event_cancel_commercial_plan_r63(p_event_id uuid,p_reason text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_count integer;v_reason text:=left(nullif(btrim(p_reason),''),1000);
begin
  if v_uid is null or p_request_id is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if v_reason is null then raise exception 'EVENT_CANCELLATION_REASON_REQUIRED'; end if;
  update public.kombax_eventos_publicos set estado='cancelado',ticketing_enabled=false,actualizado_en=now() where id=p_event_id;
  update kombax_payments.event_ticket_orders set refund_state='refund_pending',refund_reason=v_reason,refund_requested_at=coalesce(refund_requested_at,now()),updated_at=now()
  where event_id=p_event_id and status='paid' and refund_state in('not_required','refund_failed','manual_review');
  get diagnostics v_count=row_count;
  insert into kombax_payments.event_ticket_order_history(order_id,from_status,to_status,actor_user_id,source,detail)
  select o.id,o.status,o.status,v_uid,'organizer',jsonb_build_object('event_cancelled',true,'refund_state','refund_pending','reason',v_reason,'request_id',p_request_id)
  from kombax_payments.event_ticket_orders o where o.event_id=p_event_id and o.refund_state='refund_pending';
  return jsonb_build_object('ok',true,'event_id',p_event_id,'event_status','cancelado','refunds_pending',v_count,'money_moved',false,'next_action','EXECUTE_REFUNDS_THROUGH_CONNECTED_STRIPE_ACCOUNT');
end $$;
revoke all on function public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid) to authenticated;


-- Seller-side product compliance data uses the existing commerce mutation RPC.
create or replace function public.app_showcase_commerce_mutate_v259(p_item_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_item public.kombax_showcase_elementos;v_enabled boolean:=coalesce((p_payload->>'commerce_enabled')::boolean,false);v_price numeric;v_stock integer;v_safety text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  select * into strict v_item from public.kombax_showcase_elementos where id=p_item_id for update;
  if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  v_price:=nullif(p_payload->>'precio_venta','')::numeric;v_stock:=nullif(p_payload->>'stock','')::integer;
  v_safety:=coalesce(nullif(p_payload->>'safety_status',''),'allowed');
  if v_enabled and (v_price is null or v_price<=0) then raise exception 'COMMERCE_PRICE_REQUIRED'; end if;
  if v_enabled and not kombax_marketplace.seller_ready_r627(v_item.marca_id) then raise exception 'KOMBAX_SELLER_CENTER_REQUIRED'; end if;
  if v_enabled and v_safety in('prohibited','removed_illegal','removed_safety') then raise exception 'SHOWCASE_PRODUCT_SAFETY_BLOCKED'; end if;
  update public.kombax_showcase_elementos set commerce_enabled=v_enabled,precio_venta=v_price,stock=v_stock,
    variantes=coalesce(p_payload->'variantes','[]'::jsonb),fulfillment=coalesce(nullif(p_payload->>'fulfillment',''),'seller_shipping'),
    shipping_policy=nullif(btrim(p_payload->>'shipping_policy'),''),returns_policy=nullif(btrim(p_payload->>'returns_policy'),''),
    manufacturer_name=left(nullif(btrim(p_payload->>'manufacturer_name'),''),240),manufacturer_contact=left(nullif(btrim(p_payload->>'manufacturer_contact'),''),500),
    eu_responsible_person=left(nullif(btrim(p_payload->>'eu_responsible_person'),''),500),model_reference=left(nullif(btrim(p_payload->>'model_reference'),''),160),
    product_identifier=left(nullif(btrim(p_payload->>'product_identifier'),''),160),safety_warnings=left(nullif(btrim(p_payload->>'safety_warnings'),''),3000),
    safety_information_url=nullif(btrim(p_payload->>'safety_information_url'),''),regulatory_documents=coalesce(p_payload->'regulatory_documents','[]'::jsonb),
    ce_marking_applicable=case when p_payload ? 'ce_marking_applicable' then (p_payload->>'ce_marking_applicable')::boolean else null end,
    ce_marking_declared=case when p_payload ? 'ce_marking_declared' then (p_payload->>'ce_marking_declared')::boolean else false end,
    safety_status=v_safety,actualizado_por=v_uid,actualizado_en=now()
  where id=p_item_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('id',p_item_id,'commerce_enabled',v_enabled,'safety_status',v_safety));
end $$;
revoke all on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_showcase_commerce_mutate_v259(uuid,jsonb,uuid) to authenticated;


-- Align the active platform legal gate with the public 1.1.0-piloto documents.
create or replace function public.app_kombax_platform_legal_status_v129()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_terms text:='1.1.0-piloto';v_privacy text:='1.1.0-piloto';v_terms_ok boolean:=false;v_privacy_ok boolean:=false;
begin
  if v_uid is null then raise exception 'KOMBAX_AUTH_REQUIRED'; end if;
  select exists(select 1 from public.kombax_platform_legal_acceptances_v129 a where a.perfil_id=v_uid and a.tipo='terms' and a.version=v_terms and a.acknowledged) into v_terms_ok;
  select exists(select 1 from public.kombax_platform_legal_acceptances_v129 a where a.perfil_id=v_uid and a.tipo='privacy_notice' and a.version=v_privacy and a.acknowledged) into v_privacy_ok;
  return jsonb_build_object('terms_version',v_terms,'privacy_version',v_privacy,'terms_accepted',v_terms_ok,'privacy_acknowledged',v_privacy_ok,'required',not(v_terms_ok and v_privacy_ok));
end $$;

create or replace function public.app_kombax_platform_legal_accept_v129(p_terms_version text,p_privacy_version text,p_terms_accepted boolean,p_privacy_acknowledged boolean,p_user_agent text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_terms text:=btrim(coalesce(p_terms_version,''));v_privacy text:=btrim(coalesce(p_privacy_version,''));v_ua text:=left(nullif(btrim(coalesce(p_user_agent,'')),''),500);
begin
  if v_uid is null then raise exception 'KOMBAX_AUTH_REQUIRED'; end if;
  if not exists(select 1 from public.perfiles p where p.id=v_uid) then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;
  if v_terms<>'1.1.0-piloto' or v_privacy<>'1.1.0-piloto' then raise exception 'KOMBAX_PLATFORM_LEGAL_VERSION_INVALID'; end if;
  if p_terms_accepted is not true then raise exception 'KOMBAX_PLATFORM_TERMS_REQUIRED'; end if;
  if p_privacy_acknowledged is not true then raise exception 'KOMBAX_PLATFORM_PRIVACY_NOTICE_REQUIRED'; end if;
  insert into public.kombax_platform_legal_acceptances_v129(perfil_id,tipo,version,acknowledged,user_agent) values(v_uid,'terms',v_terms,true,v_ua)
  on conflict(perfil_id,tipo,version) do update set acknowledged=true,user_agent=excluded.user_agent,acknowledged_at=now();
  insert into public.kombax_platform_legal_acceptances_v129(perfil_id,tipo,version,acknowledged,user_agent) values(v_uid,'privacy_notice',v_privacy,true,v_ua)
  on conflict(perfil_id,tipo,version) do update set acknowledged=true,user_agent=excluded.user_agent,acknowledged_at=now();
  insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle) values(v_uid,null,'kombax.platform.legal.accept','platform_legal',v_uid,jsonb_build_object('terms_version',v_terms,'privacy_version',v_privacy,'terms_sha256','bdd830aa40654880e8df968a823232d5262375a256e43a72003b3bf3219ff2da','privacy_sha256','38aa7f9bbbd9cc0c317a9e7686f24120cb23f2497b92012d26790fa5abecad81'));
  return public.app_kombax_platform_legal_status_v129();
end $$;
revoke all on function public.app_kombax_platform_legal_status_v129(),public.app_kombax_platform_legal_accept_v129(text,text,boolean,boolean,text) from public,anon;
grant execute on function public.app_kombax_platform_legal_status_v129(),public.app_kombax_platform_legal_accept_v129(text,text,boolean,boolean,text) to authenticated;

insert into kombax_compliance.legal_documents(document_code,version,locale,title,relationship,content_sha256,effective_at,status,source_path)
values
 ('platform_terms','1.1.0-piloto','es-ES','Condiciones de uso de KOMBAX','KOMBAX ↔ usuario/profesional','bdd830aa40654880e8df968a823232d5262375a256e43a72003b3bf3219ff2da','2026-09-11T00:00:00+02','active','web/terms.html'),
 ('privacy_notice','1.1.0-piloto','es-ES','Política de Privacidad global de KOMBAX','KOMBAX ↔ usuario','38aa7f9bbbd9cc0c317a9e7686f24120cb23f2497b92012d26790fa5abecad81','2026-09-11T00:00:00+02','active','web/privacy.html')
on conflict(document_code,version,locale) do update set content_sha256=excluded.content_sha256,status='active',source_path=excluded.source_path;

commit;
