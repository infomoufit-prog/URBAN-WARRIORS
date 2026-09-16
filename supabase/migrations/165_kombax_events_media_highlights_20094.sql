-- KOMBAX RC13 build 20.094 · 165 · Event Media + Highlights
-- Storage privado; lectura pública mediante Edge Function que firma solo assets visibles.
begin;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-events-media','kombax-events-media',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create table if not exists public.kombax_evento_media(
 id uuid primary key,
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 combate_id uuid references public.kombax_evento_combates_publicos(id) on delete cascade,
 competidor_social_profile_id uuid references public.kombax_social_perfiles(id) on delete restrict,
 tipo text not null check(tipo in ('foto','clip','video_externo','highlight')),
 storage_bucket text not null default 'kombax-events-media' check(storage_bucket='kombax-events-media'),
 storage_path text,
 external_url text,
 mime_type text not null default '',
 titulo text not null default '' check(char_length(titulo)<=180),
 descripcion text not null default '' check(char_length(descripcion)<=1200),
 estado text not null default 'pendiente' check(estado in ('pendiente','visible','oculto','retirado')),
 destacado boolean not null default false,
 allow_download boolean not null default false,
 orden smallint not null default 0 check(orden between 0 and 500),
 expires_at timestamptz,
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_evento_media_source_ck check(
   (tipo='video_externo' and storage_path is null and external_url ~* '^https://[^[:space:]]+$')
   or (tipo<>'video_externo' and storage_path is not null and external_url is null)
 )
);
create unique index if not exists uq_kombax_evento_media_storage_v165 on public.kombax_evento_media(storage_bucket,storage_path) where storage_path is not null and estado<>'retirado';
create index if not exists idx_kombax_evento_media_public_v165 on public.kombax_evento_media(evento_id,estado,destacado desc,orden,creado_en desc,id);
create index if not exists idx_kombax_evento_media_fight_v165 on public.kombax_evento_media(combate_id,estado,orden,id) where combate_id is not null;
create index if not exists idx_kombax_evento_media_competitor_v165 on public.kombax_evento_media(competidor_social_profile_id,estado,creado_en desc,id) where competidor_social_profile_id is not null;
create index if not exists idx_kombax_evento_media_expiry_v165 on public.kombax_evento_media(expires_at,id) where expires_at is not null and estado='visible';
alter table public.kombax_evento_media enable row level security;
revoke all on public.kombax_evento_media from public,anon,authenticated;

create or replace function public.app_kombax_evento_storage_manage_v165(p_name text)
returns boolean language plpgsql stable security definer set search_path=public,auth,storage as $$
declare v_parts text[]:=storage.foldername(coalesce(p_name,''));v_event uuid;
begin
 if auth.uid() is null or coalesce(array_length(v_parts,1),0)<2 then return false; end if;
 begin v_event:=v_parts[1]::uuid; exception when others then return false; end;
 return public.app_kombax_evento_puede_gestionar_v160(v_event);
end $$;
revoke all on function public.app_kombax_evento_storage_manage_v165(text) from public,anon;
grant execute on function public.app_kombax_evento_storage_manage_v165(text) to authenticated;

create or replace function public.app_kombax_evento_media_public_path_v165(p_name text)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(
   select 1 from public.kombax_evento_media m
   join public.kombax_eventos_publicos e on e.id=m.evento_id
   where m.storage_bucket='kombax-events-media' and m.storage_path=p_name and m.estado='visible'
     and (m.expires_at is null or m.expires_at>now())
     and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 );
$$;
revoke all on function public.app_kombax_evento_media_public_path_v165(text) from public,anon;
grant execute on function public.app_kombax_evento_media_public_path_v165(text) to authenticated;

-- Managers can upload/delete their event objects. Authenticated viewers may sign visible assets.
drop policy if exists kombax_events_media_insert_v165 on storage.objects;
create policy kombax_events_media_insert_v165 on storage.objects for insert to authenticated with check(
 bucket_id='kombax-events-media' and public.app_kombax_evento_storage_manage_v165(name)
);
drop policy if exists kombax_events_media_select_v165 on storage.objects;
create policy kombax_events_media_select_v165 on storage.objects for select to authenticated using(
 bucket_id='kombax-events-media' and (public.app_kombax_evento_storage_manage_v165(name) or public.app_kombax_evento_media_public_path_v165(name))
);
drop policy if exists kombax_events_media_delete_v165 on storage.objects;
create policy kombax_events_media_delete_v165 on storage.objects for delete to authenticated using(
 bucket_id='kombax-events-media' and public.app_kombax_evento_storage_manage_v165(name)
);

create or replace function public.app_kombax_evento_media_v165(p_evento_id uuid)
returns table(
 id uuid,evento_id uuid,combate_id uuid,competidor_social_profile_id uuid,tipo text,storage_bucket text,storage_path text,external_url text,
 mime_type text,titulo text,descripcion text,estado text,destacado boolean,allow_download boolean,orden smallint,expires_at timestamptz,creado_en timestamptz
) language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false;v_public boolean:=false;
begin
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_evento_id and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')) into v_public;
 if not v_manage and not v_public then return; end if;
 return query select m.id,m.evento_id,m.combate_id,m.competidor_social_profile_id,m.tipo,m.storage_bucket,m.storage_path,m.external_url,m.mime_type,m.titulo,m.descripcion,m.estado,m.destacado,m.allow_download,m.orden,m.expires_at,m.creado_en
 from public.kombax_evento_media m where m.evento_id=p_evento_id
   and (v_manage or (m.estado='visible' and (m.expires_at is null or m.expires_at>now())))
 order by m.destacado desc,m.orden,m.creado_en desc,m.id;
