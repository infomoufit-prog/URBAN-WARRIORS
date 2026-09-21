-- KOMBAX 20.113 R64.2 · Club onboarding + Urban Warriors Premium + commercial request governance
-- Additive migration. No external billing/deploy is performed here.
begin;

-- ---------------------------------------------------------------------------
-- 1) Club applications must carry a compatible plan before submission.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_club_plan_application_guard_r642()
returns trigger
language plpgsql
security definer
set search_path=public,auth,kombax_commercial
as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
begin
  if new.tipo<>'club' then return new; end if;
  if v_plan<>'' and v_plan not in('club','premium','enterprise') then raise exception 'KOMBAX_CLUB_PLAN_INVALID'; end if;
  if v_cycle not in('monthly','annual') then raise exception 'KOMBAX_CLUB_BILLING_CYCLE_INVALID'; end if;
  if new.estado in('submitted','under_review','verified','limited') and v_plan='' then raise exception 'KOMBAX_CLUB_PLAN_REQUIRED'; end if;
  if v_plan<>'' then
    new.datos_verificacion:=jsonb_set(coalesce(new.datos_verificacion,'{}'::jsonb),'{plan_codigo}',to_jsonb(v_plan),true);
    new.datos_verificacion:=jsonb_set(new.datos_verificacion,'{billing_cycle}',to_jsonb(v_cycle),true);
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_club_plan_application_guard_r642() from public,anon,authenticated;

drop trigger if exists trg_kombax_club_plan_application_guard_r642 on public.kombax_solicitudes_alta;
create trigger trg_kombax_club_plan_application_guard_r642
before insert or update of datos_verificacion,estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_club_plan_application_guard_r642();

-- After verification/provision, preserve the selected plan as an auditable commercial request.
create or replace function public.app_kombax_club_plan_request_after_verify_r642()
returns trigger
language plpgsql
security definer
set search_path=public,auth,kombax_commercial
as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
  v_founder_open boolean:=false;
  v_founder boolean:=false;
begin
  if new.tipo<>'club' or new.estado<>'verified' or old.estado='verified' or new.club_id is null then return new; end if;
  if v_plan not in('club','premium','enterprise') then return new; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open
  from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  v_founder:=coalesce(v_founder_open,false);

  insert into kombax_commercial.plan_requests_r64(
    subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by,detail
  )
  select 'club',new.club_id,v_plan,v_cycle,v_founder,gen_random_uuid(),new.perfil_id,
    jsonb_build_object('source','club_application','application_id',new.id,'billing_activation_performed',false)
  where not exists(
    select 1 from kombax_commercial.plan_requests_r64 r
    where r.subject_type='club' and r.subject_id=new.club_id
      and coalesce(r.detail->>'application_id','')=new.id::text
  );

  insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,updated_at)
  values('club',new.club_id,v_plan,v_cycle,false,null,now())
  on conflict(subject_type,subject_id) do update set
    plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,updated_at=now();
  return new;
end $$;
revoke all on function public.app_kombax_club_plan_request_after_verify_r642() from public,anon,authenticated;

drop trigger if exists trg_kombax_club_plan_request_after_verify_r642 on public.kombax_solicitudes_alta;
create trigger trg_kombax_club_plan_request_after_verify_r642
after update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_club_plan_request_after_verify_r642();

