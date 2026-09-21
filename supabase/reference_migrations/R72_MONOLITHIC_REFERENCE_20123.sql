-- KOMBAX R72 / build 20123
-- Showcase catalog +25, reputation preservation, reviews and Events community.
begin;

-- ---------------------------------------------------------------------------
-- 1. Commercial catalogue extension: +25 Showcase items / 30 days / 8 EUR.
-- ---------------------------------------------------------------------------
insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('showcase_catalog_plus_25','{"slots":25,"days":30,"price_minor":800,"renewable":true,"stackable":true}'::jsonb,
  'Ampliación Showcase: +25 productos activos durante 30 días por 8 EUR. Renovable y acumulable. No habilita Commerce.')
on conflict(config_key) do update set value=excluded.value,description=excluded.description,updated_at=now();

insert into kombax_commercial.service_catalog(service_code,family,name,service_class,allows_checkout,pricing_status,description) values
 ('showcase_catalog_plus_25','showcase','Ampliación Showcase +25','addon',false,'fixed',
  '+25 posiciones activas de catálogo durante 30 días por 8 EUR. Acumulable. Independiente de Commerce; Enterprise mantiene catálogo ilimitado.')
on conflict(service_code) do update set name=excluded.name,service_class=excluded.service_class,allows_checkout=excluded.allows_checkout,
 pricing_status=excluded.pricing_status,description=excluded.description,active=true,updated_at=now();

update kombax_commercial.plan_pricing_r64
set config=coalesce(config,'{}'::jsonb)||jsonb_build_object('showcase_capacity_included',showcase_model_limit,'showcase_catalog_expansion','plus_25_8eur_30d'),updated_at=now()
where plan_code in('club','premium','brand_start','brand_growth');
update kombax_commercial.plan_pricing_r64
set config=coalesce(config,'{}'::jsonb)||'{"showcase_capacity_included":"unlimited","showcase_catalog_expansion":"not_required"}'::jsonb,updated_at=now()
where plan_code in('enterprise','brand_enterprise');

update public.kombax_planes set descripcion='Gestión privada del club, Social/membresías y Showcase con 15 productos incluidos. Ampliaciones +25 disponibles; Commerce mensual opcional.',actualizado_en=now() where codigo='club';
update public.kombax_planes set descripcion='Gestión, Showcase + Commerce con 25 productos incluidos, ampliaciones +25 y 2 Events públicos/mes.',actualizado_en=now() where codigo='premium';
update public.kombax_planes set descripcion='Marca verificada con Commerce y 25 productos incluidos; ampliaciones Showcase +25 disponibles.',actualizado_en=now() where codigo='brand_start';
update public.kombax_planes set descripcion='Marca verificada con Commerce, 100 productos incluidos, ampliaciones Showcase +25 y 2 Events/mes.',actualizado_en=now() where codigo='brand_growth';

alter table kombax_commercial.entitlements_r64 drop constraint if exists entitlements_r64_entitlement_code_check;
alter table kombax_commercial.entitlements_r64 add constraint entitlements_r64_entitlement_code_check
 check(entitlement_code in('SHOWCASE_COMMERCE','SHOWCASE_CATALOG_PLUS_25','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING'));

-- Product lifecycle now explicitly preserves catalog reputation/history.
alter table public.kombax_showcase_elementos drop constraint if exists kombax_showcase_elementos_estado_check;
alter table public.kombax_showcase_elementos add constraint kombax_showcase_elementos_estado_check
 check(estado in('borrador','publicado','archivado','fuera_capacidad','retirado','oculto'));

-- ---------------------------------------------------------------------------
-- 2. Reputation data. Private schema: never exposed directly through Data API.
-- ---------------------------------------------------------------------------
create schema if not exists kombax_reputation;
revoke all on schema kombax_reputation from public,anon,authenticated;
grant usage on schema kombax_reputation to service_role;

