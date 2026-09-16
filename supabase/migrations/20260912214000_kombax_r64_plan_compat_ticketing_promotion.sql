-- KOMBAX 20.112 R64 · compatibility bridge for plan capabilities, Ticketing status and single promotion requests.
-- Additive only: preserves historical plan identifiers and service_access workflows.
begin;

-- ---------------------------------------------------------------------------
-- 1) New Brand/Federation plan codes inherit the already-audited legacy
--    capability sets. Commercial limits are then overridden explicitly.
-- ---------------------------------------------------------------------------
insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select n.plan_code,pc.capacidad_clave
from (values
  ('brand_start','marca_profesional'),
  ('brand_growth','marca_profesional'),
  ('brand_enterprise','marca_profesional'),
  ('federation','federacion_institucional'),
  ('federation_partner','federacion_institucional')
) n(plan_code,template_code)
join public.kombax_plan_capacidades pc on pc.plan_codigo=n.template_code
where not (n.plan_code in('federation','federation_partner') and pc.capacidad_clave='showcase.publish')
on conflict do nothing;

insert into public.kombax_plan_limites(plan_codigo,recurso,limite)
select n.plan_code,l.recurso,l.limite
from (values
  ('brand_start','marca_profesional'),
  ('brand_growth','marca_profesional'),
  ('brand_enterprise','marca_profesional'),
  ('federation','federacion_institucional'),
  ('federation_partner','federacion_institucional')
) n(plan_code,template_code)
join public.kombax_plan_limites l on l.plan_codigo=n.template_code
where not (n.plan_code in('federation','federation_partner') and l.recurso='showcase.items')
on conflict(plan_codigo,recurso) do update set limite=excluded.limite;

-- Current commercial Showcase limits. 10,000 is the technical sentinel for
-- "unlimited" in the legacy integer limit table; commercial UI remains unlimited.
insert into public.kombax_plan_limites(plan_codigo,recurso,limite) values
  ('brand_start','showcase.items',25),
  ('brand_growth','showcase.items',100),
  ('brand_enterprise','showcase.items',10000)
on conflict(plan_codigo,recurso) do update set limite=excluded.limite;

-- Reconcile only existing active direct-profile subscriptions using the new
-- plan codes. This never creates or activates a subscription.
do $$
declare r record;
begin
  for r in
    select distinct s.sujeto_id
    from public.kombax_suscripciones s
    where s.sujeto_tipo='perfil_directo'
      and s.modalidad in('brand_start','brand_growth','brand_enterprise','federation','federation_partner')
      and s.estado in('prueba','activa','pausada')
  loop
    perform public.app_kombax_reconcile_entitlements_v071(r.sujeto_id,null);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Commercial Ticketing status reflects the R64 per-ticket fee and plans