-- ---------------------------------------------------------------------------
-- 2) Showcase availability follows the commercial plan for Clubs.
-- Premium: 15 models. Enterprise: unlimited. Base Club: no permanent Showcase.
-- Legacy club_saas/club_pro stay compatible with 15 models.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_ensure_club_v045(p_club_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare v_id uuid;v_club public.clubes;v_pc public.perfiles_club_publicos;v_plan text;
begin
  if auth.uid() is null or not exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))) then raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';end if;
  v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
  if coalesce(v_plan,'') not in('premium','enterprise','club_saas','club_pro') then raise exception 'SHOWCASE_PLAN_REQUIRED'; end if;
  select id into v_id from public.kombax_showcase_marcas where sujeto_tipo='club' and club_id=p_club_id;if v_id is not null then return v_id;end if;
  select * into v_club from public.clubes where id=p_club_id and activo;if v_club.id is null then raise exception 'SHOWCASE_CLUB_NOT_FOUND';end if;
  select * into v_pc from public.perfiles_club_publicos where club_id=p_club_id;
  insert into public.kombax_showcase_marcas(sujeto_tipo,club_id,slug,nombre,descripcion,logo_url,banner_url,web_url,verificada,estado,creada_por)
  values('club',p_club_id,'club-'||v_club.slug,coalesce(nullif(v_pc.nombre_publico,''),v_club.nombre),coalesce(v_pc.descripcion,v_club.lema),coalesce(v_pc.logo_url,v_club.logo_url),coalesce(v_pc.portada_url,v_club.portada_url),v_pc.web_publica,true,'publicada',auth.uid()) returning id into v_id;
  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_id,auth.uid(),'responsable',auth.uid()) on conflict do nothing;
  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values('club',p_club_id,'showcase.publish',true,'suscripcion',auth.uid()) on conflict do nothing;
  return v_id;
end $$;
revoke all on function public.app_kombax_showcase_ensure_club_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_club_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth,kombax_commercial as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g join public.kombax_showcase_marcas gm on gm.id=g.marca_id where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo and (gm.sujeto_tipo<>'club' or coalesce(kombax_commercial.active_plan_r64('club',gm.club_id),'') in('premium','enterprise','club_saas','club_pro')))
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)) and coalesce(kombax_commercial.active_plan_r64('club',m.club_id),'') in('premium','enterprise','club_saas','club_pro'));
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
    if coalesce(v_plan,'') in('premium','enterprise','club_saas','club_pro') then v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id); end if;
  end if;
  for r in select d.id from public.perfiles_kombax_directos d where d.tipo in ('marca','federacion','competidor') and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social') and public.app_kombax_perfil_servicio_activo_v071(d.id)
  loop
    begin v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id); exception when sqlstate 'P0001' then if sqlerrm<>'SHOWCASE_PLAN_CAPABILITY_REQUIRED' then raise;end if; end;
  end loop;
  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    case when m.sujeto_tipo='club' then case when kombax_commercial.active_plan_r64('club',m.club_id)='enterprise' then 10000 else 15 end
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
      if coalesce(v_plan,'') not in('premium','enterprise','club_saas','club_pro') then raise exception 'SHOWCASE_PLAN_REQUIRED'; end if;
      if v_plan='enterprise' then v_limit:=null; else v_limit:=15; end if;
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
-- 3) Owner queue: every plan/activation request is visible and plan activation
-- can be completed manually after billing/contract confirmation.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_commercial_owner_requests_r642(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path=public,auth,kombax_commercial as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  return jsonb_build_object(
    'ok',true,
    'plan_requests',coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'subject_type',r.subject_type,'subject_id',r.subject_id,'subject_name',case when r.subject_type='club' then (select c.nombre from public.clubes c where c.id=r.subject_id) else (select d.nombre_publico from public.perfiles_kombax_directos d where d.id=r.subject_id) end,
      'plan_code',r.requested_plan_code,'plan_name',p.display_name,'billing_cycle',r.billing_cycle,'founder_requested',r.founder_requested,'status',r.status,'detail',r.detail,'created_at',r.created_at
    ) order by r.created_at desc) from (select * from kombax_commercial.plan_requests_r64 where status in('requested','under_review') order by created_at desc limit greatest(1,least(coalesce(p_limit,100),200))) r join kombax_commercial.plan_pricing_r64 p on p.plan_code=r.requested_plan_code),'[]'::jsonb),
    'activation_requests',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'subject_type',e.subject_type,'subject_id',e.subject_id,'entitlement_code',e.entitlement_code,'status',e.status,'scope_id',e.scope_id,'detail',e.detail,'created_at',e.created_at) order by e.created_at desc) from (select * from kombax_commercial.entitlements_r64 where status in('requested','pending_payment') order by created_at desc limit greatest(1,least(coalesce(p_limit,100),200))) e),'[]'::jsonb)
  );
