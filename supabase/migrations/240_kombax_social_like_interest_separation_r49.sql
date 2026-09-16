-- KOMBAX 20.101 R49 · Separate public Like from private interest preference + off-topic moderation.
begin;

-- Combat Social is a thematic network. Add an auditable report reason without changing the moderation pipeline.
alter table public.kombax_social_reportes drop constraint if exists kombax_social_reportes_motivo_check;
alter table public.kombax_social_reportes add constraint kombax_social_reportes_motivo_check
  check(motivo in ('fuera_tematica','acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro'));

-- Private ranking preference. IMPORTANT: this RPC never inserts/deletes public likes.
create or replace function public.app_kombax_social_preference_v240(
  p_publicacion_id uuid,
  p_valor smallint default 0,
  p_request_id uuid default null
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_request uuid:=coalesce(p_request_id,gen_random_uuid());
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if p_publicacion_id is null then raise exception 'KOMBAX_POST_ID_INVALID';end if;
  if coalesce(p_valor,0) not in (-1,0,1) then raise exception 'KOMBAX_SOCIAL_PREFERENCE_INVALID';end if;
  if not exists(select 1 from public.kombax_social_publicaciones p where p.id=p_publicacion_id and p.estado='activa') then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
  if not public.app_kombax_social_puede_ver_publicacion_v083(p_publicacion_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;

  select * into v_existing from public.app_mutation_requests where request_id=v_request;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>'kombax.social.preferencia.v240' then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
      values(v_request,v_uid,null,'kombax.social.preferencia.v240');
  end if;

  delete from public.kombax_social_preferencias_usuario_v237
   where user_id=v_uid and publicacion_id=p_publicacion_id;
  if p_valor in (-1,1) then
    insert into public.kombax_social_preferencias_usuario_v237(user_id,publicacion_id,valor)
      values(v_uid,p_publicacion_id,p_valor)
      on conflict(user_id,publicacion_id) do update set valor=excluded.valor,actualizado_en=now();
  end if;

  v_result:=jsonb_build_object('ok',true,'request_id',v_request,'data',jsonb_build_object('publicacion_id',p_publicacion_id,'valor',coalesce(p_valor,0)));
  update public.app_mutation_requests set result=v_result,completed_at=now()
   where request_id=v_request and user_id=v_uid;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=v_request and user_id=v_uid and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_preference_v240(uuid,smallint,uuid) from public,anon;
grant execute on function public.app_kombax_social_preference_v240(uuid,smallint,uuid) to authenticated;

-- Dedicated thematic report path. It feeds the same global moderation queue and never auto-deletes content.
create or replace function public.app_kombax_social_report_offtopic_v240(
  p_publicacion_id uuid,
  p_detalle text default null
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_report public.kombax_social_reportes;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if p_publicacion_id is null or not exists(select 1 from public.kombax_social_publicaciones p where p.id=p_publicacion_id and p.estado='activa') then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
  if not public.app_kombax_social_puede_ver_publicacion_v083(p_publicacion_id) then raise exception 'KOMBAX_POST_AUDIENCE_FORBIDDEN';end if;
  insert into public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id,motivo,detalle)
    values(v_uid,'publicacion',p_publicacion_id,'fuera_tematica',left(nullif(btrim(coalesce(p_detalle,'')),''),1500))
    on conflict(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision')
    do update set motivo='fuera_tematica',detalle=excluded.detalle,creado_en=now()
    returning * into v_report;
  return jsonb_build_object('ok',true,'id',v_report.id,'estado',v_report.estado,'motivo',v_report.motivo);
end $$;
revoke all on function public.app_kombax_social_report_offtopic_v240(uuid,text) from public,anon;
grant execute on function public.app_kombax_social_report_offtopic_v240(uuid,text) to authenticated;

-- Ranked feed v238: public likes and private interest are independent signals.
create or replace function public.app_kombax_social_feed_v238(
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
      coalesce((select count(*) from public.kombax_social_likes l2 join public.kombax_social_publicaciones p2 on p2.id=l2.publicacion_id where l2.perfil_id=auth.uid() and p2.autor_perfil_id=p.autor_perfil_id),0)::integer as author_like_count,
      coalesce((select count(*) from public.kombax_social_preferencias_usuario_v237 pref2 join public.kombax_social_publicaciones p2 on p2.id=pref2.publicacion_id where pref2.user_id=auth.uid() and pref2.valor=1 and p2.autor_perfil_id=p.autor_perfil_id),0)::integer as author_interest_count,
      coalesce((select count(*) from public.kombax_social_guardados g3 join public.kombax_social_publicaciones p3 on p3.id=g3.publicacion_id where g3.perfil_id=auth.uid() and p3.autor_perfil_id=p.autor_perfil_id),0)::integer as author_saved_count,
      coalesce((select count(*) from public.kombax_social_preferencias_usuario_v237 d join public.kombax_social_publicaciones p4 on p4.id=d.publicacion_id where d.user_id=auth.uid() and d.valor=-1 and p4.autor_perfil_id=p.autor_perfil_id),0)::integer as author_disinterest_count,
      coalesce((select pref.valor from public.kombax_social_preferencias_usuario_v237 pref where pref.user_id=auth.uid() and pref.publicacion_id=p.id),0)::smallint as my_interest,
      exists(select 1 from public.kombax_social_likes lx where lx.publicacion_id=p.id and lx.perfil_id=auth.uid()) as my_like,
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
        + ln(1+greatest(coalesce(b.likes_count,0),0))::numeric * 1.05
        + ln(1+greatest(coalesce(b.comentarios_count,0),0))::numeric * 1.45
        + ln(1+greatest(coalesce(b.saved_count,0),0))::numeric * 1.85
        + least(3::numeric,greatest(-3::numeric,(coalesce(b.author_like_count,0)::numeric*.18)+(coalesce(b.author_interest_count,0)::numeric*.42)+(coalesce(b.author_saved_count,0)::numeric*.55)-(coalesce(b.author_disinterest_count,0)::numeric*.72)))
        + case when b.my_like then .40 else 0 end
        + case b.my_interest when 1 then 1.30 when -1 then -2.35 else 0 end
      )::numeric,6) as score
    from base b
  )
  select s.id,s.tipo,s.texto,s.likes_count,s.comentarios_count,s.creado_en,s.sp_id,s.nombre_publico,s.sp_tipo,s.slug,
    s.avatar_url,s.avatar_path,s.verificado,
    nullif(s.aff_json->>'club_id','')::uuid,s.aff_json->>'club_nombre',nullif(s.aff_json->>'club_social_id','')::uuid,coalesce((s.aff_json->>'verificada')::boolean,false),
    s.my_like,
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=s.id and g.perfil_id=auth.uid()),s.contactable,s.comentarios_estado,
    s.resolved_media_id,s.resolved_media_tipo,s.resolved_media_path,s.resolved_media_bucket,s.resolved_media_mime,s.resolved_media_duration,
    s.audiencia,s.audience_label,s.my_interest,s.score
  from scored s
  where p_cursor_score is null or s.score<p_cursor_score or (s.score=p_cursor_score and (p_cursor is null or s.creado_en<p_cursor or (s.creado_en=p_cursor and s.id<p_cursor_id)))
  order by s.score desc,s.creado_en desc,s.id desc
  limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v238(numeric,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v238(numeric,timestamptz,uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;
