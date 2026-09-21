-- KOMBAX 20.114 R64.3 · Showcase/Commerce/Ticketing commercial rebalance
-- Additive correction over R64/R64.2. No destructive renames.
begin;

-- ---------------------------------------------------------------------------
-- 1) Club / Premium Showcase and Commerce model
-- ---------------------------------------------------------------------------
update kombax_commercial.plan_pricing_r64
set showcase_model_limit=15,
    commerce_mode='temporary',
    config=coalesce(config,'{}'::jsonb)||'{"social":true,"memberships":true,"club_management":true,"showcase":"display_15","commerce":"monthly_addon","events":"punctual"}'::jsonb,
    updated_at=now()
where plan_code='club';

update kombax_commercial.plan_pricing_r64
set showcase_model_limit=25,
    commerce_mode='included',
    config=coalesce(config,'{}'::jsonb)||'{"social":true,"memberships":true,"club_management":true,"showcase":"commerce_25","commerce":"included","events":"2_per_calendar_month"}'::jsonb,
    updated_at=now()
where plan_code='premium';

update public.kombax_planes
set descripcion='Gestión privada del club, Social/membresías y Showcase Display hasta 15 modelos. Commerce activable mensualmente.',actualizado_en=now()
where codigo='club';
update public.kombax_planes
set descripcion='Gestión, Showcase + Commerce hasta 25 modelos y 2 Events públicos/mes.',actualizado_en=now()
where codigo='premium';

insert into public.kombax_commerce_entitlements(plan_code,max_products,commerce_enabled,advanced_stock,analytics,promotions) values
 ('club',15,false,false,false,true),
 ('premium',25,true,true,true,true)
on conflict(plan_code) do update set max_products=excluded.max_products,commerce_enabled=excluded.commerce_enabled,
 advanced_stock=excluded.advanced_stock,analytics=excluded.analytics,promotions=excluded.promotions,updated_at=now();

-- Basic Club Commerce: one-month renewable activation. Premium includes Commerce.
insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('commerce_temporary','{"30":{"price_minor":1200,"renewable":true},"plan":"club","billing_period":"monthly"}'::jsonb,'Club básico: activación Showcase Commerce por 30 días a 12 EUR, renovable mes a mes. Premium/Enterprise lo incluyen.'),
 ('ticketing_buyer_fee_minor','0'::jsonb,'Compatibilidad: no se añade gasto por entrada al comprador en R64.3.'),
 ('ticketing_activation_tiers','{"50":1000,"100":1500,"200":2500,"500":4500,"1000":7500}'::jsonb,'Activación puntual Ticketing por capacidad del evento. Más de 1000 = Gran Evento con condiciones específicas.'),
 ('ticketing_pricing_mode','"capacity_activation"'::jsonb,'Ticketing se comercializa mediante activación puntual por capacidad, no mediante fee por entrada.')
on conflict(config_key) do update set value=excluded.value,description=excluded.description,updated_at=now();

update kombax_commercial.service_catalog
set pricing_status='fixed',description='Commerce agrupa checkout, pedidos, stock, seguimiento y posventa. Club básico: 12 EUR/mes; Premium y Enterprise: incluido.',updated_at=now()
where service_code='showcase_commerce';
update kombax_commercial.service_catalog
set pricing_status='fixed',description='Venta de entradas con checkout, ticket digital, QR, lector y control de acceso. Activación puntual por capacidad: 50/100/200/500/1000; más de 1000 = Gran Evento.',updated_at=now()
where service_code='events_ticketing';

