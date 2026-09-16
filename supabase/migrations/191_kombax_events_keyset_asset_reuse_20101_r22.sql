-- KOMBAX 20.101 R22 · Keyset discovery + media asset reuse without binary duplication
begin;

-- Album references reuse an already published event asset (poster/banner/participant photo)
-- without copying the underlying object in Storage.
alter table public.kombax_evento_media
  add column if not exists source_kind text,
  add column if not exists source_id uuid;

alter table public.kombax_evento_media drop constraint if exists kombax_evento_media_tipo_check;
alter table public.kombax_evento_media add constraint kombax_evento_media_tipo_check
  check (tipo = any(array['foto'::text,'foto_referencia'::text,'clip'::text,'video_externo'::text,'highlight'::text]));

alter table public.kombax_evento_media drop constraint if exists kombax_evento_media_source_ck;
alter table public.kombax_evento_media add constraint kombax_evento_media_source_ck check (
  ((tipo in ('video_externo','foto_referencia')) and storage_path is null and external_url ~* '^https://[^[:space:]]+$')
  or
  ((tipo not in ('video_externo','foto_referencia')) and storage_path is not null and external_url is null)
);

alter table public.kombax_evento_media drop constraint if exists kombax_evento_media_reference_source_ck;
alter table public.kombax_evento_media add constraint kombax_evento_media_reference_source_ck check (
  (tipo='foto_referencia' and source_kind in ('poster','banner','participant') and source_id is not null)
  or
  (tipo<>'foto_referencia' and source_kind is null and source_id is null)
);

create unique index if not exists uq_kombax_evento_media_reference_r22
  on public.kombax_evento_media(evento_id,source_kind,source_id)
  where tipo='foto_referencia' and estado<>'retirado';

