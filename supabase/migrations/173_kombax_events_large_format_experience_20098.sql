-- KOMBAX RC13 build 20.098 · 173 · Events Large Format Experience
-- Additive public-event merchandising/venue windows + large-format discovery readers.
-- Never reads or migrates Mi Club > Eventos (eventos_competicion/evento_participantes/evento_combates).
begin;

alter table public.kombax_eventos_publicos
  add column if not exists direccion text not null default '',
  add column if not exists codigo_postal text not null default '',
  add column if not exists mapa_url text,
  add column if not exists web_oficial_url text,
  add column if not exists inscripcion_url text,
  add column if not exists inscripciones_abren_en timestamptz,
  add column if not exists inscripciones_cierran_en timestamptz,
  add column if not exists inscripcion_precio_desde numeric(10,2),
  add column if not exists inscripciones_info text not null default '',
  add column if not exists tickets_url text,
  add column if not exists tickets_proveedor text not null default '',
  add column if not exists tickets_abren_en timestamptz,
  add column if not exists tickets_cierran_en timestamptz,
  add column if not exists ticket_precio_desde numeric(10,2),
  add column if not exists entradas_info text not null default '',
  add column if not exists streaming_url text,
  add column if not exists aforo integer,
  add column if not exists acceso_info text not null default '';

do $$ begin
  if not exists(select 1 from pg_constraint where conname='kombax_eventos_publicos_direccion_v173_ck') then
    alter table public.kombax_eventos_publicos add constraint kombax_eventos_publicos_direccion_v173_ck
      check(char_length(direccion)<=260 and char_length(codigo_postal)<=24);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_eventos_publicos_info_v173_ck') then
    alter table public.kombax_eventos_publicos add constraint kombax_eventos_publicos_info_v173_ck
      check(char_length(inscripciones_info)<=700 and char_length(entradas_info)<=700 and char_length(acceso_info)<=1200 and char_length(tickets_proveedor)<=120);
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_eventos_publicos_prices_v173_ck') then
    alter table public.kombax_eventos_publicos add constraint kombax_eventos_publicos_prices_v173_ck
      check((inscripcion_precio_desde is null or inscripcion_precio_desde>=0) and (ticket_precio_desde is null or ticket_precio_desde>=0) and (aforo is null or aforo>=0));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_eventos_publicos_windows_v173_ck') then
    alter table public.kombax_eventos_publicos add constraint kombax_eventos_publicos_windows_v173_ck
      check((inscripciones_cierran_en is null or inscripciones_abren_en is null or inscripciones_cierran_en>=inscripciones_abren_en)
        and (tickets_cierran_en is null or tickets_abren_en is null or tickets_cierran_en>=tickets_abren_en));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_eventos_publicos_https_v173_ck') then
    alter table public.kombax_eventos_publicos add constraint kombax_eventos_publicos_https_v173_ck
      check(
        (mapa_url is null or mapa_url ~* '^https://[^[:space:]]+$') and
        (web_oficial_url is null or web_oficial_url ~* '^https://[^[:space:]]+$') and
        (inscripcion_url is null or inscripcion_url ~* '^https://[^[:space:]]+$') and
        (tickets_url is null or tickets_url ~* '^https://[^[:space:]]+$') and
        (streaming_url is null or streaming_url ~* '^https://[^[:space:]]+$')
      );
  end if;
end $$;

create index if not exists idx_kombax_eventos_publicos_registration_window_v173
  on public.kombax_eventos_publicos(inscripciones_abren_en,inscripciones_cierran_en,fecha_inicio,id)
  where visibilidad='publico';
create index if not exists idx_kombax_eventos_publicos_ticket_window_v173
  on public.kombax_eventos_publicos(tickets_abren_en,tickets_cierran_en,fecha_inicio,id)
  where visibilidad='publico' and tickets_url is not null;

