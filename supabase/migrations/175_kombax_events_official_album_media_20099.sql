-- KOMBAX RC13 build 20.099 · 175 · Official Event Album + HD Clips
-- 15 fotos totales por evento + 5 vídeos almacenados, clips <=60s y <=1080p.
-- El álbum vive antes/durante/después del evento mediante momento=previo|evento|posterior.
begin;

update storage.buckets
set public=false,
    file_size_limit=104857600,
    allowed_mime_types=array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[]
where id='kombax-events-media';

alter table public.kombax_evento_media
  add column if not exists momento text not null default 'evento',
  add column if not exists bytes bigint,
  add column if not exists width integer,
  add column if not exists height integer,
  add column if not exists duration_seconds numeric(8,3);

do $$ begin
  if not exists(select 1 from pg_constraint where conname='kombax_evento_media_momento_ck') then
    alter table public.kombax_evento_media add constraint kombax_evento_media_momento_ck check(momento in ('previo','evento','posterior'));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_evento_media_bytes_ck') then
    alter table public.kombax_evento_media add constraint kombax_evento_media_bytes_ck check(bytes is null or bytes between 1 and 104857600);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_evento_media_dimensions_ck') then
    alter table public.kombax_evento_media add constraint kombax_evento_media_dimensions_ck check((width is null and height is null) or (width between 1 and 8192 and height between 1 and 8192));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_evento_media_duration_ck') then
    alter table public.kombax_evento_media add constraint kombax_evento_media_duration_ck check(duration_seconds is null or duration_seconds between 0.01 and 60.2);
  end if;
end $$;

create index if not exists idx_kombax_evento_media_quota_20099
  on public.kombax_evento_media(evento_id,mime_type,estado,id)
  where estado<>'retirado';
create index if not exists idx_kombax_evento_media_album_momento_20099
  on public.kombax_evento_media(evento_id,momento,orden,creado_en desc,id)
  where estado<>'retirado';

create or replace function public.app_kombax_evento_media_v175(p_evento_id uuid,p_workspace_club_id uuid default null)
returns table(
 id uuid,evento_id uuid,combate_id uuid,competidor_social_profile_id uuid,tipo text,storage_bucket text,storage_path text,external_url text,
 mime_type text,titulo text,descripcion text,estado text,destacado boolean,allow_download boolean,orden smallint,expires_at timestamptz,creado_en timestamptz,
 momento text,bytes bigint,width integer,height integer,duration_seconds numeric
) language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false;v_public boolean:=false;
begin
 if auth.uid() is not null then
   if p_workspace_club_id is not null then
     select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
   else
     v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id);
   end if;
 end if;
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_evento_id and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')) into v_public;
 if not coalesce(v_manage,false) and not v_public then return; end if;
 return query
 select m.id,m.evento_id,m.combate_id,m.competidor_social_profile_id,m.tipo,m.storage_bucket,m.storage_path,m.external_url,m.mime_type,m.titulo,m.descripcion,m.estado,m.destacado,m.allow_download,m.orden,m.expires_at,m.creado_en,
        m.momento,m.bytes,m.width,m.height,m.duration_seconds
 from public.kombax_evento_media m
 where m.evento_id=p_evento_id
   and (coalesce(v_manage,false) or (m.estado='visible' and (m.expires_at is null or m.expires_at>now())))
 order by case m.momento when 'previo' then 1 when 'evento' then 2 else 3 end,m.destacado desc,m.orden,m.creado_en desc,m.id;
end $$;
revoke all on function public.app_kombax_evento_media_v175(uuid,uuid) from public;
grant execute on function public.app_kombax_evento_media_v175(uuid,uuid) to anon,authenticated;

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
   15,
   count(*) filter(where m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'video/%')::integer,
   5,60,104857600::bigint
 from public.kombax_evento_media m where m.evento_id=p_evento_id;
end $$;
revoke all on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) to authenticated;

create or replace function public.app_kombax_eventos_mutate_v175(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_event_id uuid;v_media_id uuid;v_media public.kombax_evento_media;
 v_mime text;v_momento text;v_bytes bigint;v_width integer;v_height integer;v_duration numeric;v_used integer;v_is_image boolean;v_is_video boolean;
begin
 if p_operation not in ('event.media.register','event.media.update') then
   return public.app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id);
 end if;
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 v_momento:=coalesce(nullif(lower(btrim(v_payload->>'momento')),''),'evento');
 if v_momento not in ('previo','evento','posterior') then raise exception 'EVENT_MEDIA_MOMENT_INVALID'; end if;

 if p_operation='event.media.register' then
   v_event_id:=nullif(v_payload->>'evento_id','')::uuid;
   v_media_id:=nullif(v_payload->>'media_id','')::uuid;
   if v_event_id is null or v_media_id is null then raise exception 'EVENT_MEDIA_ID_REQUIRED'; end if;
   -- Serialize quota checks per event to prevent 14->16 race conditions.
   perform pg_advisory_xact_lock(hashtextextended(v_event_id::text,20099));
   v_mime:=lower(btrim(coalesce(v_payload->>'mime_type','')));
   v_is_image:=v_mime like 'image/%';v_is_video:=v_mime like 'video/%';
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
     update public.kombax_evento_media set momento=v_momento,bytes=v_bytes,width=v_width,height=v_height,duration_seconds=case when v_is_video then v_duration else null end,actualizado_en=now()
       where id=v_media_id returning * into v_media;
   end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');
   update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
   return v_result;
 end if;

 -- event.media.update: preserve v173/v171 authorization, then only allow album phase metadata here.
 v_result:=public.app_kombax_eventos_mutate_v173(p_operation,v_payload,p_request_id);
 v_media_id:=nullif(v_payload->>'media_id','')::uuid;
 if v_media_id is not null and v_payload ? 'momento' then
   update public.kombax_evento_media set momento=v_momento,actualizado_en=now() where id=v_media_id returning * into v_media;
   if v_media.id is not null then
     v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');
     update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
   end if;
 end if;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) to authenticated;

comment on function public.app_kombax_evento_media_v175(uuid,uuid) is '20.099 official Event album reader: 15-photo/5-video model with before/during/after phase and optional club-workspace isolation.';
comment on function public.app_kombax_eventos_mutate_v175(text,jsonb,uuid) is '20.099 media quota gateway. Photo/video count is transactionally enforced; uploaded videos declare <=60s <=1080p metadata and <=100MB.';
notify pgrst,'reload schema';
commit;