-- Cursor/keyset discovery. The first viewport and every next page are capped and
-- independent from the total number of events stored in the platform.
create or replace function public.app_kombax_eventos_publicos_page_v191(
  p_query text default '',
  p_tipo text default null,
  p_estado text default null,
  p_phase text default null,
  p_cursor_bucket integer default null,
  p_cursor_fecha text default null,
  p_cursor_id uuid default null,
  p_limit integer default 24
) returns jsonb
language sql stable security definer set search_path=public as $$
with params as (
  select least(48,greatest(1,coalesce(p_limit,24)))::integer as lim
), base as materialized (
  select
    e.id,e.slug,e.tipo,e.nombre,e.resumen,e.descripcion,e.estado,
    case
      when e.estado='en_curso' then 'ahora'
      when e.estado='finalizado' then 'finalizado'
      when e.fecha_inicio is not null and e.fecha_inicio<=now() and coalesce(e.fecha_fin,e.fecha_inicio+interval '6 hours')>=now() then 'ahora'
      when e.fecha_inicio is not null and coalesce(e.fecha_fin,e.fecha_inicio)<now() then 'finalizado'
      else 'proximo'
    end as fase_temporal,
    case when e.fecha_inicio is null then false else (e.fecha_inicio at time zone e.timezone)::date=(now() at time zone e.timezone)::date end as es_hoy,
    e.fecha_inicio,e.fecha_fin,e.timezone,e.lugar_nombre,e.direccion,e.codigo_postal,e.municipio,e.provincia,e.pais,
    e.cartel_url,e.banner_url,e.cartel_focus_x,e.cartel_focus_y,e.banner_focus_x,e.banner_focus_y,e.tema_visual,e.creador_tipo,e.organizador_nombre,
    e.mapa_url,e.web_oficial_url,e.inscripcion_url,e.inscripciones_abren_en,e.inscripciones_cierran_en,e.inscripcion_precio_desde,e.inscripciones_info,
    public.app_kombax_evento_inscripciones_estado_v173(e.id) as inscripciones_estado,
    e.tickets_url,e.tickets_proveedor,e.tickets_abren_en,e.tickets_cierran_en,e.ticket_precio_desde,e.entradas_info,
    public.app_kombax_evento_entradas_estado_v173(e.id) as entradas_estado,
    e.streaming_url,e.aforo,e.acceso_info,
    mf.id as main_event_fight_id,mf.a_nombre as main_event_a_nombre,mf.b_nombre as main_event_b_nombre,
    mf.a_foto_url as main_event_a_foto_url,mf.b_foto_url as main_event_b_foto_url,mf.disciplina as main_event_disciplina,
    mf.peso_texto as main_event_peso_texto,mf.estado as main_event_estado,
    case
      when (e.estado='en_curso' or (e.fecha_inicio is not null and e.fecha_inicio<=now() and coalesce(e.fecha_fin,e.fecha_inicio+interval '6 hours')>=now())) then 0
      when e.fecha_inicio>=now() then 1
      else 2
    end as sort_bucket,
    coalesce(e.fecha_inicio,'infinity'::timestamptz) as sort_fecha
  from public.kombax_eventos_publicos e
  left join lateral (
    select f.id,a.nombre_publico as a_nombre,b.nombre_publico as b_nombre,
      case when a.origen='kombax' then public.app_kombax_social_avatar_url_v063(asp.id) else a.foto_url_externa end as a_foto_url,
      case when b.origen='kombax' then public.app_kombax_social_avatar_url_v063(bsp.id) else b.foto_url_externa end as b_foto_url,
      f.disciplina,f.peso_texto,f.estado
    from public.kombax_evento_combates_publicos f
    join public.kombax_evento_participantes_publicos a on a.id=f.participante_a_id and a.evento_id=f.evento_id and a.estado_inscripcion='aceptada'
    join public.kombax_evento_participantes_publicos b on b.id=f.participante_b_id and b.evento_id=f.evento_id and b.estado_inscripcion='aceptada'
    left join public.kombax_social_perfiles asp on asp.id=a.competidor_social_profile_id
    left join public.kombax_social_perfiles bsp on bsp.id=b.competidor_social_profile_id
    where f.evento_id=e.id and f.visible_publico and f.estado<>'cancelado'
    order by f.destacado desc,f.co_estelar desc,f.orden nulls last,f.hora_programada nulls last,f.creado_en,f.id
    limit 1
  ) mf on true
  where e.visibilidad='publico'
    and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
    and (p_tipo is null or p_tipo='' or e.tipo=p_tipo)
    and (p_estado is null or p_estado='' or e.estado=p_estado)
    and (coalesce(trim(p_query),'')='' or lower(concat_ws(' ',e.nombre,e.resumen,e.descripcion,e.organizador_nombre,e.lugar_nombre,e.direccion,e.municipio,e.provincia,e.pais,e.tickets_proveedor)) like '%'||lower(trim(p_query))||'%')
), eligible as (
  select b.* from base b
  where (p_phase is null or p_phase='' or b.fase_temporal=p_phase)
    and (
      p_cursor_bucket is null or p_cursor_id is null
      or (b.sort_bucket,b.sort_fecha,b.id) > (p_cursor_bucket,coalesce(nullif(p_cursor_fecha,''),'infinity')::timestamptz,p_cursor_id)
    )
  order by b.sort_bucket,b.sort_fecha,b.id
  limit (select lim+1 from params)
), visible as (
  select * from eligible
  order by sort_bucket,sort_fecha,id
  limit (select lim from params)
), payload as (
  select coalesce(jsonb_agg(to_jsonb(v)-'sort_bucket'-'sort_fecha' order by v.sort_bucket,v.sort_fecha,v.id),'[]'::jsonb) as items
  from visible v
), last_row as (
  select v.sort_bucket,v.sort_fecha,v.id
  from visible v order by v.sort_bucket desc,v.sort_fecha desc,v.id desc limit 1
)
select jsonb_build_object(
  'items',(select items from payload),
  'has_more',(select count(*)>(select lim from params) from eligible),
  'next_cursor',case when exists(select 1 from last_row) then (
    select jsonb_build_object('bucket',sort_bucket,'fecha',sort_fecha::text,'id',id) from last_row
  ) else null end
);
$$;
revoke all on function public.app_kombax_eventos_publicos_page_v191(text,text,text,text,integer,text,uuid,integer) from public;
grant execute on function public.app_kombax_eventos_publicos_page_v191(text,text,text,text,integer,text,uuid,integer) to anon,authenticated;

-- The logical album quota counts referenced photographs as album entries, while
-- poster/banner/fighter images remain outside the album until explicitly linked.
create or replace function public.app_kombax_evento_media_cuota_v175(p_evento_id uuid,p_workspace_club_id uuid default null)
returns table(fotos_usadas integer,fotos_limite integer,videos_usados integer,videos_limite integer,max_video_seconds integer,max_video_bytes bigint)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false;
begin
 if auth.uid() is null then return; end if;
 if p_workspace_club_id is not null then
   select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(p_evento_id,p_workspace_club_id) x;
 else v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 if not coalesce(v_manage,false) then return; end if;
 return query select
   count(*) filter(where m.estado<>'retirado' and (m.mime_type like 'image/%' or m.tipo in ('foto','foto_referencia')))::integer,
   30,
   count(*) filter(where m.estado<>'retirado' and m.storage_path is not null and m.mime_type like 'video/%')::integer,
   5,60,104857600::bigint
 from public.kombax_evento_media m where m.evento_id=p_evento_id;
end $$;
revoke all on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_evento_media_cuota_v175(uuid,uuid) to authenticated;

