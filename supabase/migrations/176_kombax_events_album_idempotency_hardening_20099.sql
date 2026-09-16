-- KOMBAX RC13 build 20.099 · 176 · Event Album idempotency hardening
begin;
create or replace function public.app_kombax_eventos_mutate_v175(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_event_id uuid;v_media_id uuid;v_media public.kombax_evento_media;
 v_mime text;v_momento text;v_bytes bigint;v_width integer;v_height integer;v_duration numeric;v_used integer;v_is_image boolean;v_is_video boolean;
begin
 if p_operation not in ('event.media.register','event.media.update') then return public.app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id); end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 end if;
 v_momento:=coalesce(nullif(lower(btrim(v_payload->>'momento')),''),'evento');
 if v_momento not in ('previo','evento','posterior') then raise exception 'EVENT_MEDIA_MOMENT_INVALID'; end if;
 if p_operation='event.media.register' then
   v_event_id:=nullif(v_payload->>'evento_id','')::uuid;v_media_id:=nullif(v_payload->>'media_id','')::uuid;
   if v_event_id is null or v_media_id is null then raise exception 'EVENT_MEDIA_ID_REQUIRED'; end if;
   perform pg_advisory_xact_lock(hashtextextended(v_event_id::text,20099));
   v_mime:=lower(btrim(coalesce(v_payload->>'mime_type','')));v_is_image:=v_mime like 'image/%';v_is_video:=v_mime like 'video/%';
   if coalesce(v_payload->>'tipo','')='video_externo' then
     v_result:=public.app_kombax_eventos_mutate_v173(p_operation,v_payload || jsonb_build_object('momento',v_momento),p_request_id);
     update public.kombax_evento_media set momento=v_momento where id=v_media_id returning * into v_media;
   else
     if not v_is_image and not v_is_video then raise exception 'EVENT_MEDIA_MIME_INVALID'; end if;
     v_bytes:=nullif(v_payload->>'bytes','')::bigint;v_width:=nullif(v_payload->>'width','')::integer;v_height:=nullif(v_payload->>'height','')::integer;v_duration:=nullif(v_payload->>'duration_seconds','')::numeric;
     if v_bytes is null or v_bytes<1 then raise exception 'EVENT_MEDIA_BYTES_REQUIRED'; end if;
     if v_width is null or v_height is null or v_width<1 or v_height<1 then raise exception 'EVENT_MEDIA_DIMENSIONS_REQUIRED'; end if;
     if v_is_image then
       if v_bytes>8388608 then raise exception 'EVENT_PHOTO_TOO_LARGE'; end if;
       select count(*)::integer into v_used from public.kombax_evento_media m where m.evento_id=v_event_id and m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'image/%';
       if v_used>=15 then raise exception 'EVENT_PHOTO_LIMIT_REACHED'; end if;
     else
       if v_bytes>104857600 then raise exception 'EVENT_VIDEO_TOO_LARGE'; end if;
       if v_duration is null or v_duration<=0 or v_duration>60.2 then raise exception 'EVENT_VIDEO_DURATION_INVALID'; end if;
       if greatest(v_width,v_height)>1920 or least(v_width,v_height)>1080 then raise exception 'EVENT_VIDEO_RESOLUTION_INVALID'; end if;
       select count(*)::integer into v_used from public.kombax_evento_media m where m.evento_id=v_event_id and m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'video/%';
       if v_used>=5 then raise exception 'EVENT_VIDEO_LIMIT_REACHED'; end if;
     end if;
     v_result:=public.app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id);
     update public.kombax_evento_media set momento=v_momento,bytes=v_bytes,width=v_width,height=v_height,duration_seconds=case when v_is_video then v_duration else null end,actualizado_en=now() where id=v_media_id returning * into v_media;
   end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');
   update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
   return v_result;
 end if;
 v_result:=public.app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id);v_media_id:=nullif(v_payload->>'media_id','')::uuid;
 if v_media_id is not null and v_payload ? 'momento' then
   update public.kombax_evento_media set momento=v_momento,actualizado_en=now() where id=v_media_id returning * into v_media;
   if v_media.id is not null then v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;end if;
 end if;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) to authenticated;
comment on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) is '20.099 album gateway: request-id idempotency checked before quota lock; 15 photos + 5 uploaded videos per event.';
notify pgrst,'reload schema';
commit;
