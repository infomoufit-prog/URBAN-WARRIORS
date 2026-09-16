-- KOMBAX 20.101 R22 · Performance / scale / Fight Card hierarchy / album quota
begin;

alter table public.kombax_evento_combates_publicos
  add column if not exists co_estelar boolean not null default false;
create unique index if not exists uq_kombax_evento_one_co_main_r22
  on public.kombax_evento_combates_publicos(evento_id)
  where co_estelar=true and estado<>'cancelado';

-- Discovery index for the public first viewport / incremental loading path.
create index if not exists idx_kombax_eventos_publicos_discovery_r22
  on public.kombax_eventos_publicos(fecha_inicio,id)
  where visibilidad='publico' and estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado');

-- R22: official album is 30 uploaded photos. Poster/banner and participant/fighter
-- photos are stored outside kombax_evento_media, therefore they never consume this quota.
create or replace function public.app_kombax_evento_media_cuota_v175(p_evento_id uuid,p_workspace_club_id uuid default null)
returns table(fotos_usadas integer,fotos_limite integer,videos_usados integer,videos_limite integer,max_video_seconds integer,max_video_bytes bigint)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false;
begin
 if auth.uid() is null then return; end if;
 if p_workspace_club_id is not null then
   select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
 else v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 if not coalesce(v_manage,false) then return; end if;
 return query select
   count(*) filter(where m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'image/%')::integer,
   30,
   count(*) filter(where m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'video/%')::integer,
   5,60,104857600::bigint
 from public.kombax_evento_media m where m.evento_id=p_evento_id;
end $$;
revoke all on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) to authenticated;

-- Same idempotent gateway contract as 20.099, with the intentional R22 album limit 30.
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
   perform pg_advisory_xact_lock(hashtextextended(v_event_id::text,2010122));
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
       if v_used>=30 then raise exception 'EVENT_PHOTO_LIMIT_REACHED'; end if;
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

-- One HTTP roundtrip for detail: base detail + R21 framing + media + engagement + scoped management.
create or replace function public.app_kombax_evento_bundle_v189(p_evento_id uuid,p_workspace_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_media jsonb;v_eng jsonb;v_manage boolean:=false;
begin
 v_base:=public.app_kombax_evento_publico_detalle_v178(p_evento_id);
 if v_base is null then return null; end if;
 select coalesce(jsonb_agg(to_jsonb(m) || jsonb_build_object('media_presentation',coalesce(em.media_presentation,'{}'::jsonb)) order by m.orden,m.creado_en desc),'[]'::jsonb)
   into v_media
 from public.app_kombax_evento_media_v175(p_evento_id,p_workspace_club_id) m
 left join public.kombax_evento_media em on em.id=m.id;
 select to_jsonb(x) into v_eng from public.app_kombax_evento_engagement_v162(p_evento_id) x limit 1;
 if auth.uid() is not null then
   if p_workspace_club_id is not null then select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
   else v_manage:=coalesce((v_base->>'can_manage')::boolean,false); end if;
 end if;
 return v_base || jsonb_build_object('media',coalesce(v_media,'[]'::jsonb),'engagement',coalesce(v_eng,'null'::jsonb),'can_manage',coalesce(v_manage,false));
end $$;
revoke all on function public.app_kombax_evento_bundle_v189(uuid,uuid) from public;
grant execute on function public.app_kombax_evento_bundle_v189(uuid,uuid) to anon,authenticated;

-- R22 top-level mutation wrapper: 30 fights + explicit Co-Main role.
create or replace function public.app_kombax_eventos_mutate_v189(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_event uuid;v_result jsonb;v_fight uuid;v_count integer;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_operation='event.fight.save' then
   v_event:=nullif(v_payload->>'evento_id','')::uuid;
   if v_event is null then raise exception 'EVENT_REQUIRED'; end if;
   if nullif(v_payload->>'id','') is null then
     perform pg_advisory_xact_lock(hashtextextended(v_event::text,2010130));
     select count(*)::integer into v_count from public.kombax_evento_combates_publicos where evento_id=v_event and estado<>'cancelado';
     if v_count>=30 then raise exception 'EVENT_FIGHT_LIMIT_REACHED'; end if;
   end if;
 end if;
 v_result:=public.app_kombax_eventos_mutate_v181(p_operation,v_payload,p_request_id);
 if p_operation='event.fight.save' then
   v_fight:=nullif(v_result#>>'{data,id}','')::uuid;v_event:=nullif(v_result#>>'{data,evento_id}','')::uuid;
   if v_fight is not null and v_event is not null then
     if coalesce((v_payload->>'destacado')::boolean,false) then
       update public.kombax_evento_combates_publicos set co_estelar=false,actualizado_en=now() where id=v_fight and co_estelar=true;
     elsif coalesce((v_payload->>'co_estelar')::boolean,false) then
       update public.kombax_evento_combates_publicos set co_estelar=false,actualizado_en=now() where evento_id=v_event and id<>v_fight and co_estelar=true;
       update public.kombax_evento_combates_publicos set co_estelar=true,actualizado_en=now() where id=v_fight;
     elsif v_payload ? 'co_estelar' then
       update public.kombax_evento_combates_publicos set co_estelar=false,actualizado_en=now() where id=v_fight;
     end if;
     select jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(f)-'creado_por') into v_result from public.kombax_evento_combates_publicos f where f.id=v_fight;
     update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
   end if;
 end if;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v189(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v189(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
