-- KOMBAX RC13 build 20045 · 083 · perfiles Social públicos + audiencias por publicación.
-- Contrato de producto:
--   * El perfil Social y su álbum son públicos para usuarios autenticados de KOMBAX, salvo moderación/suspensión.
--   * Las publicaciones son públicas por defecto.
--   * Una publicación puede restringirse al club, a afiliados de una federación o solo a gestores de clubes afiliados.
--   * Relaciones continúan privadas y se usan únicamente como prueba interna de afiliación Club<->Federación.

begin;

alter table public.kombax_social_publicaciones
  add column if not exists audiencia text not null default 'publica',
  add column if not exists audiencia_club_id uuid references public.clubes(id) on delete restrict,
  add column if not exists audiencia_federacion_social_id uuid references public.kombax_social_perfiles(id) on delete restrict;

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_check
check (audiencia in ('publica','club','federacion','clubes_federacion'));

alter table public.kombax_social_publicaciones drop constraint if exists kombax_social_publicaciones_audiencia_target_check;
alter table public.kombax_social_publicaciones add constraint kombax_social_publicaciones_audiencia_target_check check(
  (audiencia='publica' and audiencia_club_id is null and audiencia_federacion_social_id is null)
  or (audiencia='club' and audiencia_club_id is not null and audiencia_federacion_social_id is null)
  or (audiencia in ('federacion','clubes_federacion') and audiencia_club_id is null and audiencia_federacion_social_id is not null)
);

create index if not exists idx_kombax_social_posts_audiencia_v083
  on public.kombax_social_publicaciones(audiencia,audiencia_club_id,audiencia_federacion_social_id,estado,creado_en desc);

-- No existe perfil Social privado por decisión del usuario. El campo histórico `visible`
-- sigue existiendo para moderación/estado, no como preferencia de privacidad.
update public.perfiles_club_publicos set visible=true where visible=false and not coalesce(moderacion_oculta,false);

create or replace function public.app_kombax_social_sync_club_public_v051()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_active boolean;
begin
  select coalesce(c.activo,false) into v_active from public.clubes c where c.id=new.club_id;
  update public.kombax_social_perfiles set
    slug=new.slug,nombre_publico=new.nombre_publico,bio=new.descripcion,
    avatar_url=new.logo_url,banner_url=new.portada_url,
    visible=v_active and not new.moderacion_oculta,
    publicar_habilitado=v_active and not new.moderacion_oculta,
    estado=case when v_active and not new.moderacion_oculta then 'activo' else 'limitado' end,
    actualizado_en=now()
  where sujeto_tipo='club' and club_id=new.club_id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_club_public_v051() from public,anon,authenticated;

update public.kombax_social_perfiles sp set
  visible=c.activo and not pc.moderacion_oculta,
  publicar_habilitado=c.activo and not pc.moderacion_oculta,
  estado=case when c.activo and not pc.moderacion_oculta then 'activo' else 'limitado' end,
  actualizado_en=now()
from public.perfiles_club_publicos pc join public.clubes c on c.id=pc.club_id
where sp.sujeto_tipo='club' and sp.club_id=pc.club_id;

create or replace function public.app_kombax_social_actor_club_v083(p_social_id uuid)
returns uuid language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' then sp.club_id
    else nullif(public.app_kombax_social_afiliacion_v072(sp.id)->>'club_id','')::uuid
  end
  from public.kombax_social_perfiles sp where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_social_actor_club_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_club_social_v083(p_club_id uuid)
returns uuid language sql stable security definer set search_path=public as $$
  select sp.id from public.kombax_social_perfiles sp
  where sp.sujeto_tipo='club' and sp.club_id=p_club_id and sp.estado='activo' and sp.visible
  order by sp.creado_en limit 1;
