-- KOMBAX R72 / build 20123 live section 04
begin;
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
commit;
