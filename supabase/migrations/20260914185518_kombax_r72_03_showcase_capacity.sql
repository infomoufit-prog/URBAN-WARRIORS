-- KOMBAX R72 / build 20123 live section 03
begin;
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
commit;
