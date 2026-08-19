-- KOMBAX RC13 build 20054 · 099 · Social product limits and profile pagination
begin;

-- Daily publish quota survives post deletion. The audit row is immutable from clients.
create index if not exists idx_kombax_actor_audit_social_publish_v099
  on public.kombax_actor_audit(public_social_id,accion,creado_en desc)
  where accion='social.publish';

create or replace function public.app_kombax_social_cupo_v099(p_social_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth as $$
declare
  v_active integer:=0;v_today integer:=0;v_videos integer:=0;v_oldest_id uuid;v_oldest_at timestamptz;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_social_id is null or not public.app_kombax_social_puede_actuar_v051(p_social_id) then
    raise exception 'KOMBAX_SOCIAL_QUOTA_FORBIDDEN';
  end if;

  select count(*)::integer into v_active
  from public.kombax_social_publicaciones
  where autor_perfil_id=p_social_id and estado='activa';

  select p.id,p.creado_en into v_oldest_id,v_oldest_at
  from public.kombax_social_publicaciones p
  where p.autor_perfil_id=p_social_id and p.estado='activa'
  order by p.creado_en asc,p.id asc limit 1;

  select count(*)::integer into v_videos
  from public.kombax_social_publicaciones p
  join public.kombax_social_media m on m.id=p.social_media_id
  where p.autor_perfil_id=p_social_id and p.estado='activa' and m.estado='active' and m.tipo='video';

  -- Use audit rather than live posts: deleting today's post must not reset the anti-spam quota.
  select count(*)::integer into v_today
  from public.kombax_actor_audit a
  where a.public_social_id=p_social_id and a.accion='social.publish'
    and a.creado_en>=date_trunc('day',now()) and a.creado_en<date_trunc('day',now())+interval '1 day';

  return jsonb_build_object(
    'social_profile_id',p_social_id,
    'active_posts',v_active,'active_limit',30,
    'published_today',v_today,'daily_limit',3,
    'active_videos',v_videos,'video_limit',10,
    'oldest_post_id',v_oldest_id,'oldest_post_at',v_oldest_at,
    'can_publish',v_active<30 and v_today<3,
    'active_limit_reached',v_active>=30,
    'daily_limit_reached',v_today>=3
  );
end $$;
revoke all on function public.app_kombax_social_cupo_v099(uuid) from public,anon;
grant execute on function public.app_kombax_social_cupo_v099(uuid) to authenticated;

create or replace function public.app_kombax_social_profile_posts_v099(
  p_social_id uuid,
  p_cursor timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 10
)
returns table(
  id uuid,tipo text,texto text,creado_en timestamptz,likes_count integer,comentarios_count integer,
  comentarios_estado text,audiencia text,audiencia_label text
)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_own boolean:=false;v_limit integer:=least(greatest(coalesce(p_limit,10),1),10);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v_own:=public.app_kombax_social_puede_actuar_v051(p_social_id);
  if not v_own and not exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible=true and sp.estado='activo'
  ) then raise exception 'KOMBAX_PROFILE_NOT_AVAILABLE';end if;

  return query
  select p.id,p.tipo,p.texto,p.creado_en,p.likes_count,p.comentarios_count,p.comentarios_estado,p.audiencia,
         public.app_kombax_social_audiencia_label_v083(p.id)
  from public.kombax_social_publicaciones p
  where p.autor_perfil_id=p_social_id and p.estado='activa'
    and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and (p_cursor_id is null or p.id<p_cursor_id)))
  order by p.creado_en desc,p.id desc
  limit v_limit;
end $$;
revoke all on function public.app_kombax_social_profile_posts_v099(uuid,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_profile_posts_v099(uuid,timestamptz,uuid,integer) to authenticated;

-- Harden the daily quota so physical deletion cannot be used to publish more than 3 times/day.
create or replace function public.app_kombax_social_mutate_v099(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_actor uuid;v_existing public.app_mutation_requests;v_today integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    return public.app_kombax_social_mutate_v085(p_operation,p_payload,p_request_id);
  end if;

  if p_operation='kombax.social.publicar' then
    begin v_actor:=(coalesce(p_payload,'{}'::jsonb)->>'autor_perfil_id')::uuid;
    exception when others then raise exception 'KOMBAX_POST_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_POST_NOT_ALLOWED';end if;
    select count(*)::integer into v_today
    from public.kombax_actor_audit a
    where a.public_social_id=v_actor and a.accion='social.publish'
      and a.creado_en>=date_trunc('day',now()) and a.creado_en<date_trunc('day',now())+interval '1 day';
    if v_today>=3 then raise exception 'KOMBAX_POST_DAILY_LIMIT_3';end if;
  end if;

  return public.app_kombax_social_mutate_v085(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_social_mutate_v099(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v099(text,jsonb,uuid) to authenticated;

-- v099 is the authenticated write façade from this build onward.
revoke execute on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) from authenticated;
grant execute on function public.app_kombax_social_mutate_v085(text,jsonb,uuid) to service_role;

notify pgrst,'reload schema';
commit;
