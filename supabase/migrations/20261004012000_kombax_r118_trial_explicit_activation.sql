-- R118 FIX05: explicit nullable activation and paid-plan status after trial.
-- R118 FIX05: enforce the trial expiry on subscription-derived federation capabilities.
create or replace function public.app_kombax_space_trial_r118(p_subject_type text,p_subject_id uuid,p_activate boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_trial kombax_commercial.space_trials_r118%rowtype;v_plan text;v_uid uuid:=auth.uid();v_kind text;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
  if p_subject_type='club' then
    perform 1 from public.clubes where id=p_subject_id for update;
    if not found or not public.app_puede_gestionar_perfil_club_v035(p_subject_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
    v_plan:='club';
  elsif p_subject_type='direct_profile' then
    select tipo into v_kind from public.perfiles_kombax_directos where id=p_subject_id and perfil_id=v_uid and estado='activo' for update;
    if not found or v_kind<>'federacion' then raise exception 'ORGANIZATION_OWNER_REQUIRED' using errcode='42501';end if;
    v_plan:='federation';
  else raise exception 'INVALID_SUBJECT';end if;
  if exists(select 1 from kombax_commercial.pilot_entities_r97 where subject_type=p_subject_type and subject_id=p_subject_id) then
    return jsonb_build_object('ok',true,'status','pilot','activation_allowed',false,'billing_activation_performed',false);
  end if;
  if exists(select 1 from public.kombax_suscripciones s where s.sujeto_tipo=case when p_subject_type='direct_profile' then 'perfil_directo' else p_subject_type end
    and s.sujeto_id=p_subject_id and s.estado='activa' and s.proveedor is distinct from 'kombax_trial_r118'
    and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())) then
    return jsonb_build_object('ok',true,'status','active','activation_allowed',false,'billing_activation_performed',false);
  end if;
  select * into v_trial from kombax_commercial.space_trials_r118 where subject_type=p_subject_type and subject_id=p_subject_id;
  if v_trial.subject_id is not null then
    return jsonb_build_object('ok',true,'status',case when v_trial.ends_at>now() then 'trial' else 'expired' end,'activation_allowed',false,'started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'billing_activation_performed',false);
  end if;
  if kombax_commercial.active_plan_r64(p_subject_type,p_subject_id) is not null then
    return jsonb_build_object('ok',true,'status','active','activation_allowed',false,'billing_activation_performed',false);
  end if;
  if not coalesce(p_activate,false) then return jsonb_build_object('ok',true,'status','available','activation_allowed',true,'days',30,'billing_activation_performed',false);end if;
  insert into kombax_commercial.space_trials_r118(subject_type,subject_id,ends_at,created_by)
    values(p_subject_type,p_subject_id,now()+interval '30 days',v_uid) returning * into v_trial;
  insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en,termina_en)
    values(case when p_subject_type='direct_profile' then 'perfil_directo' else p_subject_type end,p_subject_id,'prueba',v_plan,'kombax_trial_r118',p_subject_type||':'||p_subject_id::text,v_trial.started_at,v_trial.ends_at);
  if p_subject_type='direct_profile' then
    perform public.app_kombax_reconcile_entitlements_v071(p_subject_id,v_uid);
    update public.kombax_entitlements set termina_en=v_trial.ends_at
      where sujeto_tipo='perfil_directo' and sujeto_id=p_subject_id and origen='suscripcion' and activa;
  end if;
  return jsonb_build_object('ok',true,'status','trial','activation_allowed',false,'started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'billing_activation_performed',false);
end $$;