create table if not exists kombax_reputation.product_reviews(
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.kombax_showcase_elementos(id) on delete restrict,
 reviewer_user_id uuid not null references public.perfiles(id) on delete restrict,
 rating smallint not null check(rating between 1 and 5),
 body text not null default '' check(char_length(body)<=4000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_purchase boolean not null default false,
 verified_order_id uuid references kombax_payments.showcase_orders(id) on delete set null,
 seller_response text check(seller_response is null or char_length(seller_response)<=3000),
 seller_response_by uuid references public.perfiles(id) on delete set null,
 seller_response_at timestamptz,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(product_id,reviewer_user_id)
);

create table if not exists kombax_reputation.event_comments(
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
 user_id uuid not null references public.perfiles(id) on delete restrict,
 parent_id uuid references kombax_reputation.event_comments(id) on delete set null,
 body text not null default '' check(char_length(body)<=3000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_attendance boolean not null default false,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists kombax_reputation.event_reviews(
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
 user_id uuid not null references public.perfiles(id) on delete restrict,
 rating smallint not null check(rating between 1 and 5),
 body text not null default '' check(char_length(body)<=4000),
 media jsonb not null default '[]'::jsonb check(jsonb_typeof(media)='array' and jsonb_array_length(media)<=5),
 verified_attendance boolean not null default false,
 organizer_response text check(organizer_response is null or char_length(organizer_response)<=3000),
 organizer_response_by uuid references public.perfiles(id) on delete set null,
 organizer_response_at timestamptz,
 status text not null default 'active' check(status in('active','reported','hidden','deleted_by_user')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(event_id,user_id)
);

create table if not exists kombax_reputation.reputation_reports(
 id uuid primary key default gen_random_uuid(),
 reporter_user_id uuid not null references public.perfiles(id) on delete restrict,
 target_type text not null check(target_type in('product_review','event_comment','event_review')),
 target_id uuid not null,
 reason text not null check(char_length(reason) between 2 and 80),
 detail text not null default '' check(char_length(detail)<=1500),
 status text not null default 'pending' check(status in('pending','reviewing','dismissed','actioned')),
 resolution text,
 resolved_by uuid references public.perfiles(id) on delete set null,
 resolved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table kombax_reputation.product_reviews enable row level security;
alter table kombax_reputation.event_comments enable row level security;
alter table kombax_reputation.event_reviews enable row level security;
alter table kombax_reputation.reputation_reports enable row level security;
revoke all on all tables in schema kombax_reputation from public,anon,authenticated;
grant select,insert,update,delete on all tables in schema kombax_reputation to service_role;

create index if not exists idx_r72_product_reviews_product on kombax_reputation.product_reviews(product_id,status,created_at desc);
create index if not exists idx_r72_product_reviews_user on kombax_reputation.product_reviews(reviewer_user_id,updated_at desc);
create index if not exists idx_r72_event_comments_event on kombax_reputation.event_comments(event_id,status,created_at desc);
create index if not exists idx_r72_event_comments_parent on kombax_reputation.event_comments(parent_id) where parent_id is not null;
create index if not exists idx_r72_event_reviews_event on kombax_reputation.event_reviews(event_id,status,created_at desc);
create index if not exists idx_r72_reports_pending on kombax_reputation.reputation_reports(status,created_at desc);
create unique index if not exists uq_r72_report_open on kombax_reputation.reputation_reports(reporter_user_id,target_type,target_id) where status in('pending','reviewing');

-- ---------------------------------------------------------------------------
-- 3. Capacity source of truth.
-- ---------------------------------------------------------------------------
create or replace function kombax_commercial.provider_showcase_capacity_r72(p_provider_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
 v_provider public.kombax_showcase_marcas;v_subject_type text;v_subject_id uuid;v_direct_type text;v_plan text;
 v_base integer;v_blocks integer:=0;v_total integer;v_active integer:=0;v_archived integer:=0;v_out integer:=0;
 v_plan_monthly integer:=0;v_enterprise_monthly integer;v_effective_monthly integer;v_recommend boolean:=false;
begin
 select * into v_provider from public.kombax_showcase_marcas where id=p_provider_id;
 if not found then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND'; end if;
 if v_provider.sujeto_tipo='club' then v_subject_type:='club';v_subject_id:=v_provider.club_id;
 else v_subject_type:='direct_profile';v_subject_id:=v_provider.perfil_directo_id; end if;
 v_plan:=kombax_commercial.active_plan_r64(v_subject_type,v_subject_id);
 if v_provider.sujeto_tipo='club' then
   if v_plan in('enterprise','club_saas') then v_base:=null;
   elsif v_plan in('premium','club_pro') then v_base:=25;
   else v_base:=15; end if;
 else
   select tipo into v_direct_type from public.perfiles_kombax_directos where id=v_provider.perfil_directo_id;
   if v_direct_type='marca' then
     if v_plan in('brand_enterprise') then v_base:=null;
     elsif v_plan in('brand_growth','marca_profesional') then v_base:=100;
     else v_base:=25; end if;
   elsif v_direct_type='federacion' then v_base:=0;
   else v_base:=coalesce(nullif(public.app_kombax_plan_limite_v071(v_provider.perfil_directo_id,'showcase.items'),0),case when v_direct_type='competidor' then 15 else 30 end); end if;
 end if;
 if v_base is not null and v_base>0 then
   select count(*)::integer into v_blocks from kombax_commercial.entitlements_r64 e
   where e.subject_type=v_subject_type and e.subject_id=v_subject_id and e.entitlement_code='SHOWCASE_CATALOG_PLUS_25'
     and e.status='active' and coalesce(e.starts_at,now())<=now() and (e.ends_at is null or e.ends_at>now());
 end if;
 v_total:=case when v_base is null then null else v_base+(v_blocks*25) end;
 select count(*)::integer into v_active from public.kombax_showcase_elementos where marca_id=p_provider_id and estado='publicado';
 select count(*)::integer into v_archived from public.kombax_showcase_elementos where marca_id=p_provider_id and estado='archivado';
 select count(*)::integer into v_out from public.kombax_showcase_elementos where marca_id=p_provider_id and estado='fuera_capacidad';
 if v_plan is not null then select standard_monthly_minor into v_plan_monthly from kombax_commercial.plan_pricing_r64 where plan_code=v_plan; end if;
 if v_provider.sujeto_tipo='club' then select standard_monthly_minor into v_enterprise_monthly from kombax_commercial.plan_pricing_r64 where plan_code='enterprise';
 elsif v_direct_type='marca' then select standard_monthly_minor into v_enterprise_monthly from kombax_commercial.plan_pricing_r64 where plan_code='brand_enterprise'; end if;
 v_effective_monthly:=coalesce(v_plan_monthly,0)+(v_blocks*800);
 v_recommend:=v_enterprise_monthly is not null and v_plan not in('enterprise','brand_enterprise') and v_effective_monthly>=v_enterprise_monthly;
 return jsonb_build_object('provider_id',p_provider_id,'subject_type',v_subject_type,'subject_id',v_subject_id,'plan_code',v_plan,
   'base_limit',v_base,'extra_blocks',v_blocks,'extra_slots',v_blocks*25,'total_limit',v_total,'unlimited',v_total is null,
   'active_products',v_active,'archived_products',v_archived,'out_of_capacity_products',v_out,
   'available_slots',case when v_total is null then null else greatest(v_total-v_active,0) end,
   'addon',jsonb_build_object('code','SHOWCASE_CATALOG_PLUS_25','slots',25,'days',30,'price_minor',800,'renewable',true,'stackable',true),
   'effective_monthly_minor',v_effective_monthly,'enterprise_monthly_minor',v_enterprise_monthly,'enterprise_upgrade_recommended',v_recommend);
end $$;
revoke all on function kombax_commercial.provider_showcase_capacity_r72(uuid) from public,anon,authenticated;
grant execute on function kombax_commercial.provider_showcase_capacity_r72(uuid) to service_role;

create or replace function public.app_kombax_showcase_capacity_r72(p_provider_id uuid,p_reconcile boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_cap jsonb;v_limit integer;v_active integer;v_over integer;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.app_kombax_showcase_puede_gestionar_v045(p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
 v_cap:=kombax_commercial.provider_showcase_capacity_r72(p_provider_id);v_limit:=nullif(v_cap->>'total_limit','')::integer;v_active:=coalesce((v_cap->>'active_products')::integer,0);
 if p_reconcile and v_limit is not null and v_active>v_limit then
   v_over:=v_active-v_limit;
   with overflow as(
     select id from public.kombax_showcase_elementos where marca_id=p_provider_id and estado='publicado'
     order by coalesce(publicado_en,creado_en) desc,id desc limit v_over
   ) update public.kombax_showcase_elementos e set estado='fuera_capacidad',commerce_enabled=false,actualizado_en=now(),actualizado_por=auth.uid()
     from overflow o where e.id=o.id;
   insert into public.kombax_actor_audit(actor_perfil_id,accion,objeto_tipo,objeto_id,detalle)
   values(auth.uid(),'showcase.capacity.reconcile','showcase_provider',p_provider_id,jsonb_build_object('moved_out_of_capacity',v_over,'limit',v_limit));
   v_cap:=kombax_commercial.provider_showcase_capacity_r72(p_provider_id);
 end if;
 return v_cap;
end $$;
revoke all on function public.app_kombax_showcase_capacity_r72(uuid,boolean) from public,anon;
grant execute on function public.app_kombax_showcase_capacity_r72(uuid,boolean) to authenticated;

-- Management list shows the dynamic total capacity. NULL means unlimited.
create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path='' as $$
declare r record;v_id uuid;v_plan text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_club_id is not null and public.app_puede_gestionar_perfil_club_v035(p_club_id) then
   v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
   if coalesce(v_plan,'') in('club','premium','enterprise','club_saas','club_pro') then v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id); end if;
 end if;
 for r in select d.id from public.perfiles_kombax_directos d where d.tipo in('marca','federacion','competidor') and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited') and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social') and public.app_kombax_perfil_servicio_activo_v071(d.id)
 loop begin v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id); exception when sqlstate 'P0001' then if sqlerrm<>'SHOWCASE_PLAN_CAPABILITY_REQUIRED' then raise; end if; end; end loop;
 return query select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
   nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
   (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
 from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v045(m.id)
 order by case m.sujeto_tipo when 'club' then 0 when 'federacion' then 1 when 'marca' then 2 else 3 end,m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_item_guard_v045()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_cap jsonb;v_limit integer;v_count integer;
begin
 if jsonb_typeof(coalesce(new.galeria,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(new.galeria,'[]'::jsonb))>3 then raise exception 'SHOWCASE_GALLERY_MAX_3_ADDITIONAL'; end if;
 if new.estado='publicado' and (tg_op='INSERT' or old.estado is distinct from 'publicado' or old.marca_id is distinct from new.marca_id) then
   v_cap:=kombax_commercial.provider_showcase_capacity_r72(new.marca_id);v_limit:=nullif(v_cap->>'total_limit','')::integer;
   if v_limit=0 then raise exception 'SHOWCASE_PLAN_REQUIRED'; end if;
   if v_limit is not null then select count(*) into v_count from public.kombax_showcase_elementos where marca_id=new.marca_id and estado='publicado' and id<>new.id;
     if v_count>=v_limit then raise exception 'SHOWCASE_VISIBLE_LIMIT_REACHED_%',v_limit; end if; end if;
 end if;
 return new;
end $$;
revoke all on function public.app_kombax_showcase_item_guard_v045() from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 4. Commercial activation supports stackable +25 blocks.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commercial_activation_request_r64(p_subject_type text,p_subject_id uuid,p_entitlement_code text,p_scope_id uuid,p_days integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_code text:=upper(trim(p_entitlement_code));v_id uuid;v_detail jsonb;v_plan text;
begin
 if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
 if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
 if v_code not in('SHOWCASE_COMMERCE','SHOWCASE_CATALOG_PLUS_25','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING') then raise exception 'COMMERCIAL_ENTITLEMENT_INVALID'; end if;
 if p_days is not null and p_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
 v_plan:=kombax_commercial.active_plan_r64(p_subject_type,p_subject_id);
 if v_code='SHOWCASE_COMMERCE' then
   if v_plan in('premium','enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then raise exception 'SHOWCASE_COMMERCE_ALREADY_INCLUDED'; end if;
   if v_plan<>'club' then raise exception 'SHOWCASE_COMMERCE_REQUIRES_CLUB_PLAN'; end if;
   if p_days<>30 then raise exception 'COMMERCE_MONTHLY_ACTIVATION_REQUIRED'; end if;
 elsif v_code='SHOWCASE_CATALOG_PLUS_25' then
   if v_plan in('enterprise','brand_enterprise','club_saas') then raise exception 'SHOWCASE_CATALOG_ALREADY_UNLIMITED'; end if;
   if v_plan not in('club','premium','club_pro','brand_start','brand_growth','marca_profesional') then raise exception 'SHOWCASE_CATALOG_EXPANSION_PLAN_REQUIRED'; end if;
   if p_days<>30 or p_scope_id is not null then raise exception 'SHOWCASE_CATALOG_PLUS_25_MONTHLY_REQUIRED'; end if;
 elsif v_code='EVENT_PUBLICATION' then
   if v_plan in('enterprise','brand_enterprise','federation','federation_partner','federacion_institucional') then raise exception 'EVENT_PUBLICATION_ALREADY_INCLUDED'; end if;
   if p_scope_id is null or not public.app_kombax_evento_puede_gestionar_v160(p_scope_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
   if p_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_DURATION_INVALID'; end if;
 elsif v_code='CONTENT_PROMOTION' then
   if p_scope_id is null or p_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_INVALID'; end if;
 elsif v_code='EVENT_TICKETING' then
   if v_plan in('enterprise','brand_enterprise') then raise exception 'EVENT_TICKETING_ALREADY_INCLUDED'; end if;
   if p_scope_id is null then raise exception 'EVENT_TICKETING_EVENT_SCOPE_REQUIRED'; end if;
 end if;
 v_detail:=jsonb_build_object('requested_days',p_days,'scope_id',p_scope_id,'payment_activation_performed',false,'plan_at_request',v_plan,
   'price_minor',case when v_code='SHOWCASE_CATALOG_PLUS_25' then 800 when v_code='SHOWCASE_COMMERCE' then 1200 else null end,
   'slots',case when v_code='SHOWCASE_CATALOG_PLUS_25' then 25 else null end);
 insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
 values(p_subject_type,p_subject_id,v_code,'requested',p_scope_id,p_request_id,v_detail,v_uid)
 on conflict(request_id) do update set updated_at=now() returning id into v_id;
 return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) to authenticated;

create or replace function public.app_kombax_commercial_admin_entitlement_decide_r642(p_entitlement_id uuid,p_decision text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_row kombax_commercial.entitlements_r64;v_decision text:=lower(trim(coalesce(p_decision,'')));v_days integer;v_plan text;v_last record;v_start timestamptz:=now();v_end timestamptz;v_price integer;
begin
 if v_uid is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if char_length(trim(coalesce(p_note,'')))<5 then raise exception 'COMMERCIAL_REVIEW_NOTE_REQUIRED'; end if;
 select * into strict v_row from kombax_commercial.entitlements_r64 where id=p_entitlement_id for update;
 if v_row.status not in('requested','pending_payment') then raise exception 'COMMERCIAL_ENTITLEMENT_NOT_REVIEWABLE'; end if;
 if v_decision='reject' then update kombax_commercial.entitlements_r64 set status='rejected',detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'billing_activation_performed',false),updated_at=now() where id=v_row.id;return jsonb_build_object('ok',true,'status','rejected','entitlement_id',v_row.id); end if;
 if v_decision<>'activate' then raise exception 'COMMERCIAL_DECISION_INVALID'; end if;
 v_days:=nullif(v_row.detail->>'requested_days','')::integer;if v_days is null or v_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
 v_plan:=kombax_commercial.active_plan_r64(v_row.subject_type,v_row.subject_id);
 if v_row.entitlement_code='SHOWCASE_COMMERCE' then
   if v_plan<>'club' or v_days<>30 then raise exception 'SHOWCASE_COMMERCE_REQUIRES_CLUB_PLAN'; end if;v_price:=1200;
   select e.* into v_last from kombax_commercial.entitlements_r64 e where e.subject_type=v_row.subject_type and e.subject_id=v_row.subject_id and e.entitlement_code='SHOWCASE_COMMERCE' and e.id<>v_row.id and e.status='active' and e.ends_at>now() order by e.ends_at desc limit 1;
   if v_last.id is not null and v_last.ends_at>v_start then v_start:=v_last.ends_at; end if;
 elsif v_row.entitlement_code='SHOWCASE_CATALOG_PLUS_25' then
   if v_plan in('enterprise','brand_enterprise','club_saas') or v_plan not in('club','premium','club_pro','brand_start','brand_growth','marca_profesional') or v_days<>30 then raise exception 'SHOWCASE_CATALOG_EXPANSION_INVALID'; end if;
   v_price:=800; -- intentionally starts now: blocks stack concurrently, they do not queue.
 elsif v_row.entitlement_code='EVENT_PUBLICATION' then
   if v_row.scope_id is null or not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_row.scope_id) or v_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_INVALID'; end if;
 elsif v_row.entitlement_code='CONTENT_PROMOTION' then
   if v_row.scope_id is null or v_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_INVALID'; end if;
 else raise exception 'COMMERCIAL_ENTITLEMENT_USE_DEDICATED_FLOW'; end if;
 v_end:=v_start+make_interval(days=>v_days);
 update kombax_commercial.entitlements_r64 set status='active',starts_at=v_start,ends_at=v_end,
   detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'manual_activation',true,'billing_activation_performed',false,'activation_price_minor',v_price),updated_at=now() where id=v_row.id;
 return jsonb_build_object('ok',true,'status','active','entitlement_id',v_row.id,'starts_at',v_start,'ends_at',v_end,'activation_price_minor',v_price,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Verified purchase / attendance helpers.
-- ---------------------------------------------------------------------------
create or replace function kombax_reputation.verified_purchase_order_r72(p_user_id uuid,p_product_id uuid)
returns uuid language sql stable security definer set search_path='' as $$
 select o.id from kombax_payments.showcase_orders o join kombax_payments.showcase_order_items i on i.order_id=o.id
 where o.buyer_user_id=p_user_id and i.product_id=p_product_id and o.status='delivered'
 order by coalesce(o.delivered_at,o.updated_at) desc limit 1;
$$;
revoke all on function kombax_reputation.verified_purchase_order_r72(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_reputation.verified_purchase_order_r72(uuid,uuid) to service_role;

create or replace function kombax_reputation.has_verified_attendance_r72(p_user_id uuid,p_event_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from kombax_payments.event_tickets t join kombax_payments.event_ticket_orders o on o.id=t.order_id
 where t.event_id=p_event_id and t.used_at is not null and t.status='used' and (t.holder_user_id=p_user_id or o.buyer_user_id=p_user_id));
$$;
revoke all on function kombax_reputation.has_verified_attendance_r72(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_reputation.has_verified_attendance_r72(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Showcase reviews.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_reviews_r72(p_product_id uuid,p_filter text default 'recent',p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_summary jsonb;v_reviews jsonb;v_product public.kombax_showcase_elementos;
begin
 select * into strict v_product from public.kombax_showcase_elementos where id=p_product_id;
 if v_product.estado<>'publicado' and not (v_uid is not null and public.app_kombax_showcase_puede_gestionar_v045(v_product.marca_id)) then raise exception 'SHOWCASE_PRODUCT_NOT_AVAILABLE'; end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_purchase),'with_photos',count(*) filter(where jsonb_array_length(r.media)>0),
  'distribution',jsonb_build_object('5',count(*) filter(where rating=5),'4',count(*) filter(where rating=4),'3',count(*) filter(where rating=3),'2',count(*) filter(where rating=2),'1',count(*) filter(where rating=1))) into v_summary
 from kombax_reputation.product_reviews r where r.product_id=p_product_id and r.status in('active','reported');
 select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_a desc,q.created_at desc),'[]'::jsonb) into v_reviews from(
   select r.id,r.rating,r.body,r.media,r.verified_purchase,r.created_at,r.updated_at,r.seller_response,r.seller_response_at,
    trim(concat_ws(' ',p.nombre,p.apellidos)) as author_name,p.avatar_url,(r.reviewer_user_id=v_uid) as own,
    case lower(coalesce(p_filter,'recent')) when 'best' then r.rating::bigint when 'worst' then (6-r.rating)::bigint when 'verified' then case when r.verified_purchase then 10 else 0 end when 'photos' then case when jsonb_array_length(r.media)>0 then 10 else 0 end else extract(epoch from r.created_at)::bigint end as sort_a
   from kombax_reputation.product_reviews r join public.perfiles p on p.id=r.reviewer_user_id
   where r.product_id=p_product_id and r.status in('active','reported')
    and (lower(coalesce(p_filter,'recent'))<>'verified' or r.verified_purchase)
    and (lower(coalesce(p_filter,'recent'))<>'photos' or jsonb_array_length(r.media)>0)
   limit least(greatest(coalesce(p_limit,50),1),100)
 )q;
 return jsonb_build_object('product_id',p_product_id,'summary',v_summary,'reviews',v_reviews,'can_review',v_uid is not null and v_product.estado='publicado' and v_product.commerce_enabled and v_product.listing_kind='product');
end $$;
revoke all on function public.app_kombax_showcase_reviews_r72(uuid,text,integer) from public;
grant execute on function public.app_kombax_showcase_reviews_r72(uuid,text,integer) to anon,authenticated;

create or replace function public.app_kombax_showcase_review_upsert_r72(p_product_id uuid,p_rating integer,p_body text default '',p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_product public.kombax_showcase_elementos;v_order uuid;v_id uuid;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into strict v_product from public.kombax_showcase_elementos where id=p_product_id;
 if not v_product.commerce_enabled or v_product.listing_kind<>'product' then raise exception 'REVIEW_COMMERCE_PRODUCT_REQUIRED'; end if;
 if p_rating not between 1 and 5 then raise exception 'REVIEW_RATING_INVALID'; end if;
 if char_length(trim(coalesce(p_body,'')))>4000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'REVIEW_CONTENT_INVALID'; end if;
 v_order:=kombax_reputation.verified_purchase_order_r72(v_uid,p_product_id);
 insert into kombax_reputation.product_reviews(product_id,reviewer_user_id,rating,body,media,verified_purchase,verified_order_id,status)
 values(p_product_id,v_uid,p_rating,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_order is not null,v_order,'active')
 on conflict(product_id,reviewer_user_id) do update set rating=excluded.rating,body=excluded.body,media=excluded.media,verified_purchase=excluded.verified_purchase,verified_order_id=excluded.verified_order_id,status='active',updated_at=now()
 returning id into v_id;
 return jsonb_build_object('ok',true,'review_id',v_id,'verified_purchase',v_order is not null,'verified_order_id',v_order);
end $$;
revoke all on function public.app_kombax_showcase_review_upsert_r72(uuid,integer,text,jsonb) from public,anon;
grant execute on function public.app_kombax_showcase_review_upsert_r72(uuid,integer,text,jsonb) to authenticated;

create or replace function public.app_kombax_showcase_review_withdraw_r72(p_review_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 update kombax_reputation.product_reviews set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_review_id and reviewer_user_id=v_uid returning id into v_id;
 if v_id is null then raise exception 'REVIEW_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'review_id',v_id,'withdrawn',true);end $$;
revoke all on function public.app_kombax_showcase_review_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_review_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_showcase_review_respond_r72(p_review_id uuid,p_response text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_product uuid;v_provider uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_response,'')))>3000 then raise exception 'REVIEW_RESPONSE_TOO_LONG';end if;
 select r.product_id,e.marca_id into v_product,v_provider from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where r.id=p_review_id;
 if v_product is null or not public.app_kombax_showcase_puede_gestionar_v045(v_provider) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
 update kombax_reputation.product_reviews set seller_response=nullif(trim(p_response),''),seller_response_by=case when trim(coalesce(p_response,''))='' then null else v_uid end,seller_response_at=case when trim(coalesce(p_response,''))='' then null else now() end,updated_at=now() where id=p_review_id;
 return jsonb_build_object('ok',true,'review_id',p_review_id);end $$;
revoke all on function public.app_kombax_showcase_review_respond_r72(uuid,text) from public,anon;
grant execute on function public.app_kombax_showcase_review_respond_r72(uuid,text) to authenticated;

create or replace function public.app_kombax_showcase_seller_reviews_r72(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_reviews jsonb;v_summary jsonb;
begin if auth.uid() is null or not public.app_kombax_showcase_puede_gestionar_v045(p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_purchase),'unanswered',count(*) filter(where r.seller_response is null)) into v_summary from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported');
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'product_id',e.id,'product_name',e.nombre,'rating',r.rating,'body',r.body,'media',r.media,'verified_purchase',r.verified_purchase,'seller_response',r.seller_response,'created_at',r.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos))) order by r.created_at desc),'[]'::jsonb) into v_reviews from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id join public.perfiles p on p.id=r.reviewer_user_id where e.marca_id=p_provider_id and r.status in('active','reported') limit least(greatest(coalesce(p_limit,100),1),200);
 return jsonb_build_object('provider_id',p_provider_id,'summary',v_summary,'reviews',v_reviews);end $$;
revoke all on function public.app_kombax_showcase_seller_reviews_r72(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_seller_reviews_r72(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Events community + ratings.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_event_community_r72(p_event_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_comments jsonb;v_reviews jsonb;v_summary jsonb;v_exists boolean;
begin
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or (v_uid is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)))) into v_exists;
 if not v_exists then raise exception 'EVENT_NOT_AVAILABLE';end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_attendance),'comments',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.status in('active','reported'))) into v_summary from kombax_reputation.event_reviews r where r.event_id=p_event_id and r.status in('active','reported');
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'parent_id',c.parent_id,'body',c.body,'media',c.media,'verified_attendance',c.verified_attendance,'created_at',c.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos)),'avatar_url',p.avatar_url,'own',c.user_id=v_uid) order by c.created_at asc),'[]'::jsonb) into v_comments from kombax_reputation.event_comments c join public.perfiles p on p.id=c.user_id where c.event_id=p_event_id and c.status in('active','reported') limit least(greatest(coalesce(p_limit,100),1),200);
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'rating',r.rating,'body',r.body,'media',r.media,'verified_attendance',r.verified_attendance,'organizer_response',r.organizer_response,'created_at',r.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos)),'own',r.user_id=v_uid) order by r.created_at desc),'[]'::jsonb) into v_reviews from kombax_reputation.event_reviews r join public.perfiles p on p.id=r.user_id where r.event_id=p_event_id and r.status in('active','reported') limit 50;
 return jsonb_build_object('event_id',p_event_id,'summary',v_summary,'comments',v_comments,'reviews',v_reviews,'authenticated',v_uid is not null,'verified_attendee',case when v_uid is null then false else kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id) end);