--    where Ticketing is permanently included, while preserving the existing
--    service_access review queue for punctual activation.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_event_commercial_status_r628(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();
  v_access kombax_commercial.service_access;
  v_seller jsonb;
  v_contracts jsonb;
  v_account kombax_payments.connected_accounts;
  v_plan text;
  v_plan_row kombax_commercial.plan_pricing_r64;
  v_active boolean:=false;
  v_included boolean:=false;
  v_status text;
  v_fee_minor integer:=150;
begin
  if v_uid is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into v_access from kombax_commercial.service_access where subject_type='event' and subject_id=p_event_id and service_code='events_ticketing';
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  select * into v_plan_row from kombax_commercial.plan_pricing_r64 p where p.plan_code=v_plan and p.active;
  v_included:=v_plan in('enterprise','brand_enterprise');
  v_active:=kombax_commercial.event_ticketing_active_r628(p_event_id);
  v_status:=case when v_active then 'active' else coalesce(v_access.status,'not_requested') end;
  select coalesce((value#>>'{}')::integer,150) into v_fee_minor from kombax_commercial.runtime_config_r64 where config_key='ticketing_buyer_fee_minor';
  v_fee_minor:=coalesce(v_fee_minor,150);
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=v_seller->>'subject_type' and a.subject_id=(v_seller->>'subject_id')::uuid;
  select coalesce(jsonb_agg(jsonb_build_object(
      'code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,'legal_review_status',p.legal_review_status,
      'accepted',exists(select 1 from kombax_commercial.event_contract_acceptances a where a.event_id=p_event_id and a.organizer_subject_type=v_seller->>'subject_type' and a.organizer_subject_id=(v_seller->>'subject_id')::uuid and a.policy_code=p.policy_code and a.policy_version=p.version)
    ) order by p.policy_code),'[]'::jsonb)
    into v_contracts from kombax_commercial.event_contract_documents p where p.status='active' and p.required_for_ticketing;
  return jsonb_build_object(
    'events_publish',jsonb_build_object('status','active','service_class','core','pricing_status','included'),
    'events_ticketing',jsonb_build_object(
      'status',v_status,'service_class','addon','pricing_status','per_ticket',
      'buyer_fee_minor',v_fee_minor,'buyer_fee_payer','buyer','included_by_plan',v_included,
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

-- Enterprise/Brand Enterprise must not be sent into the punctual Owner queue.
create or replace function public.app_kombax_event_ticketing_service_request_r628(p_event_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v public.kombax_eventos_publicos;a kombax_commercial.service_access;v_old text;v_seller jsonb;v_plan text;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select * into strict v from public.kombax_eventos_publicos where id=p_event_id;
  v_seller:=kombax_payments.event_seller_r625(p_event_id);
  v_plan:=kombax_commercial.seller_plan_r64(v_seller->>'subject_type',(v_seller->>'subject_id')::uuid);
  if v_plan in('enterprise','brand_enterprise') then
    return jsonb_build_object('ok',true,'request_id',p_request_id,'reused',true,'included_by_plan',true,'status','active','plan_code',v_plan);
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
    return jsonb_build_object('ok',true,'request_id',p_request_id,'reused',true,'data',to_jsonb(a));
  end if;
  insert into kombax_commercial.service_events(service_access_id,actor_user_id,event_type,from_status,to_status,request_id,detail)
  values(a.id,v_uid,'ticketing.request',v_old,a.status,p_request_id,jsonb_build_object('event_id',p_event_id,'pricing_model','buyer_fee_per_ticket','buyer_fee_minor',150));
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',to_jsonb(a));
end $$;
revoke all on function public.app_kombax_event_ticketing_service_request_r628(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_service_request_r628(uuid,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) One scoped promotion request API for both Events and Showcase.
--    It records a request only; no payment/activation is fabricated.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_content_promotion_request_r64(
  p_content_type text,p_content_id uuid,p_days integer,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid();v_type text:=lower(trim(coalesce(p_content_type,'')));v_subject_type text;v_subject_id uuid;v_id uuid;v_item public.kombax_showcase_elementos;
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if p_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_DURATION_INVALID'; end if;
  if v_type='event' then
    if not public.app_kombax_evento_puede_gestionar_v160(p_content_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
    v_subject_type:='event';v_subject_id:=p_content_id;
  elsif v_type='showcase_product' then
    select * into strict v_item from public.kombax_showcase_elementos where id=p_content_id;
    if not kombax_payments.can_manage_provider(v_uid,v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    if v_item.estado<>'publicado' then raise exception 'SHOWCASE_PROMOTION_REQUIRES_PUBLISHED_ITEM'; end if;
    v_subject_type:='showcase_provider';v_subject_id:=v_item.marca_id;
  else
    raise exception 'CONTENT_PROMOTION_TYPE_INVALID';
  end if;
  insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
  values(v_subject_type,v_subject_id,'CONTENT_PROMOTION','requested',p_content_id,p_request_id,
    jsonb_build_object('content_type',v_type,'content_id',p_content_id,'requested_days',p_days,'payment_activation_performed',false,'social_amplification',true),v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $$;
revoke all on function public.app_kombax_content_promotion_request_r64(text,uuid,integer,uuid) from public,anon;
grant execute on function public.app_kombax_content_promotion_request_r64(text,uuid,integer,uuid) to authenticated;

-- If a future billing/admin workflow marks a requested promotion active, create
-- the serving campaign automatically. Requested rows never become campaigns.
create or replace function kombax_commercial.sync_promotion_campaign_r64()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_type text;v_days integer;v_start timestamptz;v_end timestamptz;
begin
  if new.entitlement_code<>'CONTENT_PROMOTION' then return new; end if;
  if new.status='active' then
    v_type:=coalesce(nullif(new.detail->>'content_type',''),case when new.subject_type='event' then 'event' else 'showcase_product' end);
    v_days:=coalesce(nullif(new.detail->>'requested_days','')::integer,7);
    v_start:=coalesce(new.starts_at,now());v_end:=coalesce(new.ends_at,v_start+make_interval(days=>v_days));
    new.starts_at:=v_start;new.ends_at:=v_end;
    insert into kombax_commercial.promotion_campaigns_r64(entitlement_id,content_type,content_id,social_distribution,status,starts_at,ends_at)
    values(new.id,v_type,coalesce(new.scope_id,new.subject_id),true,'active',v_start,v_end)
    on conflict(entitlement_id) do update set content_type=excluded.content_type,content_id=excluded.content_id,social_distribution=true,status='active',starts_at=excluded.starts_at,ends_at=excluded.ends_at;
  elsif old.status='active' and new.status in('expired','cancelled','rejected') then
    update kombax_commercial.promotion_campaigns_r64 set status=case when new.status='expired' then 'ended' else 'cancelled' end where entitlement_id=new.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_sync_promotion_campaign_r64 on kombax_commercial.entitlements_r64;
create trigger trg_sync_promotion_campaign_r64 before update of status,starts_at,ends_at on kombax_commercial.entitlements_r64
for each row execute function kombax_commercial.sync_promotion_campaign_r64();

-- Showcase public feed: active R64 promotion is resolved dynamically, so expiry
-- cannot leave a stale highlighted flag. Historical moderator highlights remain valid.
create or replace function public.app_kombax_showcase_list_v054(
  p_query text default '',p_categoria text default null,p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 24
)
returns table(
  id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,precio_orientativo numeric,moneda text,
  visitar_url text,donde_encontrar_url text,contacto_url text,destacado boolean,etiqueta_destacada text,publicado_en timestamptz,
  marca_id uuid,marca_slug text,marca_nombre text,marca_logo_url text,marca_verificada boolean,categoria_slug text,categoria_nombre text,
  cta_tipo text,cta_label text,guardado boolean,proveedor_social_id uuid,sujeto_tipo text
)
language sql stable security definer set search_path='' as $$
  select e.id,e.slug,e.nombre,e.resumen,e.descripcion,e.imagen_url,e.galeria,e.precio_orientativo,e.moneda,
    e.visitar_url,e.donde_encontrar_url,e.contacto_url,(e.destacado or coalesce(pr.active,false)),
    case when coalesce(pr.active,false) then 'Destacado KOMBAX' else e.etiqueta_destacada end,e.publicado_en,
    m.id,m.slug,m.nombre,m.logo_url,m.verificada,c.slug,c.nombre,e.cta_tipo,e.cta_label,
    case when auth.uid() is null then false else exists(select 1 from public.kombax_showcase_guardados g where g.perfil_id=auth.uid() and g.elemento_id=e.id) end,
    case when m.sujeto_tipo='club' then (select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='club' and sp.club_id=m.club_id and sp.estado='activo' limit 1)
         else (select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=m.perfil_directo_id and sp.estado='activo' limit 1) end,
    m.sujeto_tipo
  from public.kombax_showcase_elementos e
  join public.kombax_showcase_marcas m on m.id=e.marca_id and m.estado='publicada'
  left join public.kombax_showcase_categorias c on c.id=e.categoria_id
  left join lateral (
    select true as active from kombax_commercial.promotion_campaigns_r64 pc
    where pc.content_type='showcase_product' and pc.content_id=e.id and pc.status='active' and pc.starts_at<=now() and pc.ends_at>now()
    limit 1
  ) pr on true
  where e.estado='publicado'
    and (nullif(btrim(coalesce(p_query,'')),'') is null or e.nombre ilike '%'||btrim(p_query)||'%' or coalesce(e.resumen,'') ilike '%'||btrim(p_query)||'%' or m.nombre ilike '%'||btrim(p_query)||'%')
    and (p_categoria is null or c.slug=p_categoria)
    and (p_cursor is null or e.publicado_en<p_cursor or (e.publicado_en=p_cursor and e.id<p_cursor_id))
  order by (e.destacado or coalesce(pr.active,false)) desc,e.publicado_en desc,e.id desc
  limit least(greatest(coalesce(p_limit,24),1),24);
$$;
revoke all on function public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer) from public;
grant execute on function public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer) to anon,authenticated;

-- Public Events promoted placement. This is read-only and does not consume a Social impression.
create or replace function public.app_kombax_promoted_events_r64(p_limit integer default 6)
returns setof public.kombax_eventos_publicos
language sql stable security definer set search_path='' as $$
  select e.*
  from kombax_commercial.promotion_campaigns_r64 c
  join public.kombax_eventos_publicos e on e.id=c.content_id
  where c.content_type='event' and c.status='active' and c.starts_at<=now() and c.ends_at>now()
    and e.visibilidad='publico'
    and e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
  order by c.starts_at desc,e.fecha_inicio asc nulls last,e.id
  limit least(12,greatest(1,coalesce(p_limit,6)));
$$;
revoke all on function public.app_kombax_promoted_events_r64(integer) from public;
grant execute on function public.app_kombax_promoted_events_r64(integer) to anon,authenticated;

-- Social amplification: at most two eligible promotion cards are offered. The
-- serving helper enforces event/day and same-content/72h caps. UI interleaving
-- guarantees promoted cards are never consecutive.
alter table kombax_commercial.promotion_impressions_r64 add column if not exists request_id uuid;
create unique index if not exists uq_promo_impression_request_r64 on kombax_commercial.promotion_impressions_r64(request_id) where request_id is not null;

create or replace function public.app_kombax_social_promotions_r64(p_limit integer default 2)
returns table(
  campaign_id uuid,content_type text,content_id uuid,title text,subtitle text,image_url text,target_slug text,label text
) language sql stable security definer set search_path='' as $$
  with eligible as (
    select c.*
    from kombax_commercial.promotion_campaigns_r64 c
    where auth.uid() is not null and c.social_distribution and c.status='active'
      and c.starts_at<=now() and c.ends_at>now()
      and kombax_commercial.promotion_can_serve_r64(c.id,auth.uid())
    order by c.starts_at desc,c.id
    limit least(2,greatest(1,coalesce(p_limit,2)))
  )
  select c.id,'event'::text,e.id,e.nombre,
         nullif(concat_ws(' · ',nullif(e.organizador_nombre,''),nullif(e.municipio,'')),''),
         coalesce(e.cartel_url,e.banner_url),e.slug,'EVENTO DESTACADO'::text
  from eligible c join public.kombax_eventos_publicos e on e.id=c.content_id
  where c.content_type='event' and e.visibilidad='publico'
    and e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
  union all
  select c.id,'showcase_product'::text,i.id,i.nombre,
         nullif(concat_ws(' · ',m.nombre,nullif(i.resumen,'')),''),
         i.imagen_url,i.slug,'SHOWCASE DESTACADO'::text
  from eligible c
  join public.kombax_showcase_elementos i on i.id=c.content_id
  join public.kombax_showcase_marcas m on m.id=i.marca_id
  where c.content_type='showcase_product' and i.estado='publicado' and m.estado='publicada';
$$;
revoke all on function public.app_kombax_social_promotions_r64(integer) from public,anon;
grant execute on function public.app_kombax_social_promotions_r64(integer) to authenticated;

create or replace function public.app_kombax_social_promotion_impression_r64(p_campaign_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_inserted bigint;
begin
  if v_uid is null or p_campaign_id is null or p_request_id is null then raise exception 'PROMOTION_IMPRESSION_AUTH_REQUIRED'; end if;
  if not kombax_commercial.promotion_can_serve_r64(p_campaign_id,v_uid) then
    return jsonb_build_object('ok',false,'served',false,'reason','frequency_cap');
  end if;
  insert into kombax_commercial.promotion_impressions_r64(campaign_id,viewer_user_id,request_id)
  values(p_campaign_id,v_uid,p_request_id)
  on conflict(request_id) do nothing returning id into v_inserted;
  return jsonb_build_object('ok',true,'served',v_inserted is not null,'campaign_id',p_campaign_id);
end $$;
revoke all on function public.app_kombax_social_promotion_impression_r64(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_social_promotion_impression_r64(uuid,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
