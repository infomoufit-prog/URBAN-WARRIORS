-- KOMBAX build 20028 · 053 · subida directa de multimedia en Social y álbum de identidad de miembro.
begin;

create table if not exists public.kombax_social_media(
  id uuid primary key default gen_random_uuid(),
  social_profile_id uuid not null references public.kombax_social_perfiles(id) on delete cascade,
  tipo text not null check(tipo in ('avatar','banner','photo','video')),
  storage_path text not null unique,
  mime_type text not null,
  bytes bigint not null check(bytes between 1 and 26214400),
  width integer,
  height integer,
  duration_seconds numeric(6,2),
  en_album boolean not null default false,
  estado text not null default 'active' check(estado in ('active','hidden','removed','pending_review')),
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check((tipo='video' and mime_type in ('video/mp4','video/webm','video/quicktime') and duration_seconds is not null and duration_seconds>0 and duration_seconds<=15.2)
     or (tipo in ('avatar','banner','photo') and mime_type in ('image/jpeg','image/png','image/webp') and duration_seconds is null))
);
create index if not exists idx_kombax_social_media_v053 on public.kombax_social_media(social_profile_id,estado,en_album,tipo,creado_en desc);
create unique index if not exists uq_kombax_social_avatar_v053 on public.kombax_social_media(social_profile_id) where tipo='avatar' and estado in ('active','pending_review');
create unique index if not exists uq_kombax_social_banner_v053 on public.kombax_social_media(social_profile_id) where tipo='banner' and estado in ('active','pending_review');
alter table public.kombax_social_media enable row level security;
revoke all on public.kombax_social_media from public,anon,authenticated;

alter table public.kombax_social_publicaciones add column if not exists social_media_id uuid references public.kombax_social_media(id) on delete set null;

create or replace function public.app_kombax_social_media_guard_v053()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;v_subject text;
begin
  if not public.app_kombax_social_puede_actuar_v051(new.social_profile_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN';end if;
  if new.en_album and new.tipo in ('photo','video') and new.estado in ('active','pending_review') then
    select sujeto_tipo into v_subject from public.kombax_social_perfiles where id=new.social_profile_id;
    -- El álbum Social propio se usa para miembros. Club/perfil directo conservan sus álbumes 046/043.
    if v_subject='miembro' then
      select count(*) into v_count from public.kombax_social_media m where m.social_profile_id=new.social_profile_id and m.tipo=new.tipo and m.en_album and m.estado in ('active','pending_review') and m.id<>new.id;
      if new.tipo='photo' and v_count>=10 then raise exception 'KOMBAX_SOCIAL_ALBUM_PHOTO_LIMIT_10';end if;
      if new.tipo='video' and v_count>=3 then raise exception 'KOMBAX_SOCIAL_ALBUM_VIDEO_LIMIT_3';end if;
    end if;
  end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_social_media_guard_v053() from public,anon,authenticated;
drop trigger if exists kombax_social_media_guard_v053 on public.kombax_social_media;
create trigger kombax_social_media_guard_v053 before insert or update on public.kombax_social_media for each row execute function public.app_kombax_social_media_guard_v053();

-- Ruta de subida directa: auth.uid()/social/social_profile_id/uuid.ext.
drop policy if exists kombax_social_media_insert_v053 on storage.objects;
create policy kombax_social_media_insert_v053 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='social'
  and public.app_kombax_social_puede_actuar_v051(((storage.foldername(name))[3])::uuid)
);

drop policy if exists kombax_social_media_delete_v053 on storage.objects;
create policy kombax_social_media_delete_v053 on storage.objects for delete to authenticated using(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='social'
);

