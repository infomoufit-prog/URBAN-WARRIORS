begin;
CREATE OR REPLACE FUNCTION public.app_kombax_social_mutate_v053(p_operation text, p_payload jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_actor uuid;v_media_id uuid;v_media public.kombax_social_media;v_post public.kombax_social_publicaciones;v_count integer;v_type text;v_text text;v_mode text;v_path text;v_kind text;v_album boolean;v_old_path text;v_source text;v_source_id uuid;v_src record;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation not in ('kombax.social.media.add','kombax.social.media.remove','kombax.social.media.avatar','kombax.social.media.banner','kombax.social.media.from_album','kombax.social.publicar') then return public.app_kombax_social_mutate_v050(p_operation,p_payload,p_request_id);end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation in ('kombax.social.media.add','kombax.social.media.avatar','kombax.social.media.banner') then
    begin v_actor:=(v_payload->>'social_profile_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_actor) then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN';end if;
    v_kind:=case when p_operation='kombax.social.media.avatar' then 'avatar' when p_operation='kombax.social.media.banner' then 'banner' else lower(coalesce(v_payload->>'tipo','')) end;
    if v_kind not in ('avatar','banner','photo','video') then raise exception 'KOMBAX_SOCIAL_MEDIA_TYPE_INVALID';end if;
    v_path:=v_payload->>'storage_path';if v_path is null or v_path not like v_uid::text||'/social/'||v_actor::text||'/%' then raise exception 'KOMBAX_SOCIAL_MEDIA_PATH_INVALID';end if;
    v_album:=coalesce((v_payload->>'en_album')::boolean,false) and v_kind in ('photo','video');
    if v_kind in ('avatar','banner') then update public.kombax_social_media set estado='removed',actualizado_en=now() where social_profile_id=v_actor and tipo=v_kind and estado in ('active','pending_review') returning storage_path into v_old_path;end if;
    insert into public.kombax_social_media(social_profile_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,en_album,creado_por)
    values(v_actor,v_kind,v_path,lower(v_payload->>'mime_type'),coalesce((v_payload->>'bytes')::bigint,0),nullif(v_payload->>'width','')::integer,nullif(v_payload->>'height','')::integer,nullif(v_payload->>'duration_seconds','')::numeric,v_album,v_uid) returning * into v_media;
    if v_kind='avatar' then update public.kombax_social_perfiles set avatar_path=v_path,actualizado_en=now() where id=v_actor;end if;
    if v_kind='banner' then update public.kombax_social_perfiles set banner_path=v_path,actualizado_en=now() where id=v_actor;end if;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,v_actor,coalesce(sp.club_id,i.club_origen_id),'social.media.'||v_kind,'social_media',v_media.id,jsonb_build_object('en_album',v_album) from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id where sp.id=v_actor;
    v_result:=to_jsonb(v_media)||jsonb_build_object('old_storage_path',v_old_path);

  elsif p_operation='kombax.social.media.from_album' then
    begin v_actor:=(v_payload->>'social_profile_id')::uuid;v_source_id:=(v_payload->>'source_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_ALBUM_SOURCE_INVALID';end;
    if not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_actor) then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN';end if;
    v_source:=lower(coalesce(v_payload->>'source_type',''));
    if v_source='club' then
      select cm.tipo,cm.storage_path,cm.mime_type,cm.bytes,cm.width,cm.height,cm.duration_seconds into v_src
      from public.kombax_club_media cm join public.kombax_social_perfiles sp on sp.id=v_actor and sp.sujeto_tipo='club' and sp.club_id=cm.club_id
      where cm.id=v_source_id and cm.estado='active';
    elsif v_source='perfil_directo' then
      select pm.tipo,pm.storage_path,pm.mime_type,pm.bytes,pm.width,pm.height,pm.duration_seconds into v_src
      from public.kombax_perfil_media pm join public.kombax_social_perfiles sp on sp.id=v_actor and sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=pm.perfil_directo_id
      where pm.id=v_source_id and pm.estado='active';
    else raise exception 'KOMBAX_SOCIAL_ALBUM_SOURCE_TYPE_INVALID';end if;
    if v_src.storage_path is null or v_src.tipo not in ('photo','video') then raise exception 'KOMBAX_SOCIAL_ALBUM_SOURCE_NOT_FOUND';end if;
    select * into v_media from public.kombax_social_media where social_profile_id=v_actor and storage_path=v_src.storage_path and estado='active' limit 1;
    if v_media.id is null then
      insert into public.kombax_social_media(social_profile_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,en_album,creado_por)
      values(v_actor,v_src.tipo,v_src.storage_path,v_src.mime_type,v_src.bytes,v_src.width,v_src.height,v_src.duration_seconds,false,v_uid) returning * into v_media;
    end if;
    v_result:=to_jsonb(v_media);

  elsif p_operation='kombax.social.media.remove' then
    begin v_media_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_MEDIA_ID_INVALID';end;
    select * into v_media from public.kombax_social_media where id=v_media_id for update;if v_media.id is null or not public.app_kombax_social_puede_gestionar_perfil_publico_r117(v_media.social_profile_id) then raise exception 'KOMBAX_SOCIAL_MEDIA_NOT_OWNED';end if;
    update public.kombax_social_media set estado='removed',actualizado_en=now() where id=v_media_id returning * into v_media;
    update public.kombax_social_perfiles set avatar_path=case when avatar_path=v_media.storage_path then null else avatar_path end,banner_path=case when banner_path=v_media.storage_path then null else banner_path end,actualizado_en=now() where id=v_media.social_profile_id;
    v_result:=jsonb_build_object('id',v_media.id,'storage_path',v_media.storage_path,'estado',v_media.estado);

  elsif p_operation='kombax.social.publicar' then
    begin v_actor:=(v_payload->>'autor_perfil_id')::uuid;v_media_id:=nullif(v_payload->>'social_media_id','')::uuid;exception when others then raise exception 'KOMBAX_POST_PROFILE_OR_MEDIA_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and estado='activa';if v_count>=30 then raise exception 'KOMBAX_POST_ACTIVE_LIMIT_30';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and creado_en>=date_trunc('day',now()) and estado<>'retirada';if v_count>=3 then raise exception 'KOMBAX_POST_DAILY_LIMIT_3';end if;
    if v_media_id is not null then
      if not exists(select 1 from public.kombax_social_media m where m.id=v_media_id and m.social_profile_id=v_actor and m.estado='active' and m.tipo in ('photo','video')) then raise exception 'KOMBAX_POST_MEDIA_NOT_OWNED';end if;
      if exists(select 1 from public.kombax_social_media where id=v_media_id and tipo='video') then select count(*) into v_count from public.kombax_social_publicaciones p join public.kombax_social_media m on m.id=p.social_media_id where p.autor_perfil_id=v_actor and p.estado='activa' and m.tipo='video';if v_count>=10 then raise exception 'KOMBAX_POST_VIDEO_ACTIVE_LIMIT_10';end if;end if;
    end if;
    v_type:=lower(coalesce(v_payload->>'tipo','actualizacion'));if v_type not in ('actualizacion','resultado','evento','oportunidad') then raise exception 'KOMBAX_POST_TYPE_INVALID';end if;
    v_text:=btrim(coalesce(v_payload->>'texto',''));if char_length(v_text)<1 or char_length(v_text)>1500 then raise exception 'KOMBAX_POST_TEXT_INVALID';end if;
    v_mode:=lower(coalesce(v_payload->>'comentarios_estado','open'));if v_mode not in ('open','verified_only','closed') then raise exception 'KOMBAX_COMMENT_MODE_INVALID';end if;
    insert into public.kombax_social_publicaciones(autor_perfil_id,tipo,texto,comentarios_estado,social_media_id) values(v_actor,v_type,v_text,v_mode,v_media_id) returning * into v_post;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,v_actor,coalesce(sp.club_id,i.club_origen_id),'social.publish','social_post',v_post.id,jsonb_build_object('tipo',v_type,'media',v_media_id is not null) from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id where sp.id=v_actor;
    v_result:=to_jsonb(v_post);
  end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $function$
;
drop function if exists private.kombax_social_album_remove_r271(uuid);
commit;