end $$;
revoke all on function public.app_kombax_commercial_owner_requests_r642(integer) from public,anon;
grant execute on function public.app_kombax_commercial_owner_requests_r642(integer) to authenticated;

create or replace function public.app_kombax_commercial_admin_activate_plan_r642(p_plan_request_id uuid,p_note text default '')
returns jsonb language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare r kombax_commercial.plan_requests_r64;v_terms kombax_commercial.organization_terms_r64;v_founder boolean:=false;v_subject_type text;v_sub_id uuid;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select * into r from kombax_commercial.plan_requests_r64 where id=p_plan_request_id for update;
  if not found or r.status not in('requested','under_review') then raise exception 'COMMERCIAL_PLAN_REQUEST_NOT_ACTIONABLE'; end if;
  v_subject_type:=case when r.subject_type='direct_profile' then 'perfil_directo' else r.subject_type end;
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=r.subject_type and subject_id=r.subject_id;
  v_founder:=coalesce(r.founder_requested,false) and v_terms.founder_lost_at is null;

  update public.kombax_suscripciones set estado='cancelada',termina_en=coalesce(termina_en,now()),actualizado_en=now()
  where sujeto_tipo=v_subject_type and sujeto_id=r.subject_id and estado in('prueba','activa','pausada');
  insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en)
  values(v_subject_type,r.subject_id,'activa',r.requested_plan_code,'kombax_manual_admin','plan-request:'||r.id::text,now()) returning id into v_sub_id;

  insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,founder_lost_at,updated_at)
  values(r.subject_type,r.subject_id,r.requested_plan_code,r.billing_cycle,v_founder,case when v_founder then now() else null end,v_terms.founder_lost_at,now())
  on conflict(subject_type,subject_id) do update set plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,founder_locked=excluded.founder_locked,founder_continuous_since=case when excluded.founder_locked then coalesce(kombax_commercial.organization_terms_r64.founder_continuous_since,excluded.founder_continuous_since) else kombax_commercial.organization_terms_r64.founder_continuous_since end,updated_at=now();

  update kombax_commercial.plan_requests_r64 set status='approved',detail=coalesce(detail,'{}'::jsonb)||jsonb_build_object('review_note',left(coalesce(p_note,''),1000),'activated_by',auth.uid(),'activated_at',now(),'billing_activation_performed',false,'manual_activation',true),updated_at=now() where id=r.id;
  return jsonb_build_object('ok',true,'plan_request_id',r.id,'subscription_id',v_sub_id,'plan_code',r.requested_plan_code,'founder_locked',v_founder);