$$;
revoke all on function public.app_kombax_social_club_social_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_club_afiliado_federacion_v083(p_club_id uuid,p_federacion_social_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1
    from public.kombax_relaciones r
    join public.kombax_social_perfiles f on f.id=p_federacion_social_id and f.estado='activo' and f.visible
    left join public.perfiles_kombax_directos fd on fd.id=f.perfil_directo_id
    where r.tipo='club_federacion' and r.estado='confirmed'
      and fd.tipo='federacion'
      and (
        (r.origen_social_id=public.app_kombax_social_club_social_v083(p_club_id) and r.destino_social_id=p_federacion_social_id)
        or (r.destino_social_id=public.app_kombax_social_club_social_v083(p_club_id) and r.origen_social_id=p_federacion_social_id)
      )
  );
$$;
revoke all on function public.app_kombax_social_club_afiliado_federacion_v083(uuid,uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_pertenece_club_v083(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    exists(select 1 from public.miembros_club mc where mc.perfil_id=auth.uid() and mc.club_id=p_club_id and mc.activo)
    or exists(select 1 from public.identidades_sociales i where i.perfil_id=auth.uid() and i.club_origen_id=p_club_id and i.estado='activa')
  );
$$;
revoke all on function public.app_kombax_social_usuario_pertenece_club_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_gestiona_club_v083(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and exists(
    select 1 from public.miembros_club mc
    where mc.perfil_id=auth.uid() and mc.club_id=p_club_id and mc.activo
      and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false))
  );
$$;
revoke all on function public.app_kombax_social_usuario_gestiona_club_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_usuario_afiliado_federacion_v083(p_federacion_social_id uuid,p_solo_gestores boolean default false)
returns boolean language sql stable security definer set search_path=public,auth as $$
  with clubs as(
    select distinct mc.club_id
    from public.miembros_club mc where mc.perfil_id=auth.uid() and mc.activo
    union
    select distinct i.club_origen_id
    from public.identidades_sociales i where i.perfil_id=auth.uid() and i.estado='activa'
  )
  select auth.uid() is not null and exists(
    select 1 from clubs c
    where public.app_kombax_social_club_afiliado_federacion_v083(c.club_id,p_federacion_social_id)
      and (not p_solo_gestores or public.app_kombax_social_usuario_gestiona_club_v083(c.club_id))
  );
$$;
revoke all on function public.app_kombax_social_usuario_afiliado_federacion_v083(uuid,boolean) from public,anon,authenticated;

