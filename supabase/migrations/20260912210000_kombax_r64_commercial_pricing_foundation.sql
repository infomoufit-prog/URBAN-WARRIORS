-- KOMBAX 20.112 R64 · Commercial pricing foundation
-- Additive/composable commercial layer. Does not activate billing or deploy externally.
begin;

create schema if not exists kombax_commercial;

-- ---------------------------------------------------------------------------
-- 1) Current commercial plan catalog (source of truth for UI/pricing)
-- ---------------------------------------------------------------------------
create table if not exists kombax_commercial.plan_pricing_r64(
  plan_code text primary key,
  audience text not null check(audience in('club','brand','federation')),
  display_name text not null,
  tagline text not null,
  founder_monthly_minor integer not null check(founder_monthly_minor>=0),
  standard_monthly_minor integer not null check(standard_monthly_minor>=0),
  standard_annual_minor integer not null check(standard_annual_minor>=0),
  annual_discount_percent numeric(5,2) not null default 16 check(annual_discount_percent between 0 and 100),
  platform_fee_percent numeric(7,4) not null default 0 check(platform_fee_percent between 0 and 100),
  showcase_model_limit integer check(showcase_model_limit is null or showcase_model_limit>=0),
  events_monthly_limit integer check(events_monthly_limit is null or events_monthly_limit>=0),
  commerce_mode text not null check(commerce_mode in('none','temporary','included')),
  ticketing_mode text not null check(ticketing_mode in('temporary','included')),
  assist_level text not null check(assist_level in('base','plus','pro')),
  migrations_level text not null check(migrations_level in('base','plus','pro')),
  founder_enabled boolean not null default true,
  active boolean not null default true,
  sort_order integer not null default 0,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table kombax_commercial.plan_pricing_r64 enable row level security;
revoke all on kombax_commercial.plan_pricing_r64 from public,anon,authenticated;
grant select,insert,update,delete on kombax_commercial.plan_pricing_r64 to service_role;

insert into kombax_commercial.plan_pricing_r64(
  plan_code,audience,display_name,tagline,founder_monthly_minor,standard_monthly_minor,standard_annual_minor,
  annual_discount_percent,platform_fee_percent,showcase_model_limit,events_monthly_limit,commerce_mode,ticketing_mode,assist_level,migrations_level,sort_order,config
) values
 ('club','club','KOMBAX Club','Gestiona',2900,3600,36300,16,1.5,0,0,'none','temporary','base','base',10,
  '{"social":true,"memberships":true,"club_management":true,"showcase":"none","events":"punctual"}'::jsonb),
 ('premium','club','KOMBAX Premium','Gestiona y promociona',4700,5900,59500,16,1.5,15,2,'temporary','temporary','plus','plus',20,
  '{"social":true,"memberships":true,"club_management":true,"showcase":"display","events":"2_per_calendar_month"}'::jsonb),
 ('enterprise','club','KOMBAX Enterprise','Gestiona, promociona y vende sin comisión KOMBAX',7900,9900,99800,16,0,null,null,'included','included','pro','pro',30,
  '{"social":true,"memberships":true,"club_management":true,"showcase":"unlimited","events":"unlimited"}'::jsonb),
 ('brand_start','brand','Brand Start','Vende y haz crecer tu marca',3900,4900,49400,16,1.5,25,0,'included','temporary','base','base',10,
  '{"showcase":"commerce","events":"punctual","verified_brand_required":true}'::jsonb),
 ('brand_growth','brand','Brand Growth','Escala catálogo y promoción',6900,8900,89700,16,1.5,100,2,'included','temporary','plus','plus',20,
  '{"showcase":"commerce","events":"2_per_calendar_month","verified_brand_required":true}'::jsonb),
 ('brand_enterprise','brand','Brand Enterprise','Commerce sin límites y sin comisión KOMBAX',12900,16100,162300,16,0,null,null,'included','included','pro','pro',30,
  '{"showcase":"unlimited","events":"unlimited","verified_brand_required":true}'::jsonb),
 ('federation','federation','KOMBAX Federation','Gestiona y conecta tu red',1900,2400,24200,16,1.5,0,null,'none','temporary','plus','plus',10,
  '{"network_management":true,"federative_events":true,"partner_eligible":true}'::jsonb),
 ('federation_partner','federation','KOMBAX Federation Partner','Haz crecer tu red y consigue ventajas',1900,2400,24200,16,1.5,0,null,'none','temporary','plus','plus',20,
  '{"network_management":true,"federative_events":true,"partner_program":true}'::jsonb)
on conflict(plan_code) do update set
 audience=excluded.audience,display_name=excluded.display_name,tagline=excluded.tagline,
 founder_monthly_minor=excluded.founder_monthly_minor,standard_monthly_minor=excluded.standard_monthly_minor,
 standard_annual_minor=excluded.standard_annual_minor,annual_discount_percent=excluded.annual_discount_percent,
 platform_fee_percent=excluded.platform_fee_percent,showcase_model_limit=excluded.showcase_model_limit,
 events_monthly_limit=excluded.events_monthly_limit,commerce_mode=excluded.commerce_mode,ticketing_mode=excluded.ticketing_mode,
 assist_level=excluded.assist_level,migrations_level=excluded.migrations_level,active=true,sort_order=excluded.sort_order,config=excluded.config,updated_at=now();

-- Keep the legacy plan engine compatible while adding the current commercial codes.
insert into public.kombax_planes(codigo,perfil_tipo,nombre,modalidad,requiere_checkout,descripcion) values
 ('club','club','KOMBAX Club','subscription',true,'Gestión privada del club, Social/membresías y servicios base.'),
 ('premium','club','KOMBAX Premium','subscription',true,'Gestión, Showcase Display hasta 15 modelos y 2 Events públicos/mes.'),
 ('enterprise','club','KOMBAX Enterprise','subscription',true,'Gestión, Commerce y Events/Ticketing sin platform fee KOMBAX.'),
 ('brand_start','marca','Brand Start','subscription',true,'Marca verificada con Commerce y hasta 25 modelos.'),
 ('brand_growth','marca','Brand Growth','subscription',true,'Marca verificada con Commerce, hasta 100 modelos y 2 Events/mes.'),
 ('brand_enterprise','marca','Brand Enterprise','subscription',true,'Marca verificada con Commerce/Events/Ticketing ilimitados y 0% platform fee.'),
 ('federation','federacion','KOMBAX Federation','subscription',true,'Gestión de red federativa, Events, Assist y Migrations.'),
 ('federation_partner','federacion','KOMBAX Federation Partner','subscription',true,'Federation con programa Partner y bonificaciones por clubes referidos.')
on conflict(codigo) do update set nombre=excluded.nombre,modalidad=excluded.modalidad,requiere_checkout=excluded.requiere_checkout,descripcion=excluded.descripcion,activo=true,actualizado_en=now();

-- Preserve the existing commerce-entitlement table as a compatibility source.
insert into public.kombax_commerce_entitlements(plan_code,max_products,commerce_enabled,advanced_stock,analytics,promotions) values
 ('club',0,false,false,false,false),
 ('premium',15,false,false,false,true),
 ('enterprise',10000,true,true,true,true),
 ('brand_start',25,true,false,false,true),
 ('brand_growth',100,true,true,true,true),
 ('brand_enterprise',10000,true,true,true,true),
 ('federation',0,false,false,false,true),
 ('federation_partner',0,false,false,false,true)
on conflict(plan_code) do update set max_products=excluded.max_products,commerce_enabled=excluded.commerce_enabled,
 advanced_stock=excluded.advanced_stock,analytics=excluded.analytics,promotions=excluded.promotions,updated_at=now();

-- ---------------------------------------------------------------------------
-- 2) Commercial configuration and temporary entitlements
-- ---------------------------------------------------------------------------
create table if not exists kombax_commercial.runtime_config_r64(
  config_key text primary key,
  value jsonb not null,
  description text not null,
  updated_at timestamptz not null default now()
);
alter table kombax_commercial.runtime_config_r64 enable row level security;
revoke all on kombax_commercial.runtime_config_r64 from public,anon,authenticated;
grant all on kombax_commercial.runtime_config_r64 to service_role;

insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('founder_sales_open','true'::jsonb,'Permite nuevas altas con tarifa Founder. Se cierra por configuración, no por hardcode.'),
 ('annual_discount_percent','16'::jsonb,'Descuento anual estándar. No acumulable con Founder.'),
 ('ticketing_buyer_fee_minor','150'::jsonb,'Gastos de gestión por entrada pagados por comprador.'),
 ('large_event_threshold','1000'::jsonb,'Más de este número de entradas requiere condiciones Gran Evento.'),
 ('commerce_temporary','{"7":{"price_minor":900},"30":{"price_minor":1900},"90":{"price_minor":5900},"rolling_12m_max_days":120,"max_consecutive_days":90,"cooldown_days":30}'::jsonb,'Activación temporal Commerce Premium y límites anticanibalización.'),
 ('event_publication','{"7":500,"15":800,"30":1200,"60":1800}'::jsonb,'Publicación puntual KOMBAX Events.'),
 ('content_promotion','{"7":1500,"15":2400,"30":3500,"max_promoted_events_per_user_day":2,"same_event_frequency_hours":72,"no_consecutive_promotions":true}'::jsonb,'Único servicio Destacar para Events/Showcase con amplificación Social.'),
 ('partner_program','{"1_9_percent":25,"10_plus_percent":30,"federation_agreement_percent":30,"commissioned_installments_start":2,"commissioned_installments_end":13,"federation_free_active_referrals":5,"annual_billing_reward_rule":"pending"}'::jsonb,'Reglas Partner. Liquidación anual deliberadamente pendiente.'),
 ('assist_limits','{"base":10,"plus":30,"pro":100}'::jsonb,'Conversaciones Assist por mes.'),
 ('migrations_limits','{"base":2,"plus":10,"pro":30}'::jsonb,'Procesos Migrations por mes.')