create or replace function public.app_kombax_evento_inscripciones_estado_v173(p_evento_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when e.id is null then null
    when e.estado in ('cancelado','finalizado','inscripciones_cerradas') then 'cerradas'
    when e.inscripciones_abren_en is not null and now()<e.inscripciones_abren_en then 'proximamente'
    when e.inscripciones_cierran_en is not null and now()>e.inscripciones_cierran_en then 'cerradas'
    when e.estado='inscripciones_abiertas' then 'abiertas'
    when e.inscripcion_url is not null and (e.inscripciones_abren_en is null or now()>=e.inscripciones_abren_en) and (e.inscripciones_cierran_en is null or now()<=e.inscripciones_cierran_en) then 'abiertas'
    else 'no_disponible'
  end
  from public.kombax_eventos_publicos e where e.id=p_evento_id limit 1;
$$;
revoke all on function public.app_kombax_evento_inscripciones_estado_v173(uuid) from public;
grant execute on function public.app_kombax_evento_inscripciones_estado_v173(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_entradas_estado_v173(p_evento_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when e.id is null then null
    when e.tickets_url is null then 'no_disponible'
    when e.estado in ('cancelado','finalizado') then 'cerradas'
    when e.tickets_abren_en is not null and now()<e.tickets_abren_en then 'proximamente'
    when e.tickets_cierran_en is not null and now()>e.tickets_cierran_en then 'cerradas'
    else 'venta'
  end
  from public.kombax_eventos_publicos e where e.id=p_evento_id limit 1;
$$;
revoke all on function public.app_kombax_evento_entradas_estado_v173(uuid) from public;
grant execute on function public.app_kombax_evento_entradas_estado_v173(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_publicos_v173(
 p_query text default '',p_tipo text default null,p_estado text default null,p_limit integer default 60
) returns table(
 id uuid,slug text,tipo text,nombre text,resumen text,descripcion text,estado text,fase_temporal text,es_hoy boolean,
 fecha_inicio timestamptz,fecha_fin timestamptz,timezone text,lugar_nombre text,direccion text,codigo_postal text,municipio text,provincia text,pais text,
 cartel_url text,banner_url text,tema_visual text,creador_tipo text,organizador_nombre text,
 mapa_url text,web_oficial_url text,inscripcion_url text,inscripciones_abren_en timestamptz,inscripciones_cierran_en timestamptz,inscripcion_precio_desde numeric,inscripciones_info text,inscripciones_estado text,
 tickets_url text,tickets_proveedor text,tickets_abren_en timestamptz,tickets_cierran_en timestamptz,ticket_precio_desde numeric,entradas_info text,entradas_estado text,
 streaming_url text,aforo integer,acceso_info text,
 main_event_fight_id uuid,main_event_a_nombre text,main_event_b_nombre text,main_event_a_foto_url text,main_event_b_foto_url text,main_event_disciplina text,main_event_peso_texto text,main_event_estado text
) language sql stable security definer set search_path=public as $$
 select e.id,e.slug,e.tipo,e.nombre,e.resumen,e.descripcion,e.estado,public.app_kombax_evento_estado_temporal_v164(e.id),
   case when e.fecha_inicio is null then false else (e.fecha_inicio at time zone e.timezone)::date=(now() at time zone e.timezone)::date end,
   e.fecha_inicio,e.fecha_fin,e.timezone,e.lugar_nombre,e.direccion,e.codigo_postal,e.municipio,e.provincia,e.pais,
   e.cartel_url,e.banner_url,e.tema_visual,e.creador_tipo,e.organizador_nombre,
   e.mapa_url,e.web_oficial_url,e.inscripcion_url,e.inscripciones_abren_en,e.inscripciones_cierran_en,e.inscripcion_precio_desde,e.inscripciones_info,public.app_kombax_evento_inscripciones_estado_v173(e.id),
   e.tickets_url,e.tickets_proveedor,e.tickets_abren_en,e.tickets_cierran_en,e.ticket_precio_desde,e.entradas_info,public.app_kombax_evento_entradas_estado_v173(e.id),
   e.streaming_url,e.aforo,e.acceso_info,
   mf.id,mf.a_nombre,mf.b_nombre,mf.a_foto_url,mf.b_foto_url,mf.disciplina,mf.peso_texto,mf.estado
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
   order by f.destacado desc,f.orden nulls last,f.hora_programada nulls last,f.creado_en,f.id
   limit 1
 ) mf on true
 where e.visibilidad='publico'
   and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
   and (p_tipo is null or p_tipo='' or e.tipo=p_tipo)
   and (p_estado is null or p_estado='' or e.estado=p_estado)
   and (coalesce(trim(p_query),'')='' or lower(concat_ws(' ',e.nombre,e.resumen,e.descripcion,e.organizador_nombre,e.lugar_nombre,e.direccion,e.municipio,e.provincia,e.pais,e.tickets_proveedor)) like '%'||lower(trim(p_query))||'%')
 order by case when public.app_kombax_evento_estado_temporal_v164(e.id)='ahora' then 0 when e.fecha_inicio>=now() then 1 else 2 end,e.fecha_inicio asc nulls last,e.id
 limit least(100,greatest(1,coalesce(p_limit,60)));
$$;
revoke all on function public.app_kombax_eventos_publicos_v173(text,text,text,integer) from public;
grant execute on function public.app_kombax_eventos_publicos_v173(text,text,text,integer) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_detalle_v173(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_event jsonb;v_main jsonb;
begin
  v_base:=public.app_kombax_evento_publico_detalle_v161(p_evento_id);
  if v_base is null then return null; end if;
  select jsonb_build_object(
    'direccion',e.direccion,'codigo_postal',e.codigo_postal,'mapa_url',e.mapa_url,'web_oficial_url',e.web_oficial_url,
    'inscripcion_url',e.inscripcion_url,'inscripciones_abren_en',e.inscripciones_abren_en,'inscripciones_cierran_en',e.inscripciones_cierran_en,'inscripcion_precio_desde',e.inscripcion_precio_desde,'inscripciones_info',e.inscripciones_info,'inscripciones_estado',public.app_kombax_evento_inscripciones_estado_v173(e.id),
    'tickets_url',e.tickets_url,'tickets_proveedor',e.tickets_proveedor,'tickets_abren_en',e.tickets_abren_en,'tickets_cierran_en',e.tickets_cierran_en,'ticket_precio_desde',e.ticket_precio_desde,'entradas_info',e.entradas_info,'entradas_estado',public.app_kombax_evento_entradas_estado_v173(e.id),
    'streaming_url',e.streaming_url,'aforo',e.aforo,'acceso_info',e.acceso_info,
    'fase_temporal',public.app_kombax_evento_estado_temporal_v164(e.id),
    'es_hoy',case when e.fecha_inicio is null then false else (e.fecha_inicio at time zone e.timezone)::date=(now() at time zone e.timezone)::date end
  ) into v_event from public.kombax_eventos_publicos e where e.id=p_evento_id;
  select to_jsonb(x) into v_main from (
    select f.id as fight_id,a.nombre_publico as a_nombre,b.nombre_publico as b_nombre,
      case when a.origen='kombax' then public.app_kombax_social_avatar_url_v063(asp.id) else a.foto_url_externa end as a_foto_url,
      case when b.origen='kombax' then public.app_kombax_social_avatar_url_v063(bsp.id) else b.foto_url_externa end as b_foto_url,
      f.disciplina,f.categoria,f.peso_texto,f.estado,f.destacado
    from public.kombax_evento_combates_publicos f
    join public.kombax_evento_participantes_publicos a on a.id=f.participante_a_id and a.evento_id=f.evento_id
    join public.kombax_evento_participantes_publicos b on b.id=f.participante_b_id and b.evento_id=f.evento_id
    left join public.kombax_social_perfiles asp on asp.id=a.competidor_social_profile_id
    left join public.kombax_social_perfiles bsp on bsp.id=b.competidor_social_profile_id
    where f.evento_id=p_evento_id and f.visible_publico and f.estado<>'cancelado' and a.estado_inscripcion='aceptada' and b.estado_inscripcion='aceptada'
    order by f.destacado desc,f.orden nulls last,f.hora_programada nulls last,f.creado_en,f.id limit 1
  ) x;
  return jsonb_set(v_base,'{event}',coalesce(v_base->'event','{}'::jsonb)||coalesce(v_event,'{}'::jsonb),true)
    || jsonb_build_object('main_event',coalesce(v_main,'null'::jsonb));
end $$;
revoke all on function public.app_kombax_evento_publico_detalle_v173(uuid) from public;
grant execute on function public.app_kombax_evento_publico_detalle_v173(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_slug_v173(p_slug text)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_id uuid;v_base jsonb;v_eng jsonb;v_fights jsonb;v_media jsonb;
begin
  select e.id into v_id from public.kombax_eventos_publicos e
   where e.slug=lower(btrim(coalesce(p_slug,''))) and e.visibilidad='publico'
     and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') limit 1;
  if v_id is null then return null; end if;
  v_base:=public.app_kombax_evento_publico_detalle_v173(v_id);if v_base is null then return null;end if;
  select to_jsonb(x) into v_eng from public.app_kombax_evento_engagement_v162(v_id) x;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_fights from public.app_kombax_evento_resultados_v164(v_id) x;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_media from public.app_kombax_evento_media_v165(v_id) x;
  return v_base || jsonb_build_object(
    'engagement',coalesce(v_eng,jsonb_build_object('interesados',0,'asistiran',0,'mi_estado',null,'mis_notificaciones',false)),
    'fights',coalesce(v_fights,'[]'::jsonb),'media',coalesce(v_media,'[]'::jsonb)
  );
end $$;
revoke all on function public.app_kombax_evento_publico_slug_v173(text) from public;
grant execute on function public.app_kombax_evento_publico_slug_v173(text) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v173(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_event_id uuid;v_event public.kombax_eventos_publicos;
begin
  v_result:=public.app_kombax_eventos_mutate_v171(p_operation,v_payload,p_request_id);
  if p_operation<>'event.save' then return v_result; end if;
  v_event_id:=nullif(v_result#>>'{data,id}','')::uuid;
  if v_event_id is null then raise exception 'EVENT_SAVE_RESULT_INVALID'; end if;

  update public.kombax_eventos_publicos e set
    direccion=case when v_payload?'direccion' then left(coalesce(v_payload->>'direccion',''),260) else e.direccion end,
    codigo_postal=case when v_payload?'codigo_postal' then left(coalesce(v_payload->>'codigo_postal',''),24) else e.codigo_postal end,
    mapa_url=case when v_payload?'mapa_url' then nullif(v_payload->>'mapa_url','') else e.mapa_url end,
    web_oficial_url=case when v_payload?'web_oficial_url' then nullif(v_payload->>'web_oficial_url','') else e.web_oficial_url end,
    inscripcion_url=case when v_payload?'inscripcion_url' then nullif(v_payload->>'inscripcion_url','') else e.inscripcion_url end,
    inscripciones_abren_en=case when v_payload?'inscripciones_abren_en' then nullif(v_payload->>'inscripciones_abren_en','')::timestamptz else e.inscripciones_abren_en end,
    inscripciones_cierran_en=case when v_payload?'inscripciones_cierran_en' then nullif(v_payload->>'inscripciones_cierran_en','')::timestamptz else e.inscripciones_cierran_en end,
    inscripcion_precio_desde=case when v_payload?'inscripcion_precio_desde' then nullif(v_payload->>'inscripcion_precio_desde','')::numeric else e.inscripcion_precio_desde end,
    inscripciones_info=case when v_payload?'inscripciones_info' then left(coalesce(v_payload->>'inscripciones_info',''),700) else e.inscripciones_info end,
    tickets_url=case when v_payload?'tickets_url' then nullif(v_payload->>'tickets_url','') else e.tickets_url end,
    tickets_proveedor=case when v_payload?'tickets_proveedor' then left(coalesce(v_payload->>'tickets_proveedor',''),120) else e.tickets_proveedor end,
    tickets_abren_en=case when v_payload?'tickets_abren_en' then nullif(v_payload->>'tickets_abren_en','')::timestamptz else e.tickets_abren_en end,
    tickets_cierran_en=case when v_payload?'tickets_cierran_en' then nullif(v_payload->>'tickets_cierran_en','')::timestamptz else e.tickets_cierran_en end,
    ticket_precio_desde=case when v_payload?'ticket_precio_desde' then nullif(v_payload->>'ticket_precio_desde','')::numeric else e.ticket_precio_desde end,
    entradas_info=case when v_payload?'entradas_info' then left(coalesce(v_payload->>'entradas_info',''),700) else e.entradas_info end,
    streaming_url=case when v_payload?'streaming_url' then nullif(v_payload->>'streaming_url','') else e.streaming_url end,
    aforo=case when v_payload?'aforo' then nullif(v_payload->>'aforo','')::integer else e.aforo end,
    acceso_info=case when v_payload?'acceso_info' then left(coalesce(v_payload->>'acceso_info',''),1200) else e.acceso_info end,
    actualizado_en=now()
  where e.id=v_event_id returning e.* into v_event;

  if v_event.id is null then raise exception 'EVENT_NOT_FOUND'; end if;
  if v_event.inscripciones_cierran_en is not null and v_event.inscripciones_abren_en is not null and v_event.inscripciones_cierran_en<v_event.inscripciones_abren_en then raise exception 'EVENT_REGISTRATION_WINDOW_INVALID'; end if;
  if v_event.tickets_cierran_en is not null and v_event.tickets_abren_en is not null and v_event.tickets_cierran_en<v_event.tickets_abren_en then raise exception 'EVENT_TICKET_WINDOW_INVALID'; end if;
  if v_event.inscripcion_precio_desde is not null and v_event.inscripcion_precio_desde<0 then raise exception 'EVENT_REGISTRATION_PRICE_INVALID'; end if;
  if v_event.ticket_precio_desde is not null and v_event.ticket_precio_desde<0 then raise exception 'EVENT_TICKET_PRICE_INVALID'; end if;
  if v_event.aforo is not null and v_event.aforo<0 then raise exception 'EVENT_CAPACITY_INVALID'; end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_event)-'creado_por');
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v173(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v173(text,jsonb,uuid) to authenticated;

revoke all on public.kombax_eventos_publicos from public,anon,authenticated;
comment on function public.app_kombax_eventos_publicos_v173(text,text,text,integer) is '20.098 large-format public Events discovery with independent registration/ticket states and Main Event teaser. Does not query Mi Club Events.';
comment on function public.app_kombax_eventos_mutate_v173(text,jsonb,uuid) is '20.098 additive event-save wrapper preserving 20.097 workspace isolation; external commerce is links-only.';
notify pgrst,'reload schema';
commit;
