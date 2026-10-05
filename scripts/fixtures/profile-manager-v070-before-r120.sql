CREATE OR REPLACE FUNCTION public.app_kombax_profile_manager_mutate_v070(p_operation text, p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid();v_profile uuid;v_target uuid;v_role text;v_row public.kombax_perfil_gestores;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_profile:=(p_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
  begin v_target:=(p_payload->>'perfil_id')::uuid;exception when others then raise exception 'KOMBAX_MANAGER_ID_INVALID';end;
  if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
  if not exists(select 1 from public.perfiles where id=v_target) then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
  if exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_target) then raise exception 'KOMBAX_OWNER_ROLE_IMMUTABLE';end if;
  if p_operation in ('kombax.profile.manager.add','kombax.profile.manager.update') then
    v_role:=lower(btrim(coalesce(p_payload->>'rol','editor')));
    if v_role not in ('admin','editor','comunicacion') then raise exception 'KOMBAX_MANAGER_ROLE_INVALID';end if;
    insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por)
    values(v_profile,v_target,v_role,'activo',v_uid)
    on conflict(perfil_directo_id,perfil_id) do update set rol=excluded.rol,estado='activo',concedido_por=v_uid,actualizado_en=now()
    returning * into v_row;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,case when p_operation='kombax.profile.manager.add' then 'manager_added' else 'manager_updated' end,jsonb_build_object('perfil_id',v_target,'rol',v_role));
  elsif p_operation='kombax.profile.manager.remove' then
    update public.kombax_perfil_gestores set estado='revocado',actualizado_en=now()
    where perfil_directo_id=v_profile and perfil_id=v_target and rol<>'owner' returning * into v_row;
    if v_row.id is null then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,'manager_removed',jsonb_build_object('perfil_id',v_target,'rol',v_row.rol));
  else raise exception 'KOMBAX_MANAGER_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_profile,'perfil_id',v_target,'rol',v_row.rol,'estado',v_row.estado));
  return v_result;
end $function$;
