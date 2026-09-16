-- KOMBAX R66 · Founder is monthly-only.
-- Defensive server-side guard: annual never carries/locks Founder pricing.
begin;

create or replace function public.app_kombax_commercial_plan_request_r64(p_subject_type text,p_subject_id uuid,p_plan_code text,p_billing_cycle text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_audience text;v_plan kombax_commercial.plan_pricing_r64;v_id uuid;v_founder_open boolean:=false;v_terms kombax_commercial.organization_terms_r64;v_founder_requested boolean:=false;v_cycle text:=lower(p_billing_cycle);
begin
  if v_uid is null or p_request_id is null then raise exception 'AUTH_AND_REQUEST_REQUIRED'; end if;
  if not kombax_commercial.can_manage_subject_r64(p_subject_type,p_subject_id) then raise exception 'COMMERCIAL_SUBJECT_MANAGEMENT_REQUIRED'; end if;
  if v_cycle not in('monthly','annual') then raise exception 'COMMERCIAL_BILLING_CYCLE_INVALID'; end if;
  if p_subject_type='club' then v_audience:='club'; else select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' else d.tipo end into v_audience from public.perfiles_kombax_directos d where d.id=p_subject_id; end if;
  select * into v_plan from kombax_commercial.plan_pricing_r64 where plan_code=lower(p_plan_code) and active and audience=v_audience;
  if not found then raise exception 'COMMERCIAL_PLAN_NOT_AVAILABLE_FOR_SUBJECT'; end if;
  if v_audience='brand' and not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado') then raise exception 'VERIFIED_BRAND_REQUIRED'; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=p_subject_type and subject_id=p_subject_id;
  v_founder_requested:=v_cycle='monthly' and (coalesce(v_terms.founder_locked,false) or (coalesce(v_founder_open,false) and v_terms.founder_lost_at is null));
  insert into kombax_commercial.plan_requests_r64(subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by)
  values(p_subject_type,p_subject_id,v_plan.plan_code,v_cycle,v_founder_requested,p_request_id,v_uid)
  on conflict(request_id) do update set updated_at=now() returning id into v_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'plan_request_id',v_id,'status','requested','founder_requested',v_founder_requested,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_plan_request_r64(text,uuid,text,text,uuid) from public,anon;
grant execute on function public.app_kombax_commercial_plan_request_r64(text,uuid,text,text,uuid) to authenticated;

create or replace function public.app_kombax_club_plan_request_after_verify_r642()
returns trigger language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
  v_founder_open boolean:=false;
  v_founder boolean:=false;
begin
  if new.tipo<>'club' or new.estado<>'verified' or old.estado='verified' or new.club_id is null then return new; end if;
  if v_plan not in('club','premium','enterprise') then return new; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  v_founder:=coalesce(v_founder_open,false) and v_cycle='monthly';
  insert into kombax_commercial.plan_requests_r64(subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by,detail)
  select 'club',new.club_id,v_plan,v_cycle,v_founder,gen_random_uuid(),new.perfil_id,jsonb_build_object('source','club_application','application_id',new.id,'billing_activation_performed',false)
  where not exists(select 1 from kombax_commercial.plan_requests_r64 r where r.subject_type='club' and r.subject_id=new.club_id and coalesce(r.detail->>'application_id','')=new.id::text);
  insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,updated_at)
  values('club',new.club_id,v_plan,v_cycle,false,null,now())
  on conflict(subject_type,subject_id) do update set plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,updated_at=now();
  return new;
end $$;
revoke all on function public.app_kombax_club_plan_request_after_verify_r642() from public,anon,authenticated;

create or replace function public.app_kombax_direct_commercial_plan_request_after_verify_r66()
returns trigger language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
  v_founder_open boolean:=false;
  v_valid boolean:=false;
  v_founder boolean:=false;
