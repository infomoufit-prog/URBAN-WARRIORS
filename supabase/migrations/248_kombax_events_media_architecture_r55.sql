-- KOMBAX 20.105 R55 · Events media / pagination / deep-link hardening.
-- Pilot goals:
-- 1) Every media asset/cover/thumbnail uses the same v236 visibility decision as the event itself.
-- 2) Deep links by slug work for authorised restricted audiences, without exposing unauthorised events.
-- 3) Participant payloads are paginated instead of forcing the full roster into every event bundle.
-- 4) External video links are quota-controlled and media quota reports all logical video channels.
begin;

create or replace function public.app_kombax_evento_participantes_page_v253(
  p_evento_id uuid,
  p_query text default '',
  p_cursor_creado_en timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 24
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_manage boolean:=false;
  v_view boolean:=false;
  v_limit integer:=least(100,greatest(1,coalesce(p_limit,24)));
  v_items jsonb:='[]'::jsonb;
  v_total integer:=0;
  v_accepted integer:=0;
  v_pending integer:=0;
  v_has_more boolean:=false;
  v_next jsonb:=null;
begin
  if auth.uid() is not null then
    v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id);
  end if;
  v_view:=public.app_kombax_event_can_view_v236(p_evento_id);
  if not coalesce(v_manage,false) and not coalesce(v_view,false) then
    return jsonb_build_object('items','[]'::jsonb,'total_count',0,'accepted_count',0,'pending_count',0,'has_more',false,'next_cursor',null);
  end if;

  with eligible as materialized (
    select
      p.id,p.evento_id,p.origen,p.competidor_social_profile_id,p.nombre_publico,
      case when p.origen='kombax' then public.app_kombax_social_avatar_url_v063(cp.id) else p.foto_url_externa end as foto_url,
      p.club_social_profile_id,coalesce(nullif(p.club_nombre,''),cl.nombre_publico,'') as club_nombre,
      p.disciplina,p.categoria,p.peso,p.estado_inscripcion,p.visible_publico,
      p.presentado_por_social_profile_id,pr.nombre_publico as presentado_por_nombre,p.creado_en,p.media_presentation
    from public.kombax_evento_participantes_publicos p
    left join public.kombax_social_perfiles cp on cp.id=p.competidor_social_profile_id
    left join public.kombax_social_perfiles cl on cl.id=p.club_social_profile_id
    left join public.kombax_social_perfiles pr on pr.id=p.presentado_por_social_profile_id
    where p.evento_id=p_evento_id
      and (
        (p.estado_inscripcion='aceptada' and p.visible_publico)
        or coalesce(v_manage,false)
        or (
          auth.uid() is not null
          and p.presentado_por_social_profile_id is not null
          and public.app_kombax_eventos_puede_actuar_social_v160(p.presentado_por_social_profile_id)
        )
      )
      and (
        coalesce(btrim(p_query),'')=''
        or lower(concat_ws(' ',p.nombre_publico,p.club_nombre,cl.nombre_publico,p.disciplina,p.categoria)) like '%'||lower(btrim(p_query))||'%'
      )
  ), counts as (
    select count(*)::integer total_count,
      count(*) filter(where estado_inscripcion='aceptada')::integer accepted_count,
      count(*) filter(where estado_inscripcion='pendiente')::integer pending_count
    from eligible
  ), page_plus as (
    select * from eligible
    where p_cursor_id is null or p_cursor_creado_en is null or (creado_en,id)>(p_cursor_creado_en,p_cursor_id)
    order by creado_en,id
    limit v_limit+1
  ), page as (
    select * from page_plus order by creado_en,id limit v_limit
  ), payload as (
    select coalesce(jsonb_agg(to_jsonb(x) order by x.creado_en,x.id),'[]'::jsonb) items from page x
  ), tail as (
    select creado_en,id from page order by creado_en desc,id desc limit 1
  )
  select p.items,c.total_count,c.accepted_count,c.pending_count,
    (select count(*)>v_limit from page_plus),
    case when exists(select 1 from tail) then (select jsonb_build_object('creado_en',creado_en,'id',id) from tail) else null end
  into v_items,v_total,v_accepted,v_pending,v_has_more,v_next
  from payload p cross join counts c;

  return jsonb_build_object(
    'items',coalesce(v_items,'[]'::jsonb),
    'total_count',coalesce(v_total,0),
    'accepted_count',coalesce(v_accepted,0),
    'pending_count',coalesce(v_pending,0),
    'has_more',coalesce(v_has_more,false),
    'next_cursor',v_next
  );
