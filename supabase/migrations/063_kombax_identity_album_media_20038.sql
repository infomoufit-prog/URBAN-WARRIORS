-- KOMBAX RC13 build 20038 · 063 · identidad visual, álbum y media sin recorte.
begin;

-- La ruta real emitida por el cliente es <uid>/club/<club_id>/<archivo>.
drop policy if exists kombax_club_media_insert_v046 on storage.objects;
create policy kombax_club_media_insert_v046 on storage.objects
for insert to authenticated
with check (
  bucket_id='kombax-public-media'
  and array_length(storage.foldername(name),1)>=3
  and (storage.foldername(name))[1]=auth.uid()::text
  and (storage.foldername(name))[2]='club'
  and public.app_puede_gestionar_perfil_club_v035(((storage.foldername(name))[3])::uuid)
);

-- Fuente canónica de URL pública para Club. Los paths Social explícitos siguen teniendo
-- prioridad en cliente/RPC; esta función evita depender de una copia materializada obsoleta.
create or replace function public.app_kombax_social_avatar_url_v063(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' then coalesce(pc.logo_url,c.logo_url,sp.avatar_url)
    else sp.avatar_url
  end
  from public.kombax_social_perfiles sp
  left join public.perfiles_club_publicos pc on pc.club_id=sp.club_id
  left join public.clubes c on c.id=sp.club_id
  where sp.id=p_social_id;
$$;
create or replace function public.app_kombax_social_banner_url_v063(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' then coalesce(pc.portada_url,c.portada_url,sp.banner_url)
    else sp.banner_url
  end
  from public.kombax_social_perfiles sp
  left join public.perfiles_club_publicos pc on pc.club_id=sp.club_id
  left join public.clubes c on c.id=sp.club_id
  where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_social_avatar_url_v063(uuid) from public,anon;
revoke all on function public.app_kombax_social_banner_url_v063(uuid) from public,anon;
grant execute on function public.app_kombax_social_avatar_url_v063(uuid) to authenticated;
grant execute on function public.app_kombax_social_banner_url_v063(uuid) to authenticated;

-- Sincronización exacta del perfil público del Club. `coalesce(new.logo_url,avatar_url)`
-- impedía retirar un logo y permitía conservar materializaciones antiguas.
create or replace function public.app_kombax_social_sync_club_public_v051()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  update public.kombax_social_perfiles set
    slug=new.slug,nombre_publico=new.nombre_publico,bio=new.descripcion,
    avatar_url=new.logo_url,banner_url=new.portada_url,
    visible=new.visible and not new.moderacion_oculta,
    publicar_habilitado=new.visible and not new.moderacion_oculta,
    estado=case when new.visible and not new.moderacion_oculta then 'activo' else 'limitado' end,
    actualizado_en=now()
  where sujeto_tipo='club' and club_id=new.club_id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_club_public_v051() from public,anon,authenticated;
drop trigger if exists club_public_sync_kombax_social_v051 on public.perfiles_club_publicos;
create trigger club_public_sync_kombax_social_v051 after insert or update on public.perfiles_club_publicos
for each row execute function public.app_kombax_social_sync_club_public_v051();

-- Backfill de clubes existentes desde la fuente pública actual.
update public.kombax_social_perfiles sp set
  slug=pc.slug,nombre_publico=pc.nombre_publico,bio=pc.descripcion,
  avatar_url=pc.logo_url,banner_url=pc.portada_url,
  visible=pc.visible and not pc.moderacion_oculta,
  publicar_habilitado=pc.visible and not pc.moderacion_oculta,
  estado=case when pc.visible and not pc.moderacion_oculta then 'activo' else 'limitado' end,
  actualizado_en=now()
from public.perfiles_club_publicos pc
where sp.sujeto_tipo='club' and sp.club_id=pc.club_id;

create or replace function public.app_kombax_social_directorio_v052(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contactable boolean,club_id uuid,club_nombre text)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query select sp.id,sp.sujeto_tipo,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.nombre_publico,sp.bio,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
    public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),sp.verificado,
    public.app_kombax_social_contactable_v041(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre
  from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id) left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
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
  return query select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),
    public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
  left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  where p.estado='activa' and sp.visible and sp.estado='activo' and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v053(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_mis_perfiles_v051(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
    public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
    public.app_kombax_social_tipo_v051(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre,
    case when sp.sujeto_tipo='club' then c.nombre||' · Club' when sp.sujeto_tipo='miembro' then sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end else sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id)) end
  from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where public.app_kombax_social_puede_actuar_v051(sp.id) and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
  order by case when p_club_id is not null and sp.sujeto_tipo='club' and sp.club_id=p_club_id then 0 when sp.sujeto_tipo='miembro' then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_comentarios_v053(p_publicacion_id uuid,p_limit integer default 100)
returns table(id uuid,parent_id uuid,texto text,estado text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if not exists(select 1 from public.kombax_social_publicaciones p where p.id=p_publicacion_id and p.estado='activa') then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
  return query select c.id,c.parent_id,c.texto,c.estado,c.creado_en,sp.id,sp.nombre_publico,sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,public.app_kombax_social_puede_actuar_v051(sp.id)
  from public.kombax_social_comentarios c join public.kombax_social_perfiles sp on sp.id=c.autor_social_id
  where c.publicacion_id=p_publicacion_id and c.estado='active' and sp.estado='activo' and sp.visible
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by coalesce(c.parent_id,c.id),case when c.parent_id is null then 0 else 1 end,c.creado_en,c.id limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_comentarios_v053(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v053(uuid,integer) to authenticated;

create or replace function public.app_kombax_perfil_publico_v053(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_member_album jsonb;v_avatar text;v_banner text;v_avatar_url text;v_banner_url text;v_theme text;
begin
  v:=public.app_kombax_perfil_publico_v052(p_social_id);
  v_avatar:=public.app_kombax_social_avatar_path_v058(p_social_id);v_banner:=public.app_kombax_social_banner_path_v058(p_social_id);
  v_avatar_url:=public.app_kombax_social_avatar_url_v063(p_social_id);v_banner_url:=public.app_kombax_social_banner_url_v063(p_social_id);
  v:=jsonb_set(v,'{avatar_url}',coalesce(to_jsonb(v_avatar_url),'null'::jsonb),true);
  v:=jsonb_set(v,'{banner_url}',coalesce(to_jsonb(v_banner_url),'null'::jsonb),true);
  v:=jsonb_set(v,'{avatar_path}',coalesce(to_jsonb(v_avatar),'null'::jsonb),true);
  v:=jsonb_set(v,'{banner_path}',coalesce(to_jsonb(v_banner),'null'::jsonb),true);
  if coalesce(v->>'sujeto_tipo','')='miembro' then
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds) order by m.creado_en desc),'[]'::jsonb)
      into v_member_album from public.kombax_social_media m where m.social_profile_id=p_social_id and m.estado='active' and m.en_album and m.tipo in ('photo','video');
    v:=jsonb_set(v,'{album}',coalesce(v_member_album,'[]'::jsonb),true);
  end if;
  if coalesce(v->>'sujeto_tipo','')='club' then
    select coalesce(c.theme_id,'combat-dark') into v_theme from public.clubes c where c.id=nullif(v->>'club_id','')::uuid;
    if v_theme is not null then v:=jsonb_set(v,'{theme_id}',to_jsonb(v_theme),true);end if;
  end if;
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v053(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v053(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