end $$;
revoke all on function public.app_kombax_evento_media_v165(uuid) from public;
grant execute on function public.app_kombax_evento_media_v165(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_media_asset_v165(p_media_id uuid)
returns table(storage_bucket text,storage_path text,external_url text,mime_type text,tipo text,allow_download boolean)
language sql stable security definer set search_path=public as $$
 select m.storage_bucket,m.storage_path,m.external_url,m.mime_type,m.tipo,m.allow_download
 from public.kombax_evento_media m join public.kombax_eventos_publicos e on e.id=m.evento_id
 where m.id=p_media_id and m.estado='visible' and (m.expires_at is null or m.expires_at>now())
   and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 limit 1;
$$;
revoke all on function public.app_kombax_evento_media_asset_v165(uuid) from public;
grant execute on function public.app_kombax_evento_media_asset_v165(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v165(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_media public.kombax_evento_media;
 v_event_id uuid;v_media_id uuid;v_fight_id uuid;v_competitor uuid;v_type text;v_state text;v_path text;v_external text;
begin
 if p_operation not in ('event.media.register','event.media.update','event.media.remove') then
   return public.app_kombax_eventos_mutate_v164(p_operation,v_payload,p_request_id);
 end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation); end if;

 if p_operation='event.media.register' then
   v_event_id:=nullif(v_payload->>'evento_id','')::uuid;v_media_id:=nullif(v_payload->>'media_id','')::uuid;
   if v_event_id is null or v_media_id is null or not public.app_kombax_evento_puede_gestionar_v160(v_event_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   v_type:=coalesce(nullif(v_payload->>'tipo',''),'foto');v_state:=coalesce(nullif(v_payload->>'estado',''),'visible');
   if v_type not in ('foto','clip','video_externo','highlight') or v_state not in ('pendiente','visible','oculto') then raise exception 'EVENT_MEDIA_INVALID'; end if;
   v_fight_id:=nullif(v_payload->>'combate_id','')::uuid;v_competitor:=nullif(v_payload->>'competidor_social_profile_id','')::uuid;
   if v_fight_id is not null and not exists(select 1 from public.kombax_evento_combates_publicos f where f.id=v_fight_id and f.evento_id=v_event_id) then raise exception 'EVENT_MEDIA_FIGHT_INVALID'; end if;
   if v_competitor is not null and not exists(select 1 from public.kombax_evento_participantes_publicos p where p.evento_id=v_event_id and p.competidor_social_profile_id=v_competitor and p.estado_inscripcion='aceptada') then raise exception 'EVENT_MEDIA_COMPETITOR_INVALID'; end if;
   v_path:=nullif(v_payload->>'storage_path','');v_external:=nullif(v_payload->>'external_url','');
   if v_type='video_externo' then
     if v_external is null or v_external !~* '^https://[^[:space:]]+$' then raise exception 'EVENT_MEDIA_EXTERNAL_URL_INVALID'; end if;v_path:=null;
   else
     if v_path is null or v_path not like v_event_id::text||'/'||v_media_id::text||'/%' then raise exception 'EVENT_MEDIA_STORAGE_PATH_INVALID'; end if;v_external:=null;
   end if;
   insert into public.kombax_evento_media(id,evento_id,combate_id,competidor_social_profile_id,tipo,storage_path,external_url,mime_type,titulo,descripcion,estado,destacado,allow_download,orden,expires_at,creado_por)
   values(v_media_id,v_event_id,v_fight_id,v_competitor,v_type,v_path,v_external,left(coalesce(v_payload->>'mime_type',''),120),left(coalesce(v_payload->>'titulo',''),180),left(coalesce(v_payload->>'descripcion',''),1200),v_state,coalesce((v_payload->>'destacado')::boolean,false),coalesce((v_payload->>'allow_download')::boolean,false),coalesce(nullif(v_payload->>'orden','')::smallint,0),nullif(v_payload->>'expires_at','')::timestamptz,v_uid)
   returning * into v_media;
 elsif p_operation='event.media.update' then
   select * into v_media from public.kombax_evento_media where id=nullif(v_payload->>'media_id','')::uuid for update;
   if v_media.id is null or not public.app_kombax_evento_puede_gestionar_v160(v_media.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   v_state:=coalesce(nullif(v_payload->>'estado',''),v_media.estado);
   if v_state not in ('pendiente','visible','oculto','retirado') then raise exception 'EVENT_MEDIA_STATE_INVALID'; end if;
   update public.kombax_evento_media set titulo=left(coalesce(v_payload->>'titulo',titulo),180),descripcion=left(coalesce(v_payload->>'descripcion',descripcion),1200),estado=v_state,destacado=coalesce((v_payload->>'destacado')::boolean,destacado),allow_download=coalesce((v_payload->>'allow_download')::boolean,allow_download),orden=coalesce(nullif(v_payload->>'orden','')::smallint,orden),expires_at=case when v_payload ? 'expires_at' then nullif(v_payload->>'expires_at','')::timestamptz else expires_at end,actualizado_en=now() where id=v_media.id returning * into v_media;
 else
   select * into v_media from public.kombax_evento_media where id=nullif(v_payload->>'media_id','')::uuid for update;
   if v_media.id is null or not public.app_kombax_evento_puede_gestionar_v160(v_media.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   update public.kombax_evento_media set estado='retirado',actualizado_en=now() where id=v_media.id returning * into v_media;
 end if;
 insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
 values(v_uid,null,p_operation,'kombax_event_media',v_media.id,jsonb_build_object('evento_id',v_media.evento_id,'estado',v_media.estado,'tipo',v_media.tipo));
 v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v165(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v165(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
