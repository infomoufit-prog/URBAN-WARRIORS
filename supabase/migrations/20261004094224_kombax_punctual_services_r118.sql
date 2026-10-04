begin;
create table kombax_commercial.legacy_catalog_capacity_r118(provider_id uuid primary key references public.kombax_showcase_marcas(id),slots integer not null check(slots>=0));
alter table kombax_commercial.legacy_catalog_capacity_r118 enable row level security;
revoke all on kombax_commercial.legacy_catalog_capacity_r118 from public,anon,authenticated;
insert into kombax_commercial.legacy_catalog_capacity_r118(provider_id,slots)
select m.id,count(e.id)::integer from public.kombax_showcase_marcas m left join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado'
where m.sujeto_tipo<>'profesional' and kombax_commercial.active_plan_r64(case when m.sujeto_tipo='club' then 'club' else 'direct_profile' end,coalesce(m.club_id,m.perfil_directo_id)) is null group by m.id;
create or replace function kombax_commercial.verified_seller_subject_r118(p_type text,p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.kombax_showcase_marcas m where m.verificada and m.estado='publicada'
 and ((p_type='club' and m.club_id=p_id and m.sujeto_tipo='club' and exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_id and a.tipo='club' and a.estado='verified'))
 or (p_type='direct_profile' and m.perfil_directo_id=p_id and exists(select 1 from public.perfiles_kombax_directos d where d.id=p_id and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited'))))
 and kombax_marketplace.seller_ready_r627(m.id));
$$;
revoke all on function kombax_commercial.verified_seller_subject_r118(text,uuid) from public,anon,authenticated;


CREATE OR REPLACE FUNCTION public.app_kombax_showcase_ensure_direct_v113(p_perfil_directo_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;v_d public.perfiles_kombax_directos;v_needs_plan boolean;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v_d from public.perfiles_kombax_directos where id=p_perfil_directo_id;
  if v_d.id is null or v_d.tipo not in ('marca','media','federacion','competidor','profesional') or v_d.estado<>'activo' or v_d.verificacion_estado<>'verificado' or coalesce(v_d.workflow_estado,'verified') not in ('verified','limited') then raise exception 'SHOWCASE_VERIFIED_ACTIVE_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(v_d.id,'social') and not public.app_kombax_es_moderador_v041() then raise exception 'SHOWCASE_PROFILE_MANAGEMENT_REQUIRED'; end if;
  select id into v_id from public.kombax_showcase_marcas where perfil_directo_id=v_d.id;
  if v_id is null then
    insert into public.kombax_showcase_marcas(sujeto_tipo,perfil_directo_id,slug,nombre,descripcion,logo_url,banner_url,web_url,contacto_url,verificada,estado,creada_por)
    values(v_d.tipo,v_d.id,v_d.slug,v_d.nombre_publico,v_d.descripcion,null,null,v_d.web_publica,v_d.web_publica,true,'publicada',auth.uid()) returning id into v_id;
  else
    update public.kombax_showcase_marcas set sujeto_tipo=v_d.tipo,verificada=true,estado=case when estado='suspendida' then estado else 'publicada' end,actualizado_en=now() where id=v_id;
  end if;
  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_id,v_d.perfil_id,'responsable',auth.uid()) on conflict do nothing;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_showcase_ensure_club_v045(p_club_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_club public.clubes;
  v_pc public.perfiles_club_publicos;
  v_plan text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_club_id is null then raise exception 'SHOWCASE_CLUB_REQUIRED'; end if;
  if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then
    raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';
  end if;

  v_plan := kombax_commercial.active_plan_r64('club',p_club_id);
  if coalesce(v_plan,'') not in ('club','premium','enterprise','club_saas','club_pro') and not exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_club_id and a.tipo='club' and a.estado='verified') then
    raise exception 'SHOWCASE_PLAN_REQUIRED';
  end if;

  select m.id into v_id
  from public.kombax_showcase_marcas m
  where m.sujeto_tipo='club' and m.club_id=p_club_id
  limit 1;

  if v_id is null then
    select * into v_club from public.clubes where id=p_club_id and activo;
    if v_club.id is null then raise exception 'SHOWCASE_CLUB_NOT_FOUND'; end if;
    select * into v_pc from public.perfiles_club_publicos where club_id=p_club_id;

    insert into public.kombax_showcase_marcas(
      sujeto_tipo,club_id,slug,nombre,descripcion,logo_url,banner_url,web_url,verificada,estado,creada_por
    ) values(
      'club',p_club_id,'club-'||v_club.slug,
      coalesce(nullif(v_pc.nombre_publico,''),v_club.nombre),coalesce(v_pc.descripcion,v_club.lema),
      coalesce(v_pc.logo_url,v_club.logo_url),coalesce(v_pc.portada_url,v_club.portada_url),v_pc.web_publica,
      true,'publicada',v_uid
    )
    on conflict (club_id) where (sujeto_tipo='club' and club_id is not null)
    do update set actualizado_en=now()
    returning id into v_id;
  end if;

  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,activo,asignado_por)
  values(v_id,v_uid,'responsable',true,v_uid)
  on conflict(marca_id,perfil_id) do update
    set activo=true,
        rol=case when public.kombax_showcase_gestores.rol='responsable' then public.kombax_showcase_gestores.rol else 'responsable' end,
        asignado_por=excluded.asignado_por;

  if v_plan is not null then
  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por)
  values('club',p_club_id,'showcase.publish',true,'suscripcion',v_uid)
  on conflict do nothing;
  end if;

  return v_id;
