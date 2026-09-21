-- KOMBAX build 20031 · 058 · consistencia de avatar/perfil público Social y fixes QA 20030.
begin;

-- Storage: `${auth.uid()}/social/${social_profile_id}/archivo` tiene 3 carpetas según storage.foldername().
drop policy if exists kombax_social_media_insert_v053 on storage.objects;
create policy kombax_social_media_insert_v053 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='social'
  and public.app_kombax_social_puede_actuar_v051(((storage.foldername(name))[3])::uuid)
);
drop policy if exists kombax_social_media_delete_v053 on storage.objects;
create policy kombax_social_media_delete_v053 on storage.objects for delete to authenticated using(
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='social'
  and public.app_kombax_social_puede_actuar_v051(((storage.foldername(name))[3])::uuid)
);

-- Fuente canónica: media Social activa primero; campo materializado como fallback.
create or replace function public.app_kombax_social_avatar_path_v058(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select coalesce(
    (select m.storage_path from public.kombax_social_media m
      where m.social_profile_id=sp.id and m.tipo='avatar' and m.estado='active'
      order by m.creado_en desc,m.id desc limit 1),
    sp.avatar_path
  ) from public.kombax_social_perfiles sp where sp.id=p_social_id;
$$;
create or replace function public.app_kombax_social_banner_path_v058(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select coalesce(
    (select m.storage_path from public.kombax_social_media m
      where m.social_profile_id=sp.id and m.tipo='banner' and m.estado='active'
      order by m.creado_en desc,m.id desc limit 1),
    sp.banner_path
  ) from public.kombax_social_perfiles sp where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_social_avatar_path_v058(uuid) from public,anon;
revoke all on function public.app_kombax_social_banner_path_v058(uuid) from public,anon;
grant execute on function public.app_kombax_social_avatar_path_v058(uuid) to authenticated;
grant execute on function public.app_kombax_social_banner_path_v058(uuid) to authenticated;

create or replace function public.app_kombax_social_media_sync_profile_v058()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_social_id uuid;v_avatar text;v_banner text;
begin
  if tg_op='DELETE' then v_social_id:=old.social_profile_id;else v_social_id:=new.social_profile_id;end if;
  select m.storage_path into v_avatar from public.kombax_social_media m where m.social_profile_id=v_social_id and m.tipo='avatar' and m.estado='active' order by m.creado_en desc,m.id desc limit 1;
  select m.storage_path into v_banner from public.kombax_social_media m where m.social_profile_id=v_social_id and m.tipo='banner' and m.estado='active' order by m.creado_en desc,m.id desc limit 1;
  update public.kombax_social_perfiles sp set avatar_path=v_avatar,banner_path=v_banner,actualizado_en=now()
   where sp.id=v_social_id and (sp.avatar_path is distinct from v_avatar or sp.banner_path is distinct from v_banner);
  if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function public.app_kombax_social_media_sync_profile_v058() from public,anon,authenticated;
drop trigger if exists kombax_social_media_sync_profile_v058 on public.kombax_social_media;
create trigger kombax_social_media_sync_profile_v058 after insert or delete or update of estado,storage_path,tipo,social_profile_id on public.kombax_social_media for each row execute function public.app_kombax_social_media_sync_profile_v058();

-- Backfill de avatares/portadas Social ya existentes.
update public.kombax_social_perfiles sp set avatar_path=(select m.storage_path from public.kombax_social_media m where m.social_profile_id=sp.id and m.tipo='avatar' and m.estado='active' order by m.creado_en desc,m.id desc limit 1),actualizado_en=now()
where sp.sujeto_tipo='miembro' and (sp.avatar_path like '%/social/%' or exists(select 1 from public.kombax_social_media m where m.social_profile_id=sp.id and m.tipo='avatar' and m.estado='active'));
update public.kombax_social_perfiles sp set banner_path=(select m.storage_path from public.kombax_social_media m where m.social_profile_id=sp.id and m.tipo='banner' and m.estado='active' order by m.creado_en desc,m.id desc limit 1),actualizado_en=now()
where sp.sujeto_tipo='miembro' and (sp.banner_path like '%/social/%' or exists(select 1 from public.kombax_social_media m where m.social_profile_id=sp.id and m.tipo='banner' and m.estado='active'));

-- Evita ambigüedad PL/pgSQL entre columnas OUT `id` y columnas de tabla.
create or replace function public.app_kombax_social_media_v053(p_social_id uuid)
returns table(id uuid,tipo text,storage_path text,mime_type text,bytes bigint,width integer,height integer,duration_seconds numeric,en_album boolean,estado text,creado_en timestamptz,editable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=public.app_kombax_social_puede_actuar_v051(p_social_id);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not v_manage and not exists(select 1 from public.kombax_social_perfiles sp where sp.id=p_social_id and sp.visible and sp.estado='activo') then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_AVAILABLE';end if;
  return query select m.id,m.tipo,m.storage_path,m.mime_type,m.bytes,m.width,m.height,m.duration_seconds,m.en_album,m.estado,m.creado_en,v_manage
  from public.kombax_social_media m where m.social_profile_id=p_social_id and (v_manage or m.estado='active') order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.creado_en desc;
end $$;
revoke all on function public.app_kombax_social_media_v053(uuid) from public,anon;
grant execute on function public.app_kombax_social_media_v053(uuid) to authenticated;

create or replace function public.app_kombax_social_comentarios_v053(p_publicacion_id uuid,p_limit integer default 100)
returns table(id uuid,parent_id uuid,texto text,estado text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if not exists(select 1 from public.kombax_social_publicaciones p where p.id=p_publicacion_id and p.estado='activa') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
  return query select c.id,c.parent_id,c.texto,c.estado,c.creado_en,sp.id,sp.nombre_publico,sp.slug,sp.avatar_url,public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,public.app_kombax_social_puede_actuar_v051(sp.id)
  from public.kombax_social_comentarios c join public.kombax_social_perfiles sp on sp.id=c.autor_social_id
  where c.publicacion_id=p_publicacion_id and c.estado='active' and sp.estado='activo' and sp.visible
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by coalesce(c.parent_id,c.id),case when c.parent_id is null then 0 else 1 end,c.creado_en,c.id limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_comentarios_v053(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v053(uuid,integer) to authenticated;

create or replace function public.app_kombax_social_directorio_v052(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contactable boolean,club_id uuid,club_nombre text)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query select sp.id,sp.sujeto_tipo,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.nombre_publico,sp.bio,sp.avatar_url,public.app_kombax_social_avatar_path_v058(sp.id),sp.banner_url,public.app_kombax_social_banner_path_v058(sp.id),sp.verificado,public.app_kombax_social_contactable_v041(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre
  from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id) left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.visible and sp.estado='activo' and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%' or lower(coalesce(c.nombre,'')) like '%'||v_q||'%' or lower(coalesce(d.tipo,'')) like '%'||v_q||'%')
  order by sp.verificado desc,sp.nombre_publico limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v052(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v052(text,integer) to authenticated;

create or replace function public.app_kombax_social_feed_v053(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.avatar_url,public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active' left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  where p.estado='activa' and sp.visible and sp.estado='activo' and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_mis_perfiles_v051(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,sp.avatar_url,public.app_kombax_social_avatar_path_v058(sp.id),sp.banner_url,public.app_kombax_social_banner_path_v058(sp.id),sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,public.app_kombax_social_tipo_v051(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre,
    case when sp.sujeto_tipo='club' then c.nombre||' · Club' when sp.sujeto_tipo='miembro' then sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end else sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id)) end
  from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where public.app_kombax_social_puede_actuar_v051(sp.id) and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
  order by case when p_club_id is not null and sp.sujeto_tipo='club' and sp.club_id=p_club_id then 0 when sp.sujeto_tipo='miembro' then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;

create or replace function public.app_kombax_perfil_publico_v053(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_member_album jsonb;v_avatar text;v_banner text;
begin
  v:=public.app_kombax_perfil_publico_v052(p_social_id);v_avatar:=public.app_kombax_social_avatar_path_v058(p_social_id);v_banner:=public.app_kombax_social_banner_path_v058(p_social_id);
  if v_avatar is not null then v:=jsonb_set(v,'{avatar_path}',to_jsonb(v_avatar),true);end if;if v_banner is not null then v:=jsonb_set(v,'{banner_path}',to_jsonb(v_banner),true);end if;
  if coalesce(v->>'sujeto_tipo','')='miembro' then select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds) order by m.creado_en desc),'[]'::jsonb) into v_member_album from public.kombax_social_media m where m.social_profile_id=p_social_id and m.estado='active' and m.en_album and m.tipo in ('photo','video');v:=jsonb_set(v,'{album}',coalesce(v_member_album,'[]'::jsonb),true);end if;
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v053(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v053(uuid) to authenticated;

-- Contrato de release del candidato QA 20031.
create or replace function public.app_kombax_release_contract_v056()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
  return jsonb_build_object('ok',true,'build',20031,'identity_context',to_regprocedure('public.app_kombax_social_mis_perfiles_v051(uuid)') is not null,'public_profiles',to_regprocedure('public.app_kombax_perfil_publico_v052(uuid)') is not null,'social_media',to_regprocedure('public.app_kombax_social_mutate_v053(text,jsonb,uuid)') is not null,'showcase_actions',to_regprocedure('public.app_kombax_showcase_mutate_v054(text,jsonb,uuid)') is not null,'platform_admin',to_regprocedure('public.app_kombax_platform_dashboard_v055()') is not null,'tables',jsonb_build_object('social_media',to_regclass('public.kombax_social_media') is not null,'showcase_saved',to_regclass('public.kombax_showcase_guardados') is not null,'team_permissions',to_regclass('public.kombax_club_team_permissions') is not null,'actor_audit',to_regclass('public.kombax_actor_audit') is not null,'platform_admins',to_regclass('public.kombax_platform_admins') is not null));
end $$;
revoke all on function public.app_kombax_release_contract_v056() from public,anon;
grant execute on function public.app_kombax_release_contract_v056() to authenticated;

notify pgrst,'reload schema';
commit;
