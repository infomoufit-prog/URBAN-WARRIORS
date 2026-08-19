-- KOMBAX RC13 build 20044 · 075 · kombax verified profiles public apis

begin;

create or replace function public.app_kombax_social_directorio_v072(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contactable boolean,club_id uuid,club_nombre text,club_social_id uuid,afiliacion_verificada boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return query select sp.id,sp.sujeto_tipo,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.nombre_publico,sp.bio,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),
    sp.verificado,public.app_kombax_social_contactable_v041(sp.id),nullif(aff.j->>'club_id','')::uuid,aff.j->>'club_nombre',nullif(aff.j->>'club_social_id','')::uuid,coalesce((aff.j->>'verificada')::boolean,false)
  from public.kombax_social_perfiles sp left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join lateral(select public.app_kombax_social_afiliacion_v072(sp.id) j) aff on true
  where sp.visible and sp.estado='activo' and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%' or lower(coalesce(aff.j->>'club_nombre','')) like '%'||v_q||'%' or lower(coalesce(d.tipo,'')) like '%'||v_q||'%')
  order by sp.verificado desc,sp.nombre_publico limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v072(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v072(text,integer) to authenticated;

create or replace function public.app_kombax_social_feed_v072(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED'; end if;
  return query select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    nullif(aff.j->>'club_id','')::uuid,aff.j->>'club_nombre',nullif(aff.j->>'club_social_id','')::uuid,coalesce((aff.j->>'verificada')::boolean,false),
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active' left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  left join lateral(select public.app_kombax_social_afiliacion_v072(sp.id) j) aff on true
  where p.estado='activa' and sp.visible and sp.estado='activo' and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v072(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v072(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_perfil_publico_v072(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_aff jsonb;v_badge text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  v:=public.app_kombax_perfil_publico_v068(p_social_id); if v is null then return null; end if;
  v_aff:=public.app_kombax_social_afiliacion_v072(p_social_id); v_badge:=public.app_kombax_badge_tipo_v069(p_social_id);
  v:=jsonb_set(v,'{badge_type}',to_jsonb(v_badge),true);
  v:=jsonb_set(v,'{verified}',to_jsonb(v_badge is not null),true);
  if v_aff is not null then v:=jsonb_set(v,'{affiliation}',v_aff,true); else v:=v-'affiliation'; end if;
  return v-'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v072(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v072(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
