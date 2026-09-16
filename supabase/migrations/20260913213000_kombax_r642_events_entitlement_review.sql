-- KOMBAX 20.113 R64.2 · Events drafts + scoped publication + entitlement review
-- Additive/conservative: preserves existing Events, promotion and Ticketing engines.
begin;

-- A base Club can create/manage drafts. Publication remains gated separately by
-- Premium quota, Enterprise inclusion or a scoped EVENT_PUBLICATION entitlement.
create or replace function public.app_kombax_eventos_sujeto_puede_organizar_v160(p_sujeto_tipo text,p_sujeto_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_plan text;v_direct public.perfiles_kombax_directos;v_existing boolean:=false;v_pro_organizer boolean:=false;
begin
  if v_uid is null or p_sujeto_id is null then return false; end if;
  if p_sujeto_tipo='club' then
    if not exists(select 1 from public.miembros_club m where m.club_id=p_sujeto_id and m.perfil_id=v_uid and m.activo and (m.rol in('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))) then return false; end if;
    select exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='club' and e.sujeto_id=p_sujeto_id and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())) into v_existing;
    if v_existing then return true; end if;
    v_plan:=kombax_commercial.active_plan_r64('club',p_sujeto_id);
    -- Club base is allowed to create drafts; publication is asserted independently.
    if v_plan in('club','premium','enterprise','club_saas','club_pro') then return true; end if;
    return kombax_commercial.unconsumed_event_publication_entitlement_r64('club',p_sujeto_id) is not null;
  elsif p_sujeto_tipo='perfil_directo' then
    select * into v_direct from public.perfiles_kombax_directos d where d.id=p_sujeto_id and d.perfil_id=v_uid and d.estado='activo';
    if not found then return false; end if;
    select exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='perfil_directo' and e.sujeto_id=p_sujeto_id and e.capacidad_clave='events.public.organize' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())) into v_existing;
    if v_existing then return true; end if;
    if v_direct.verificacion_estado<>'verificado' then return false; end if;
    v_plan:=kombax_commercial.active_plan_r64('direct_profile',p_sujeto_id);
    if v_direct.tipo='federacion' and v_plan in('federation','federation_partner','federacion_institucional') then return true; end if;
    -- Brand Start may draft an Event and later purchase publication; Growth/Enterprise have plan quota/inclusion.
    if v_direct.tipo='marca' and v_plan in('brand_start','brand_growth','brand_enterprise','marca_profesional') then return true; end if;
    if v_direct.tipo='profesional' then
      select exists(
        select 1 from public.kombax_profesional_perfiles_v196 p where p.perfil_directo_id=p_sujeto_id and p.especialidad_principal='promotor_organizador'
        union all
        select 1 from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=p_sujeto_id and s.especialidad_codigo='promotor_organizador'
      ) into v_pro_organizer;
      if v_pro_organizer then return true; end if;
    end if;
    -- Historical/manual punctual entitlement remains compatible.
    return kombax_commercial.unconsumed_event_publication_entitlement_r64('direct_profile',p_sujeto_id) is not null;
  end if;
  return false;
end $$;
revoke all on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_sujeto_puede_organizar_v160(text,uuid) to authenticated;

-- Publication is always scoped to a concrete event in the new flow.
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
    if v_plan in('enterprise','brand_enterprise') then raise exception 'SHOWCASE_COMMERCE_ALREADY_INCLUDED'; end if;
    if v_plan<>'premium' then raise exception 'SHOWCASE_COMMERCE_REQUIRES_PREMIUM'; end if;
    if p_days not in(7,30,90) then raise exception 'COMMERCE_DURATION_INVALID'; end if;
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

-- Owner/admin decision for non-Ticketing entitlements. Activation is only a
-- manual record after external/commercial validation; it never performs a charge.
create or replace function public.app_kombax_commercial_admin_entitlement_decide_r642(p_entitlement_id uuid,p_decision text,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_row kombax_commercial.entitlements_r64;v_decision text:=lower(trim(coalesce(p_decision,'')));v_days integer;v_plan text;v_used numeric:=0;v_last record;v_start timestamptz:=now();v_end timestamptz;
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
    if v_plan<>'premium' then raise exception 'SHOWCASE_COMMERCE_REQUIRES_PREMIUM'; end if;
    if v_days not in(7,30,90) then raise exception 'COMMERCE_DURATION_INVALID'; end if;
    select e.* into v_last from kombax_commercial.entitlements_r64 e
      where e.subject_type=v_row.subject_type and e.subject_id=v_row.subject_id and e.entitlement_code='SHOWCASE_COMMERCE'
        and e.id<>v_row.id and e.status in('active','expired') and e.ends_at is not null
      order by e.ends_at desc limit 1;
    if v_last.id is not null and v_last.starts_at is not null and v_last.ends_at-v_last.starts_at>=interval '89 days'
       and v_last.ends_at>now()-interval '30 days' then raise exception 'COMMERCE_30_DAY_COOLDOWN_REQUIRED'; end if;
    select coalesce(sum(greatest(0, extract(epoch from (least(e.ends_at,now()) - greatest(e.starts_at,now()-interval '12 months'))) / 86400)),0)
      into v_used from kombax_commercial.entitlements_r64 e
      where e.subject_type=v_row.subject_type and e.subject_id=v_row.subject_id and e.entitlement_code='SHOWCASE_COMMERCE'
        and e.id<>v_row.id and e.status in('active','expired') and e.starts_at is not null and e.ends_at is not null and e.ends_at>now()-interval '12 months';
    if v_used+v_days>120 then raise exception 'COMMERCE_ROLLING_12M_LIMIT_REACHED'; end if;
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
    detail=detail||jsonb_build_object('review_note',trim(p_note),'reviewed_by',v_uid,'reviewed_at',now(),'manual_activation',true,'billing_activation_performed',false),updated_at=now()
    where id=v_row.id;
  return jsonb_build_object('ok',true,'status','active','entitlement_id',v_row.id,'starts_at',v_start,'ends_at',v_end,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_commercial_admin_entitlement_decide_r642(uuid,text,text) to authenticated;

notify pgrst,'reload schema';
commit;