on conflict(config_key) do update set value=excluded.value,description=excluded.description,updated_at=now();

create table if not exists kombax_commercial.entitlements_r64(
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check(subject_type in('club','direct_profile','showcase_provider','event')),
  subject_id uuid not null,
  entitlement_code text not null check(entitlement_code in('SHOWCASE_COMMERCE','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING')),
  status text not null default 'requested' check(status in('requested','pending_payment','active','expired','cancelled','rejected')),
  starts_at timestamptz,
  ends_at timestamptz,
  scope_id uuid,
  limit_value integer,
  payment_reference text,
  request_id uuid,
  detail jsonb not null default '{}'::jsonb,
  created_by uuid references public.perfiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(ends_at is null or starts_at is null or ends_at>starts_at)
);
create index if not exists idx_commercial_entitlement_active_r64 on kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,ends_at);
create unique index if not exists uq_commercial_entitlement_request_r64 on kombax_commercial.entitlements_r64(request_id) where request_id is not null;
alter table kombax_commercial.entitlements_r64 enable row level security;
revoke all on kombax_commercial.entitlements_r64 from public,anon,authenticated;
grant all on kombax_commercial.entitlements_r64 to service_role;

create table if not exists kombax_commercial.plan_requests_r64(
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check(subject_type in('club','direct_profile')),
  subject_id uuid not null,
  requested_plan_code text not null references kombax_commercial.plan_pricing_r64(plan_code) on delete restrict,
  billing_cycle text not null check(billing_cycle in('monthly','annual')),
  founder_requested boolean not null default false,
  status text not null default 'requested' check(status in('requested','under_review','approved','rejected','cancelled')),
  request_id uuid not null unique,
  requested_by uuid not null references public.perfiles(id) on delete restrict,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table kombax_commercial.plan_requests_r64 enable row level security;
revoke all on kombax_commercial.plan_requests_r64 from public,anon,authenticated;
grant all on kombax_commercial.plan_requests_r64 to service_role;

create table if not exists kombax_commercial.organization_terms_r64(
  subject_type text not null check(subject_type in('club','direct_profile')),
  subject_id uuid not null,
  plan_code text references kombax_commercial.plan_pricing_r64(plan_code) on delete restrict,
  billing_cycle text not null default 'monthly' check(billing_cycle in('monthly','annual')),
  founder_locked boolean not null default false,
  founder_continuous_since timestamptz,
  founder_lost_at timestamptz,
  partner_code text,
  updated_at timestamptz not null default now(),
  primary key(subject_type,subject_id)
);
alter table kombax_commercial.organization_terms_r64 enable row level security;
revoke all on kombax_commercial.organization_terms_r64 from public,anon,authenticated;
grant all on kombax_commercial.organization_terms_r64 to service_role;

create table if not exists kombax_commercial.partner_referrals_r64(
  id uuid primary key default gen_random_uuid(),
  referrer_profile_id uuid not null references public.perfiles_kombax_directos(id) on delete restrict,
  referred_club_id uuid not null unique references public.clubes(id) on delete restrict,
  partner_code text not null,
  billing_frequency text check(billing_frequency in('monthly','annual')),
  subscription_plan text,
  activation_date timestamptz,
  active boolean not null default true,
  taxable_subscription_base_minor integer not null default 0 check(taxable_subscription_base_minor>=0),
  eligible_installment integer,
  reward_percent numeric(7,4),
  reward_amount_minor integer,
  reward_status text not null default 'pending' check(reward_status in('pending','pending_rule','eligible','approved','paid','rejected','expired')),
  reward_start timestamptz,
  reward_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table kombax_commercial.partner_referrals_r64 enable row level security;
revoke all on kombax_commercial.partner_referrals_r64 from public,anon,authenticated;
grant all on kombax_commercial.partner_referrals_r64 to service_role;

-- ---------------------------------------------------------------------------
-- 3) Helpers: subject management, active plan and temporary entitlement
-- ---------------------------------------------------------------------------
create or replace function kombax_commercial.can_manage_subject_r64(p_subject_type text,p_subject_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null or p_subject_id is null then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;
  if p_subject_type='club' then
    return public.app_puede_gestionar_perfil_club_v035(p_subject_id);
  elsif p_subject_type='direct_profile' then
    return public.app_kombax_puede_gestionar_perfil_v070(p_subject_id,'admin');
  end if;
  return false;
end $$;
revoke all on function kombax_commercial.can_manage_subject_r64(text,uuid) from public,anon;
grant execute on function kombax_commercial.can_manage_subject_r64(text,uuid) to authenticated,service_role;

create or replace function kombax_commercial.active_plan_r64(p_subject_type text,p_subject_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select s.modalidad
  from public.kombax_suscripciones s
  where s.sujeto_tipo=case when p_subject_type='direct_profile' then 'perfil_directo' else p_subject_type end
    and s.sujeto_id=p_subject_id
    and s.estado in('prueba','activa')
    and (s.inicia_en is null or s.inicia_en<=now())
    and (s.termina_en is null or s.termina_en>now())
  order by s.actualizado_en desc,s.creado_en desc limit 1;
$$;
revoke all on function kombax_commercial.active_plan_r64(text,uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.active_plan_r64(text,uuid) to service_role;

create or replace function kombax_commercial.entitlement_active_r64(p_subject_type text,p_subject_id uuid,p_code text,p_scope_id uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from kombax_commercial.entitlements_r64 e
    where e.subject_type=p_subject_type and e.subject_id=p_subject_id and e.entitlement_code=p_code and e.status='active'
      and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or e.ends_at>now())
      and (p_scope_id is null or e.scope_id is null or e.scope_id=p_scope_id)
  );
$$;
revoke all on function kombax_commercial.entitlement_active_r64(text,uuid,text,uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.entitlement_active_r64(text,uuid,text,uuid) to service_role;

-- Map Stripe seller subjects back to the KOMBAX subscription subject.
create or replace function kombax_commercial.seller_plan_r64(p_subject_type text,p_subject_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare v_provider public.kombax_showcase_marcas;v_plan text;
begin
  if p_subject_type='club' then return kombax_commercial.active_plan_r64('club',p_subject_id); end if;
  if p_subject_type in('federation','event_organizer') then return kombax_commercial.active_plan_r64('direct_profile',p_subject_id); end if;
  if p_subject_type='showcase_provider' then
    select * into v_provider from public.kombax_showcase_marcas where id=p_subject_id;
    if not found then return null; end if;
    if v_provider.sujeto_tipo='club' and v_provider.club_id is not null then
      return kombax_commercial.active_plan_r64('club',v_provider.club_id);
    elsif v_provider.perfil_directo_id is not null then
      return kombax_commercial.active_plan_r64('direct_profile',v_provider.perfil_directo_id);
    end if;
  end if;
  return null;
end $$;
revoke all on function kombax_commercial.seller_plan_r64(text,uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.seller_plan_r64(text,uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4) Commercial catalog RPC and auditable requests (no fake activation)
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commercial_catalog_r64(p_audience text default null)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'version','r64-v1',
    'plans',coalesce((select jsonb_agg(jsonb_build_object(
      'plan_code',p.plan_code,'audience',p.audience,'name',p.display_name,'tagline',p.tagline,
      'founder_monthly_minor',p.founder_monthly_minor,'standard_monthly_minor',p.standard_monthly_minor,
      'standard_annual_minor',p.standard_annual_minor,'annual_discount_percent',p.annual_discount_percent,
      'platform_fee_percent',p.platform_fee_percent,'showcase_model_limit',p.showcase_model_limit,
      'events_monthly_limit',p.events_monthly_limit,'commerce_mode',p.commerce_mode,'ticketing_mode',p.ticketing_mode,
      'assist_level',p.assist_level,'migrations_level',p.migrations_level,'config',p.config
    ) order by p.sort_order) from kombax_commercial.plan_pricing_r64 p where p.active and (p_audience is null or p.audience=lower(p_audience))),'[]'::jsonb),
    'config',coalesce((select jsonb_object_agg(c.config_key,c.value) from kombax_commercial.runtime_config_r64 c),'{}'::jsonb),
    'pricing_note','Precios finales con IVA incluido cuando corresponda. Founder no acumulable con descuento anual.',
    'partner_annual_rule','pending'
  );
$$;
revoke all on function public.app_kombax_commercial_catalog_r64(text) from public,anon;
grant execute on function public.app_kombax_commercial_catalog_r64(text) to authenticated,service_role;

create or replace function public.app_kombax_commercial_context_r64(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_plan text;v_terms kombax_commercial.organization_terms_r64;v_pricing kombax_commercial.plan_pricing_r64;v_audience text;
begin
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  v_plan:=kombax_commercial.active_plan_r64(p_subject_type,p_subject_id);
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=p_subject_type and subject_id=p_subject_id;
  if v_plan is not null then select * into v_pricing from kombax_commercial.plan_pricing_r64 where plan_code=v_plan; end if;
  if p_subject_type='club' then v_audience:='club'; else select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' else d.tipo end into v_audience from public.perfiles_kombax_directos d where d.id=p_subject_id; end if;
  return jsonb_build_object(
    'subject_type',p_subject_type,'subject_id',p_subject_id,'audience',v_audience,'plan_code',v_plan,
    'billing_cycle',coalesce(v_terms.billing_cycle,'monthly'),'founder_locked',coalesce(v_terms.founder_locked,false),
    'founder_continuous_since',v_terms.founder_continuous_since,'founder_lost_at',v_terms.founder_lost_at,
    'platform_fee_percent',coalesce(v_pricing.platform_fee_percent,case when v_plan in('enterprise','brand_enterprise') then 0 else 1.5 end),
    'commerce_active',case when v_audience='brand' and v_plan in('brand_start','brand_growth','brand_enterprise','marca_profesional') then true
                           when v_plan in('enterprise','club_saas','club_pro') then true
                           when v_plan='premium' then kombax_commercial.entitlement_active_r64(p_subject_type,p_subject_id,'SHOWCASE_COMMERCE',null)
                           else false end,
    'pending_plan_requests',coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc) from kombax_commercial.plan_requests_r64 r where r.subject_type=p_subject_type and r.subject_id=p_subject_id and r.status in('requested','under_review')),'[]'::jsonb)
  );
end $$;
revoke all on function public.app_kombax_commercial_context_r64(text,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_context_r64(text,uuid) to authenticated,service_role;

create or replace function public.app_kombax_commercial_plan_request_r64(p_subject_type text,p_subject_id uuid,p_plan_code text,p_billing_cycle text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_audience text;v_plan kombax_commercial.plan_pricing_r64;v_id uuid;v_founder_open boolean:=false;v_terms kombax_commercial.organization_terms_r64;v_founder_requested boolean:=false;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  if lower(p_billing_cycle) not in('monthly','annual') then raise exception 'COMMERCIAL_BILLING_CYCLE_INVALID'; end if;
  if p_subject_type='club' then v_audience:='club'; else select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' else d.tipo end into v_audience from public.perfiles_kombax_directos d where d.id=p_subject_id; end if;
  select * into v_plan from kombax_commercial.plan_pricing_r64 where plan_code=lower(p_plan_code) and active and audience=v_audience;
  if not found then raise exception 'COMMERCIAL_PLAN_NOT_AVAILABLE_FOR_SUBJECT'; end if;
  if v_audience='brand' and not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado') then raise exception 'VERIFIED_BRAND_REQUIRED'; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=p_subject_type and subject_id=p_subject_id;
  v_founder_requested:=coalesce(v_terms.founder_locked,false) or (coalesce(v_founder_open,false) and v_terms.founder_lost_at is null);
  insert into kombax_commercial.plan_requests_r64(subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by)
  values(p_subject_type,p_subject_id,v_plan.plan_code,lower(p_billing_cycle),v_founder_requested,p_request_id,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'plan_request_id',v_id,'status','requested','founder_requested',v_founder_requested,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_plan_request_r64(text,uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_plan_request_r64(text,uuid,text,text,uuid) to authenticated;

create or replace function public.app_kombax_commercial_activation_request_r64(p_subject_type text,p_subject_id uuid,p_entitlement_code text,p_scope_id uuid,p_days integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_code text:=upper(trim(p_entitlement_code));v_id uuid;v_detail jsonb;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  if v_code not in('SHOWCASE_COMMERCE','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING') then raise exception 'COMMERCIAL_ENTITLEMENT_INVALID'; end if;
  if p_days is not null and p_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
  if v_code='SHOWCASE_COMMERCE' and p_days not in(7,30,90) then raise exception 'COMMERCE_DURATION_INVALID'; end if;
  if v_code='EVENT_PUBLICATION' and p_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_DURATION_INVALID'; end if;
  if v_code='CONTENT_PROMOTION' and p_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_DURATION_INVALID'; end if;
  v_detail:=jsonb_build_object('requested_days',p_days,'scope_id',p_scope_id,'payment_activation_performed',false);
  insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
  values(p_subject_type,p_subject_id,v_code,'requested',p_scope_id,p_request_id,v_detail,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Commercial services: one promotion product; Ticketing consolidated
-- ---------------------------------------------------------------------------
alter table kombax_commercial.service_catalog drop constraint if exists service_catalog_pricing_status_check;
alter table kombax_commercial.service_catalog add constraint service_catalog_pricing_status_check check(pricing_status in('included','free','subscription','addon_to_define','fixed','per_ticket'));

insert into kombax_commercial.service_catalog(service_code,family,name,service_class,allows_checkout,pricing_status,description) values
 ('showcase_commerce','showcase','KOMBAX Showcase Commerce','addon',true,'fixed','Commerce agrupa checkout, pedidos, stock, seguimiento y posventa.'),
 ('content_promotion','events','Destacar','addon',false,'fixed','Único servicio de promoción: posición destacada y amplificación automática en KOMBAX Social.'),
 ('events_ticketing','events','KOMBAX Events + Ticketing','addon',true,'per_ticket','Venta de entradas con checkout, ticket digital, QR, lector y control de acceso. Gasto de gestión comprador: 1,50 € por entrada.')
on conflict(service_code) do update set name=excluded.name,service_class=excluded.service_class,allows_checkout=excluded.allows_checkout,pricing_status=excluded.pricing_status,description=excluded.description,active=true,updated_at=now();

-- Retire the QA ticketing agreement text that asserted 0% fees and replace it additively.
update kombax_commercial.event_contract_documents set status='retired',updated_at=now()
where policy_code='events_ticketing_agreement' and status='active';
insert into kombax_commercial.event_contract_documents(policy_code,version,title,body,required_for_ticketing,status,legal_review_status,effective_at) values
 ('events_ticketing_agreement','1.1-r64-qa','Acuerdo de servicio · Events + Ticketing',
 'BORRADOR OPERATIVO QA · REVISIÓN JURÍDICA OBLIGATORIA. El organizador vende las entradas en su nombre mediante su cuenta Stripe Connect. KOMBAX presta la capa tecnológica de Ticketing: checkout, ticket digital, QR, lectura y control de acceso. El comprador abona un gasto de gestión KOMBAX de 1,50 EUR por entrada. Cuando el plan del organizador esté sujeto a platform fee, KOMBAX aplica además el porcentaje configurado sobre el importe facial de la operación; Enterprise/Brand Enterprise tienen 0% según el plan comercial vigente. El organizador mantiene la responsabilidad sobre precio facial, celebración, cambios, cancelaciones, atención y devoluciones que correspondan. Los datos legales definitivos y tratamiento fiscal deberán validarse antes de lanzamiento público.',
 true,'active','pending',now())
on conflict(policy_code,version) do update set title=excluded.title,body=excluded.body,required_for_ticketing=true,status='active',legal_review_status='pending',effective_at=excluded.effective_at,updated_at=now();

notify pgrst,'reload schema';
commit;
