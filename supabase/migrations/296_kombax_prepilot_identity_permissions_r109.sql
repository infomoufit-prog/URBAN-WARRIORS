-- KOMBAX R109 / build 20162 · cierre de identidad y permisos pre-piloto.
-- Incremental: conserva R100-R108 y corrige gates contradictorios sin crear identidades paralelas.
begin;

-- 1) Competidor no se fija desde metadata autocontrolable del signup.
--    La intención permanece en frontend y el tipo queda bloqueado al crear la solicitud/perfil directo.
create or replace function public.app_kombax_account_type_on_signup_r100()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_type text:=lower(btrim(coalesce(new.raw_user_meta_data->>'kombax_account_type','')));
begin
  if v_type in ('club','marca','federacion','profesional','media') then
    insert into public.kombax_account_types_r100(user_id,account_type)
    values(new.id,v_type) on conflict(user_id) do nothing;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_account_type_on_signup_r100() from public,anon,authenticated;

-- 2) Media: reutiliza el validador canónico, con evidencia proporcional y documento opcional.
create or replace function public.app_kombax_application_validate_v072(p_solicitud_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_req public.kombax_solicitudes_alta; v_direct public.perfiles_kombax_directos;
  v_docs integer:=0; v_dob date; v_age integer; v_identity public.identidades_sociales; v_socio public.socios;
  v_pub jsonb; v_ver jsonb;
  v_need text[]:='{}'::text[];
begin
  select * into v_req from public.kombax_solicitudes_alta where id=p_solicitud_id;
  if v_req.id is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND'; end if;
  if v_req.tipo not in ('club','competidor','marca','federacion','media') then raise exception 'KOMBAX_APPLICATION_TYPE_NOT_OPEN'; end if;
  if not coalesce(v_req.declaracion_aceptada,false) then raise exception 'KOMBAX_DECLARATION_REQUIRED'; end if;
  select count(*) into v_docs from public.kombax_verificacion_documentos d where d.solicitud_id=v_req.id and d.estado='active';
  if v_req.tipo<>'media' and v_docs<1 then raise exception 'KOMBAX_VERIFICATION_DOCUMENT_REQUIRED'; end if;
  v_pub:=coalesce(v_req.datos_publicos,'{}'::jsonb); v_ver:=coalesce(v_req.datos_verificacion,'{}'::jsonb);

  if v_req.tipo='competidor' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    select * into v_direct from public.perfiles_kombax_directos where id=v_req.perfil_directo_id and tipo='competidor';
    if v_direct.id is null then raise exception 'KOMBAX_COMPETITOR_PROFILE_REQUIRED'; end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email',''))='' or position('@' in coalesce(v_ver->>'email',''))<2 then v_need:=array_append(v_need,'email'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;
    if v_direct.origen_identidad_social_id is not null then
      select * into v_identity from public.identidades_sociales where id=v_direct.origen_identidad_social_id and perfil_id=v_req.perfil_id and estado='activa';
      if v_identity.id is null then raise exception 'KOMBAX_COMPETITOR_MEMBER_IDENTITY_INVALID'; end if;
      select * into v_socio from public.socios where id=v_identity.socio_origen_id and club_id=v_identity.club_origen_id and estado='activo';
      if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'KOMBAX_COMPETITOR_AGE_MUST_BE_CLUB_VERIFIED'; end if;
      v_dob:=v_socio.fecha_nacimiento;
    else
      begin v_dob:=nullif(v_ver->>'fecha_nacimiento','')::date; exception when others then v_dob:=null; end;
      if v_dob is null then v_need:=array_append(v_need,'fecha_nacimiento'); end if;
    end if;
    if v_dob is not null then
      v_age:=extract(year from age(current_date,v_dob))::integer;
      if v_age<16 then raise exception 'KOMBAX_COMPETITOR_MIN_AGE_16'; end if;
    end if;

  elsif v_req.tipo='marca' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    if btrim(coalesce(v_pub->>'categoria',''))='' then v_need:=array_append(v_need,'categoria'); end if;
    if btrim(coalesce(v_pub->>'web_publica','')) !~* '^https://[^[:space:]]+$' then v_need:=array_append(v_need,'web_publica_https'); end if;
    if btrim(coalesce(v_ver->>'razon_social',''))='' then v_need:=array_append(v_need,'razon_social'); end if;
    if btrim(coalesce(v_ver->>'email_corporativo',''))='' or position('@' in coalesce(v_ver->>'email_corporativo',''))<2 then v_need:=array_append(v_need,'email_corporativo'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;

  elsif v_req.tipo='federacion' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    if btrim(coalesce(v_pub->>'pais',''))='' then v_need:=array_append(v_need,'pais'); end if;
    if btrim(coalesce(v_pub->>'territorio',''))='' then v_need:=array_append(v_need,'territorio'); end if;
    if btrim(coalesce(v_pub->>'web_publica','')) !~* '^https://[^[:space:]]+$' then v_need:=array_append(v_need,'web_publica_https'); end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email_oficial',''))='' or position('@' in coalesce(v_ver->>'email_oficial',''))<2 then v_need:=array_append(v_need,'email_oficial'); end if;
    if btrim(coalesce(v_ver->>'registro_entidad',''))='' then v_need:=array_append(v_need,'registro_entidad'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;

  elsif v_req.tipo='media' then
    if v_req.perfil_directo_id is null then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED'; end if;
    if not exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=v_req.perfil_directo_id and d.perfil_id=v_req.perfil_id and d.tipo='media'
    ) then raise exception 'KOMBAX_MEDIA_PROFILE_REQUIRED'; end if;
    -- Media usa evidencia proporcional: portfolio, referencias, web/redes o actividad pública.
    -- El documento privado es opcional y puede añadirse si KOMBAX solicita información adicional.
    if char_length(btrim(coalesce(v_ver->>'evidencia','')))<8 then v_need:=array_append(v_need,'evidencia'); end if;

  elsif v_req.tipo='club' then
    if btrim(coalesce(v_pub->>'ubicacion',''))='' then v_need:=array_append(v_need,'ubicacion'); end if;
    if jsonb_typeof(coalesce(v_pub->'disciplinas','[]'::jsonb))<>'array' or jsonb_array_length(coalesce(v_pub->'disciplinas','[]'::jsonb))<1 then v_need:=array_append(v_need,'disciplinas'); end if;
    if btrim(coalesce(v_ver->>'nombre_legal',''))='' then v_need:=array_append(v_need,'nombre_legal'); end if;
    if btrim(coalesce(v_ver->>'email_oficial',''))='' or position('@' in coalesce(v_ver->>'email_oficial',''))<2 then v_need:=array_append(v_need,'email_oficial'); end if;
    if btrim(coalesce(v_ver->>'responsable',''))='' then v_need:=array_append(v_need,'responsable'); end if;
    if btrim(coalesce(v_ver->>'rol_responsable',''))='' then v_need:=array_append(v_need,'rol_responsable'); end if;
    if btrim(coalesce(v_ver->>'evidencia',''))='' then v_need:=array_append(v_need,'evidencia'); end if;
  end if;

  if cardinality(v_need)>0 then raise exception 'KOMBAX_APPLICATION_FIELDS_REQUIRED:%',array_to_string(v_need,','); end if;
  return jsonb_build_object('valid',true,'tipo',v_req.tipo,'documentos',v_docs,'fecha_nacimiento_verificada',v_dob,'edad',v_age,'schema_version',v_req.schema_version);
end $$;

revoke all on function public.app_kombax_application_validate_v072(uuid) from public,anon,authenticated;

-- 3) Media: persiste declaración/requisitos para que submit/review existentes sean utilizables.
create or replace function public.app_kombax_perfil_mutate_r58(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_type text:=lower(btrim(coalesce(p_payload->>'tipo','')));v_name text;v_slug text;v_id uuid;v_profile public.perfiles_kombax_directos;v_request public.kombax_solicitudes_alta;v_result jsonb;v_decl boolean;
begin
  if v_type<>'media' or p_operation not in ('kombax.profile.save','kombax.application.save') then
    return public.app_kombax_perfil_mutate_v196(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  v_name:=btrim(coalesce(p_payload->>'nombre_publico',''));if char_length(v_name)<2 or char_length(v_name)>160 then raise exception 'KOMBAX_PROFILE_NAME_INVALID';end if;
  if p_operation='kombax.profile.save' then
    begin v_id:=nullif(coalesce(p_payload->>'id',p_payload->>'perfil_directo_id'),'')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_id is null then
      v_slug:=public.app_kombax_slug_v043(coalesce(nullif(p_payload->>'slug',''),v_name));if exists(select 1 from public.perfiles_kombax_directos where slug=v_slug) then v_slug:=left(v_slug,50)||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);end if;
      insert into public.perfiles_kombax_directos(perfil_id,tipo,slug,nombre_publico,descripcion,workflow_estado,ubicacion,disciplinas,categoria,club_declarado,web_publica,publico)
      values(v_uid,'media',v_slug,v_name,left(nullif(btrim(p_payload->>'descripcion'),''),1600),'draft',left(nullif(btrim(p_payload->>'ubicacion'),''),160),
        coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),left(nullif(btrim(p_payload->>'categoria'),''),120),null,nullif(btrim(p_payload->>'web_publica'),''),false) returning * into v_profile;
      insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen) values('perfil_directo',v_profile.id,'profile.direct.manage',true,'manual') on conflict do nothing;
    else
      update public.perfiles_kombax_directos set nombre_publico=v_name,descripcion=left(nullif(btrim(p_payload->>'descripcion'),''),1600),ubicacion=left(nullif(btrim(p_payload->>'ubicacion'),''),160),
        disciplinas=coalesce(array(select jsonb_array_elements_text(coalesce(p_payload->'disciplinas','[]'::jsonb)) limit 12),'{}'::text[]),categoria=left(nullif(btrim(p_payload->>'categoria'),''),120),web_publica=nullif(btrim(p_payload->>'web_publica'),''),actualizado_en=now()
      where id=v_id and perfil_id=v_uid and tipo='media' and workflow_estado not in ('under_review','verified','suspended') returning * into v_profile;
      if v_profile.id is null then raise exception 'KOMBAX_PROFILE_NOT_EDITABLE';end if;
    end if;
    v_result:=to_jsonb(v_profile);
  else
    begin v_id:=nullif(p_payload->>'perfil_directo_id','')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
    if v_id is null or not exists(select 1 from public.perfiles_kombax_directos where id=v_id and perfil_id=v_uid and tipo='media') then raise exception 'KOMBAX_DIRECT_PROFILE_REQUIRED';end if;
    v_decl:=coalesce((p_payload->>'declaracion_aceptada')::boolean,false);
    insert into public.kombax_solicitudes_alta(perfil_id,tipo,perfil_directo_id,nombre_publico,datos_publicos,datos_verificacion,estado,schema_version,declaracion_aceptada,declaracion_en,requisitos_version)
    values(v_uid,'media',v_id,v_name,coalesce(p_payload->'datos_publicos','{}'::jsonb),coalesce(p_payload->'datos_verificacion','{}'::jsonb),'draft',4,v_decl,case when v_decl then now() else null end,'media-r109-v1')
    on conflict(perfil_id,tipo) where estado in ('draft','submitted','under_review','needs_information') do update
      set nombre_publico=excluded.nombre_publico,perfil_directo_id=excluded.perfil_directo_id,datos_publicos=excluded.datos_publicos,datos_verificacion=excluded.datos_verificacion,
          declaracion_aceptada=excluded.declaracion_aceptada,declaracion_en=case when excluded.declaracion_aceptada then coalesce(public.kombax_solicitudes_alta.declaracion_en,now()) else null end,
          schema_version=4,requisitos_version='media-r109-v1',actualizado_en=now()
    returning * into v_request;v_result:=to_jsonb(v_request)-'datos_verificacion';
  end if;
  return jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',v_result);
