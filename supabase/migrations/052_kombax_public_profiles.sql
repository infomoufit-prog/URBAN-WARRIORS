-- KOMBAX build 20028 · 052 · perfil público completo y navegación por identidad Social.
begin;

create or replace function public.app_kombax_social_directorio_v052(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,contactable boolean,club_id uuid,club_nombre text)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query
  select sp.id,sp.sujeto_tipo,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.nombre_publico,sp.bio,
    sp.avatar_url,sp.avatar_path,sp.banner_url,sp.banner_path,sp.verificado,public.app_kombax_social_contactable_v041(sp.id),
    coalesce(sp.club_id,i.club_origen_id),c.nombre
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%' or lower(coalesce(c.nombre,'')) like '%'||v_q||'%' or lower(coalesce(d.tipo,'')) like '%'||v_q||'%')
  order by sp.verificado desc,sp.nombre_publico
  limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v052(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v052(text,integer) to authenticated;

create or replace function public.app_kombax_perfil_publico_v052(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare sp public.kombax_social_perfiles;v_type text;v_core jsonb:='{}'::jsonb;v_album jsonb:='[]'::jsonb;v_posts jsonb:='[]'::jsonb;v_rel jsonb:='[]'::jsonb;v_showcase jsonb:='[]'::jsonb;v_club uuid;v_direct uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into sp from public.kombax_social_perfiles where id=p_social_id and visible and estado='activo';
  if sp.id is null then raise exception 'KOMBAX_PUBLIC_PROFILE_NOT_AVAILABLE';end if;
  if exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id) then raise exception 'KOMBAX_PROFILE_BLOCKED';end if;
  v_type:=public.app_kombax_social_tipo_v051(sp.id);v_club:=sp.club_id;v_direct:=sp.perfil_directo_id;

  if sp.sujeto_tipo='club' then
    select coalesce(to_jsonb(pc)-'actualizado_por','{}'::jsonb) into v_core from public.perfiles_club_publicos pc where pc.club_id=sp.club_id;
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds,'position',m.position) order by case m.tipo when 'photo' then 0 else 1 end,m.position,m.creado_en),'[]'::jsonb)
      into v_album from public.kombax_club_media m where m.club_id=sp.club_id and m.estado='active';
  elsif sp.sujeto_tipo='miembro' then
    select i.club_origen_id into v_club from public.identidades_sociales i where i.id=sp.identidad_social_id;
    select jsonb_build_object('club_id',i.club_origen_id,'club_nombre',c.nombre,'bio_publica',coalesce(i.bio_publica,sp.bio),'tipo','miembro')
      into v_core from public.identidades_sociales i join public.clubes c on c.id=i.club_origen_id where i.id=sp.identidad_social_id;
  else
    select coalesce(to_jsonb(d)-'perfil_id'-'moderacion_estado','{}'::jsonb) into v_core from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id;
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'tipo',m.tipo,'storage_path',m.storage_path,'mime_type',m.mime_type,'duration_seconds',m.duration_seconds,'position',m.position) order by case m.tipo when 'avatar' then 0 when 'banner' then 1 when 'photo' then 2 else 3 end,m.position,m.creado_en),'[]'::jsonb)
      into v_album from public.kombax_perfil_media m where m.perfil_directo_id=sp.perfil_directo_id and m.estado='active' and m.tipo in ('photo','video');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'tipo',p.tipo,'texto',p.texto,'likes_count',p.likes_count,'comentarios_count',p.comentarios_count,'creado_en',p.creado_en,'comentarios_estado',p.comentarios_estado) order by p.creado_en desc),'[]'::jsonb)
    into v_posts from (select * from public.kombax_social_publicaciones where autor_perfil_id=sp.id and estado='activa' order by creado_en desc limit 20) p;

  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'tipo',r.tipo,'otro_id',case when r.origen_social_id=sp.id then r.destino_social_id else r.origen_social_id end,'otro_nombre',case when r.origen_social_id=sp.id then d.nombre_publico else o.nombre_publico end,'confirmado_en',r.confirmado_en) order by r.confirmado_en desc),'[]'::jsonb)
    into v_rel from public.kombax_relaciones r join public.kombax_social_perfiles o on o.id=r.origen_social_id join public.kombax_social_perfiles d on d.id=r.destino_social_id where r.estado='confirmed' and (r.origen_social_id=sp.id or r.destino_social_id=sp.id);

  if sp.sujeto_tipo='club' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url) order by e.destacado desc,e.publicado_en desc),'[]'::jsonb)
      into v_showcase from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado' where m.sujeto_tipo='club' and m.club_id=sp.club_id and m.estado='publicada';
  elsif sp.sujeto_tipo='perfil_directo' and v_type='marca' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url) order by e.destacado desc,e.publicado_en desc),'[]'::jsonb)
      into v_showcase from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado' where m.sujeto_tipo='marca' and m.perfil_directo_id=sp.perfil_directo_id and m.estado='publicada';
  end if;

  return jsonb_build_object(
    'id',sp.id,'sujeto_tipo',sp.sujeto_tipo,'perfil_tipo',v_type,'slug',sp.slug,'nombre_publico',sp.nombre_publico,'bio',sp.bio,
    'avatar_url',sp.avatar_url,'avatar_path',sp.avatar_path,'banner_url',sp.banner_url,'banner_path',sp.banner_path,'verificado',sp.verificado,
    'contactable',public.app_kombax_social_contactable_v041(sp.id),'own',public.app_kombax_social_puede_actuar_v051(sp.id),
    'club_id',v_club,'perfil_directo_id',v_direct,'core',coalesce(v_core,'{}'::jsonb),'album',coalesce(v_album,'[]'::jsonb),'posts',coalesce(v_posts,'[]'::jsonb),'relations',coalesce(v_rel,'[]'::jsonb),'showcase',coalesce(v_showcase,'[]'::jsonb)
  );
end $$;
revoke all on function public.app_kombax_perfil_publico_v052(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v052(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