end
$function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(id uuid, sujeto_tipo text, slug text, nombre text, descripcion text, logo_url text, banner_url text, web_url text, contacto_url text, verificada boolean, estado text, limite_visible integer, publicados integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  v_id uuid;
  v_plan text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  if p_club_id is not null then
    if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then
      raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';
    end if;
    v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
    if coalesce(v_plan,'') not in ('club','premium','enterprise','club_saas','club_pro') and not exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_club_id and a.tipo='club' and a.estado='verified') then
      raise exception 'SHOWCASE_PLAN_REQUIRED';
    end if;
    v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);
    return query
    select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
      nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
      (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
    from public.kombax_showcase_marcas m
    where m.id=v_id and m.sujeto_tipo='club' and m.club_id=p_club_id
      and public.app_kombax_showcase_puede_gestionar_v045(m.id);
    return;
  end if;

  for r in
    select d.id from public.perfiles_kombax_directos d
    where d.tipo in ('marca','media','federacion','competidor','profesional')
      and d.estado='activo' and d.verificacion_estado='verificado'
      and d.workflow_estado in ('verified','limited')
      and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')

  loop
    begin
      v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id);
    exception when sqlstate 'P0001' then
      if sqlerrm not in ('SHOWCASE_PLAN_CAPABILITY_REQUIRED','SHOWCASE_ACTIVE_SERVICE_REQUIRED') then raise; end if;
    end;
  end loop;

  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m
  where m.sujeto_tipo in ('marca','media','federacion','competidor','profesional')
    and public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'federacion' then 1 when 'marca' then 2 when 'media' then 3 when 'competidor' then 4 else 5 end,m.nombre;
end
$function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'kombax_commercial'
AS $function$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g join public.kombax_showcase_marcas gm on gm.id=g.marca_id where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo and (gm.sujeto_tipo<>'club' or (coalesce(kombax_commercial.active_plan_r64('club',gm.club_id),'') in('club','premium','enterprise','club_saas','club_pro') or exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=gm.club_id and a.tipo='club' and a.estado='verified'))))
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)) and (coalesce(kombax_commercial.active_plan_r64('club',m.club_id),'') in('club','premium','enterprise','club_saas','club_pro') or exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=m.club_id and a.tipo='club' and a.estado='verified')));
$function$
;

