-- KOMBAX R72 / build 20123 live section 01
begin;
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
commit;