create or replace function public.app_kombax_social_audiencias_v083(p_autor_social_id uuid)
returns table(audiencia text,target_social_id uuid,target_club_id uuid,label text,descripcion text,predeterminada boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_type text;v_club uuid;v_fed record;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_puede_actuar_v051(p_autor_social_id) then raise exception 'KOMBAX_AUDIENCE_ACTOR_FORBIDDEN';end if;
  v_type:=public.app_kombax_social_tipo_v051(p_autor_social_id);
  v_club:=public.app_kombax_social_actor_club_v083(p_autor_social_id);

  return query select 'publica'::text,null::uuid,null::uuid,'Público · Todo KOMBAX'::text,'Visible para toda la red KOMBAX Social.'::text,true;

  if v_type in ('miembro','competidor','club') and v_club is not null then
    return query select 'club'::text,null::uuid,v_club,'Solo mi club'::text,'Visible únicamente para cuentas vinculadas a tu club.'::text,false;
  end if;

  if v_type='federacion' then
    return query select 'federacion'::text,p_autor_social_id,null::uuid,'Solo afiliados a mi federación'::text,'Visible para miembros y equipo de clubes afiliados.'::text,false;
    return query select 'clubes_federacion'::text,p_autor_social_id,null::uuid,'Solo clubes afiliados'::text,'Circular dirigida únicamente a responsables autorizados de clubes afiliados.'::text,false;
  elsif v_club is not null then
    for v_fed in
      select distinct f.id,f.nombre_publico
      from public.kombax_relaciones r
      join public.kombax_social_perfiles clubsp on clubsp.id=public.app_kombax_social_club_social_v083(v_club)
      join public.kombax_social_perfiles f on f.id=case when r.origen_social_id=clubsp.id then r.destino_social_id else r.origen_social_id end
      join public.perfiles_kombax_directos d on d.id=f.perfil_directo_id and d.tipo='federacion'
      where r.tipo='club_federacion' and r.estado='confirmed'
        and (r.origen_social_id=clubsp.id or r.destino_social_id=clubsp.id)
        and f.estado='activo' and f.visible
      order by f.nombre_publico
    loop
      return query select 'federacion'::text,v_fed.id,null::uuid,('Solo afiliados · '||v_fed.nombre_publico)::text,'Visible únicamente para la comunidad de clubes afiliados a esta federación.'::text,false;
    end loop;
  end if;
end $$;
revoke all on function public.app_kombax_social_audiencias_v083(uuid) from public,anon;
grant execute on function public.app_kombax_social_audiencias_v083(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_ver_publicacion_v083(p_publicacion_id uuid)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
declare v_post public.kombax_social_publicaciones;v_author public.kombax_social_perfiles;
begin
  if auth.uid() is null then return false;end if;
  select * into v_post from public.kombax_social_publicaciones where id=p_publicacion_id and estado='activa';
  if v_post.id is null then return false;end if;
  select * into v_author from public.kombax_social_perfiles where id=v_post.autor_perfil_id and estado='activo' and visible;
  if v_author.id is null then return false;end if;
  if public.app_kombax_social_puede_actuar_v051(v_author.id) then return true;end if;
  if v_post.audiencia='publica' then return true;end if;
  if v_post.audiencia='club' then return public.app_kombax_social_usuario_pertenece_club_v083(v_post.audiencia_club_id);end if;
  if v_post.audiencia='federacion' then return public.app_kombax_social_usuario_afiliado_federacion_v083(v_post.audiencia_federacion_social_id,false);end if;
  if v_post.audiencia='clubes_federacion' then return public.app_kombax_social_usuario_afiliado_federacion_v083(v_post.audiencia_federacion_social_id,true);end if;
  return false;
end $$;
revoke all on function public.app_kombax_social_puede_ver_publicacion_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_audiencia_label_v083(p_publicacion_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case p.audiencia
    when 'publica' then 'Público'
    when 'club' then 'Solo club'
    when 'federacion' then 'Solo federación'
    when 'clubes_federacion' then 'Solo clubes afiliados'
    else 'Público' end
  from public.kombax_social_publicaciones p where p.id=p_publicacion_id;
$$;
revoke all on function public.app_kombax_social_audiencia_label_v083(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_social_feed_v083(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric,audiencia text,audiencia_label text)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    nullif(aff.j->>'club_id','')::uuid,aff.j->>'club_nombre',nullif(aff.j->>'club_social_id','')::uuid,coalesce((aff.j->>'verificada')::boolean,false),
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds),
    p.audiencia,public.app_kombax_social_audiencia_label_v083(p.id)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active' left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  left join lateral(select public.app_kombax_social_afiliacion_v072(sp.id) j) aff on true
  where p.estado='activa' and sp.visible and sp.estado='activo'
    and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_perfil_publico_v083(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_posts jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v:=public.app_kombax_perfil_publico_v072(p_social_id);if v is null then return null;end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',p.id,'tipo',p.tipo,'texto',p.texto,'likes_count',p.likes_count,'comentarios_count',p.comentarios_count,
      'creado_en',p.creado_en,'comentarios_estado',p.comentarios_estado,'audiencia',p.audiencia,
      'audiencia_label',public.app_kombax_social_audiencia_label_v083(p.id)
    ) order by p.creado_en desc),'[]'::jsonb)
  into v_posts
  from (select * from public.kombax_social_publicaciones x where x.autor_perfil_id=p_social_id and x.estado='activa' and public.app_kombax_social_puede_ver_publicacion_v083(x.id) order by x.creado_en desc limit 20) p;
  v:=jsonb_set(v,'{posts}',coalesce(v_posts,'[]'::jsonb),true);
  return v-'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v083(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v083(uuid) to authenticated;

create or replace function public.app_kombax_social_comentarios_v083(p_publicacion_id uuid,p_limit integer default 100)
returns table(id uuid,parent_id uuid,texto text,estado text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_puede_ver_publicacion_v083(p_publicacion_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  return query select * from public.app_kombax_social_comentarios_v053(p_publicacion_id,p_limit);
end $$;
revoke all on function public.app_kombax_social_comentarios_v083(uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_comentarios_v083(uuid,integer) to authenticated;

create or replace function public.app_kombax_social_guardados_v083(p_limit integer default 100)
returns table(id uuid,tipo text,texto text,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_slug text,audiencia text,audiencia_label text)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query select p.id,p.tipo,p.texto,p.creado_en,sp.id,sp.nombre_publico,sp.slug,p.audiencia,public.app_kombax_social_audiencia_label_v083(p.id)
  from public.kombax_social_guardados g join public.kombax_social_publicaciones p on p.id=g.publicacion_id join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  where g.perfil_id=auth.uid() and p.estado='activa' and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
  order by g.creado_en desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_social_guardados_v083(integer) from public,anon;
grant execute on function public.app_kombax_social_guardados_v083(integer) to authenticated;

create or replace function public.app_kombax_social_mutate_v083(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_actor uuid;v_post_id uuid;v_audience text;v_target_social uuid;v_target_club uuid;v_match boolean;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_operation='kombax.social.publicar' then
    begin
      v_actor:=(v_payload->>'autor_perfil_id')::uuid;
      v_target_social:=nullif(v_payload->>'audiencia_federacion_social_id','')::uuid;
      v_target_club:=nullif(v_payload->>'audiencia_club_id','')::uuid;
    exception when others then raise exception 'KOMBAX_POST_AUDIENCE_INVALID';end;
    v_audience:=lower(coalesce(nullif(v_payload->>'audiencia',''),'publica'));
    select exists(select 1 from public.app_kombax_social_audiencias_v083(v_actor) a
      where a.audiencia=v_audience and a.target_social_id is not distinct from v_target_social and a.target_club_id is not distinct from v_target_club)
      into v_match;
    if not v_match then raise exception 'KOMBAX_POST_AUDIENCE_NOT_ALLOWED';end if;
    v_result:=public.app_kombax_social_mutate_v067(p_operation,p_payload,p_request_id);
    begin v_post_id:=(v_result->'data'->>'id')::uuid;exception when others then raise exception 'KOMBAX_POST_RESULT_INVALID';end;
    update public.kombax_social_publicaciones set audiencia=v_audience,audiencia_club_id=v_target_club,audiencia_federacion_social_id=v_target_social,actualizado_en=now() where id=v_post_id;
    v_result:=jsonb_set(v_result,'{data,audiencia}',to_jsonb(v_audience),true);
    v_result:=jsonb_set(v_result,'{data,audiencia_club_id}',coalesce(to_jsonb(v_target_club),'null'::jsonb),true);
    v_result:=jsonb_set(v_result,'{data,audiencia_federacion_social_id}',coalesce(to_jsonb(v_target_social),'null'::jsonb),true);
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=auth.uid();
    return v_result;
  end if;

  if p_operation in ('kombax.social.like','kombax.social.guardar','kombax.social.comentar') then
    begin v_post_id:=(v_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    if not public.app_kombax_social_puede_ver_publicacion_v083(v_post_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  elsif p_operation='kombax.social.denunciar' and lower(coalesce(v_payload->>'objetivo_tipo',''))='publicacion' then
    begin v_post_id:=(v_payload->>'objetivo_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    if not public.app_kombax_social_puede_ver_publicacion_v083(v_post_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  end if;
  return public.app_kombax_social_mutate_v067(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) to authenticated;

-- Cerrar rutas anteriores que permitirían saltarse la audiencia de una publicación.
revoke execute on function public.app_kombax_social_mutate_v067(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_social_feed_v072(timestamptz,uuid,integer) from authenticated;
revoke execute on function public.app_kombax_perfil_publico_v072(uuid) from authenticated;
revoke execute on function public.app_kombax_social_comentarios_v053(uuid,integer) from authenticated;
revoke execute on function public.app_kombax_social_guardados_v044(integer) from authenticated;

notify pgrst,'reload schema';
commit;