CREATE OR REPLACE FUNCTION kombax_commercial.provider_showcase_capacity_r72(p_provider_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 if v_plan is null and coalesce(v_direct_type,'club')<>'profesional' then select coalesce((select slots from kombax_commercial.legacy_catalog_capacity_r118 where provider_id=p_provider_id),0) into v_base;end if;
 if v_base is not null and v_base>=0 then
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
end $function$
;

CREATE OR REPLACE FUNCTION kombax_commercial.provider_commerce_allowed_r64(p_provider_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_provider public.kombax_showcase_marcas;v_plan text;v_subject_type text;v_subject_id uuid;
begin
  select * into v_provider from public.kombax_showcase_marcas where id=p_provider_id;
  if not found then return false; end if;
  if v_provider.sujeto_tipo='club' then v_subject_type:='club';v_subject_id:=v_provider.club_id; else v_subject_type:='direct_profile';v_subject_id:=v_provider.perfil_directo_id; end if;
  v_plan:=kombax_commercial.active_plan_r64(v_subject_type,v_subject_id);
  if v_plan in('premium','enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then return true; end if;
  if kombax_commercial.verified_seller_subject_r118(v_subject_type,v_subject_id) then return kombax_commercial.entitlement_active_r64(v_subject_type,v_subject_id,'SHOWCASE_COMMERCE',null); end if;
  return false;
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_commercial_activation_request_r64(p_subject_type text, p_subject_id uuid, p_entitlement_code text, p_scope_id uuid, p_days integer, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid();v_code text:=upper(trim(p_entitlement_code));v_id uuid;v_detail jsonb;v_plan text;
begin
 if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
 if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
 if v_code not in('SHOWCASE_COMMERCE','SHOWCASE_CATALOG_PLUS_25','EVENT_PUBLICATION','CONTENT_PROMOTION','EVENT_TICKETING') then raise exception 'COMMERCIAL_ENTITLEMENT_INVALID'; end if;
 if p_days is not null and p_days<=0 then raise exception 'COMMERCIAL_DURATION_INVALID'; end if;
 v_plan:=kombax_commercial.active_plan_r64(p_subject_type,p_subject_id);
 if v_code='SHOWCASE_COMMERCE' then
   if v_plan in('premium','enterprise','brand_start','brand_growth','brand_enterprise','club_saas','club_pro','marca_profesional') then raise exception 'SHOWCASE_COMMERCE_ALREADY_INCLUDED'; end if;
   if not kombax_commercial.verified_seller_subject_r118(p_subject_type,p_subject_id) then raise exception 'VERIFIED_SELLER_REQUIRED';end if;
   if p_days is distinct from 30 or p_scope_id is not null then raise exception 'COMMERCE_MONTHLY_ACTIVATION_REQUIRED';end if;
 elsif v_code='SHOWCASE_CATALOG_PLUS_25' then
   if v_plan in('enterprise','brand_enterprise','club_saas') then raise exception 'SHOWCASE_CATALOG_ALREADY_UNLIMITED'; end if;
   if coalesce(v_plan,'') not in('','club','premium','club_pro','brand_start','brand_growth','marca_profesional','federation','federation_partner','federacion_institucional') then raise exception 'SHOWCASE_CATALOG_EXPANSION_PLAN_REQUIRED';end if;
   if v_plan is null and not kombax_commercial.verified_seller_subject_r118(p_subject_type,p_subject_id) then raise exception 'VERIFIED_SELLER_REQUIRED';end if;
   if p_days is distinct from 30 or p_scope_id is not null then raise exception 'SHOWCASE_CATALOG_PLUS_25_MONTHLY_REQUIRED';end if;
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
 if exists(select 1 from kombax_commercial.entitlements_r64 e where e.request_id=p_request_id and (e.subject_type<>p_subject_type or e.subject_id<>p_subject_id or e.created_by<>v_uid or e.entitlement_code<>v_code)) then raise exception 'REQUEST_ID_CONFLICT';end if;
 v_detail:=jsonb_build_object('requested_days',p_days,'scope_id',p_scope_id,'payment_activation_performed',false,'plan_at_request',v_plan,
   'price_minor',case when v_code='SHOWCASE_CATALOG_PLUS_25' then 800 when v_code='SHOWCASE_COMMERCE' then 1200 else null end,
   'slots',case when v_code='SHOWCASE_CATALOG_PLUS_25' then 25 else null end);
 insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
 values(p_subject_type,p_subject_id,v_code,'requested',p_scope_id,p_request_id,v_detail,v_uid)
 on conflict(request_id) do update set updated_at=now() returning id into v_id;
 return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_commercial_admin_entitlement_decide_r642(p_entitlement_id uuid, p_decision text, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
   if not kombax_commercial.verified_seller_subject_r118(v_row.subject_type,v_row.subject_id) or v_days<>30 then raise exception 'VERIFIED_SELLER_REQUIRED';end if;v_price:=1200;
   select e.* into v_last from kombax_commercial.entitlements_r64 e where e.subject_type=v_row.subject_type and e.subject_id=v_row.subject_id and e.entitlement_code='SHOWCASE_COMMERCE' and e.id<>v_row.id and e.status='active' and e.ends_at>now() order by e.ends_at desc limit 1;
   if v_last.id is not null and v_last.ends_at>v_start then v_start:=v_last.ends_at; end if;
 elsif v_row.entitlement_code='SHOWCASE_CATALOG_PLUS_25' then
   if v_plan in('enterprise','brand_enterprise','club_saas') or coalesce(v_plan,'') not in('','club','premium','club_pro','brand_start','brand_growth','marca_profesional','federation','federation_partner','federacion_institucional') or v_days<>30 then raise exception 'SHOWCASE_CATALOG_EXPANSION_INVALID'; end if;
   if v_plan is null and not kombax_commercial.verified_seller_subject_r118(v_row.subject_type,v_row.subject_id) then raise exception 'VERIFIED_SELLER_REQUIRED';end if;
   v_price:=800;
 elsif v_row.entitlement_code='EVENT_PUBLICATION' then
   if v_row.scope_id is null or not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_row.scope_id) or v_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_INVALID'; end if;
 elsif v_row.entitlement_code='CONTENT_PROMOTION' then
   if v_row.scope_id is null or v_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_INVALID'; end if;
 else raise exception 'COMMERCIAL_ENTITLEMENT_USE_DEDICATED_FLOW'; end if;
 v_end:=v_start+make_interval(days=>v_days);
 update kombax_commercial.entitlements_r64 set status='active',starts_at=v_start,ends_at=v_end,
   detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'manual_activation',true,'billing_activation_performed',false,'activation_price_minor',v_price),updated_at=now() where id=v_row.id;
 return jsonb_build_object('ok',true,'status','active','entitlement_id',v_row.id,'starts_at',v_start,'ends_at',v_end,'activation_price_minor',v_price,'billing_activation_performed',false);
end $function$
;

alter function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) rename to app_kombax_eventos_sujeto_legacy_r118;
revoke all on function public.app_kombax_eventos_sujeto_legacy_r118(text,uuid) from public,anon,authenticated;
create function public.app_kombax_eventos_sujeto_puede_organizar_v160(p_sujeto_tipo text,p_sujeto_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then return false;end if;
 if p_sujeto_tipo='perfil_directo' then
  return exists(select 1 from public.perfiles_kombax_directos d where d.id=p_sujeto_id and d.perfil_id=auth.uid() and d.tipo in('profesional','competidor','marca','federacion') and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited'));
 end if;
 if public.app_kombax_eventos_sujeto_legacy_r118(p_sujeto_tipo,p_sujeto_id) then return true;end if;
 return p_sujeto_tipo='club' and exists(select 1 from public.miembros_club m where m.club_id=p_sujeto_id and m.perfil_id=auth.uid() and m.activo and (m.rol in('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)))
 and exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_sujeto_id and a.tipo='club' and a.estado='verified');
end $$;
revoke all on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) to authenticated;


CREATE OR REPLACE FUNCTION public.app_kombax_eventos_mis_organizadores_v160()
 RETURNS TABLE(social_profile_id uuid, sujeto_tipo text, sujeto_id uuid, perfil_tipo text, nombre_publico text, slug text, logo_url text, verificado boolean, puede_organizar boolean, motivo text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'kombax_commercial'
AS $function$
  select sp.id,case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end,public.app_kombax_social_tipo_v051(sp.id),sp.nombre_publico,sp.slug,public.app_kombax_social_avatar_url_v063(sp.id),sp.verificado,public.app_kombax_eventos_sujeto_puede_organizar_v160(case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end),case when sp.sujeto_tipo='club' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('club',sp.club_id) then 'Revisa Club, Premium o Enterprise y las activaciones de Events disponibles' when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='marca' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Revisa Brand Start, Growth o Enterprise y las activaciones de Events disponibles' when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='federacion' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Revisa Federation y sus capacidades de Events' when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='profesional' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Verifica tu identidad para preparar un borrador. Publicar y Ticketing requieren autorización puntual.' when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='competidor' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id) then 'Verifica tu identidad para preparar un borrador. Publicar y Ticketing requieren autorización puntual.' else '' end from public.kombax_social_perfiles sp left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id where auth.uid() is not null and sp.visible and sp.estado='activo' and sp.sujeto_tipo in('club','perfil_directo') and ((sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club m where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)))) or (sp.sujeto_tipo='perfil_directo' and d.perfil_id=auth.uid() and d.tipo in('federacion','marca','profesional','competidor') and d.estado='activo')) order by public.app_kombax_eventos_sujeto_puede_organizar_v160(case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end) desc,sp.nombre_publico;
$function$
;

commit;