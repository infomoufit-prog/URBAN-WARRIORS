-- KOMBAX RC13 build 20046 · 085 · restricted Social media confidentiality
-- Public profiles/album stay in kombax-public-media. Restricted post attachments use a separate private bucket.
begin;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('kombax-restricted-media','kombax-restricted-media',false,26214400,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

alter table public.kombax_social_media add column if not exists storage_bucket text not null default 'kombax-public-media';
alter table public.kombax_social_media drop constraint if exists kombax_social_media_storage_bucket_check;
alter table public.kombax_social_media add constraint kombax_social_media_storage_bucket_check
  check(storage_bucket in ('kombax-public-media','kombax-restricted-media'));
update public.kombax_social_media set storage_bucket='kombax-public-media' where storage_bucket is null;
create index if not exists idx_kombax_social_media_bucket_path_v085 on public.kombax_social_media(storage_bucket,storage_path) where estado='active';

create or replace function public.app_kombax_social_restricted_media_visible_v085(p_path text)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(
    select 1
    from public.kombax_social_media m
    join public.kombax_social_publicaciones p on p.social_media_id=m.id
    where m.storage_bucket='kombax-restricted-media' and m.storage_path=p_path and m.estado='active' and p.estado='activa'
      and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
  );
$$;
revoke all on function public.app_kombax_social_restricted_media_visible_v085(text) from public,anon;
grant execute on function public.app_kombax_social_restricted_media_visible_v085(text) to authenticated;

-- Restricted media: owner can upload/remove, but reads are authorized by the post audience itself.
drop policy if exists kombax_restricted_media_insert_v085 on storage.objects;
create policy kombax_restricted_media_insert_v085 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-restricted-media'
  and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='social'
  and public.app_kombax_social_puede_actuar_v051(((storage.foldername(name))[3])::uuid)
);
drop policy if exists kombax_restricted_media_select_v085 on storage.objects;
create policy kombax_restricted_media_select_v085 on storage.objects for select to authenticated using(
  bucket_id='kombax-restricted-media' and public.app_kombax_social_restricted_media_visible_v085(name)
);
drop policy if exists kombax_restricted_media_delete_v085 on storage.objects;
create policy kombax_restricted_media_delete_v085 on storage.objects for delete to authenticated using(
  bucket_id='kombax-restricted-media'
  and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='social'
  and public.app_kombax_social_puede_actuar_v051(((storage.foldername(name))[3])::uuid)
);

-- Preserve the 20.045 implementations under internal names, then rebind their
-- public signatures to compatibility wrappers that enforce the 085 security contract.
do $$ begin
  if to_regprocedure('public.app_kombax_social_media_v053(uuid)') is not null
     and to_regprocedure('public.app_kombax_social_media_v053_pre_media_v085(uuid)') is null then
    alter function public.app_kombax_social_media_v053(uuid) rename to app_kombax_social_media_v053_pre_media_v085;
  end if;
  if to_regprocedure('public.app_kombax_social_feed_v083(timestamptz,uuid,integer)') is not null
     and to_regprocedure('public.app_kombax_social_feed_v083_pre_media_v085(timestamptz,uuid,integer)') is null then
    alter function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) rename to app_kombax_social_feed_v083_pre_media_v085;
  end if;
  if to_regprocedure('public.app_kombax_social_mutate_v083(text,jsonb,uuid)') is not null
     and to_regprocedure('public.app_kombax_social_mutate_v083_pre_media_v085(text,jsonb,uuid)') is null then
    alter function public.app_kombax_social_mutate_v083(text,jsonb,uuid) rename to app_kombax_social_mutate_v083_pre_media_v085;
  end if;
end $$;

