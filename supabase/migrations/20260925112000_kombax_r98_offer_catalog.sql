-- WORK phase 3: current offers are versioned separately from legacy contract prices.
begin;
create table if not exists kombax_commercial.products_r98(
 product_code text primary key,
 audience text not null check(audience in ('club','brand','federation')),
 display_name text not null,
 product_kind text not null check(product_kind in ('identity','subscription','activation','expansion')),
 legacy_plan_code text references kombax_commercial.plan_pricing_r64(plan_code),
 requestable boolean not null default false,
 active boolean not null default true,
 sort_order integer not null default 0,
 eligibility jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create table if not exists kombax_commercial.product_prices_r98(
 product_code text not null references kombax_commercial.products_r98(product_code),
 country_code text not null default 'ES',
 currency_code text not null default 'EUR',
 billing_cycle text not null default 'monthly' check(billing_cycle in ('monthly','annual','one_time')),
 cohort text not null default 'public',
 amount_minor integer check(amount_minor is null or amount_minor>=0),
 tax_mode text not null default 'exclusive' check(tax_mode in ('exclusive','inclusive','not_applicable')),
 is_starting_price boolean not null default false,
 published boolean not null default false,
 valid_from timestamptz not null default now(),
 primary key(product_code,country_code,currency_code,billing_cycle,cohort)
);
create table if not exists kombax_commercial.product_capabilities_r98(
 product_code text not null references kombax_commercial.products_r98(product_code),
 capability_key text not null references public.kombax_capacidades(clave),
 primary key(product_code,capability_key)
);
create table if not exists kombax_commercial.product_limits_r98(
 product_code text not null references kombax_commercial.products_r98(product_code),
 resource_key text not null,
 limit_value integer,
 primary key(product_code,resource_key)
);
alter table kombax_commercial.products_r98 enable row level security;
alter table kombax_commercial.product_prices_r98 enable row level security;
alter table kombax_commercial.product_capabilities_r98 enable row level security;
alter table kombax_commercial.product_limits_r98 enable row level security;
revoke all on kombax_commercial.products_r98,kombax_commercial.product_prices_r98,kombax_commercial.product_capabilities_r98,kombax_commercial.product_limits_r98 from public,anon,authenticated;
grant all on kombax_commercial.products_r98,kombax_commercial.product_prices_r98,kombax_commercial.product_capabilities_r98,kombax_commercial.product_limits_r98 to service_role;

insert into kombax_commercial.products_r98(product_code,audience,display_name,product_kind,legacy_plan_code,requestable,sort_order) values
 ('club_profile','club','Perfil Club','identity',null,false,0),
 ('club','club','KOMBAX Club','subscription','club',false,10),
 ('premium','club','KOMBAX Premium','subscription','premium',false,20),
 ('multiclub','club','KOMBAX MultiClub','subscription',null,false,30),
 ('enterprise','club','KOMBAX Enterprise','subscription','enterprise',false,40),
 ('brand_profile','brand','Perfil Marca','identity',null,false,0),
 ('brand_plan','brand','Plan Marca','subscription',null,false,10),
 ('federation_profile','federation','Perfil Federación','identity',null,false,0),
 ('federation_plan','federation','Plan Federación','subscription',null,false,10)
on conflict(product_code) do update set display_name=excluded.display_name,requestable=excluded.requestable,active=true,sort_order=excluded.sort_order;

insert into kombax_commercial.product_prices_r98(product_code,country_code,currency_code,billing_cycle,cohort,amount_minor,tax_mode,is_starting_price,published) values
 ('club_profile','ES','EUR','monthly','public',0,'not_applicable',false,true),
 ('club','ES','EUR','monthly','public',2390,'exclusive',false,true),
 ('premium','ES','EUR','monthly','public',3790,'exclusive',false,true),
 ('multiclub','ES','EUR','monthly','public',2990,'exclusive',true,true),
 ('enterprise','ES','EUR','monthly','public',null,'exclusive',false,false),
 ('brand_profile','ES','EUR','monthly','public',0,'not_applicable',false,true),
 ('brand_plan','ES','EUR','monthly','public',null,'exclusive',false,false),
 ('federation_profile','ES','EUR','monthly','public',0,'not_applicable',false,true),
 ('federation_plan','ES','EUR','monthly','public',null,'exclusive',false,false)
on conflict(product_code,country_code,currency_code,billing_cycle,cohort) do update set amount_minor=excluded.amount_minor,tax_mode=excluded.tax_mode,is_starting_price=excluded.is_starting_price,published=excluded.published;

insert into kombax_commercial.product_capabilities_r98(product_code,capability_key)
select p.product_code,pc.capacidad_clave from kombax_commercial.products_r98 p
join public.kombax_plan_capacidades pc on pc.plan_codigo=p.legacy_plan_code
join public.kombax_capacidades c on c.clave=pc.capacidad_clave
where p.product_code in ('club','premium','enterprise')
on conflict do nothing;
insert into kombax_commercial.product_limits_r98(product_code,resource_key,limit_value)
select p.product_code,l.recurso,l.limite from kombax_commercial.products_r98 p
join public.kombax_plan_limites l on l.plan_codigo=p.legacy_plan_code
where p.product_code in ('club','premium','enterprise')
on conflict(product_code,resource_key) do update set limit_value=excluded.limit_value;

create or replace function public.app_kombax_offer_catalog_r98(p_audience text default null,p_country text default 'ES')
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('version','work-r98','country',upper(coalesce(p_country,'ES')),
  'offers',coalesce(jsonb_agg(jsonb_build_object(
   'product_code',p.product_code,'audience',p.audience,'name',p.display_name,'kind',p.product_kind,
   'legacy_plan_code',p.legacy_plan_code,'requestable',p.requestable,'price_minor',pr.amount_minor,
   'currency',pr.currency_code,'tax_mode',pr.tax_mode,'starting_price',pr.is_starting_price,
   'price_published',pr.published,'billing_cycle',pr.billing_cycle,
   'capabilities',(select coalesce(jsonb_agg(pc.capability_key),'[]'::jsonb) from kombax_commercial.product_capabilities_r98 pc where pc.product_code=p.product_code),
   'limits',(select coalesce(jsonb_object_agg(l.resource_key,l.limit_value),'{}'::jsonb) from kombax_commercial.product_limits_r98 l where l.product_code=p.product_code)
  ) order by p.sort_order),'[]'::jsonb))
 from kombax_commercial.products_r98 p left join kombax_commercial.product_prices_r98 pr
  on pr.product_code=p.product_code and pr.country_code=upper(coalesce(p_country,'ES')) and pr.currency_code='EUR' and pr.billing_cycle='monthly' and pr.cohort='public'
 where p.active and (p_audience is null or p.audience=lower(p_audience));
$$;
revoke all on function public.app_kombax_offer_catalog_r98(text,text) from public;
grant execute on function public.app_kombax_offer_catalog_r98(text,text) to anon,authenticated,service_role;
commit;
