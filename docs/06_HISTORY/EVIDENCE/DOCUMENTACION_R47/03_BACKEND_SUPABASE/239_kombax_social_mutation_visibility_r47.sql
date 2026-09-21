-- KOMBAX 20.101 R47 · Social preference / visibility mutation gateway.
begin;
create or replace function public.app_kombax_social_mutate_v123(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_direct public.perfiles_kombax_directos;v_consent public.kombax_social_minor_consents_v121;v_result jsonb;v_existing public.app_mutation_requests;
  v_post public.kombax_social_publicaciones;v_post_id uuid;v_value smallint;v_audience text;v_target_social uuid;v_target_club uuid;v_match boolean;v_media_bucket text;
  v_include jsonb:=case when jsonb_typeof(p_payload->'audiencia_club_ids')='array' then p_payload->'audiencia_club_ids' else '[]'::jsonb end;
  v_exclude jsonb:=case when jsonb_typeof(p_payload->'audiencia_excluded_club_ids')='array' then p_payload->'audiencia_excluded_club_ids' else '[]'::jsonb end;
  v_profiles jsonb:=case when jsonb_typeof(p_payload->'audiencia_profile_ids')='array' then p_payload->'audiencia_profile_ids' else '[]'::jsonb end;
  v_types jsonb:=case when jsonb_typeof(p_payload->'audiencia_profile_types')='array' then p_payload->'audiencia_profile_types' else '[]'::jsonb end;
  v_item text;v_club uuid;v_social uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;

  if p_operation in ('kombax.social.preferencia','kombax.social.visibilidad') then
    if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null then
      if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
      if v_existing.result is not null then return v_existing.result;end if;
    else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(p_payload->>'club_id','')::uuid,p_operation);end if;
    begin v_post_id:=(p_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;

    if p_operation='kombax.social.preferencia' then
      if not public.app_kombax_social_puede_ver_publicacion_v083(v_post_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
      begin v_value:=coalesce((p_payload->>'valor')::smallint,0);exception when others then raise exception 'KOMBAX_SOCIAL_PREFERENCE_INVALID';end;
      if v_value not in (-1,0,1) then raise exception 'KOMBAX_SOCIAL_PREFERENCE_INVALID';end if;
      delete from public.kombax_social_preferencias_usuario_v237 where user_id=v_uid and publicacion_id=v_post_id;
      if v_value=1 then
        insert into public.kombax_social_likes(publicacion_id,perfil_id) values(v_post_id,v_uid) on conflict do nothing;
      elsif v_value=-1 then
        delete from public.kombax_social_likes where publicacion_id=v_post_id and perfil_id=v_uid;
        insert into public.kombax_social_preferencias_usuario_v237(user_id,publicacion_id,valor) values(v_uid,v_post_id,-1)
          on conflict(user_id,publicacion_id) do update set valor=-1,actualizado_en=now();
      else
        delete from public.kombax_social_likes where publicacion_id=v_post_id and perfil_id=v_uid;
      end if;
      if v_value=1 then
        insert into public.kombax_social_preferencias_usuario_v237(user_id,publicacion_id,valor) values(v_uid,v_post_id,1)
          on conflict(user_id,publicacion_id) do update set valor=1,actualizado_en=now();
      end if;
      v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('publicacion_id',v_post_id,'valor',v_value));
    else
      select * into v_post from public.kombax_social_publicaciones where id=v_post_id for update;
      if v_post.id is null then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
      if not public.app_kombax_social_puede_actuar_v051(v_post.autor_perfil_id) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
      begin v_target_social:=nullif(p_payload->>'audiencia_federacion_social_id','')::uuid;v_target_club:=nullif(p_payload->>'audiencia_club_id','')::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_INVALID';end;
      v_audience:=lower(coalesce(nullif(p_payload->>'audiencia',''),'publica'));
      select exists(select 1 from public.app_kombax_social_audiencias_v083(v_post.autor_perfil_id) a where a.audiencia=v_audience and a.target_social_id is not distinct from v_target_social and a.target_club_id is not distinct from v_target_club) into v_match;
      if not v_match then raise exception 'KOMBAX_POST_AUDIENCE_NOT_ALLOWED';end if;
      if jsonb_array_length(v_include)>50 or jsonb_array_length(v_exclude)>50 or jsonb_array_length(v_profiles)>50 or jsonb_array_length(v_types)>7 then raise exception 'KOMBAX_POST_AUDIENCE_LIMIT';end if;
      if v_audience='clubes_seleccionados' and jsonb_array_length(v_include)<1 then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_REQUIRED';end if;
      if v_audience='kombax_excepto' and jsonb_array_length(v_exclude)<1 then raise exception 'KOMBAX_POST_AUDIENCE_EXCLUSION_REQUIRED';end if;
      if v_audience='perfiles_seleccionados' and jsonb_array_length(v_profiles)<1 then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_REQUIRED';end if;
      if v_audience='tipos_perfil' and jsonb_array_length(v_types)<1 then raise exception 'KOMBAX_POST_AUDIENCE_TYPE_REQUIRED';end if;
      v_media_bucket:=case when v_post.social_media_id is not null then coalesce((select m.storage_bucket from public.kombax_social_media m where m.id=v_post.social_media_id),'kombax-public-media') when v_post.media_id is not null then 'kombax-public-media' else null end;
      if v_post.social_media_id is not null or v_post.media_id is not null then
        if v_audience='publica' and coalesce(v_media_bucket,'kombax-public-media')<>'kombax-public-media' then raise exception 'KOMBAX_PUBLIC_POST_REQUIRES_PUBLIC_MEDIA';end if;
        if v_audience<>'publica' and coalesce(v_media_bucket,'kombax-public-media')<>'kombax-restricted-media' then raise exception 'KOMBAX_RESTRICTED_POST_REQUIRES_PRIVATE_MEDIA';end if;
      end if;
      delete from public.kombax_social_post_visibility_clubs_v235 where post_id=v_post_id;
      delete from public.kombax_social_post_visibility_profiles_v237 where post_id=v_post_id;
      delete from public.kombax_social_post_visibility_types_v237 where post_id=v_post_id;
      if v_audience='clubes_seleccionados' then
        for v_item in select distinct value from jsonb_array_elements_text(v_include) loop
          begin v_club:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_INVALID';end;
          if not exists(select 1 from public.clubes c where c.id=v_club and c.activo) then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_NOT_FOUND';end if;
          insert into public.kombax_social_post_visibility_clubs_v235(post_id,club_id,rule,created_by) values(v_post_id,v_club,'include',v_uid);
        end loop;
      elsif v_audience='kombax_excepto' then
        for v_item in select distinct value from jsonb_array_elements_text(v_exclude) loop
          begin v_club:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_INVALID';end;
          if not exists(select 1 from public.clubes c where c.id=v_club and c.activo) then raise exception 'KOMBAX_POST_AUDIENCE_CLUB_NOT_FOUND';end if;
          insert into public.kombax_social_post_visibility_clubs_v235(post_id,club_id,rule,created_by) values(v_post_id,v_club,'exclude',v_uid);
        end loop;
      elsif v_audience='perfiles_seleccionados' then
        for v_item in select distinct value from jsonb_array_elements_text(v_profiles) loop
          begin v_social:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_INVALID';end;
          if not exists(select 1 from public.kombax_social_perfiles sp where sp.id=v_social and sp.visible and sp.estado='activo') then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_NOT_FOUND';end if;
          insert into public.kombax_social_post_visibility_profiles_v237(post_id,social_id,created_by) values(v_post_id,v_social,v_uid);
        end loop;
      elsif v_audience='tipos_perfil' then
        for v_item in select distinct value from jsonb_array_elements_text(v_types) loop
          if v_item not in ('miembro','club','competidor','marca','federacion','profesional','espectador') then raise exception 'KOMBAX_POST_AUDIENCE_TYPE_INVALID';end if;
          insert into public.kombax_social_post_visibility_types_v237(post_id,profile_type,created_by) values(v_post_id,v_item,v_uid);
        end loop;
      end if;
      update public.kombax_social_publicaciones set audiencia=v_audience,audiencia_club_id=v_target_club,audiencia_federacion_social_id=v_target_social,actualizado_en=now() where id=v_post_id;
      v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('publicacion_id',v_post_id,'audiencia',v_audience,'audiencia_club_id',v_target_club,'audiencia_federacion_social_id',v_target_social));
    end if;
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=v_uid;
    return v_result;
  end if;

  if p_operation='kombax.social.direct.activate' then
    begin select * into v_direct from public.perfiles_kombax_directos where id=(p_payload->>'perfil_directo_id')::uuid and perfil_id=v_uid;exception when others then v_direct.id:=null;end;
    if v_direct.id is not null and v_direct.fecha_nacimiento_verificada is not null and v_direct.fecha_nacimiento_verificada>current_date-interval '18 years' then
      select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.estado='approved' and c.revocado_en is null order by c.actualizado_en desc limit 1;
      if v_consent.id is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';end if;
      if coalesce((p_payload->>'acepta_seguridad_menor')::boolean,false) is not true then raise exception 'KOMBAX_MINOR_SOCIAL_SAFETY_REMINDER_REQUIRED';end if;
    end if;
  end if;
  v_result:=public.app_kombax_social_mutate_v099(p_operation,p_payload,p_request_id);
  if p_operation='kombax.social.publicar' then
    begin v_post_id:=(v_result->'data'->>'id')::uuid;exception when others then raise exception 'KOMBAX_POST_RESULT_INVALID';end;
    v_audience:=lower(coalesce(nullif(p_payload->>'audiencia',''),'publica'));
    if jsonb_array_length(v_profiles)>50 or jsonb_array_length(v_types)>7 then raise exception 'KOMBAX_POST_AUDIENCE_LIMIT';end if;
    if v_audience='perfiles_seleccionados' then
      if jsonb_array_length(v_profiles)<1 then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_REQUIRED';end if;
      for v_item in select distinct value from jsonb_array_elements_text(v_profiles) loop
        begin v_social:=v_item::uuid;exception when others then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_INVALID';end;
        if not exists(select 1 from public.kombax_social_perfiles sp where sp.id=v_social and sp.visible and sp.estado='activo') then raise exception 'KOMBAX_POST_AUDIENCE_PROFILE_NOT_FOUND';end if;
        insert into public.kombax_social_post_visibility_profiles_v237(post_id,social_id,created_by) values(v_post_id,v_social,v_uid) on conflict do nothing;
      end loop;
    elsif v_audience='tipos_perfil' then
      if jsonb_array_length(v_types)<1 then raise exception 'KOMBAX_POST_AUDIENCE_TYPE_REQUIRED';end if;
      for v_item in select distinct value from jsonb_array_elements_text(v_types) loop
        if v_item not in ('miembro','club','competidor','marca','federacion','profesional','espectador') then raise exception 'KOMBAX_POST_AUDIENCE_TYPE_INVALID';end if;
        insert into public.kombax_social_post_visibility_types_v237(post_id,profile_type,created_by) values(v_post_id,v_item,v_uid) on conflict do nothing;
      end loop;
    end if;
  end if;
  if p_operation='kombax.social.direct.activate' and v_consent.id is not null then update public.kombax_social_minor_consents_v121 set minor_safety_ack_at=now(),safety_version='2026-08-23',actualizado_en=now() where id=v_consent.id;end if;
  return v_result;
exception when others then
  if p_operation in ('kombax.social.preferencia','kombax.social.visibilidad') and p_request_id is not null then delete from public.app_mutation_requests where request_id=p_request_id and result is null;end if;
  raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