create or replace function public.app_kombax_social_media_v053(p_social_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,en_album boolean,estado text,creado_en timestamptz,editable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=public.app_kombax_social_puede_actuar_v051(p_social_id);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not v_manage and not exists(select 1 from public.kombax_social_perfiles where id=p_social_id and visible and estado='activo') then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_AVAILABLE';end if;
  return query select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.en_album,m.estado,m.creado_en,v_manage
  from public.kombax_social_media m where m.social_profile_id=p_social_id and (v_manage or m.estado='active') order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.creado_en desc;
end $$;
revoke all on function public.app_kombax_social_media_v053(uuid) from public,anon;
grant execute on function public.app_kombax_social_media_v053(uuid) to authenticated;

create or replace function public.app_kombax_social_feed_v053(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.avatar_url,sp.avatar_path,sp.verificado,
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),
    public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds)
  from public.kombax_social_publicaciones p
  join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
  left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  where p.estado='activa' and sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_perfil_publico_v053(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_member_album jsonb;v_avatar text;v_banner text;
begin
  v:=public.app_kombax_perfil_publico_v052(p_social_id);
  if coalesce(v->>'sujeto_tipo','')='miembro' then
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds) order by m.creado_en desc),'[]'::jsonb)
      into v_member_album from public.kombax_social_media m where m.social_profile_id=p_social_id and m.estado='active' and m.en_album and m.tipo in ('photo','video');
    select storage_path into v_avatar from public.kombax_social_media where social_profile_id=p_social_id and tipo='avatar' and estado='active' order by creado_en desc limit 1;
    select storage_path into v_banner from public.kombax_social_media where social_profile_id=p_social_id and tipo='banner' and estado='active' order by creado_en desc limit 1;
    v:=jsonb_set(v,'{album}',coalesce(v_member_album,'[]'::jsonb),true);
    if v_avatar is not null then v:=jsonb_set(v,'{avatar_path}',to_jsonb(v_avatar),true);end if;
    if v_banner is not null then v:=jsonb_set(v,'{banner_path}',to_jsonb(v_banner),true);end if;
  end if;
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v053(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v053(uuid) to authenticated;

create or replace function public.app_kombax_social_mutate_v053(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_actor uuid;v_media_id uuid;v_media public.kombax_social_media;v_post public.kombax_social_publicaciones;v_count integer;v_type text;v_text text;v_mode text;v_path text;v_kind text;v_album boolean;v_old_path text;v_source text;v_source_id uuid;v_src record;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation not in ('kombax.social.media.add','kombax.social.media.remove','kombax.social.media.avatar','kombax.social.media.banner','kombax.social.media.from_album','kombax.social.publicar') then return public.app_kombax_social_mutate_v050(p_operation,p_payload,p_request_id);end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;

  if p_operation in ('kombax.social.media.add','kombax.social.media.avatar','kombax.social.media.banner') then
    begin v_actor:=(v_payload->>'social_profile_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN';end if;
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
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN';end if;
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
    select * into v_media from public.kombax_social_media where id=v_media_id for update;if v_media.id is null or not public.app_kombax_social_puede_actuar_v051(v_media.social_profile_id) then raise exception 'KOMBAX_SOCIAL_MEDIA_NOT_OWNED';end if;
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
end $$;
revoke all on function public.app_kombax_social_mutate_v053(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v053(text,jsonb,uuid) to authenticated;


create or replace function public.app_kombax_social_comentarios_v053(p_publicacion_id uuid,p_limit integer default 100)
returns table(id uuid,parent_id uuid,texto text,estado text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if not exists(select 1 from public.kombax_social_publicaciones where id=p_publicacion_id and estado='activa') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
  return query select c.id,c.parent_id,c.texto,c.estado,c.creado_en,sp.id,sp.nombre_publico,sp.slug,sp.avatar_url,sp.avatar_path,sp.verificado,public.app_kombax_social_puede_actuar_v051(sp.id)
  from public.kombax_social_comentarios c join public.kombax_social_perfiles sp on sp.id=c.autor_social_id
  where c.publicacion_id=p_publicacion_id and c.estado='active' and sp.estado='activo' and sp.visible
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by coalesce(c.parent_id,c.id),case when c.parent_id is null then 0 else 1 end,c.creado_en,c.id limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_comentarios_v053(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v053(uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;