-- Top-level R22 mutation gateway: preserves all previous mutations, enforces the
-- logical 30-photo quota for uploads and adds reference-only album entries.
create or replace function public.app_kombax_eventos_mutate_v191(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_existing public.app_mutation_requests;
  v_event uuid;
  v_workspace uuid;
  v_manage boolean:=false;
  v_count integer:=0;
  v_kind text;
  v_source uuid;
  v_url text;
  v_title text;
  v_momento text;
  v_media public.kombax_evento_media;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;

  -- Close the logical quota race before delegating a normal photo upload.
  if p_operation='event.media.register' and lower(coalesce(v_payload->>'mime_type','')) like 'image/%' then
    v_event:=nullif(v_payload->>'evento_id','')::uuid;
    if v_event is null then raise exception 'EVENT_MEDIA_ID_REQUIRED'; end if;
    perform pg_advisory_xact_lock(hashtextextended(v_event::text,2010130));
    select count(*)::integer into v_count from public.kombax_evento_media m
      where m.evento_id=v_event and m.estado<>'retirado' and (m.mime_type like 'image/%' or m.tipo in ('foto','foto_referencia'));
    if v_count>=30 then raise exception 'EVENT_PHOTO_LIMIT_REACHED'; end if;
    return public.app_kombax_eventos_mutate_v189(p_operation,v_payload,p_request_id);
  end if;

  if p_operation<>'event.media.reference.add' then
    return public.app_kombax_eventos_mutate_v189(p_operation,v_payload,p_request_id);
  end if;

  v_event:=nullif(v_payload->>'evento_id','')::uuid;
  v_kind:=lower(btrim(coalesce(v_payload->>'source_kind','')));
  v_source:=nullif(v_payload->>'source_id','')::uuid;
  v_momento:=coalesce(nullif(lower(btrim(v_payload->>'momento')),''),'evento');
  v_title:=left(coalesce(nullif(btrim(v_payload->>'titulo'),''),'Recurso del evento'),180);
  if v_event is null or v_kind not in ('poster','banner','participant') then raise exception 'EVENT_MEDIA_REFERENCE_INVALID'; end if;
  if v_momento not in ('previo','evento','posterior') then raise exception 'EVENT_MEDIA_MOMENT_INVALID'; end if;
  if nullif(v_payload->>'workspace_club_id','') is not null then
    v_workspace:=(v_payload->>'workspace_club_id')::uuid;
    select x.puede_gestionar into v_manage from public.app_kombax_evento_contexto_gestion_v171(v_event,v_workspace) x;
  else
    v_manage:=public.app_kombax_evento_puede_gestionar_v160(v_event);
  end if;
  if not coalesce(v_manage,false) then raise exception 'EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN'; end if;

  if v_kind='poster' then
    v_source:=v_event;
    select e.cartel_url into v_url from public.kombax_eventos_publicos e where e.id=v_event;
  elsif v_kind='banner' then
    v_source:=v_event;
    select e.banner_url into v_url from public.kombax_eventos_publicos e where e.id=v_event;
  else
    if v_source is null then raise exception 'EVENT_MEDIA_REFERENCE_PARTICIPANT_REQUIRED'; end if;
    select case when p.origen='kombax' then public.app_kombax_social_avatar_url_v063(sp.id) else p.foto_url_externa end
      into v_url
    from public.kombax_evento_participantes_publicos p
    left join public.kombax_social_perfiles sp on sp.id=p.competidor_social_profile_id
    where p.id=v_source and p.evento_id=v_event;
  end if;
  if v_url is null or v_url !~* '^https://[^[:space:]]+$' then raise exception 'EVENT_MEDIA_REFERENCE_URL_INVALID'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_workspace,p_operation);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_event::text,2010130));
  select * into v_media from public.kombax_evento_media m
    where m.evento_id=v_event and m.tipo='foto_referencia' and m.source_kind=v_kind and m.source_id=v_source and m.estado<>'retirado'
    limit 1 for update;

  if v_media.id is null then
    select count(*)::integer into v_count from public.kombax_evento_media m
      where m.evento_id=v_event and m.estado<>'retirado' and (m.mime_type like 'image/%' or m.tipo in ('foto','foto_referencia'));
    if v_count>=30 then raise exception 'EVENT_PHOTO_LIMIT_REACHED'; end if;
    insert into public.kombax_evento_media(id,evento_id,tipo,storage_path,external_url,mime_type,titulo,descripcion,estado,destacado,allow_download,orden,momento,source_kind,source_id,creado_por)
    values(gen_random_uuid(),v_event,'foto_referencia',null,v_url,'image/reference',v_title,'Reutiliza un recurso ya publicado en el evento sin duplicar el archivo físico.','visible',false,false,0,v_momento,v_kind,v_source,v_uid)
    returning * into v_media;
  else
    update public.kombax_evento_media set external_url=v_url,titulo=v_title,momento=v_momento,estado='visible',actualizado_en=now()
      where id=v_media.id returning * into v_media;
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_media)-'creado_por');
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v191(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v191(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