end $$;
revoke all on function public.app_kombax_commercial_admin_activate_plan_r642(uuid,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_activate_plan_r642(uuid,text) to authenticated;

create or replace function public.app_kombax_commercial_admin_reject_plan_r642(p_plan_request_id uuid,p_note text default '')
returns jsonb language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  update kombax_commercial.plan_requests_r64 set status='rejected',detail=coalesce(detail,'{}'::jsonb)||jsonb_build_object('review_note',left(coalesce(p_note,''),1000),'reviewed_by',auth.uid(),'reviewed_at',now()),updated_at=now()
  where id=p_plan_request_id and status in('requested','under_review');
  if not found then raise exception 'COMMERCIAL_PLAN_REQUEST_NOT_ACTIONABLE'; end if;
  return jsonb_build_object('ok',true,'plan_request_id',p_plan_request_id,'status','rejected');
end $$;
revoke all on function public.app_kombax_commercial_admin_reject_plan_r642(uuid,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_reject_plan_r642(uuid,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Urban Warriors pilot: Premium active, Showcase Display enabled, no Commerce.
-- Resolve the pilot Club by stable slug; do not hardcode a generated database UUID.
-- ---------------------------------------------------------------------------
do $$
declare v_urban uuid;v_open uuid;
begin
  select c.id into v_urban
  from public.clubes c
  where lower(trim(c.slug))='urban-warriors'
  order by c.creado_en asc nulls last,c.id
  limit 1;
  if v_urban is not null then
    select id into v_open from public.kombax_suscripciones where sujeto_tipo='club' and sujeto_id=v_urban and estado in('prueba','activa','pausada') order by actualizado_en desc limit 1;
    if v_open is null then
      insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en)
      values('club',v_urban,'activa','premium','kombax_pilot_r642','urban-warriors-premium',now());
    else
      update public.kombax_suscripciones set estado='activa',modalidad='premium',proveedor='kombax_pilot_r642',referencia_externa='urban-warriors-premium',inicia_en=coalesce(inicia_en,now()),termina_en=null,actualizado_en=now() where id=v_open;
    end if;
    insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,updated_at)
    values('club',v_urban,'premium','monthly',true,now(),now())
    on conflict(subject_type,subject_id) do update set plan_code='premium',billing_cycle='monthly',founder_locked=true,founder_continuous_since=coalesce(kombax_commercial.organization_terms_r64.founder_continuous_since,now()),founder_lost_at=null,updated_at=now();
    update kombax_commercial.entitlements_r64 set status='cancelled',updated_at=now(),detail=coalesce(detail,'{}'::jsonb)||'{"cancel_reason":"Urban Premium pilot: Commerce not enabled"}'::jsonb
    where subject_type='club' and subject_id=v_urban and entitlement_code='SHOWCASE_COMMERCE' and status in('requested','pending_payment','active');
  end if;
end $$;


-- Guard temporary activations against plan canibalization / incompatible plans.
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
    if v_plan='enterprise' then raise exception 'COMMERCE_ALREADY_INCLUDED'; end if;
    if v_plan<>'premium' then raise exception 'COMMERCE_PREMIUM_REQUIRED'; end if;
    if p_days not in(7,30,90) then raise exception 'COMMERCE_DURATION_INVALID'; end if;
  elsif v_code='EVENT_PUBLICATION' then
    if v_plan in('enterprise','brand_enterprise') then raise exception 'EVENT_PUBLICATION_ALREADY_INCLUDED'; end if;
    if p_days not in(7,15,30,60) then raise exception 'EVENT_PUBLICATION_DURATION_INVALID'; end if;
  elsif v_code='CONTENT_PROMOTION' then
    if p_scope_id is null then raise exception 'CONTENT_PROMOTION_SCOPE_REQUIRED'; end if;
    if p_days not in(7,15,30) then raise exception 'CONTENT_PROMOTION_DURATION_INVALID'; end if;
  elsif v_code='EVENT_TICKETING' then
    if v_plan in('enterprise','brand_enterprise') then raise exception 'EVENT_TICKETING_ALREADY_INCLUDED'; end if;
    if p_scope_id is null then raise exception 'EVENT_TICKETING_SCOPE_REQUIRED'; end if;
  end if;
  v_detail:=jsonb_build_object('requested_days',p_days,'scope_id',p_scope_id,'payment_activation_performed',false,'plan_at_request',v_plan);
  insert into kombax_commercial.entitlements_r64(subject_type,subject_id,entitlement_code,status,scope_id,request_id,detail,created_by)
  values(p_subject_type,p_subject_id,v_code,'requested',p_scope_id,p_request_id,v_detail,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'entitlement_id',v_id,'status','requested','payment_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_activation_request_r64(text,uuid,text,uuid,integer,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