end $$;
revoke all on function public.app_kombax_event_community_r72(uuid,integer) from public;
grant execute on function public.app_kombax_event_community_r72(uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_event_comment_upsert_r72(p_event_id uuid,p_body text,p_parent_id uuid default null,p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_verified boolean;v_parent_event uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_body,'')))<1 and jsonb_array_length(coalesce(p_media,'[]'::jsonb))=0 then raise exception 'COMMENT_EMPTY';end if;if char_length(trim(coalesce(p_body,'')))>3000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'COMMENT_CONTENT_INVALID';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 if p_parent_id is not null then select event_id into v_parent_event from kombax_reputation.event_comments where id=p_parent_id and status in('active','reported');if v_parent_event is distinct from p_event_id then raise exception 'COMMENT_PARENT_INVALID';end if;end if;
 v_verified:=kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id);
 insert into kombax_reputation.event_comments(event_id,user_id,parent_id,body,media,verified_attendance) values(p_event_id,v_uid,p_parent_id,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_verified) returning id into v_id;
 return jsonb_build_object('ok',true,'comment_id',v_id,'verified_attendance',v_verified);end $$;
revoke all on function public.app_kombax_event_comment_upsert_r72(uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_event_comment_upsert_r72(uuid,text,uuid,jsonb) to authenticated;

create or replace function public.app_kombax_event_comment_withdraw_r72(p_comment_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;update kombax_reputation.event_comments set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_comment_id and user_id=auth.uid() returning id into v_id;if v_id is null then raise exception 'COMMENT_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'comment_id',v_id);end $$;
revoke all on function public.app_kombax_event_comment_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_event_comment_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_event_review_upsert_r72(p_event_id uuid,p_rating integer,p_body text default '',p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_verified boolean;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_rating not between 1 and 5 then raise exception 'REVIEW_RATING_INVALID';end if;if char_length(trim(coalesce(p_body,'')))>4000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'REVIEW_CONTENT_INVALID';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 v_verified:=kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id);
 insert into kombax_reputation.event_reviews(event_id,user_id,rating,body,media,verified_attendance,status) values(p_event_id,v_uid,p_rating,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_verified,'active')
 on conflict(event_id,user_id) do update set rating=excluded.rating,body=excluded.body,media=excluded.media,verified_attendance=excluded.verified_attendance,status='active',updated_at=now() returning id into v_id;
 return jsonb_build_object('ok',true,'review_id',v_id,'verified_attendance',v_verified);end $$;
revoke all on function public.app_kombax_event_review_upsert_r72(uuid,integer,text,jsonb) from public,anon;
grant execute on function public.app_kombax_event_review_upsert_r72(uuid,integer,text,jsonb) to authenticated;

create or replace function public.app_kombax_event_review_withdraw_r72(p_review_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;update kombax_reputation.event_reviews set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_review_id and user_id=auth.uid() returning id into v_id;if v_id is null then raise exception 'REVIEW_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'review_id',v_id);end $$;
revoke all on function public.app_kombax_event_review_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_event_review_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_event_review_respond_r72(p_review_id uuid,p_response text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_event uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_response,'')))>3000 then raise exception 'REVIEW_RESPONSE_TOO_LONG';end if;select event_id into v_event from kombax_reputation.event_reviews where id=p_review_id;if v_event is null or not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENT_MANAGE_REQUIRED';end if;update kombax_reputation.event_reviews set organizer_response=nullif(trim(p_response),''),organizer_response_by=case when trim(coalesce(p_response,''))='' then null else auth.uid() end,organizer_response_at=case when trim(coalesce(p_response,''))='' then null else now() end,updated_at=now() where id=p_review_id;return jsonb_build_object('ok',true,'review_id',p_review_id);end $$;
revoke all on function public.app_kombax_event_review_respond_r72(uuid,text) from public,anon;
grant execute on function public.app_kombax_event_review_respond_r72(uuid,text) to authenticated;

-- Reports are shared by Showcase and Events. Sellers/organizers report; platform moderates.
create or replace function public.app_kombax_reputation_report_r72(p_target_type text,p_target_id uuid,p_reason text,p_detail text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_type text:=lower(trim(p_target_type));
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if v_type not in('product_review','event_comment','event_review') or char_length(trim(coalesce(p_reason,'')))<2 then raise exception 'REPORT_INVALID';end if;
 if (v_type='product_review' and not exists(select 1 from kombax_reputation.product_reviews where id=p_target_id)) or (v_type='event_comment' and not exists(select 1 from kombax_reputation.event_comments where id=p_target_id)) or (v_type='event_review' and not exists(select 1 from kombax_reputation.event_reviews where id=p_target_id)) then raise exception 'REPORT_TARGET_NOT_FOUND';end if;
 insert into kombax_reputation.reputation_reports(reporter_user_id,target_type,target_id,reason,detail) values(v_uid,v_type,p_target_id,left(trim(p_reason),80),left(trim(coalesce(p_detail,'')),1500)) on conflict do nothing returning id into v_id;
 if v_id is null then select id into v_id from kombax_reputation.reputation_reports where reporter_user_id=v_uid and target_type=v_type and target_id=p_target_id and status in('pending','reviewing') order by created_at desc limit 1;end if;
 return jsonb_build_object('ok',true,'report_id',v_id,'status','pending');end $$;
revoke all on function public.app_kombax_reputation_report_r72(text,uuid,text,text) from public,anon;
grant execute on function public.app_kombax_reputation_report_r72(text,uuid,text,text) to authenticated;

create or replace function public.app_kombax_event_community_manage_r72(p_event_id uuid,p_limit integer default 150)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb;v_reports integer;
begin if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED';end if;v_base:=public.app_kombax_event_community_r72(p_event_id,p_limit);select count(*) into v_reports from kombax_reputation.reputation_reports rr where rr.status in('pending','reviewing') and ((rr.target_type='event_comment' and exists(select 1 from kombax_reputation.event_comments c where c.id=rr.target_id and c.event_id=p_event_id)) or (rr.target_type='event_review' and exists(select 1 from kombax_reputation.event_reviews r where r.id=rr.target_id and r.event_id=p_event_id)));return v_base||jsonb_build_object('pending_reports',v_reports);end $$;
revoke all on function public.app_kombax_event_community_manage_r72(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_community_manage_r72(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Safe delete: hard-delete only when history is absent; otherwise retire.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_mutate_v067(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_item_id uuid;v_item public.kombax_showcase_elementos;v_brand public.kombax_showcase_marcas;v_has_history boolean:=false;
begin
 if p_operation<>'kombax.showcase.elemento.eliminar' then return public.app_kombax_showcase_mutate_v054(p_operation,p_payload,p_request_id);end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
 else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;
 begin v_item_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
 select * into v_item from public.kombax_showcase_elementos where id=v_item_id for update;if v_item.id is null or not public.app_kombax_showcase_puede_gestionar_v045(v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;select * into v_brand from public.kombax_showcase_marcas where id=v_item.marca_id;
 v_has_history:=exists(select 1 from kombax_payments.showcase_order_items where product_id=v_item.id) or exists(select 1 from kombax_reputation.product_reviews where product_id=v_item.id);
 if v_has_history then
   update public.kombax_showcase_elementos set estado='retirado',commerce_enabled=false,destacado=false,actualizado_en=now(),actualizado_por=v_uid where id=v_item.id;
   insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle) values(v_uid,v_brand.club_id,'showcase.item.retire','showcase_item',v_item.id,jsonb_build_object('marca_id',v_item.marca_id,'history_preserved',true));
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_item.id,'deleted',false,'retired',true,'history_preserved',true));
 else
   delete from public.kombax_showcase_elementos where id=v_item.id;
   insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle) values(v_uid,v_brand.club_id,'showcase.item.delete','showcase_item',v_item.id,jsonb_build_object('marca_id',v_item.marca_id,'history_preserved',false));
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_item.id,'deleted',true,'retired',false,'history_preserved',false,'imagen_url',v_item.imagen_url,'galeria',v_item.galeria));
 end if;
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;end $$;
revoke all on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) to authenticated;

