-- A pilot place requires a verified Club, including administrator assignments
-- from the existing-club list. No card or paid subscription is created.
begin;
create or replace function public.app_kombax_pilot_assign_r99(
  p_club_id uuid,p_plan_code text,p_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_start timestamptz;v_end timestamptz;v_slots integer;v_enrolled boolean;
        v_existing text;v_plan text:=lower(btrim(coalesce(p_plan_code,'')));
begin
  if auth.uid() is null or not public.app_kombax_es_platform_admin_v055() then
    raise exception 'platform_admin_required' using errcode='42501';
  end if;
  if p_club_id is null or not exists(select 1 from public.clubes where id=p_club_id) then
    raise exception 'club_not_found';
  end if;
  if not exists(select 1 from public.kombax_solicitudes_alta s
    where s.tipo='club' and s.club_id=p_club_id and s.estado='verified') then
    raise exception 'club_verification_required';
  end if;
  if v_plan not in ('club','premium','enterprise') then raise exception 'invalid_pilot_plan'; end if;
  select trim(both '"' from value::text)::timestamptz into v_start
    from kombax_commercial.runtime_config_r64 where config_key='pilot_start_at';
  select trim(both '"' from value::text)::timestamptz into v_end
    from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at';
  if v_start is null or v_end is null or v_start>=v_end or now()>=v_end then
    raise exception 'pilot_window_closed';
  end if;
  perform pg_advisory_xact_lock(hashtext('kombax-pilot-club-slots'));
  select exists(select 1 from kombax_commercial.pilot_entities_r97
    where subject_type='club' and subject_id=p_club_id) into v_enrolled;
  select greatest(0,least(100,coalesce(value::text::integer,4))) into v_slots
    from kombax_commercial.runtime_config_r64 where config_key='pilot_club_slots';
  v_slots:=coalesce(v_slots,4);
  if not v_enrolled and
     (select count(*) from kombax_commercial.pilot_entities_r97 where subject_type='club')>=v_slots then
    raise exception 'pilot_club_slots_full';
  end if;
  select b.plan_code into v_existing from kombax_commercial.plan_benefits_r97 b
    where b.subject_type='club' and b.subject_id=p_club_id and b.benefit_code='PILOT_ACCESS'
    order by b.created_at desc limit 1;
  if v_existing is not null and v_existing<>v_plan then raise exception 'pilot_plan_already_assigned'; end if;
  perform public.app_kombax_pilot_enroll_r97('club',p_club_id,left(p_notes,500));
  insert into kombax_commercial.plan_benefits_r97(
    subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by
  ) values('club',p_club_id,'PILOT_ACCESS',v_plan,v_start,v_end,'pilot_no_card',auth.uid())
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;
  return jsonb_build_object('ok',true,'club_id',p_club_id,'plan_code',v_plan,
    'starts_at',v_start,'ends_at',v_end,'payment_method_required',false);
end $$;
revoke all on function public.app_kombax_pilot_assign_r99(uuid,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_pilot_assign_r99(uuid,text,text) to authenticated;
commit;
