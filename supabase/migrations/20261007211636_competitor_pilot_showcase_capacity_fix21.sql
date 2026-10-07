-- Scoped to the five existing Owner-authorized pilot slots. No seller/payment gates changed.
begin;
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
 -- Owner-authorized five-profile pilot: catalog presentation only, never seller approval.
 if v_direct_type='competidor' and v_base is not null and exists(
   select 1 from kombax_pilot.competitor_grants g
   join public.perfiles_kombax_directos d on d.id=g.profile_id and d.perfil_id=g.account_id
   where g.profile_id=v_provider.perfil_directo_id and g.cohort_id='competitor-pilot-five-fix18'
     and d.tipo='competidor' and d.estado='activo' and d.verificacion_estado='verificado'
     and d.workflow_estado in ('verified','limited')
 ) then v_base:=greatest(v_base,15);end if;
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
commit;
