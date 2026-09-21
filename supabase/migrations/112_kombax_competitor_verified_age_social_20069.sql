-- KOMBAX RC13 build 20069 · permite Social a Competidores 16+ ya verificados.
-- Conservado desde la versión de trabajo anterior para evitar regresiones.
begin;

create or replace function public.app_kombax_social_mutate_v099(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_actor uuid;
  v_existing public.app_mutation_requests;v_today integer;v_direct public.perfiles_kombax_directos;
  v_social_id uuid;v_version text;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation='kombax.social.direct.activate' then
    begin v_direct.id:=(v_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_DIRECT_PROFILE_INVALID';end;
    select * into v_direct from public.perfiles_kombax_directos d where d.id=v_direct.id and d.perfil_id=v_uid for update;
    if v_direct.id is null or v_direct.estado<>'activo' or v_direct.verificacion_estado<>'verificado' then raise exception 'KOMBAX_DIRECT_PROFILE_VERIFIED_REQUIRED';end if;
    if v_direct.tipo='profesional' then raise exception 'KOMBAX_SOCIAL_CLUB_VERIFIED_AGE_REQUIRED';end if;
    if v_direct.tipo='competidor' and (v_direct.fecha_nacimiento_verificada is null or v_direct.fecha_nacimiento_verificada>current_date-interval '16 years') then raise exception 'KOMBAX_SOCIAL_CLUB_VERIFIED_AGE_REQUIRED';end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then raise exception 'KOMBAX_SOCIAL_CONSENT_REQUIRED';end if;
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null then
      if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
      if v_existing.result is not null then return v_existing.result;end if;
    else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);end if;
    select version into v_version from public.textos_legales where tipo='comunidad_general' and vigente order by creado_en desc limit 1;
    v_version:=coalesce(v_version,'1.2.0');
    update public.perfiles_kombax_directos set social_activo=true,social_activado_en=coalesce(social_activado_en,now()),social_normas_version=v_version,actualizado_en=now() where id=v_direct.id;
    insert into public.kombax_aceptaciones_globales(perfil_id,perfil_directo_id,tipo,version,aceptado,user_agent) values
      (v_uid,v_direct.id,'social_normas',v_version,true,left(coalesce(v_payload->>'user_agent',''),500)),
      (v_uid,v_direct.id,'social_privacidad',v_version,true,left(coalesce(v_payload->>'user_agent',''),500))
    on conflict(perfil_directo_id,tipo,version) do update set aceptado=true,aceptado_en=now(),revocado_en=null,user_agent=excluded.user_agent;
    select id into v_social_id from public.kombax_social_perfiles where perfil_directo_id=v_direct.id;
    if v_social_id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_CREATED';end if;
    v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_direct.id,'social_profile_id',v_social_id,'status','activa'));
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
    return v_result;
  end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then return public.app_kombax_social_mutate_v085(p_operation,p_payload,p_request_id);end if;
  if p_operation='kombax.social.publicar' then
    begin v_actor:=(v_payload->>'autor_perfil_id')::uuid;exception when others then raise exception 'KOMBAX_POST_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
    select count(*)::integer into v_today from public.kombax_actor_audit a where a.public_social_id=v_actor and a.accion='social.publish' and a.creado_en>=date_trunc('day',now()) and a.creado_en<date_trunc('day',now())+interval '1 day';
    if v_today>=3 then raise exception 'KOMBAX_POST_DAILY_LIMIT_3';end if;
  end if;
  return public.app_kombax_social_mutate_v085(p_operation,p_payload,p_request_id);
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v099(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v099(text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