create or replace function public.app_kombax_social_media_v085(p_social_id uuid)
returns table(id uuid,tipo text,storage_path text,storage_bucket text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,en_album boolean,estado text,creado_en timestamptz,editable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=public.app_kombax_social_puede_actuar_v051(p_social_id);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not v_manage and not exists(select 1 from public.kombax_social_perfiles sp where sp.id=p_social_id and sp.visible and sp.estado='activo') then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_AVAILABLE';end if;
  return query
  select m.id,m.tipo,m.storage_path,m.storage_bucket,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.en_album,m.estado,m.creado_en,v_manage
  from public.kombax_social_media m
  where m.social_profile_id=p_social_id
    and (v_manage or (m.estado='active' and m.storage_bucket='kombax-public-media'))
  order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.creado_en desc;
end $$;
revoke all on function public.app_kombax_social_media_v085(uuid) from public,anon;
grant execute on function public.app_kombax_social_media_v085(uuid) to authenticated;

create or replace function public.app_kombax_social_feed_v085(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_bucket text,media_mime text,media_duration numeric,audiencia text,audiencia_label text)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    nullif(aff.j->>'club_id','')::uuid,aff.j->>'club_nombre',nullif(aff.j->>'club_social_id','')::uuid,coalesce((aff.j->>'verificada')::boolean,false),
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.storage_bucket,'kombax-public-media'),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds),
    p.audiencia,public.app_kombax_social_audiencia_label_v083(p.id)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
  left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  left join lateral(select public.app_kombax_social_afiliacion_v072(sp.id) j) aff on true
  where p.estado='activa' and sp.visible and sp.estado='activo'
    and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v085(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v085(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_mutate_v085(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_media_id uuid;v_post_id uuid;v_bucket text;v_audience text;v_media public.kombax_social_media;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;

  if p_operation in ('kombax.social.media.add','kombax.social.media.avatar','kombax.social.media.banner') then
    v_bucket:=lower(coalesce(nullif(v_payload->>'storage_bucket',''),'kombax-public-media'));
    if v_bucket not in ('kombax-public-media','kombax-restricted-media') then raise exception 'KOMBAX_SOCIAL_MEDIA_BUCKET_INVALID';end if;
    if v_bucket='kombax-restricted-media' and p_operation<>'kombax.social.media.add' then raise exception 'KOMBAX_RESTRICTED_MEDIA_POST_ONLY';end if;
    if v_bucket='kombax-restricted-media' then v_payload:=jsonb_set(v_payload,'{en_album}','false'::jsonb,true);end if;
    v_result:=public.app_kombax_social_mutate_v067(p_operation,v_payload,p_request_id);
    begin v_media_id:=(v_result->'data'->>'id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_MEDIA_RESULT_INVALID';end;
    update public.kombax_social_media set storage_bucket=v_bucket,en_album=case when v_bucket='kombax-restricted-media' then false else en_album end,actualizado_en=now()
      where id=v_media_id returning * into v_media;
    if v_media.id is null then raise exception 'KOMBAX_SOCIAL_MEDIA_RESULT_NOT_FOUND';end if;
    v_result:=jsonb_set(v_result,'{data,storage_bucket}',to_jsonb(v_bucket),true);
    v_result:=jsonb_set(v_result,'{data,en_album}',to_jsonb(v_media.en_album),true);
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=auth.uid();
    return v_result;
  end if;

  if p_operation='kombax.social.publicar' then
    v_audience:=lower(coalesce(nullif(v_payload->>'audiencia',''),'publica'));
    begin v_media_id:=nullif(v_payload->>'social_media_id','')::uuid;exception when others then raise exception 'KOMBAX_POST_MEDIA_INVALID';end;
    if v_media_id is not null then
      select * into v_media from public.kombax_social_media where id=v_media_id and estado='active';
      if v_media.id is null then raise exception 'KOMBAX_POST_MEDIA_NOT_AVAILABLE';end if;
      if v_audience='publica' and v_media.storage_bucket<>'kombax-public-media' then raise exception 'KOMBAX_PUBLIC_POST_REQUIRES_PUBLIC_MEDIA';end if;
      if v_audience<>'publica' and v_media.storage_bucket<>'kombax-restricted-media' then raise exception 'KOMBAX_RESTRICTED_POST_REQUIRES_PRIVATE_MEDIA';end if;
      if v_audience<>'publica' and v_media.en_album then raise exception 'KOMBAX_RESTRICTED_MEDIA_CANNOT_BE_ALBUM';end if;
    end if;
    return public.app_kombax_social_mutate_v083_pre_media_v085(p_operation,v_payload,p_request_id);
  end if;

  if p_operation='kombax.social.media.remove' then
    begin v_media_id:=(v_payload->>'media_id')::uuid;exception when others then raise exception 'KOMBAX_SOCIAL_MEDIA_ID_INVALID';end;
    select storage_bucket into v_bucket from public.kombax_social_media where id=v_media_id;
    v_result:=public.app_kombax_social_mutate_v083_pre_media_v085(p_operation,v_payload,p_request_id);
    v_result:=jsonb_set(v_result,'{data,storage_bucket}',to_jsonb(coalesce(v_bucket,'kombax-public-media')),true);
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=auth.uid();
    return v_result;
  end if;

  if p_operation='kombax.social.eliminar' then
    begin v_post_id:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    select coalesce(m.storage_bucket,'kombax-public-media') into v_bucket
    from public.kombax_social_publicaciones p
    left join public.kombax_social_media m on m.id=p.social_media_id
    where p.id=v_post_id;
    v_result:=public.app_kombax_social_mutate_v083_pre_media_v085(p_operation,v_payload,p_request_id);
    v_result:=jsonb_set(v_result,'{data,storage_bucket}',to_jsonb(coalesce(v_bucket,'kombax-public-media')),true);
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=auth.uid();
    return v_result;
  end if;

  return public.app_kombax_social_mutate_v083_pre_media_v085(p_operation,v_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) to authenticated;


-- 20.045 compatibility: old signatures remain callable, but route through the
-- hardened logic. Restricted media paths are not exposed to the old public-bucket UI.
create or replace function public.app_kombax_social_media_v053(p_social_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,en_album boolean,estado text,creado_en timestamptz,editable boolean)
language sql stable security definer set search_path=public,auth as $$
  select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.en_album,m.estado,m.creado_en,m.editable
  from public.app_kombax_social_media_v085(p_social_id) m;
$$;
revoke all on function public.app_kombax_social_media_v053(uuid) from public,anon;
grant execute on function public.app_kombax_social_media_v053(uuid) to authenticated;

create or replace function public.app_kombax_social_feed_v083(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric,audiencia text,audiencia_label text)
language sql stable security definer set search_path=public,auth as $$
  select f.id,f.tipo,f.texto,f.likes_count,f.comentarios_count,f.creado_en,f.autor_id,f.autor_nombre,f.autor_tipo,f.autor_slug,
    f.autor_avatar_url,f.autor_avatar_path,f.autor_verificado,f.autor_club_id,f.autor_club_nombre,f.autor_club_social_id,f.autor_afiliacion_verificada,
    f.liked_by_me,f.saved_by_me,f.contactable,f.comentarios_estado,f.media_id,f.media_tipo,
    case when f.media_bucket='kombax-public-media' then f.media_path else null end,
    f.media_mime,f.media_duration,f.audiencia,f.audiencia_label
  from public.app_kombax_social_feed_v085(p_cursor,p_cursor_id,p_limit) f;
$$;
revoke all on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_mutate_v083(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language sql security definer set search_path=public,auth as $$
  select public.app_kombax_social_mutate_v085(p_operation,p_payload,p_request_id);
$$;
revoke all on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
