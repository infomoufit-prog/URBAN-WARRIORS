begin;

-- R46: señal privada de "ocultar publicación". No modera ni modifica el contenido global.
create table if not exists public.kombax_social_ocultados_usuario (
  user_id uuid not null,
  publicacion_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(user_id,publicacion_id)
);
create index if not exists idx_kombax_social_ocultados_usuario_post_r46 on public.kombax_social_ocultados_usuario(publicacion_id,user_id);
alter table public.kombax_social_ocultados_usuario enable row level security;
revoke all on public.kombax_social_ocultados_usuario from public,anon,authenticated;

-- Feed inicial de relevancia explicable. Mantiene las mismas reglas de visibilidad de R40.
create or replace function public.app_kombax_social_feed_v236(
  p_cursor_score numeric default null,
  p_cursor timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table(
  id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,
  autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,
  autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,
  liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,
  media_id uuid,media_tipo text,media_path text,media_bucket text,media_mime text,media_duration numeric,
  audiencia text,audiencia_label text,relevance_score numeric
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
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
      and not exists(select 1 from public.kombax_social_ocultados_usuario h where h.user_id=auth.uid() and h.publicacion_id=p.id)
  ), scored as (
    select b.*,
      round((
        greatest(0::numeric,6 - (extract(epoch from (date_trunc('hour',now())-b.creado_en))/3600)::numeric/28)
        + ln(1+greatest(coalesce(b.likes_count,0),0))::numeric * 1.10
        + ln(1+greatest(coalesce(b.comentarios_count,0),0))::numeric * 1.45
        + ln(1+greatest(coalesce(b.saved_count,0),0))::numeric * 1.85
        + least(3::numeric,(coalesce(b.author_interest_count,0)::numeric * .35)+(coalesce(b.author_saved_count,0)::numeric * .55))
      )::numeric,6) as score
    from base b
  )
  select s.id,s.tipo,s.texto,s.likes_count,s.comentarios_count,s.creado_en,s.sp_id,s.nombre_publico,s.sp_tipo,s.slug,
    s.avatar_url,s.avatar_path,s.verificado,
    nullif(s.aff_json->>'club_id','')::uuid,s.aff_json->>'club_nombre',nullif(s.aff_json->>'club_social_id','')::uuid,coalesce((s.aff_json->>'verificada')::boolean,false),
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=s.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=s.id and g.perfil_id=auth.uid()),s.contactable,s.comentarios_estado,
    s.resolved_media_id,s.resolved_media_tipo,s.resolved_media_path,s.resolved_media_bucket,s.resolved_media_mime,s.resolved_media_duration,
    s.audiencia,s.audience_label,s.score
  from scored s
  where p_cursor_score is null
    or s.score<p_cursor_score
    or (s.score=p_cursor_score and (p_cursor is null or s.creado_en<p_cursor or (s.creado_en=p_cursor and s.id<p_cursor_id)))
  order by s.score desc,s.creado_en desc,s.id desc
  limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v236(numeric,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v236(numeric,timestamptz,uuid,integer) to authenticated;

-- Extiende el gateway vigente sin romper protecciones de menores ni operaciones históricas.
create or replace function public.app_kombax_social_mutate_v123(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_direct public.perfiles_kombax_directos;v_consent public.kombax_social_minor_consents_v121;v_result jsonb;v_post_id uuid;v_hidden boolean;v_existing public.app_mutation_requests;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_operation='kombax.social.ocultar' then
    if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null then
      if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
      if v_existing.result is not null then return v_existing.result;end if;
    else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(p_payload->>'club_id','')::uuid,p_operation);end if;
    begin v_post_id:=(p_payload->>'publicacion_id')::uuid;exception when others then raise exception 'KOMBAX_POST_ID_INVALID';end;
    v_hidden:=coalesce((p_payload->>'oculto')::boolean,true);
    if v_hidden then
      if not exists(select 1 from public.kombax_social_publicaciones p where p.id=v_post_id and p.estado='activa' and public.app_kombax_social_puede_ver_publicacion_v083(p.id)) then raise exception 'KOMBAX_POST_NOT_AVAILABLE';end if;
      insert into public.kombax_social_ocultados_usuario(user_id,publicacion_id) values(v_uid,v_post_id) on conflict do nothing;
    else delete from public.kombax_social_ocultados_usuario where user_id=v_uid and publicacion_id=v_post_id;end if;
    v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('publicacion_id',v_post_id,'oculto',v_hidden));
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id and user_id=v_uid;
    return v_result;
  end if;

  if p_operation='kombax.social.direct.activate' then
    begin select * into v_direct from public.perfiles_kombax_directos where id=(p_payload->>'perfil_directo_id')::uuid and perfil_id=v_uid;exception when others then v_direct.id:=null;end;
    if v_direct.id is not null and v_direct.fecha_nacimiento_verificada is not null and v_direct.fecha_nacimiento_verificada>current_date-interval '18 years' then
      select * into v_consent from public.kombax_social_minor_consents_v121 c where c.minor_profile_id=v_uid and c.estado='approved' and c.revocado_en is null order by c.actualizado_en desc limit 1;
      if v_consent.id is null then raise exception 'KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED';end if;
      if coalesce((p_payload->>'acepta_seguridad_menor')::boolean,false) is not true then raise exception 'KOMBAX_MINOR_SOCIAL_SAFETY_REMINDER_REQUIRED';end if;
    end if;
  end if;
  v_result:=public.app_kombax_social_mutate_v099(p_operation,p_payload,p_request_id);
  if p_operation='kombax.social.direct.activate' and v_consent.id is not null then update public.kombax_social_minor_consents_v121 set minor_safety_ack_at=now(),safety_version='2026-08-23',actualizado_en=now() where id=v_consent.id;end if;
  return v_result;
end $$;
revoke all on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v123(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
