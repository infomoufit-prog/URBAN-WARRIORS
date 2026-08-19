-- KOMBAX RC13 build 20044 · 077 · kombax verified profiles mutations

begin;

-- ---------------------------------------------------------------------------
-- 6. Mutación final de perfiles/solicitudes. Verificar NO activa plan.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_perfil_mutate_v072(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_type text;v_name text;v_slug text;v_id uuid;v_source_social uuid;v_source_identity uuid;v_profile public.perfiles_kombax_directos;v_request public.kombax_solicitudes_alta;v_doc public.kombax_verificacion_documentos;
  v_state text;v_reason text;v_public jsonb;v_verify jsonb;v_decl boolean;v_validation jsonb;v_dob date;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if; if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  delete from public.app_mutation_requests where user_id=v_uid and club_id is null and created_at<now()-interval '30 days';
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation); end if;

  if p_operation='kombax.profile.save' then
    v_type:=lower(btrim(coalesce(v_payload->>'tipo',''))); if v_type not in ('competidor','marca','federacion') then raise exception 'KOMBAX_PROFILE_TYPE_NOT_OPEN'; end if;
    v_name:=btrim(coalesce(v_payload->>'nombre_publico','')); if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_PROFILE_NAME_INVALID'; end if;
    v_id:=public.app_kombax_uuid_or_null_v070(coalesce(v_payload->>'id',v_payload->>'perfil_directo_id'));
    v_source_social:=public.app_kombax_uuid_or_null_v070(v_payload->>'miembro_social_id');
    if v_type='competidor' and v_source_social is not null then
      select sp.identidad_social_id into v_source_identity from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id
      where sp.id=v_source_social and sp.sujeto_tipo='miembro' and i.perfil_id=v_uid and i.estado='activa';
      if v_source_identity is null then raise exception 'KOMBAX_MEMBER_SOURCE_NOT_OWNED'; end if;
    end if;
    if v_id is null then
      if v_type='competidor' and exists(select 1 from public.perfiles_kombax_directos where tipo='competidor' and perfil_id=v_uid) then raise exception 'KOMBAX_COMPETITOR_ALREADY_EXISTS'; end if;
      v_slug:=public.app_kombax_slug_v043(coalesce(nullif(v_payload->>'slug',''),v_name)); if char_length(v_slug)<2 then raise exception 'KOMBAX_PROFILE_SLUG_INVALID'; end if;
      if exists(select 1 from public.perfiles_kombax_directos where slug=v_slug) then v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8); end if;
      insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico,descripcion,workflow_estado,ubicacion,disciplinas,categoria,club_declarado,web_publica,publico,origen_identidad_social_id)
      values(v_uid,v_type,v_slug,v_name,left(nullif(btrim(v_payload->>'descripcion'),''),1600),'draft',left(nullif(btrim(v_payload->>'ubicacion'),''),160),
        coalesce(array(select jsonb_array_elements_text(coalesce(v_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),left(nullif(btrim(v_payload->>'categoria'),''),120),
        left(nullif(btrim(v_payload->>'club_declarado'),''),160),nullif(btrim(v_payload->>'web_publica'),''),false,v_source_identity) returning * into v_profile;
      insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por) values(v_profile.id,v_uid,'owner','activo',v_uid) on conflict do nothing;
      insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values('perfil_directo',v_profile.id,'profile.direct.manage',true,'manual',v_uid) on conflict do nothing;
    else
      select * into v_profile from public.perfiles_kombax_directos where id=v_id for update;
      if v_profile.id is null or not public.app_kombax_puede_gestionar_perfil_v070(v_id,'edit') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED'; end if;
      if v_profile.workflow_estado in ('under_review','suspended') then raise exception 'KOMBAX_PROFILE_LOCKED_FOR_REVIEW'; end if;
      if v_profile.tipo<>v_type then raise exception 'KOMBAX_PROFILE_TYPE_IMMUTABLE'; end if;
      if v_type='competidor' and v_profile.perfil_id<>v_uid then raise exception 'KOMBAX_COMPETITOR_OWNER_ONLY'; end if;
      update public.perfiles_kombax_directos set nombre_publico=v_name,descripcion=left(nullif(btrim(v_payload->>'descripcion'),''),1600),ubicacion=left(nullif(btrim(v_payload->>'ubicacion'),''),160),
        disciplinas=coalesce(array(select jsonb_array_elements_text(coalesce(v_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),categoria=left(nullif(btrim(v_payload->>'categoria'),''),120),
        club_declarado=left(nullif(btrim(v_payload->>'club_declarado'),''),160),web_publica=nullif(btrim(v_payload->>'web_publica'),''),
        origen_identidad_social_id=case when tipo='competidor' and workflow_estado in ('draft','needs_information','rejected') then coalesce(v_source_identity,origen_identidad_social_id) else origen_identidad_social_id end,actualizado_en=now()
      where id=v_id returning * into v_profile;
    end if;
    v_result:=to_jsonb(v_profile);

  elsif p_operation='kombax.application.save' then
    v_type:=lower(btrim(coalesce(v_payload->>'tipo',''))); if v_type not in ('club','competidor','marca','federacion') then raise exception 'KOMBAX_APPLICATION_TYPE_INVALID'; end if;
    v_name:=btrim(coalesce(v_payload->>'nombre_publico','')); if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_APPLICATION_NAME_INVALID'; end if;
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'perfil_directo_id');
    if v_type<>'club' then
      if v_id is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_id and d.tipo=v_type and public.app_kombax_puede_gestionar_perfil_v070(d.id,'admin')) then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
      if v_type='competidor' and not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_id and d.perfil_id=v_uid) then raise exception 'KOMBAX_COMPETITOR_OWNER_ONLY'; end if;
    end if;
    v_public:=coalesce(v_payload->'datos_publicos','{}'::jsonb);v_verify:=coalesce(v_payload->'datos_verificacion','{}'::jsonb);v_decl:=coalesce((v_payload->>'declaracion_aceptada')::boolean,false);
    if v_id is not null then select * into v_request from public.kombax_solicitudes_alta where perfil_directo_id=v_id and estado in ('draft','submitted','under_review','needs_information') order by creado_en desc limit 1 for update;
    else select * into v_request from public.kombax_solicitudes_alta where perfil_id=v_uid and tipo='club' and perfil_directo_id is null and estado in ('draft','submitted','under_review','needs_information') order by creado_en desc limit 1 for update; end if;
    if v_request.id is null then
      insert into public.kombax_solicitudes_alta(perfil_id,tipo,perfil_directo_id,nombre_publico,datos_publicos,datos_verificacion,estado,schema_version,declaracion_aceptada,declaracion_en,requisitos_version)
      values(v_uid,v_type,v_id,v_name,v_public,v_verify,'draft',2,v_decl,case when v_decl then now() else null end,'verified-profile-v1') returning * into v_request;
    else
      if v_request.estado in ('submitted','under_review') then raise exception 'KOMBAX_APPLICATION_LOCKED_FOR_REVIEW'; end if;
      update public.kombax_solicitudes_alta set nombre_publico=v_name,datos_publicos=v_public,datos_verificacion=v_verify,declaracion_aceptada=v_decl,
        declaracion_en=case when v_decl then coalesce(declaracion_en,now()) else null end,schema_version=2,requisitos_version='verified-profile-v1',actualizado_en=now()
      where id=v_request.id returning * into v_request;
    end if;
    insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle) values(v_request.id,v_request.perfil_directo_id,v_uid,'draft_saved','{}'::jsonb);
    v_result:=to_jsonb(v_request)-'datos_verificacion';

  elsif p_operation='kombax.application.submit' then
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'solicitud_id');
    select * into v_request from public.kombax_solicitudes_alta where id=v_id and (perfil_id=v_uid or (perfil_directo_id is not null and public.app_kombax_puede_gestionar_perfil_v070(perfil_directo_id,'admin'))) for update;
    if v_request.id is null or v_request.estado not in ('draft','needs_information') then raise exception 'KOMBAX_APPLICATION_NOT_SUBMITTABLE'; end if;
    if v_request.tipo='competidor' and v_request.perfil_id<>v_uid then raise exception 'KOMBAX_COMPETITOR_OWNER_ONLY'; end if;
    v_validation:=public.app_kombax_application_validate_v072(v_request.id);
    update public.kombax_solicitudes_alta set estado='submitted',enviado_en=coalesce(enviado_en,now()),motivo_revision=null,actualizado_en=now() where id=v_request.id returning * into v_request;
    if v_request.perfil_directo_id is not null then update public.perfiles_kombax_directos set workflow_estado='submitted',estado='pendiente_verificacion',verificacion_estado='pendiente',publico=false,actualizado_en=now() where id=v_request.perfil_directo_id; end if;
    insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle) values(v_request.id,v_request.perfil_directo_id,v_uid,'submitted',v_validation);
    v_result:=to_jsonb(v_request)-'datos_verificacion';

  elsif p_operation='kombax.application.withdraw' then
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'solicitud_id');
    update public.kombax_solicitudes_alta set estado='withdrawn',actualizado_en=now() where id=v_id and perfil_id=v_uid and estado in ('draft','submitted','needs_information') returning * into v_request;
    if v_request.id is null then raise exception 'KOMBAX_APPLICATION_NOT_WITHDRAWABLE'; end if;
    if v_request.perfil_directo_id is not null then update public.perfiles_kombax_directos set workflow_estado='draft',estado='borrador',verificacion_estado='no_iniciada',publico=false,actualizado_en=now() where id=v_request.perfil_directo_id; end if;
    insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle) values(v_request.id,v_request.perfil_directo_id,v_uid,'withdrawn','{}'::jsonb);
    v_result:=jsonb_build_object('id',v_request.id,'estado',v_request.estado);

  elsif p_operation='kombax.application.document.add' then
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'solicitud_id');
    select * into v_request from public.kombax_solicitudes_alta where id=v_id and (perfil_id=v_uid or (perfil_directo_id is not null and public.app_kombax_puede_gestionar_perfil_v070(perfil_directo_id,'admin'))) and estado in ('draft','needs_information','submitted');
    if v_request.id is null then raise exception 'KOMBAX_APPLICATION_DOCUMENT_FORBIDDEN'; end if;
    if btrim(coalesce(v_payload->>'storage_path',''))='' or split_part(v_payload->>'storage_path','/',1)<>v_uid::text or split_part(v_payload->>'storage_path','/',2)<>v_id::text then raise exception 'KOMBAX_VERIFICATION_PATH_INVALID'; end if;
    insert into public.kombax_verificacion_documentos(solicitud_id,perfil_id,tipo_documento,storage_path,mime_type,bytes)
    values(v_id,v_uid,left(btrim(v_payload->>'tipo_documento'),80),btrim(v_payload->>'storage_path'),lower(btrim(v_payload->>'mime_type')),(v_payload->>'bytes')::bigint) returning * into v_doc;
    v_result:=jsonb_build_object('id',v_doc.id,'solicitud_id',v_doc.solicitud_id,'tipo_documento',v_doc.tipo_documento,'storage_path',v_doc.storage_path,'mime_type',v_doc.mime_type,'bytes',v_doc.bytes);

  elsif p_operation='kombax.application.review' then
    if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'solicitud_id');v_state:=lower(btrim(coalesce(v_payload->>'estado','')));
    if v_state not in ('under_review','needs_information','verified','limited','suspended','rejected') then raise exception 'KOMBAX_REVIEW_STATE_INVALID'; end if;
    v_reason:=left(nullif(btrim(v_payload->>'motivo'),''),2000);
    select * into v_request from public.kombax_solicitudes_alta where id=v_id and estado<>'withdrawn' for update; if v_request.id is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND'; end if;
    if v_state in ('verified','limited') then v_validation:=public.app_kombax_application_validate_v072(v_request.id); end if;
    update public.kombax_solicitudes_alta set estado=v_state,motivo_revision=v_reason,revisado_por=v_uid,revisado_en=now(),actualizado_en=now() where id=v_request.id returning * into v_request;
    if v_request.perfil_directo_id is not null then
      if v_state='verified' and v_request.tipo='competidor' then
        if (v_validation->>'fecha_nacimiento_verificada') is not null then v_dob:=(v_validation->>'fecha_nacimiento_verificada')::date; end if;
      end if;
      update public.perfiles_kombax_directos set workflow_estado=v_state,
        estado=case v_state when 'verified' then 'activo' when 'limited' then 'activo' when 'suspended' then 'suspendido' when 'rejected' then 'cerrado' else 'pendiente_verificacion' end,
        verificacion_estado=case v_state when 'verified' then 'verificado' when 'limited' then 'verificado' when 'rejected' then 'rechazado' else 'pendiente' end,
        publico=false,verificado_en=case when v_state in ('verified','limited') then now() else verificado_en end,verificado_por=case when v_state in ('verified','limited') then v_uid else verificado_por end,
        fecha_nacimiento_verificada=case when tipo='competidor' and v_state in ('verified','limited') then coalesce(v_dob,fecha_nacimiento_verificada) else fecha_nacimiento_verificada end,actualizado_en=now()
      where id=v_request.perfil_directo_id returning * into v_profile;
      perform public.app_kombax_reconcile_entitlements_v071(v_profile.id,v_uid);
    end if;
    insert into public.kombax_verificacion_eventos(solicitud_id,perfil_directo_id,actor_perfil_id,evento,detalle) values(v_request.id,v_request.perfil_directo_id,v_uid,
      case v_state when 'under_review' then 'review_started' when 'needs_information' then 'information_requested' else v_state end,jsonb_build_object('motivo',v_reason));
    v_result:=jsonb_build_object('id',v_request.id,'estado',v_request.estado,'perfil_directo_id',v_request.perfil_directo_id,'service_activated',false);
  else raise exception 'KOMBAX_PROFILE_OPERATION_NOT_ALLOWED'; end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_perfil_mutate_v072(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_perfil_mutate_v072(text,jsonb,uuid) to authenticated;

-- 043 queda cerrado para que ningún cliente antiguo pueda usar la aprobación con auto-entitlements.
revoke execute on function public.app_kombax_perfil_mutate_v043(text,jsonb,uuid) from authenticated;

notify pgrst,'reload schema';
commit;