end $$;
revoke all on function public.app_kombax_evento_participantes_page_v253(uuid,text,timestamptz,uuid,integer) from public;
grant execute on function public.app_kombax_evento_participantes_page_v253(uuid,text,timestamptz,uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_evento_bundle_v253(
  p_evento_id uuid,
  p_workspace_club_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_base jsonb;
  v_event jsonb;
  v_participants jsonb;
  v_fights jsonb;
  v_media jsonb;
  v_engagement jsonb;
  v_manage boolean:=false;
  v_main jsonb:=null;
begin
  -- v160 already gates the event through app_kombax_event_can_view_v236 and does not force the participant roster into the payload.
  v_base:=public.app_kombax_evento_publico_detalle_v160(p_evento_id);
  if v_base is null then return null; end if;

  if auth.uid() is not null then
    if p_workspace_club_id is not null then
      select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
    else
      v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id);
    end if;
  end if;

  select coalesce(v_base->'event','{}'::jsonb) || jsonb_build_object(
    'fase_temporal',public.app_kombax_evento_estado_temporal_v164(e.id),
    'es_hoy',case when e.fecha_inicio is null then false else (e.fecha_inicio at time zone e.timezone)::date=(now() at time zone e.timezone)::date end,
    'inscripciones_estado',public.app_kombax_evento_inscripciones_estado_v173(e.id),
    'entradas_estado',public.app_kombax_evento_entradas_estado_v173(e.id),
    'visibility_mode',public.app_kombax_event_visibility_mode_v236(e.id),
    'visibility_label',public.app_kombax_event_visibility_label_v236(e.id)
  ) into v_event
  from public.kombax_eventos_publicos e where e.id=p_evento_id;

  v_participants:=public.app_kombax_evento_participantes_page_v253(p_evento_id,'',null,null,24);

  select coalesce(jsonb_agg(
    to_jsonb(f) || jsonb_build_object(
      'co_estelar',coalesce(raw.co_estelar,false),
      'resultado_estado',raw.resultado_estado,
      'resultado_notas_publicas',raw.resultado_notas_publicas,
      'resultado_publicado_en',raw.resultado_publicado_en
    )
    order by raw.destacado desc,raw.co_estelar desc,raw.orden nulls last,raw.hora_programada nulls last,raw.creado_en,raw.id
  ),'[]'::jsonb)
  into v_fights
  from public.app_kombax_evento_combates_v161(p_evento_id) f
  join public.kombax_evento_combates_publicos raw on raw.id=f.id;

  select coalesce(jsonb_agg(
    to_jsonb(m) || jsonb_build_object('media_presentation',coalesce(em.media_presentation,'{}'::jsonb))
    order by m.orden,m.creado_en desc
  ),'[]'::jsonb)
  into v_media
  from public.app_kombax_evento_media_v175(p_evento_id,p_workspace_club_id) m
  left join public.kombax_evento_media em on em.id=m.id;

  select to_jsonb(x) into v_engagement from public.app_kombax_evento_engagement_v162(p_evento_id) x limit 1;
  if jsonb_array_length(coalesce(v_fights,'[]'::jsonb))>0 then
    v_main:=(v_fights->0) || jsonb_build_object('fight_id',v_fights#>>'{0,id}');
  end if;

  return jsonb_build_object(
    'event',coalesce(v_event,'{}'::jsonb),
    'entities',coalesce(v_base->'entities','[]'::jsonb),
    'participants',coalesce(v_participants->'items','[]'::jsonb),
    'participants_count',coalesce((v_participants->>'total_count')::integer,0),
    'participants_accepted_count',coalesce((v_participants->>'accepted_count')::integer,0),
    'participants_pending_count',coalesce((v_participants->>'pending_count')::integer,0),
    'participants_has_more',coalesce((v_participants->>'has_more')::boolean,false),
    'participants_next_cursor',v_participants->'next_cursor',
    'fights',coalesce(v_fights,'[]'::jsonb),
    'media',coalesce(v_media,'[]'::jsonb),
    'engagement',coalesce(v_engagement,'null'::jsonb),
    'main_event',coalesce(v_main,'null'::jsonb),
    'can_manage',coalesce(v_manage,false),
    'can_manage_fights',coalesce(v_manage,false)
  );
end $$;
revoke all on function public.app_kombax_evento_bundle_v253(uuid,uuid) from public;
grant execute on function public.app_kombax_evento_bundle_v253(uuid,uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_slug_v253(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_id uuid;
begin
  select e.id into v_id
  from public.kombax_eventos_publicos e
  where e.slug=lower(btrim(coalesce(p_slug,'')))
    and (
      (e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') and public.app_kombax_event_can_view_v236(e.id))
      or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id))
    )
  limit 1;
  if v_id is null then return null; end if;
  return public.app_kombax_evento_bundle_v253(v_id,null);
end $$;
revoke all on function public.app_kombax_evento_slug_v253(text) from public;
grant execute on function public.app_kombax_evento_slug_v253(text) to anon,authenticated;

create or replace function public.app_kombax_evento_media_asset_v253(
  p_media_id uuid,
  p_variant text default 'asset'
)
returns table(
  storage_bucket text,
  storage_path text,
  external_url text,
  mime_type text,
  tipo text,
  allow_download boolean
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_variant text:=lower(btrim(coalesce(p_variant,'asset')));
begin
  if v_variant not in ('asset','cover','thumb') then return; end if;
  return query
  select
    case
      when v_variant='cover' then nullif(m.media_presentation->>'cover_storage_bucket','')
      when v_variant='thumb' then nullif(m.media_presentation->>'thumb_storage_bucket','')
      else m.storage_bucket
    end,
    case
      when v_variant='cover' then nullif(m.media_presentation->>'cover_storage_path','')
      when v_variant='thumb' then nullif(m.media_presentation->>'thumb_storage_path','')
      else m.storage_path
    end,
    case when v_variant='asset' then m.external_url else null::text end,
    case
      when v_variant='cover' then coalesce(nullif(m.media_presentation->>'cover_mime_type',''),'image/webp')
      when v_variant='thumb' then coalesce(nullif(m.media_presentation->>'thumb_mime_type',''),'image/webp')
      else m.mime_type
    end,
    case when v_variant='cover' then 'cover'::text when v_variant='thumb' then 'thumb'::text else m.tipo end,
    case when v_variant='asset' then m.allow_download else false end
  from public.kombax_evento_media m
  join public.kombax_eventos_publicos e on e.id=m.evento_id
  where m.id=p_media_id
    and m.estado='visible'
    and (m.expires_at is null or m.expires_at>now())
    and (
      (e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') and public.app_kombax_event_can_view_v236(e.id))
      or (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(e.id))
    )
    and (
      v_variant='asset'
      or (v_variant='cover' and nullif(m.media_presentation->>'cover_storage_path','') is not null and m.media_presentation->>'cover_storage_bucket'='kombax-events-media')
      or (v_variant='thumb' and nullif(m.media_presentation->>'thumb_storage_path','') is not null and m.media_presentation->>'thumb_storage_bucket'='kombax-events-media')
    )
  limit 1;
end $$;
revoke all on function public.app_kombax_evento_media_asset_v253(uuid,text) from public;
grant execute on function public.app_kombax_evento_media_asset_v253(uuid,text) to anon,authenticated;

create or replace function public.app_kombax_evento_media_cuota_v253(p_evento_id uuid,p_workspace_club_id uuid default null)
returns table(
  fotos_usadas integer,
  fotos_limite integer,
  videos_usados integer,
  videos_limite integer,
  videos_externos_usados integer,
  videos_externos_limite integer,
  media_total_usada integer,
  media_total_limite integer,
  max_video_seconds integer,
  max_video_bytes bigint
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_manage boolean:=false;
begin
  if auth.uid() is null then return; end if;
  if p_workspace_club_id is not null then
    select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
  else
    v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id);
  end if;
  if not coalesce(v_manage,false) then return; end if;
  return query
  select
    count(*) filter(where m.estado<>'retirado' and (m.mime_type like 'image/%' or m.tipo in ('foto','foto_referencia')))::integer,
    30,
    count(*) filter(where m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'video/%')::integer,
    5,
    count(*) filter(where m.estado<>'retirado' and m.tipo='video_externo')::integer,
    5,
    count(*) filter(where m.estado<>'retirado')::integer,
    40,
    60,
    104857600::bigint
  from public.kombax_evento_media m where m.evento_id=p_evento_id;
end $$;
revoke all on function public.app_kombax_evento_media_cuota_v253(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_evento_media_cuota_v253(uuid,uuid) to authenticated;

create or replace function public.app_kombax_eventos_mutate_v253(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_event uuid;
  v_existing public.app_mutation_requests;
  v_count integer:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  end if;

  if p_operation='event.media.register' and lower(coalesce(v_payload->>'tipo',''))='video_externo' then
    v_event:=nullif(v_payload->>'evento_id','')::uuid;
    if v_event is null then raise exception 'EVENT_MEDIA_ID_REQUIRED'; end if;
    if not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN'; end if;
    perform pg_advisory_xact_lock(hashtextextended(v_event::text,2010156));
    select count(*)::integer into v_count
    from public.kombax_evento_media m
    where m.evento_id=v_event and m.estado<>'retirado' and m.tipo='video_externo';
    if v_count>=5 then raise exception 'EVENT_EXTERNAL_VIDEO_LIMIT_REACHED'; end if;
  end if;

  return public.app_kombax_eventos_mutate_v191(p_operation,v_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_eventos_mutate_v253(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v253(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