-- ---------------------------------------------------------------------------
-- 2) Current commercial context and provider Commerce gate
-- ---------------------------------------------------------------------------
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
    'commerce_active',case
      when v_audience='brand' and v_plan in('brand_start','brand_growth','brand_enterprise','marca_profesional') then true
      when v_plan in('premium','enterprise','club_saas','club_pro') then true
      when v_plan='club' then kombax_commercial.entitlement_active_r64(p_subject_type,p_subject_id,'SHOWCASE_COMMERCE',null)
      else false end,
    'pending_plan_requests',coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc) from kombax_commercial.plan_requests_r64 r where r.subject_type=p_subject_type and r.subject_id=p_subject_id and r.status in('requested','under_review')),'[]'::jsonb)
  );
end $$;
revoke all on function public.app_kombax_commercial_context_r64(text,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_context_r64(text,uuid) to authenticated,service_role;

create or replace function kombax_commercial.provider_commerce_allowed_r64(p_provider_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_provider public.kombax_showcase_marcas;v_plan text;v_subject_type text;v_subject_id uuid;
begin
  select * into v_provider from public.kombax_showcase_marcas where id=p_provider_id;
  if not found then return false; end if;
  if v_provider.sujeto_tipo='club' then v_subject_type:='club';v_subject_id:=v_provider.club_id;
  else v_subject_type:='direct_profile';v_subject_id:=v_provider.perfil_directo_id; end if;
  v_plan:=kombax_commercial.active_plan_r64(v_subject_type,v_subject_id);
  if v_plan in('premium','enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then return true; end if;
  if v_plan='club' then return kombax_commercial.entitlement_active_r64(v_subject_type,v_subject_id,'SHOWCASE_COMMERCE',null); end if;
  return false;
end $$;
revoke all on function kombax_commercial.provider_commerce_allowed_r64(uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.provider_commerce_allowed_r64(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3) Club Showcase management and model limits
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth,kombax_commercial as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g join public.kombax_showcase_marcas gm on gm.id=g.marca_id where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo and (gm.sujeto_tipo<>'club' or coalesce(kombax_commercial.active_plan_r64('club',gm.club_id),'') in('club','premium','enterprise','club_saas','club_pro')))
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)) and coalesce(kombax_commercial.active_plan_r64('club',m.club_id),'') in('club','premium','enterprise','club_saas','club_pro'));
$$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare r record;v_id uuid;v_plan text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and public.app_puede_gestionar_perfil_club_v035(p_club_id) then
    v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
    if coalesce(v_plan,'') in('club','premium','enterprise','club_saas','club_pro') then v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id); end if;
  end if;
  for r in select d.id from public.perfiles_kombax_directos d where d.tipo in ('marca','federacion','competidor') and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social') and public.app_kombax_perfil_servicio_activo_v071(d.id)
  loop
    begin v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id); exception when sqlstate 'P0001' then if sqlerrm<>'SHOWCASE_PLAN_CAPABILITY_REQUIRED' then raise;end if; end;
  end loop;
  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    case when m.sujeto_tipo='club' then case kombax_commercial.active_plan_r64('club',m.club_id) when 'enterprise' then 10000 when 'premium' then 25 when 'club_pro' then 25 else 15 end
      else coalesce(nullif(public.app_kombax_plan_limite_v071(m.perfil_directo_id,'showcase.items'),0),case when m.sujeto_tipo='competidor' then 15 else 30 end) end,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'club' then 0 when 'federacion' then 1 when 'marca' then 2 else 3 end,m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_item_guard_v045()
