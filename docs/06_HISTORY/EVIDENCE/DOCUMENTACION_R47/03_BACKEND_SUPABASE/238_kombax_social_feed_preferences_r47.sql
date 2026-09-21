-- KOMBAX 20.101 R47 · Ranked feed + reversible preference signal.
begin;
create or replace function public.app_kombax_social_feed_v237(
  p_cursor_score numeric default null,p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20
)
returns table(
  id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,
  autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,
  autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,
  liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,
  media_id uuid,media_tipo text,media_path text,media_bucket text,media_mime text,media_duration numeric,
  audiencia text,audiencia_label text,interest_by_me smallint,relevance_score numeric
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  with base as (
    select p.*,sp.id as sp_id,sp.nombre_publico,sp.slug,sp.verificado,
      public.app_kombax_social_tipo_v051(sp.id) as sp_tipo,
      public.app_kombax_social_avatar_url_v063(sp.id) as avatar_url,
      public.app_kombax_social_avatar_path_v058(sp.id) as avatar_path,
      public.app_kombax_social_contactable_v041(sp.id) as contactable,
      public.app_kombax_social_audiencia_label_v083(p.id) as audience_label,
      aff.j as aff_json,
      coalesce((select count(*) from public.kombax_social_guardados g2 where g2.publicacion_id=p.id),0)::integer as saved_count,
      coalesce((select count(*) from public.kombax_social_likes l2 join public.kombax_social_publicaciones p2 on p2.id=l2.publicacion_id where l2.perfil_id=auth.uid() and p2.autor_perfil_id=p.autor_perfil_id),0)::integer as author_interest_count,
      coalesce((select count(*) from public.kombax_social_guardados g3 join public.kombax_social_publicaciones p3 on p3.id=g3.publicacion_id where g3.perfil_id=auth.uid() and p3.autor_perfil_id=p.autor_perfil_id),0)::integer as author_saved_count,
      coalesce((select count(*) from public.kombax_social_preferencias_usuario_v237 d join public.kombax_social_publicaciones p4 on p4.id=d.publicacion_id where d.user_id=auth.uid() and d.valor=-1 and p4.autor_perfil_id=p.autor_perfil_id),0)::integer as author_disinterest_count,
      coalesce((select pref.valor from public.kombax_social_preferencias_usuario_v237 pref where pref.user_id=auth.uid() and pref.publicacion_id=p.id),case when exists(select 1 from public.kombax_social_likes lx where lx.publicacion_id=p.id and lx.perfil_id=auth.uid()) then 1 else 0 end)::smallint as my_interest,
      coalesce(sm.id,pm.id) as resolved_media_id,coalesce(sm.tipo,pm.tipo) as resolved_media_tipo,
      coalesce(sm.storage_path,pm.storage_path) as resolved_media_path,coalesce(sm.storage_bucket,'kombax-public-media') as resolved_media_bucket,
      coalesce(sm.mime_type,pm.mime_type) as resolved_media_mime,coalesce(sm.duration_seconds,pm.duration_seconds) as resolved_media_duration
    from public.kombax_social_publicaciones p
    join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
    left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
    left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
    left join lateral(select public.app_kombax_social_afiliacion_v072(sp.id) j) aff on true
    where p.estado='activa' and sp.visible and sp.estado='activo'
      and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
      and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  ), scored as (
    select b.*,
      round((
        greatest(0::numeric,6 - (extract(epoch from (date_trunc('hour',now())-b.creado_en))/3600)::numeric/28)
        + ln(1+greatest(coalesce(b.likes_count,0),0))::numeric * 1.10
        + ln(1+greatest(coalesce(b.comentarios_count,0),0))::numeric * 1.45
        + ln(1+greatest(coalesce(b.saved_count,0),0))::numeric * 1.85
        + least(3::numeric,greatest(-3::numeric,(coalesce(b.author_interest_count,0)::numeric*.35)+(coalesce(b.author_saved_count,0)::numeric*.55)-(coalesce(b.author_disinterest_count,0)::numeric*.70)))
        + case b.my_interest when 1 then 1.25 when -1 then -2.25 else 0 end
      )::numeric,6) as score
    from base b
  )
  select s.id,s.tipo,s.texto,s.likes_count,s.comentarios_count,s.creado_en,s.sp_id,s.nombre_publico,s.sp_tipo,s.slug,
    s.avatar_url,s.avatar_path,s.verificado,
    nullif(s.aff_json->>'club_id','')::uuid,s.aff_json->>'club_nombre',nullif(s.aff_json->>'club_social_id','')::uuid,coalesce((s.aff_json->>'verificada')::boolean,false),
    s.my_interest=1,
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=s.id and g.perfil_id=auth.uid()),s.contactable,s.comentarios_estado,
    s.resolved_media_id,s.resolved_media_tipo,s.resolved_media_path,s.resolved_media_bucket,s.resolved_media_mime,s.resolved_media_duration,
    s.audiencia,s.audience_label,s.my_interest,s.score
  from scored s
  where p_cursor_score is null or s.score<p_cursor_score or (s.score=p_cursor_score and (p_cursor is null or s.creado_en<p_cursor or (s.creado_en=p_cursor and s.id<p_cursor_id)))
  order by s.score desc,s.creado_en desc,s.id desc
  limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v237(numeric,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v237(numeric,timestamptz,uuid,integer) to authenticated;


notify pgrst,'reload schema';
commit;