-- UGC review/community media uses a user-owned public path.
drop policy if exists kombax_reputation_media_insert_r72 on storage.objects;
create policy kombax_reputation_media_insert_r72 on storage.objects for insert to authenticated with check(
 bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
 and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='reputation'
);
drop policy if exists kombax_reputation_media_delete_r72 on storage.objects;
create policy kombax_reputation_media_delete_r72 on storage.objects for delete to authenticated using(
 bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
 and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='reputation'
);


-- ---------------------------------------------------------------------------
-- 9. Platform moderation API for reputation/community reports.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_reputation_moderation_queue_r72(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rows jsonb;
begin
 if auth.uid() is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at asc),'[]'::jsonb) into v_rows from(
   select rr.id,rr.target_type,rr.target_id,rr.reason,rr.detail,rr.status,rr.created_at,
     trim(concat_ws(' ',p.nombre,p.apellidos)) reporter_name
   from kombax_reputation.reputation_reports rr left join public.perfiles p on p.id=rr.reporter_user_id
   where rr.status in('pending','reviewing') order by rr.created_at asc limit least(greatest(coalesce(p_limit,100),1),200)
 )q;
 return jsonb_build_object('reports',v_rows,'total',jsonb_array_length(v_rows));
end $$;
revoke all on function public.app_kombax_reputation_moderation_queue_r72(integer) from public,anon;
grant execute on function public.app_kombax_reputation_moderation_queue_r72(integer) to authenticated;