returns trigger language plpgsql security definer set search_path=public,kombax_commercial as $$
declare v_type text;v_direct uuid;v_club uuid;v_limit integer;v_count integer;v_plan text;
begin
  if jsonb_typeof(coalesce(new.galeria,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(new.galeria,'[]'::jsonb))>3 then raise exception 'SHOWCASE_GALLERY_MAX_3_ADDITIONAL'; end if;
  if new.estado='publicado' and (tg_op='INSERT' or old.estado is distinct from 'publicado' or old.marca_id is distinct from new.marca_id) then
    select sujeto_tipo,perfil_directo_id,club_id into v_type,v_direct,v_club from public.kombax_showcase_marcas where id=new.marca_id;
    if v_type='club' then
      v_plan:=kombax_commercial.active_plan_r64('club',v_club);
      if coalesce(v_plan,'') not in('club','premium','enterprise','club_saas','club_pro') then raise exception 'SHOWCASE_PLAN_REQUIRED'; end if;
      if v_plan='enterprise' then v_limit:=null;
      elsif v_plan in('premium','club_pro') then v_limit:=25;
      else v_limit:=15; end if;
    else
      v_limit:=coalesce(nullif(public.app_kombax_plan_limite_v071(v_direct,'showcase.items'),0),case when v_type='competidor' then 15 else 30 end);
    end if;
    if v_limit is not null then
      select count(*) into v_count from public.kombax_showcase_elementos where marca_id=new.marca_id and estado='publicado' and id<>new.id;
      if v_count>=v_limit then raise exception 'SHOWCASE_VISIBLE_LIMIT_REACHED_%',v_limit;end if;
    end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_item_guard_v045() from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 4) Monthly Commerce activation for Club basic only
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commercial_activation_request_r64(p_subject_type text,p_subject_id uuid,p_entitlement_code text,p_scope_id uuid,p_days integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_code text:=upper(trim(p_entitlement_code));v_id uuid;v_detail jsonb;v_plan text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  if v_code not in('SHOWCASE_COMMERCE','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING') then raise exception 'COMMERCIAL_ENTITLEMENT_INVALID'; end if;
  if p_days is not null and p_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
  v_plan:=kombax_commercial.active_plan_r64(p_subject_type,p_subject_id);
  if v_code='SHOWCASE_COMMERCE' then
    if v_plan in('premium','enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then raise exception 'SHOWCASE_COMMERCE_ALREADY_INCLUDED'; end if;
    if v_plan<>'club' then raise exception 'SHOWCASE_COMMERCE_REQUIRES_CLUB_PLAN'; end if;
    if p_days<>30 then raise exception 'COMMERCE_MONTHLY_ACTIVATION_REQUIRED'; end if;
  elsif v_code='EVENT_PUBLICATION' then
    if v_plan in('enterprise','brand_enterprise','federation','federation_partner','federacion_institucional') then raise exception 'EVENT_PUBLICATION_ALREADY_INCLUDED'; end if;
    if p_scope_id is null then raise exception 'EVENT_PUBLICATION_EVENT_SCOPE_REQUIRED'; end if;
    if not public.app_kombax_evento_puede_gestionar_v160(p_scope_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    if p_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_DURATION_INVALID'; end if;
  elsif v_code='CONTENT_PROMOTION' then
    if p_scope_id is null then raise exception 'CONTENT_PROMOTION_SCOPE_REQUIRED'; end if;
    if p_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_DURATION_INVALID'; end if;
  elsif v_code='EVENT_TICKETING' then
    if v_plan in('enterprise','brand_enterprise') then raise exception 'EVENT_TICKETING_ALREADY_INCLUDED'; end if;
    if p_scope_id is null then raise exception 'EVENT_TICKETING_EVENT_SCOPE_REQUIRED'; end if;
  end if;
  v_detail:=jsonb_build_object('requested_days',p_days,'scope_id',p_scope_id,'payment_activation_performed',false,'plan_at_request',v_plan);
  insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
  values(p_subject_type,p_subject_id,v_code,'requested',p_scope_id,p_request_id,v_detail,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) to authenticated;

create or replace function public.app_kombax_commercial_admin_entitlement_decide_r642(p_entitlement_id uuid,p_decision text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_row kombax_commercial.entitlements_r64;v_decision text:=lower(trim(coalesce(p_decision,'')));v_days integer;v_plan text;v_last record;v_start timestamptz:=now();v_end timestamptz;
begin
  if v_uid is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  if char_length(trim(coalesce(p_note,'')))<5 then raise exception 'COMMERCIAL_REVIEW_NOTE_REQUIRED'; end if;
  select * into strict v_row from kombax_commercial.entitlements_r64 where id=p_entitlement_id for update;
  if v_row.status not in('requested','pending_payment') then raise exception 'COMMERCIAL_ENTITLEMENT_NOT_REVIEWABLE'; end if;
  if v_decision='reject' then
    update kombax_commercial.entitlements_r64 set status='rejected',detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'billing_activation_performed',false),updated_at=now() where id=v_row.id;
    return jsonb_build_object('ok',true,'status','rejected','entitlement_id',v_row.id);
  end if;
  if v_decision<>'activate' then raise exception 'COMMERCIAL_DECISION_INVALID'; end if;
  v_days:=nullif(v_row.detail->>'requested_days','')::integer;
  if v_days is null or v_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
  v_plan:=kombax_commercial.active_plan_r64(v_row.subject_type,v_row.subject_id);
  if v_row.entitlement_code='SHOWCASE_COMMERCE' then
    if v_plan<>'club' then raise exception 'SHOWCASE_COMMERCE_REQUIRES_CLUB_PLAN'; end if;
    if v_days<>30 then raise exception 'COMMERCE_MONTHLY_ACTIVATION_REQUIRED'; end if;
    select e.* into v_last from kombax_commercial.entitlements_r64 e
      where e.subject_type=v_row.subject_type and e.subject_id=v_row.subject_id and e.entitlement_code='SHOWCASE_COMMERCE'
        and e.id<>v_row.id and e.status='active' and e.ends_at>now()
      order by e.ends_at desc limit 1;
    if v_last.id is not null and v_last.ends_at>v_start then v_start:=v_last.ends_at; end if;
  elsif v_row.entitlement_code='EVENT_PUBLICATION' then
    if v_row.scope_id is null then raise exception 'EVENT_PUBLICATION_EVENT_SCOPE_REQUIRED'; end if;
    if not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_row.scope_id) then raise exception 'EVENT_NOT_FOUND'; end if;
    if v_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_DURATION_INVALID'; end if;
  elsif v_row.entitlement_code='CONTENT_PROMOTION' then
    if v_row.scope_id is null or v_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_INVALID'; end if;
  else
    raise exception 'COMMERCIAL_ENTITLEMENT_USE_DEDICATED_FLOW';
  end if;
  v_end:=v_start+make_interval(days=>v_days);
  update kombax_commercial.entitlements_r64 set status='active',starts_at=v_start,ends_at=v_end,
    detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'manual_activation',true,'billing_activation_performed',false,'activation_price_minor',case when v_row.entitlement_code='SHOWCASE_COMMERCE' then 1200 else null end),updated_at=now()
    where id=v_row.id;
  return jsonb_build_object('ok',true,'status','active','entitlement_id',v_row.id,'starts_at',v_start,'ends_at',v_end,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Ticketing activation tiers; buyer ticket fee = 0
-- ---------------------------------------------------------------------------
create or replace function kombax_commercial.ticket_buyer_fee_minor_r64()
returns integer language sql stable security definer set search_path='' as $$
  select coalesce((select (value #>> '{}')::integer from kombax_commercial.runtime_config_r64 where config_key='ticketing_buyer_fee_minor'),0);
$$;
revoke all on function kombax_commercial.ticket_buyer_fee_minor_r64() from public,anon,authenticated;
grant execute on function kombax_commercial.ticket_buyer_fee_minor_r64() to service_role;

create or replace function kombax_commercial.ticketing_activation_quote_r643(p_capacity integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v jsonb;v_price integer;v_limit integer;
begin
  select value into v from kombax_commercial.runtime_config_r64 where config_key='ticketing_activation_tiers';
  if p_capacity is null or p_capacity<=0 then return jsonb_build_object('capacity',p_capacity,'tier_limit',null,'price_minor',null,'large_event',false); end if;
  if p_capacity<=50 then v_limit:=50;
  elsif p_capacity<=100 then v_limit:=100;
  elsif p_capacity<=200 then v_limit:=200;
  elsif p_capacity<=500 then v_limit:=500;
  elsif p_capacity<=1000 then v_limit:=1000;
  else return jsonb_build_object('capacity',p_capacity,'tier_limit',null,'price_minor',null,'large_event',true); end if;
  v_price:=nullif(v->>v_limit::text,'')::integer;
  return jsonb_build_object('capacity',p_capacity,'tier_limit',v_limit,'price_minor',v_price,'large_event',false);
end $$;
revoke all on function kombax_commercial.ticketing_activation_quote_r643(integer) from public,anon,authenticated;
grant execute on function kombax_commercial.ticketing_activation_quote_r643(integer) to service_role;

create or replace function public.app_kombax_event_commercial_status_r628(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v_access kombax_commercial.service_access;v_seller jsonb;v_contracts jsonb;
  v_account kombax_payments.connected_accounts;v_plan text;v_plan_row kombax_commercial.plan_pricing_r64;
  v_active boolean:=false;v_included boolean:=false;v_status text;v_capacity integer;v_quote jsonb;v_tiers jsonb;
begin
  if v_uid is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select ticket_capacity into v_capacity from public.kombax_eventos_publicos where id=p_event_id;
  select * into v_access from kombax_commercial.service_access where subject_type='event' and subject_id=p_event_id and service_code='events_ticketing';
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  select * into v_plan_row from kombax_commercial.plan_pricing_r64 p where p.plan_code=v_plan and p.active;
  v_included:=v_plan in('enterprise','brand_enterprise');
  v_active:=kombax_commercial.event_ticketing_active_r628(p_event_id);
  v_status:=case when v_active then 'active' else coalesce(v_access.status,'not_requested') end;
  v_quote:=kombax_commercial.ticketing_activation_quote_r643(v_capacity);
  select value into v_tiers from kombax_commercial.runtime_config_r64 where config_key='ticketing_activation_tiers';
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid;
  select coalesce(jsonb_agg(jsonb_build_object(
      'code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,'legal_review_status',p.legal_review_status,
      'accepted',exists(select 1 from kombax_commercial.event_contract_acceptances a where a.event_id=p_event_id and a.organizer_subject_type=v_seller->>'subject_type' and a.organizer_subject_id=(v_seller->>'subject_id')::uuid and a.policy_code=p.policy_code and a.policy_version=p.version)
    ) order by p.policy_code),'[]'::jsonb)
    into v_contracts from kombax_commercial.event_contract_documents p where p.status='active' and p.required_for_ticketing;
  return jsonb_build_object(
    'events_publish',jsonb_build_object('status','active','service_class','core','pricing_status','included'),
    'events_ticketing',jsonb_build_object(
      'status',v_status,'service_class','addon','pricing_status','capacity_activation',
      'buyer_fee_minor',0,'buyer_fee_payer',null,'included_by_plan',v_included,
      'activation_tiers',coalesce(v_tiers,'{}'::jsonb),'activation_quote',v_quote,
      'platform_fee_percent',coalesce(v_plan_row.platform_fee_percent,case when v_plan in('enterprise','brand_enterprise') then 0 else 1.5 end),
      'plan_code',v_plan,'request_id',v_access.id,'review_note',v_access.review_note
    ),
    'contracts',v_contracts,'contracts_ready',kombax_commercial.event_contracts_ready_r628(p_event_id),
    'seller_subject_type',v_seller->>'subject_type','seller_subject_id',v_seller->>'subject_id',
    'stripe_ready',coalesce(v_account.status='active' and v_account.charges_enabled and v_account.payouts_enabled,false)
  );
end $$;
revoke all on function public.app_kombax_event_commercial_status_r628(uuid) from public,anon;
grant execute on function public.app_kombax_event_commercial_status_r628(uuid) to authenticated;

create or replace function public.app_kombax_event_ticketing_service_request_r628(p_event_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v public.kombax_eventos_publicos;a kombax_commercial.service_access;v_old text;v_seller jsonb;v_plan text;v_quote jsonb;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into strict v from public.kombax_eventos_publicos where id=p_event_id;
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  v_quote:=kombax_commercial.ticketing_activation_quote_r643(v.ticket_capacity);
  if v_plan in('enterprise','brand_enterprise') and coalesce((v_quote->>'large_event')::boolean,false)=false then
    return jsonb_build_object('ok',true,'request_id',p_request_id,'reused',true,'included_by_plan',true,'status','active','plan_code',v_plan,'activation_quote',v_quote);
  end if;
  select * into a from kombax_commercial.service_access where subject_type='event' and subject_id=p_event_id and service_code='events_ticketing' for update;
  if a.id is null then
    insert into kombax_commercial.service_access(subject_type,subject_id,service_code,status,source,requested_by)
    values('event',p_event_id,'events_ticketing','requested','user_request',v_uid) returning * into a;
    v_old:=null;
  elsif a.status in ('rejected','cancelled') then
    v_old:=a.status;
    update kombax_commercial.service_access set status='requested',source='user_request',requested_by=v_uid,requested_at=now(),reviewed_by=null,reviewed_at=null,review_note=null,updated_at=now() where id=a.id returning * into a;
  else
    return jsonb_build_object('ok',true,'request_id',p_request_id,'reused',true,'data',to_jsonb(a),'activation_quote',v_quote);
  end if;
  insert into kombax_commercial.service_events(service_access_id,actor_user_id,event_type,from_status,to_status,request_id,detail)
  values(a.id,v_uid,'ticketing.request',v_old,a.status,p_request_id,jsonb_build_object('event_id',p_event_id,'pricing_model','capacity_activation','activation_quote',v_quote,'buyer_fee_minor',0));
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(a),'activation_quote',v_quote);
end $$;
revoke all on function public.app_kombax_event_ticketing_service_request_r628(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_service_request_r628(uuid,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Ticketing agreement text follows the new activation model
-- ---------------------------------------------------------------------------
update kombax_commercial.event_contract_documents set status='retired',updated_at=now()
where policy_code='events_ticketing_agreement' and status='active';
insert into kombax_commercial.event_contract_documents(policy_code,version,title,body,required_for_ticketing,status,legal_review_status,effective_at) values
 ('events_ticketing_agreement','1.2-r643-qa','Acuerdo de servicio · Events + Ticketing',
 'BORRADOR OPERATIVO QA · REVISIÓN JURÍDICA OBLIGATORIA. El organizador vende las entradas en su nombre mediante su cuenta Stripe Connect. KOMBAX presta la capa tecnológica de Ticketing: checkout, ticket digital, QR, lectura y control de acceso. Ticketing se habilita de forma puntual según la capacidad configurada del evento: hasta 50, 100, 200, 500 o 1.000 entradas; por encima de 1.000 se considera Gran Evento y requiere condiciones específicas. KOMBAX no añade en este modelo un gasto fijo por entrada al comprador. Cuando el plan del organizador esté sujeto a platform fee, KOMBAX aplica el porcentaje configurado sobre el importe facial de la operación; Enterprise/Brand Enterprise tienen 0% según el plan comercial vigente. El organizador mantiene la responsabilidad sobre precio facial, celebración, cambios, cancelaciones, atención y devoluciones que correspondan. Los datos legales definitivos y tratamiento fiscal deberán validarse antes de lanzamiento público.',
 true,'active','pending',now())
on conflict(policy_code,version) do update set title=excluded.title,body=excluded.body,required_for_ticketing=true,status='active',legal_review_status=excluded.legal_review_status,updated_at=now();

notify pgrst,'reload schema';
commit;
