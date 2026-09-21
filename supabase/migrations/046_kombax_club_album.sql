begin;

-- KOMBAX 046 · Álbum público del Club: avatar/portada siguen separados en perfil 035,
-- y el álbum queda limitado a 10 fotos + 3 vídeos de hasta 15 s.
create table if not exists public.kombax_club_media(
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tipo text not null check(tipo in ('photo','video')),
  storage_path text not null unique,
  mime_type text not null,
  bytes bigint not null check(bytes>0 and bytes<=26214400),
  width integer,
  height integer,
  duration_seconds numeric(6,2),
  position integer not null default 0,
  estado text not null default 'active' check(estado in ('active','hidden','removed','pending_review')),
  moderacion_motivo text,
  creado_por uuid not null references public.perfiles(id),
  moderado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint kombax_club_video_duration_v046 check(tipo<>'video' or (duration_seconds is not null and duration_seconds>0 and duration_seconds<=15.2)),
  constraint kombax_club_media_mime_v046 check((tipo='photo' and mime_type in ('image/jpeg','image/png','image/webp')) or (tipo='video' and mime_type in ('video/mp4','video/webm','video/quicktime')))
);
create index if not exists ix_kombax_club_media_v046 on public.kombax_club_media(club_id,estado,tipo,position,creado_en);
alter table public.kombax_club_media enable row level security;
revoke all on table public.kombax_club_media from public,anon,authenticated;

create or replace function public.app_kombax_club_media_guard_v046()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;
begin
  if auth.uid() is not null and not public.app_puede_gestionar_perfil_club_v035(new.club_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_CLUB_ALBUM_FORBIDDEN';end if;
  if new.estado in ('active','pending_review') then
    select count(*) into v_count from public.kombax_club_media m where m.club_id=new.club_id and m.tipo=new.tipo and m.estado in ('active','pending_review') and m.id<>new.id;
    if new.tipo='photo' and v_count>=10 then raise exception 'KOMBAX_CLUB_ALBUM_PHOTO_LIMIT_10';end if;
    if new.tipo='video' and v_count>=3 then raise exception 'KOMBAX_CLUB_ALBUM_VIDEO_LIMIT_3';end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_club_media_guard_v046() from public,anon,authenticated;
drop trigger if exists kombax_club_media_guard_v046 on public.kombax_club_media;
create trigger kombax_club_media_guard_v046 before insert or update on public.kombax_club_media for each row execute function public.app_kombax_club_media_guard_v046();

-- Ruta: auth.uid()/club/club_id/uuid.ext. La policy 043 de perfiles sigue intacta.
drop policy if exists kombax_club_media_insert_v046 on storage.objects;
create policy kombax_club_media_insert_v046 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='club'
  and public.app_puede_gestionar_perfil_club_v035(((storage.foldername(name))[3])::uuid)
);

create or replace function public.app_kombax_club_album_v046(p_club_id uuid)
returns table(id uuid,club_id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,"position" integer,estado text,creado_en timestamptz,editable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_public boolean;v_hidden boolean;v_manage boolean;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select p.visible,p.moderacion_oculta into v_public,v_hidden from public.perfiles_club_publicos p where p.club_id=p_club_id;
  v_manage:=public.app_puede_gestionar_perfil_club_v035(p_club_id) or public.app_kombax_es_moderador_v041();
  if not v_manage and not (coalesce(v_public,false) and not coalesce(v_hidden,false)) then raise exception 'KOMBAX_CLUB_PROFILE_NOT_PUBLIC';end if;
  return query select m.id,m.club_id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.position,m.estado,m.creado_en,v_manage
    from public.kombax_club_media m where m.club_id=p_club_id and (v_manage or m.estado='active')
    order by case m.tipo when 'photo' then 0 else 1 end,m.position,m.creado_en;
end $$;
revoke all on function public.app_kombax_club_album_v046(uuid) from public,anon;
grant execute on function public.app_kombax_club_album_v046(uuid) to authenticated;

create or replace function public.app_kombax_club_media_mutate_v046(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_club uuid;v_id uuid;v_media public.kombax_club_media;v_type text;v_path text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_club:=(v_payload->>'club_id')::uuid;exception when others then raise exception 'KOMBAX_CLUB_ID_INVALID';end;
  if not public.app_puede_gestionar_perfil_club_v035(v_club) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_CLUB_ALBUM_FORBIDDEN';end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);end if;

  if p_operation='kombax.club.media.add' then
    v_type:=lower(coalesce(v_payload->>'tipo',''));if v_type not in ('photo','video') then raise exception 'KOMBAX_CLUB_MEDIA_TYPE_INVALID';end if;
    v_path:=v_payload->>'storage_path';if v_path is null or v_path not like v_uid::text||'/club/'||v_club::text||'/%' then raise exception 'KOMBAX_CLUB_MEDIA_PATH_INVALID';end if;
    insert into public.kombax_club_media(club_id,tipo,storage_path,mime_type,bytes,width,height,duration_seconds,position,estado,creado_por)
    values(v_club,v_type,v_path,lower(v_payload->>'mime_type'),coalesce((v_payload->>'bytes')::bigint,0),nullif(v_payload->>'width','')::integer,nullif(v_payload->>'height','')::integer,nullif(v_payload->>'duration_seconds','')::numeric,coalesce((v_payload->>'position')::integer,0),'active',v_uid) returning * into v_media;
    v_result:=to_jsonb(v_media);
  elsif p_operation='kombax.club.media.remove' then
    begin v_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_CLUB_MEDIA_ID_INVALID';end;
    update public.kombax_club_media set estado='removed',actualizado_en=now() where id=v_id and club_id=v_club returning * into v_media;
    if v_media.id is null then raise exception 'KOMBAX_CLUB_MEDIA_NOT_FOUND';end if;v_result:=jsonb_build_object('id',v_media.id,'storage_path',v_media.storage_path,'estado',v_media.estado);
  elsif p_operation='kombax.club.media.moderate' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    begin v_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_CLUB_MEDIA_ID_INVALID';end;
    update public.kombax_club_media set estado=case when coalesce((v_payload->>'ocultar')::boolean,true) then 'hidden' else 'active' end,moderacion_motivo=nullif(left(btrim(v_payload->>'motivo'),600),''),moderado_por=v_uid,actualizado_en=now() where id=v_id and club_id=v_club returning * into v_media;
    if v_media.id is null then raise exception 'KOMBAX_CLUB_MEDIA_NOT_FOUND';end if;v_result:=to_jsonb(v_media);
  else raise exception 'KOMBAX_CLUB_MEDIA_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_club_media_mutate_v046(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_club_media_mutate_v046(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
