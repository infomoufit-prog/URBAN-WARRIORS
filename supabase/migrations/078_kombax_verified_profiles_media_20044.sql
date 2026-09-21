-- KOMBAX RC13 build 20044 · 078 · kombax verified profiles media

begin;

-- Media final: gestores, perfil verificado y servicio activo; avatar/banner + álbum según plan.
create or replace function public.app_kombax_media_mutate_v072(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_profile uuid;v_id uuid;v_media public.kombax_perfil_media;v_type text;v_path text;v_mime text;v_bytes bigint;v_duration numeric;v_state text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if; if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if; if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation); end if;
  if p_operation='kombax.media.add' then
    v_profile:=public.app_kombax_uuid_or_null_v070(v_payload->>'perfil_directo_id');
    if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'edit') then raise exception 'KOMBAX_PROFILE_MEDIA_FORBIDDEN'; end if;
    if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.workflow_estado in ('verified','limited') and d.verificacion_estado='verificado' and d.estado='activo' and public.app_kombax_perfil_servicio_activo_v071(d.id)) then raise exception 'KOMBAX_PROFILE_SERVICE_REQUIRED'; end if;
    v_type:=lower(btrim(coalesce(v_payload->>'tipo',''))); if v_type not in ('avatar','banner','photo','video') then raise exception 'KOMBAX_MEDIA_TYPE_INVALID'; end if;
    v_path:=btrim(coalesce(v_payload->>'storage_path','')); if v_path='' or split_part(v_path,'/',1)<>v_uid::text or split_part(v_path,'/',2)<>v_profile::text then raise exception 'KOMBAX_MEDIA_PATH_INVALID'; end if;
    v_mime:=lower(btrim(coalesce(v_payload->>'mime_type',''))); begin v_bytes:=(v_payload->>'bytes')::bigint; exception when others then raise exception 'KOMBAX_MEDIA_SIZE_INVALID'; end;
    begin v_duration:=nullif(v_payload->>'duration_seconds','')::numeric; exception when others then raise exception 'KOMBAX_MEDIA_DURATION_INVALID'; end;
    if v_type='video' and (v_duration is null or v_duration<=0 or v_duration>15) then raise exception 'KOMBAX_VIDEO_MAX_15_SECONDS'; end if;
    if v_type in ('avatar','banner') then update public.kombax_perfil_media set estado='removed',actualizado_en=now() where perfil_directo_id=v_profile and tipo=v_type and estado in ('active','pending_review'); end if;
    insert into public.kombax_perfil_media(perfil_directo_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,position,estado,creado_por)
    values(v_profile,v_type,v_path,v_mime,v_bytes,nullif(v_payload->>'width','')::integer,nullif(v_payload->>'height','')::integer,v_duration,coalesce(nullif(v_payload->>'position','')::integer,0),'active',v_uid) returning * into v_media;
    if v_type='avatar' then update public.perfiles_kombax_directos set avatar_path=v_path,actualizado_en=now() where id=v_profile; elsif v_type='banner' then update public.perfiles_kombax_directos set banner_path=v_path,actualizado_en=now() where id=v_profile; end if;
    v_result:=to_jsonb(v_media);
  elsif p_operation='kombax.media.remove' then
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'media_id'); select m.* into v_media from public.kombax_perfil_media m where m.id=v_id for update;
    if v_media.id is null or (not public.app_kombax_puede_gestionar_perfil_v070(v_media.perfil_directo_id,'edit') and not public.app_kombax_es_moderador_v041()) then raise exception 'KOMBAX_MEDIA_NOT_FOUND'; end if;
    update public.kombax_perfil_media set estado='removed',actualizado_en=now() where id=v_id returning * into v_media;
    update public.perfiles_kombax_directos set avatar_path=case when avatar_path=v_media.storage_path then null else avatar_path end,banner_path=case when banner_path=v_media.storage_path then null else banner_path end,actualizado_en=now() where id=v_media.perfil_directo_id;
    v_result:=jsonb_build_object('id',v_media.id,'storage_path',v_media.storage_path,'estado',v_media.estado);
  elsif p_operation='kombax.media.moderate' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED'; end if;
    v_id:=public.app_kombax_uuid_or_null_v070(v_payload->>'media_id');v_state:=lower(btrim(coalesce(v_payload->>'estado',''))); if v_state not in ('active','hidden','removed') then raise exception 'KOMBAX_MEDIA_STATE_INVALID'; end if;
    update public.kombax_perfil_media set estado=v_state,moderacion_motivo=left(nullif(btrim(v_payload->>'motivo'),''),1000),actualizado_en=now() where id=v_id returning * into v_media; if v_media.id is null then raise exception 'KOMBAX_MEDIA_NOT_FOUND'; end if;
    v_result:=jsonb_build_object('id',v_media.id,'estado',v_media.estado);
  else raise exception 'KOMBAX_MEDIA_OPERATION_NOT_ALLOWED'; end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb)); update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id; return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) to authenticated;
revoke execute on function public.app_kombax_media_mutate_v043(text,jsonb,uuid) from authenticated;

notify pgrst,'reload schema';
commit;