create or replace function public.app_kombax_reputation_moderation_decide_r72(p_report_id uuid,p_decision text,p_resolution text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_report kombax_reputation.reputation_reports;v_decision text:=lower(trim(coalesce(p_decision,'')));
begin
 if v_uid is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if v_decision not in('dismiss','hide','restore') then raise exception 'MODERATION_DECISION_INVALID'; end if;
 select * into strict v_report from kombax_reputation.reputation_reports where id=p_report_id for update;
 if v_decision='hide' then
   if v_report.target_type='product_review' then update kombax_reputation.product_reviews set status='hidden',updated_at=now() where id=v_report.target_id;
   elsif v_report.target_type='event_comment' then update kombax_reputation.event_comments set status='hidden',updated_at=now() where id=v_report.target_id;
   elsif v_report.target_type='event_review' then update kombax_reputation.event_reviews set status='hidden',updated_at=now() where id=v_report.target_id;
   end if;
 elsif v_decision='restore' then
   if v_report.target_type='product_review' then update kombax_reputation.product_reviews set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   elsif v_report.target_type='event_comment' then update kombax_reputation.event_comments set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   elsif v_report.target_type='event_review' then update kombax_reputation.event_reviews set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   end if;
 end if;
 update kombax_reputation.reputation_reports set status=case when v_decision='dismiss' then 'dismissed' else 'actioned' end,resolution=left(trim(coalesce(p_resolution,'')),2000),resolved_by=v_uid,resolved_at=now(),updated_at=now() where id=v_report.id;
 return jsonb_build_object('ok',true,'report_id',v_report.id,'decision',v_decision,'target_type',v_report.target_type,'target_id',v_report.target_id);
end $$;
revoke all on function public.app_kombax_reputation_moderation_decide_r72(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_reputation_moderation_decide_r72(uuid,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. R72 contract/policy refresh. QA legal drafts: legal review remains pending.
-- ---------------------------------------------------------------------------
update kombax_marketplace.policy_documents set status='retired',updated_at=now() where status='active';
insert into kombax_marketplace.policy_documents(policy_code,version,title,body,audience,required_for_seller,required_for_buyer,status,legal_review_status,effective_at) values
 ('marketplace_terms','1.2-r72-qa','Condiciones KOMBAX Showcase Marketplace',
 'BORRADOR QA · REVISIÓN JURÍDICA OBLIGATORIA. KOMBAX Showcase funciona como marketplace tecnológico. Los productos con compra directa son ofrecidos por el vendedor identificado. Los límites de catálogo de cada plan representan capacidad incluida; los planes compatibles pueden añadir bloques renovables y acumulables de +25 productos durante 30 días por 8 EUR, separados de Commerce. Archivar un producto libera capacidad activa y conserva su referencia e historial. Si un producto con pedidos, reseñas u otra trazabilidad relevante se elimina desde la gestión, KOMBAX puede retirarlo de la venta conservando el registro histórico necesario en lugar de destruirlo. Las reseñas, puntuaciones, fotografías y respuestas son contenido generado por usuarios sujeto a moderación. KOMBAX puede mostrar el distintivo Compra verificada solo cuando exista un pedido entregado atribuible al usuario y producto. Vendedor y comprador pueden reportar contenido; el vendedor no puede eliminar unilateralmente una crítica legítima. Los datos legales definitivos del operador deben completarse y someterse a revisión jurídica antes del lanzamiento comercial público.',
 'both',true,true,'active','pending',now()),
 ('seller_agreement','1.2-r72-qa','Acuerdo de vendedor KOMBAX Showcase',
 'BORRADOR QA · REVISIÓN JURÍDICA OBLIGATORIA. El vendedor actúa por cuenta propia y responde por legalidad, seguridad, descripción, precio, stock, entrega, garantías, devoluciones y atención. La venta directa exige verificación, políticas aceptadas y Stripe Connect operativo. La ampliación Showcase +25 añade 25 posiciones activas durante 30 días por 8 EUR, es acumulable y no activa Commerce ni modifica por sí sola la comisión de plataforma. Al expirar capacidad adicional KOMBAX no elimina referencias ni reputación: los productos que excedan la capacidad podrán quedar fuera de capacidad hasta que el vendedor renueve, amplíe, cambie de plan o archive referencias. Archivar libera capacidad conservando historial; la eliminación física se limita a fichas sin historial relevante. El vendedor acepta que las reseñas de usuarios, incluidas fotografías, puntuaciones y la marca Compra verificada, forman parte de la reputación del producto. Puede responder y reportar, pero no alterar ni borrar reseñas legítimas de terceros.',
 'seller',true,false,'active','pending',now()),
 ('buyer_protection','1.2-r72-qa','Protección del comprador KOMBAX Showcase',
 'BORRADOR QA · REVISIÓN JURÍDICA OBLIGATORIA. El comprador dispone de trazabilidad de pedidos, incidencias y reembolsos conforme a las condiciones aplicables. Puede publicar una valoración de producto habilitado para Commerce, con puntuación, texto y fotografías dentro de los límites técnicos. KOMBAX marcará Compra verificada únicamente cuando el sistema pueda vincular la reseña con un pedido entregado. El autor puede editar o retirar su aportación; la retirada deja de mostrar el contenido, pero KOMBAX puede conservar trazabilidad técnica o de moderación cuando sea necesario. Las reseñas deben ser veraces, respetuosas y no vulnerar derechos, privacidad ni propiedad intelectual.',
 'buyer',false,true,'active','pending',now()),
 ('prohibited_products','1.2-r72-qa','Política de productos prohibidos y restringidos',
 'BORRADOR QA · REVISIÓN JURÍDICA OBLIGATORIA. No pueden ofrecerse productos ilegales, falsificados, robados, peligrosos o sujetos a restricciones incompatibles con el servicio. El vendedor debe cumplir normativa de consumo, seguridad de producto, etiquetado, propiedad intelectual, fiscalidad y restricciones de edad o comercialización aplicables. KOMBAX puede retirar fichas, conservar evidencia histórica y suspender la venta ante riesgo o incumplimiento. Las reseñas o archivos multimedia tampoco pueden utilizarse para promocionar productos prohibidos, fraude o contenido ilícito.',
 'seller',true,false,'active','pending',now())
on conflict(policy_code,version) do update set title=excluded.title,body=excluded.body,audience=excluded.audience,required_for_seller=excluded.required_for_seller,required_for_buyer=excluded.required_for_buyer,status=excluded.status,legal_review_status=excluded.legal_review_status,effective_at=excluded.effective_at,updated_at=now();

update kombax_commercial.event_contract_documents set status='retired',updated_at=now() where policy_code='events_ticketing_agreement' and status='active';
insert into kombax_commercial.event_contract_documents(policy_code,version,title,body,required_for_ticketing,status,legal_review_status,effective_at) values
 ('events_ticketing_agreement','1.3-r72-qa','Acuerdo de servicio · KOMBAX Events + Ticketing',
 'BORRADOR OPERATIVO QA · REVISIÓN JURÍDICA OBLIGATORIA. El organizador vende entradas en su nombre mediante su cuenta Stripe Connect y mantiene la responsabilidad material sobre celebración, cambios, cancelaciones, atención y devoluciones. KOMBAX presta checkout, ticket digital, QR y control de acceso según la activación contratada. La ficha del evento puede incluir una comunidad con comentarios, respuestas, fotografías, vídeos cortos y valoraciones. KOMBAX puede identificar como Asistió al evento a un usuario cuando exista una entrada KOMBAX válida con check-in registrado. El organizador puede responder a valoraciones y reportar contenido, pero no eliminar unilateralmente críticas legítimas de terceros; la moderación corresponde a KOMBAX. Quien aporta contenido debe disponer de derechos y autorizaciones suficientes, respetar privacidad, menores, propiedad intelectual y normas de comunidad. Los datos legales definitivos y tratamiento fiscal deberán validarse antes del lanzamiento público.',
 true,'active','pending',now())
on conflict(policy_code,version) do update set title=excluded.title,body=excluded.body,required_for_ticketing=true,status='active',legal_review_status=excluded.legal_review_status,effective_at=excluded.effective_at,updated_at=now();

notify pgrst,'reload schema';
commit;