end $$;

revoke all on function public.app_kombax_perfil_mutate_r58(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_perfil_mutate_r58(text,jsonb,uuid) to authenticated;

-- 4) Publicación Social: Miembro conserva membresía; Competidor y Profesional son autónomos tras verificación y edad.
create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i
        join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        where i.id=sp.identidad_social_id and i.perfil_id=auth.uid()
          and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=14
      ))
      or (sp.sujeto_tipo='club'
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.publish')
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid()
          and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion','media')
            or (d.tipo='competidor' and d.fecha_nacimiento_verificada is not null
                and d.fecha_nacimiento_verificada<=current_date-interval '16 years')
            or (d.tipo='profesional' and exists(
              select 1 from public.kombax_perfil_persona_privada_v196 p
              where p.perfil_directo_id=d.id and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18
            ))
          )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_social_puede_actuar_v051(p_social_id);
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

-- 5) Contacto mantiene 18+ para personas, ya sin dependencia de Club.
create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.contacto_habilitado and (
      sp.sujeto_tipo='club'
      or (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        where i.id=sp.identidad_social_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=18
      ))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo and (
          d.tipo in ('marca','federacion','media')
          or (d.tipo='competidor' and d.fecha_nacimiento_verificada is not null
              and d.fecha_nacimiento_verificada<=current_date-interval '18 years')
          or (d.tipo='profesional' and exists(
            select 1 from public.kombax_perfil_persona_privada_v196 p
            where p.perfil_directo_id=d.id and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18
          ))
        )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

-- 6) Activación Social directa usa edad individual verificada/privada, no afiliación a Club.
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
    if v_direct.tipo='profesional' and not exists(select 1 from public.kombax_perfil_persona_privada_v196 p where p.perfil_directo_id=v_direct.id and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18) then raise exception 'KOMBAX_SOCIAL_PROFESSIONAL_AGE_REQUIRED';end if;
    if v_direct.tipo='competidor' and (v_direct.fecha_nacimiento_verificada is null or v_direct.fecha_nacimiento_verificada>current_date-interval '16 years') then raise exception 'KOMBAX_SOCIAL_COMPETITOR_VERIFIED_AGE_REQUIRED';end if;
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
