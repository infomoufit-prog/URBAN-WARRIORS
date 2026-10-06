begin;
CREATE OR REPLACE FUNCTION public.app_kombax_eliminacion_mutate_v047(p_operation text, p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_req public.kombax_solicitudes_eliminacion;v_scope text;v_profile uuid;v_club uuid;v_id uuid;v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation='kombax.deletion.request' then
    v_scope:=lower(coalesce(v_payload->>'alcance','account'));if v_scope not in ('account','profile','club') then raise exception 'KOMBAX_DELETION_SCOPE_INVALID';end if;
    begin v_profile:=nullif(v_payload->>'perfil_directo_id','')::uuid;v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'KOMBAX_DELETION_TARGET_INVALID';end;
    if v_scope='account' then v_profile:=null;v_club:=null;
    elsif v_scope='profile' then if v_profile is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_uid) then raise exception 'KOMBAX_DELETION_PROFILE_FORBIDDEN';end if;v_club:=null;
    else if v_club is null or not public.app_kombax_club_owner_fix14(v_club) then raise exception 'KOMBAX_DELETION_CLUB_FORBIDDEN';end if;v_profile:=null;end if;
    insert into public.kombax_solicitudes_eliminacion(perfil_id,alcance,perfil_directo_id,club_id,motivo,nota_retencion)
    values(v_uid,v_scope,v_profile,v_club,nullif(left(btrim(v_payload->>'motivo'),1200),''),'La solicitud no borra automáticamente trazabilidad económica o legal que deba conservarse.') returning * into v_req;
    v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.cancel' then
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    update public.kombax_solicitudes_eliminacion set estado='cancelled',actualizado_en=now() where id=v_id and perfil_id=v_uid and estado in ('requested','needs_information') returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_CANCEL_NOT_ALLOWED';end if;v_result:=to_jsonb(v_req);
  elsif p_operation='kombax.deletion.review' then
    if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
    begin v_id:=(v_payload->>'solicitud_id')::uuid;exception when others then raise exception 'KOMBAX_DELETION_ID_INVALID';end;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('in_review','needs_information','confirmed','rejected') then raise exception 'KOMBAX_DELETION_STATE_INVALID';end if;
    update public.kombax_solicitudes_eliminacion
       set estado=v_state,resolucion=nullif(left(btrim(v_payload->>'resolucion'),2000),''),
           nota_retencion=coalesce(nullif(left(btrim(v_payload->>'nota_retencion'),1200),''),nota_retencion),
           resuelto_por=v_uid,actualizado_en=now()
     where id=v_id and completado_en is null returning * into v_req;
    if v_req.id is null then raise exception 'KOMBAX_DELETION_NOT_FOUND';end if;v_result:=to_jsonb(v_req);
  else raise exception 'KOMBAX_DELETION_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when unique_violation then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise exception 'KOMBAX_DELETION_ALREADY_OPEN';
when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'kombax_commercial'
AS $function$
  select public.app_kombax_es_moderador_v041()
 or exists(select 1 from public.kombax_showcase_marcas m where m.id=p_provider_id and m.perfil_directo_id is not null and public.app_kombax_puede_gestionar_perfil_v070(m.perfil_directo_id,'edit'))
    or exists(select 1 from public.kombax_showcase_gestores g join public.kombax_showcase_marcas gm on gm.id=g.marca_id where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo and (gm.sujeto_tipo<>'club' or (coalesce(kombax_commercial.active_plan_r64('club',gm.club_id),'') in('club','premium','enterprise','club_saas','club_pro') or exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=gm.club_id and a.tipo='club' and a.estado='verified'))))
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)) and (coalesce(kombax_commercial.active_plan_r64('club',m.club_id),'') in('club','premium','enterprise','club_saas','club_pro') or exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=m.club_id and a.tipo='club' and a.estado='verified')));
$function$
;
notify pgrst,'reload schema';
commit;
