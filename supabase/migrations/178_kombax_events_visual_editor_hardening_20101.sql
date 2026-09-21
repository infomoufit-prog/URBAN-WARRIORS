-- KOMBAX RC13 build 20.101 · 178 · Event visual editor & Main Event hardening
-- Additive hardening on top of 20.101. Preserves Mi Club isolation and existing result/media gates.
begin;

alter table public.kombax_eventos_publicos
  add column if not exists cartel_focus_x numeric not null default 50,
  add column if not exists cartel_focus_y numeric not null default 50,
  add column if not exists banner_focus_x numeric not null default 50,
  add column if not exists banner_focus_y numeric not null default 50;

alter table public.kombax_eventos_publicos drop constraint if exists kombax_eventos_cartel_focus_x_ck;
alter table public.kombax_eventos_publicos add constraint kombax_eventos_cartel_focus_x_ck check(cartel_focus_x between 0 and 100);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_eventos_cartel_focus_y_ck;
alter table public.kombax_eventos_publicos add constraint kombax_eventos_cartel_focus_y_ck check(cartel_focus_y between 0 and 100);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_eventos_banner_focus_x_ck;
alter table public.kombax_eventos_publicos add constraint kombax_eventos_banner_focus_x_ck check(banner_focus_x between 0 and 100);
alter table public.kombax_eventos_publicos drop constraint if exists kombax_eventos_banner_focus_y_ck;
alter table public.kombax_eventos_publicos add constraint kombax_eventos_banner_focus_y_ck check(banner_focus_y between 0 and 100);

create or replace function public.app_kombax_eventos_publicos_v178(
 p_query text default '',p_tipo text default null,p_estado text default null,p_limit integer default 60
) returns table(
 id uuid,slug text,tipo text,nombre text,resumen text,descripcion text,estado text,fase_temporal text,es_hoy boolean,
 fecha_inicio timestamptz,fecha_fin timestamptz,timezone text,lugar_nombre text,direccion text,codigo_postal text,municipio text,provincia text,pais text,
 cartel_url text,banner_url text,cartel_focus_x numeric,cartel_focus_y numeric,banner_focus_x numeric,banner_focus_y numeric,tema_visual text,creador_tipo text,organizador_nombre text,
 mapa_url text,web_oficial_url text,inscripcion_url text,inscripciones_abren_en timestamptz,inscripciones_cierran_en timestamptz,inscripcion_precio_desde numeric,inscripciones_info text,inscripciones_estado text,
 tickets_url text,tickets_proveedor text,tickets_abren_en timestamptz,tickets_cierran_en timestamptz,ticket_precio_desde numeric,entradas_info text,entradas_estado text,
 streaming_url text,aforo integer,acceso_info text,
 main_event_fight_id uuid,main_event_a_nombre text,main_event_b_nombre text,main_event_a_foto_url text,main_event_b_foto_url text,main_event_disciplina text,main_event_peso_texto text,main_event_estado text
) language sql stable security definer set search_path=public as $$
 select x.id,x.slug,x.tipo,x.nombre,x.resumen,x.descripcion,x.estado,x.fase_temporal,x.es_hoy,
   x.fecha_inicio,x.fecha_fin,x.timezone,x.lugar_nombre,x.direccion,x.codigo_postal,x.municipio,x.provincia,x.pais,
   x.cartel_url,x.banner_url,e.cartel_focus_x,e.cartel_focus_y,e.banner_focus_x,e.banner_focus_y,x.tema_visual,x.creador_tipo,x.organizador_nombre,
   x.mapa_url,x.web_oficial_url,x.inscripcion_url,x.inscripciones_abren_en,x.inscripciones_cierran_en,x.inscripcion_precio_desde,x.inscripciones_info,x.inscripciones_estado,
   x.tickets_url,x.tickets_proveedor,x.tickets_abren_en,x.tickets_cierran_en,x.ticket_precio_desde,x.entradas_info,x.entradas_estado,
   x.streaming_url,x.aforo,x.acceso_info,
   x.main_event_fight_id,x.main_event_a_nombre,x.main_event_b_nombre,x.main_event_a_foto_url,x.main_event_b_foto_url,x.main_event_disciplina,x.main_event_peso_texto,x.main_event_estado
 from public.app_kombax_eventos_publicos_v173(p_query,p_tipo,p_estado,p_limit) x
 join public.kombax_eventos_publicos e on e.id=x.id;
