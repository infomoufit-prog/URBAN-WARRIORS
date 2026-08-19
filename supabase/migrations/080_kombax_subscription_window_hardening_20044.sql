-- KOMBAX RC13 build 20044 · 080 · subscription/entitlement temporal window hardening
-- Corrige cancelaciones/reevaluaciones realizadas en la misma transacción: termina_en debe ser > inicia_en.

begin;

create or replace function public.app_kombax_reconcile_entitlements_v071(p_perfil_directo_id uuid,p_actor uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_plan text;v_service boolean:=false;v_verified boolean:=false;
begin
  select d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited') and d.estado='activo'
    into v_verified from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;
  if not found then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;

  select s.modalidad,
    s.estado in ('prueba','activa') and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())
  into v_plan,v_service
  from public.kombax_suscripciones s join public.kombax_planes p on p.codigo=s.modalidad and p.activo
  where s.sujeto_tipo='perfil_directo' and s.sujeto_id=p_perfil_directo_id and s.estado in ('prueba','activa','pausada')
  order by s.actualizado_en desc limit 1;

  update public.kombax_entitlements set activa=false,
    termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond'))
  where sujeto_tipo='perfil_directo' and sujeto_id=p_perfil_directo_id and origen='suscripcion' and activa;

  if v_verified and coalesce(v_service,false) and v_plan is not null then
    insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,inicia_en,asignada_por)
    select 'perfil_directo',p_perfil_directo_id,pc.capacidad_clave,true,'suscripcion',now(),p_actor
    from public.kombax_plan_capacidades pc where pc.plan_codigo=v_plan
    on conflict do nothing;
  end if;

  update public.perfiles_kombax_directos set publico=(v_verified and coalesce(v_service,false)),actualizado_en=now()
  where id=p_perfil_directo_id;
end $$;
revoke all on function public.app_kombax_reconcile_entitlements_v071(uuid,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_subscription_mutate_v071(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_profile uuid;v_plan text;v_state text;v_type text;v_sub public.kombax_suscripciones;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation<>'kombax.subscription.set' then raise exception 'KOMBAX_SUBSCRIPTION_OPERATION_NOT_ALLOWED';end if;
  begin v_profile:=(p_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
  v_plan:=lower(btrim(coalesce(p_payload->>'plan_codigo','')));v_state:=lower(btrim(coalesce(p_payload->>'estado','activa')));
  if v_state not in ('inactiva','prueba','activa','pausada','cancelada') then raise exception 'KOMBAX_SUBSCRIPTION_STATE_INVALID';end if;
  select tipo into v_type from public.perfiles_kombax_directos where id=v_profile;
  if v_type is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
  if v_state not in ('inactiva','cancelada') then
    if not exists(select 1 from public.kombax_planes p where p.codigo=v_plan and p.perfil_tipo=v_type and p.activo) then raise exception 'KOMBAX_PLAN_PROFILE_MISMATCH';end if;
    update public.kombax_suscripciones set estado='cancelada',
      termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond')),actualizado_en=now()
    where sujeto_tipo='perfil_directo' and sujeto_id=v_profile and estado in ('prueba','activa','pausada');
    insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en,termina_en)
    values('perfil_directo',v_profile,v_state,v_plan,coalesce(nullif(p_payload->>'proveedor',''),'manual'),nullif(p_payload->>'referencia_externa',''),
      coalesce(nullif(p_payload->>'inicia_en','')::timestamptz,now()),nullif(p_payload->>'termina_en','')::timestamptz)
    returning * into v_sub;
  else
    update public.kombax_suscripciones set estado=v_state,
      termina_en=coalesce(termina_en,greatest(clock_timestamp(),inicia_en+interval '1 microsecond')),actualizado_en=now()
    where sujeto_tipo='perfil_directo' and sujeto_id=v_profile and estado in ('prueba','activa','pausada') returning * into v_sub;
  end if;
  perform public.app_kombax_reconcile_entitlements_v071(v_profile,v_uid);
  insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
  values(v_profile,v_uid,case when v_state in ('prueba','activa') then 'service_activated' else 'service_deactivated' end,
    jsonb_build_object('plan_codigo',nullif(v_plan,''),'estado',v_state));
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_profile,'plan_codigo',nullif(v_plan,''),'estado',v_state));
  return v_result;
end $$;
revoke all on function public.app_kombax_subscription_mutate_v071(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_subscription_mutate_v071(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