begin
  if new.tipo not in('marca','federacion') or new.estado<>'verified' or old.estado='verified' or new.perfil_directo_id is null then return new; end if;
  v_valid:=(new.tipo='marca' and v_plan in('brand_start','brand_growth','brand_enterprise')) or (new.tipo='federacion' and v_plan in('federation','federation_partner'));
  if not v_valid then return new; end if;
  select coalesce((value#>>'{}')::boolean,false) into v_founder_open from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';
  v_founder:=coalesce(v_founder_open,false) and v_cycle='monthly';
  insert into kombax_commercial.plan_requests_r64(subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by,detail)
  select 'direct_profile',new.perfil_directo_id,v_plan,v_cycle,v_founder,gen_random_uuid(),new.perfil_id,jsonb_build_object('source','direct_profile_application','application_id',new.id,'profile_type',new.tipo,'billing_activation_performed',false)
  where not exists(select 1 from kombax_commercial.plan_requests_r64 r where r.subject_type='direct_profile' and r.subject_id=new.perfil_directo_id and coalesce(r.detail->>'application_id','')=new.id::text);
  insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,updated_at)
  values('direct_profile',new.perfil_directo_id,v_plan,v_cycle,false,null,now())
  on conflict(subject_type,subject_id) do update set plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,updated_at=now();
  return new;
end $$;
revoke all on function public.app_kombax_direct_commercial_plan_request_after_verify_r66() from public,anon,authenticated;

create or replace function public.app_kombax_commercial_admin_activate_plan_r642(p_plan_request_id uuid,p_note text default '')
returns jsonb language plpgsql security definer set search_path=public,auth,kombax_commercial as $$
declare r kombax_commercial.plan_requests_r64;v_terms kombax_commercial.organization_terms_r64;v_founder boolean:=false;v_subject_type text;v_sub_id uuid;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select * into r from kombax_commercial.plan_requests_r64 where id=p_plan_request_id for update;
  if not found or r.status not in('requested','under_review') then raise exception 'COMMERCIAL_PLAN_REQUEST_NOT_ACTIONABLE'; end if;
  v_subject_type:=case when r.subject_type='direct_profile' then 'perfil_directo' else r.subject_type end;
  select * into v_terms from kombax_commercial.organization_terms_r64 where subject_type=r.subject_type and subject_id=r.subject_id;
  v_founder:=coalesce(r.founder_requested,false) and r.billing_cycle='monthly' and v_terms.founder_lost_at is null;
  update public.kombax_suscripciones set estado='cancelada',termina_en=coalesce(termina_en,now()),actualizado_en=now() where sujeto_tipo=v_subject_type and sujeto_id=r.subject_id and estado in('prueba','activa','pausada');
  insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en) values(v_subject_type,r.subject_id,'activa',r.requested_plan_code,'kombax_manual_admin','plan-request:'||r.id::text,now()) returning id into v_sub_id;
  insert into kombax_commercial.organization_terms_r64(subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,founder_lost_at,updated_at)
  values(r.subject_type,r.subject_id,r.requested_plan_code,r.billing_cycle,v_founder,case when v_founder then now() else null end,v_terms.founder_lost_at,now())
  on conflict(subject_type,subject_id) do update set plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,founder_locked=excluded.founder_locked,founder_continuous_since=case when excluded.founder_locked then coalesce(kombax_commercial.organization_terms_r64.founder_continuous_since,excluded.founder_continuous_since) else kombax_commercial.organization_terms_r64.founder_continuous_since end,updated_at=now();
  update kombax_commercial.plan_requests_r64 set status='approved',detail=coalesce(detail,'{}'::jsonb)||jsonb_build_object('review_note',left(coalesce(p_note,''),1000),'activated_by',auth.uid(),'activated_at',now(),'billing_activation_performed',false,'manual_activation',true),updated_at=now() where id=r.id;
  return jsonb_build_object('ok',true,'plan_request_id',r.id,'subscription_id',v_sub_id,'plan_code',r.requested_plan_code,'founder_locked',v_founder);
end $$;
revoke all on function public.app_kombax_commercial_admin_activate_plan_r642(uuid,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_activate_plan_r642(uuid,text) to authenticated;

commit;