$$;
revoke all on function public.app_kombax_eventos_publicos_v178(text,text,text,integer) from public;
grant execute on function public.app_kombax_eventos_publicos_v178(text,text,text,integer) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_detalle_v178(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_focus jsonb;
begin
  v_base:=public.app_kombax_evento_publico_detalle_v173(p_evento_id);
  if v_base is null then return null; end if;
  select jsonb_build_object(
    'cartel_focus_x',e.cartel_focus_x,'cartel_focus_y',e.cartel_focus_y,
    'banner_focus_x',e.banner_focus_x,'banner_focus_y',e.banner_focus_y
  ) into v_focus from public.kombax_eventos_publicos e where e.id=p_evento_id;
  return jsonb_set(v_base,'{event}',coalesce(v_base->'event','{}'::jsonb)||coalesce(v_focus,'{}'::jsonb),true);
end $$;
revoke all on function public.app_kombax_evento_publico_detalle_v178(uuid) from public;
grant execute on function public.app_kombax_evento_publico_detalle_v178(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_slug_v178(p_slug text)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_id uuid;v_focus jsonb;
begin
  v_base:=public.app_kombax_evento_publico_slug_v173(p_slug);
  if v_base is null or v_base->'event' is null then return v_base; end if;
  v_id:=nullif(v_base#>>'{event,id}','')::uuid;
  select jsonb_build_object(
    'cartel_focus_x',e.cartel_focus_x,'cartel_focus_y',e.cartel_focus_y,
    'banner_focus_x',e.banner_focus_x,'banner_focus_y',e.banner_focus_y
  ) into v_focus from public.kombax_eventos_publicos e where e.id=v_id;
  return jsonb_set(v_base,'{event}',coalesce(v_base->'event','{}'::jsonb)||coalesce(v_focus,'{}'::jsonb),true);
end $$;
revoke all on function public.app_kombax_evento_publico_slug_v178(text) from public;
grant execute on function public.app_kombax_evento_publico_slug_v178(text) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v178(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_result jsonb;v_event_id uuid;v_fight_id uuid;v_event public.kombax_eventos_publicos;
begin
  v_result:=public.app_kombax_eventos_mutate_v175(p_operation,v_payload,p_request_id);

  if p_operation='event.save' then
    v_event_id:=nullif(v_result#>>'{data,id}','')::uuid;
    if v_event_id is null then raise exception 'EVENT_SAVE_RESULT_INVALID'; end if;
    update public.kombax_eventos_publicos e set
      cartel_focus_x=case when v_payload?'cartel_focus_x' then least(100,greatest(0,coalesce(nullif(v_payload->>'cartel_focus_x','')::numeric,e.cartel_focus_x))) else e.cartel_focus_x end,
      cartel_focus_y=case when v_payload?'cartel_focus_y' then least(100,greatest(0,coalesce(nullif(v_payload->>'cartel_focus_y','')::numeric,e.cartel_focus_y))) else e.cartel_focus_y end,
      banner_focus_x=case when v_payload?'banner_focus_x' then least(100,greatest(0,coalesce(nullif(v_payload->>'banner_focus_x','')::numeric,e.banner_focus_x))) else e.banner_focus_x end,
      banner_focus_y=case when v_payload?'banner_focus_y' then least(100,greatest(0,coalesce(nullif(v_payload->>'banner_focus_y','')::numeric,e.banner_focus_y))) else e.banner_focus_y end,
      actualizado_en=now()
    where e.id=v_event_id returning e.* into v_event;
    v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_event)-'creado_por');
    update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  elsif p_operation='event.fight.save' and coalesce((v_payload->>'destacado')::boolean,false) then
    v_fight_id:=nullif(v_result#>>'{data,id}','')::uuid;
    v_event_id:=nullif(v_result#>>'{data,evento_id}','')::uuid;
    if v_fight_id is not null and v_event_id is not null then
      update public.kombax_evento_combates_publicos set destacado=false,actualizado_en=now()
      where evento_id=v_event_id and id<>v_fight_id and destacado=true;
    end if;
  end if;
  return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v178(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v178(text,jsonb,uuid) to authenticated;

create or replace function public.app_kombax_demo_event_seed_v178()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_result jsonb;v_event uuid;
begin
  v_result:=public.app_kombax_demo_event_seed_v177();
  v_event:=nullif(v_result->>'event_id','')::uuid;
  if v_event is null then return v_result; end if;
  update public.kombax_eventos_publicos set
    nombre='Noche de Impacto · Barcelona',
    resumen='Velada completa para demostrar a clubes y federaciones cómo se publica y vive un KOMBAX Evento.',
    descripcion='Evento completo de ejemplo con organizador, federación avaladora, Main Event, co-main femenino, undercard, participantes, entradas, inscripción, recinto, álbum previo/evento/postevento y highlights.',
    organizador_nombre='Club Fénix Elite',
    inscripciones_info='Inscripción de ejemplo para competidores. Categorías y reglamento preparados para presentación comercial.',
    tickets_proveedor='KOMBAX Tickets',
    entradas_info='Entrada general desde 29 €, grada 39 € y front row 59 €. KOMBAX enlaza al proveedor y no procesa el pago.',
    cartel_focus_x=50,cartel_focus_y=45,banner_focus_x=50,banner_focus_y=42,
    actualizado_en=now()
  where id=v_event;
  update public.kombax_evento_entidades set nombre_externo='Club Fénix Elite',actualizado_en=now()
    where evento_id=v_event and origen='externa' and rol='organizador_principal';
  update public.kombax_evento_entidades set nombre_externo='Federación Nova Combat',actualizado_en=now()
    where evento_id=v_event and origen='externa' and rol='avala';
  return jsonb_set(v_result,'{presentation}',jsonb_build_object('nombre','Noche de Impacto · Barcelona','organiza','Club Fénix Elite','avala','Federación Nova Combat'),true);
end $$;
revoke all on function public.app_kombax_demo_event_seed_v178() from public,anon;
grant execute on function public.app_kombax_demo_event_seed_v178() to authenticated;

-- One-time presentation cleanup for the existing QA event. Identification stays by slug/UUID, never by public labels.
update public.kombax_eventos_publicos set
  nombre='Noche de Impacto · Barcelona',organizador_nombre='Club Fénix Elite',
  resumen='Velada completa para demostrar a clubes y federaciones cómo se publica y vive un KOMBAX Evento.',
  descripcion='Evento completo de ejemplo con organizador, federación avaladora, Main Event, co-main femenino, undercard, participantes, entradas, inscripción, recinto, álbum previo/evento/postevento y highlights.',
  inscripciones_info='Inscripción de ejemplo para competidores. Categorías y reglamento preparados para presentación comercial.',
  tickets_proveedor='KOMBAX Tickets',
  entradas_info='Entrada general desde 29 €, grada 39 € y front row 59 €. KOMBAX enlaza al proveedor y no procesa el pago.',
  cartel_focus_x=50,cartel_focus_y=45,banner_focus_x=50,banner_focus_y=42,actualizado_en=now()
where slug='noche-de-impacto-barcelona-demo';

update public.kombax_evento_entidades ee set nombre_externo='Club Fénix Elite',actualizado_en=now()
from public.kombax_eventos_publicos e
where ee.evento_id=e.id and e.slug='noche-de-impacto-barcelona-demo' and ee.origen='externa' and ee.rol='organizador_principal';
update public.kombax_evento_entidades ee set nombre_externo='Federación Nova Combat',actualizado_en=now()
from public.kombax_eventos_publicos e
where ee.evento_id=e.id and e.slug='noche-de-impacto-barcelona-demo' and ee.origen='externa' and ee.rol='avala';

comment on function public.app_kombax_eventos_mutate_v178(text,jsonb,uuid) is '20.101 visual-editor hardening: persistent focal points and single Main Event invariant. Preserves v175 media and v171 workspace isolation.';
notify pgrst,'reload schema';
commit;
