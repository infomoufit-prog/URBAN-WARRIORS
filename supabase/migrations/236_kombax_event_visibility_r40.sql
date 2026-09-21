-- KOMBAX 20.101 R40 · Advanced KOMBAX Events visibility.
-- Mirrors live migration 20260904172248 · kombax_event_visibility_r40.
-- Discoverability is independent from R36 publication policy and private club preparation/weight data.
begin;

create table if not exists public.kombax_event_visibility_v236(
  event_id uuid primary key references public.kombax_eventos_publicos(id) on delete cascade,
  mode text not null check(mode in ('public','kombax','network','club','federation','selected_clubs','invitation')),
  target_club_id uuid references public.clubes(id) on delete restrict,
  target_federation_social_id uuid references public.kombax_social_perfiles(id) on delete restrict,
  updated_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  updated_at timestamptz not null default now(),
  check((mode='club' and target_club_id is not null and target_federation_social_id is null)
    or (mode='federation' and target_club_id is null and target_federation_social_id is not null)
    or (mode in ('public','kombax','network','selected_clubs','invitation') and target_club_id is null and target_federation_social_id is null))
);
create table if not exists public.kombax_event_visibility_clubs_v236(
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
  club_id uuid not null references public.clubes(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  primary key(event_id,club_id)
);
create index if not exists idx_kombax_event_visibility_clubs_v236_club on public.kombax_event_visibility_clubs_v236(club_id,event_id);
create index if not exists idx_kombax_event_visibility_v236_target_club on public.kombax_event_visibility_v236(target_club_id) where target_club_id is not null;
create index if not exists idx_kombax_event_visibility_v236_target_federation on public.kombax_event_visibility_v236(target_federation_social_id) where target_federation_social_id is not null;
create index if not exists idx_kombax_event_visibility_v236_updated_by on public.kombax_event_visibility_v236(updated_by) where updated_by is not null;
create index if not exists idx_kombax_event_visibility_clubs_v236_created_by on public.kombax_event_visibility_clubs_v236(created_by) where created_by is not null;
alter table public.kombax_event_visibility_v236 enable row level security;
alter table public.kombax_event_visibility_clubs_v236 enable row level security;
drop policy if exists kombax_event_visibility_v236_deny_direct on public.kombax_event_visibility_v236;
create policy kombax_event_visibility_v236_deny_direct on public.kombax_event_visibility_v236 for all using(false) with check(false);
drop policy if exists kombax_event_visibility_clubs_v236_deny_direct on public.kombax_event_visibility_clubs_v236;
create policy kombax_event_visibility_clubs_v236_deny_direct on public.kombax_event_visibility_clubs_v236 for all using(false) with check(false);
revoke all on table public.kombax_event_visibility_v236 from public,anon,authenticated;
revoke all on table public.kombax_event_visibility_clubs_v236 from public,anon,authenticated;

create or replace function public.app_kombax_event_visibility_mode_v236(p_evento_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select coalesce((select v.mode from public.kombax_event_visibility_v236 v where v.event_id=p_evento_id),
    (select case e.visibilidad when 'publico' then 'public' when 'kombax' then 'kombax' else 'invitation' end from public.kombax_eventos_publicos e where e.id=p_evento_id),'invitation');
$$;
revoke all on function public.app_kombax_event_visibility_mode_v236(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_event_visibility_label_v236(p_evento_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case public.app_kombax_event_visibility_mode_v236(p_evento_id)
    when 'public' then 'Público · web + KOMBAX' when 'kombax' then 'Todo KOMBAX' when 'network' then 'Mi red'
    when 'club' then 'Solo un club' when 'federation' then 'Solo federación / afiliados' when 'selected_clubs' then 'Clubes seleccionados' else 'Por invitación' end;
$$;
revoke all on function public.app_kombax_event_visibility_label_v236(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_event_user_in_organizer_network_v236(p_evento_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
with anchors as (
  select sp.id from public.kombax_eventos_publicos e join public.kombax_social_perfiles sp on (
    (e.creador_tipo='club' and sp.sujeto_tipo='club' and sp.club_id=e.creador_club_id)
    or (e.creador_tipo='perfil_directo' and sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=e.creador_perfil_directo_id))
  where e.id=p_evento_id and sp.visible and sp.estado='activo'
  union
  select ee.social_profile_id from public.kombax_evento_entidades ee join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id and sp.visible and sp.estado='activo'
  where ee.evento_id=p_evento_id and ee.estado='aceptada' and ee.rol in ('organizador_principal','organizador','coorganizador') and ee.social_profile_id is not null
)
select auth.uid() is not null and exists(
  select 1 from anchors a join public.kombax_relaciones r on r.estado='confirmed' and (r.origen_social_id=a.id or r.destino_social_id=a.id)
  where public.app_kombax_social_usuario_controla_social_v235(case when r.origen_social_id=a.id then r.destino_social_id else r.origen_social_id end)
);
$$;
revoke all on function public.app_kombax_event_user_in_organizer_network_v236(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_event_user_invited_v236(p_evento_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and (
    exists(select 1 from public.kombax_evento_entidades ee where ee.evento_id=p_evento_id and ee.estado in ('pendiente','aceptada') and ee.social_profile_id is not null and public.app_kombax_social_usuario_controla_social_v235(ee.social_profile_id))
    or exists(select 1 from public.kombax_evento_participantes_publicos p where p.evento_id=p_evento_id and (
      (p.competidor_social_profile_id is not null and public.app_kombax_social_usuario_controla_social_v235(p.competidor_social_profile_id))
      or (p.presentado_por_social_profile_id is not null and public.app_kombax_social_usuario_controla_social_v235(p.presentado_por_social_profile_id))))
  );
$$;
revoke all on function public.app_kombax_event_user_invited_v236(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_event_can_view_v236(p_evento_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_mode text;v_club uuid;v_fed uuid;
begin
  if public.app_kombax_evento_puede_gestionar_v160(p_evento_id) then return true;end if;
  select coalesce(v.mode,case e.visibilidad when 'publico' then 'public' when 'kombax' then 'kombax' else 'invitation' end),v.target_club_id,v.target_federation_social_id
  into v_mode,v_club,v_fed from public.kombax_eventos_publicos e left join public.kombax_event_visibility_v236 v on v.event_id=e.id where e.id=p_evento_id;
  if v_mode is null then return false;end if;
  if v_mode='public' then return true;end if;
  if auth.uid() is null then return false;end if;
  if v_mode='kombax' then return true;end if;
  if v_mode='network' then return public.app_kombax_event_user_in_organizer_network_v236(p_evento_id);end if;
  if v_mode='club' then return public.app_kombax_social_usuario_pertenece_club_v083(v_club);end if;
  if v_mode='federation' then return public.app_kombax_social_usuario_afiliado_federacion_v083(v_fed,false);end if;
  if v_mode='selected_clubs' then return exists(select 1 from public.kombax_event_visibility_clubs_v236 c where c.event_id=p_evento_id and public.app_kombax_social_usuario_pertenece_club_v083(c.club_id));end if;
  if v_mode='invitation' then return public.app_kombax_event_user_invited_v236(p_evento_id);end if;
  return false;
end $$;
revoke all on function public.app_kombax_event_can_view_v236(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_event_visibility_v236(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_out jsonb;
begin
  if not public.app_kombax_evento_puede_gestionar_v160(p_evento_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED';end if;
  select jsonb_build_object('event_id',e.id,'mode',public.app_kombax_event_visibility_mode_v236(e.id),'label',public.app_kombax_event_visibility_label_v236(e.id),
    'target_club_id',cfg.target_club_id,'target_federation_social_id',cfg.target_federation_social_id,
    'club_ids',coalesce((select jsonb_agg(c.club_id order by c.club_id) from public.kombax_event_visibility_clubs_v236 c where c.event_id=e.id),'[]'::jsonb))
  into v_out from public.kombax_eventos_publicos e left join public.kombax_event_visibility_v236 cfg on cfg.event_id=e.id where e.id=p_evento_id;
  return v_out;
end $$;
revoke all on function public.app_kombax_event_visibility_v236(uuid) from public,anon;
grant execute on function public.app_kombax_event_visibility_v236(uuid) to authenticated;

create or replace function public.app_kombax_event_visibility_mutate_v236(p_evento_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_mode text:=lower(coalesce(nullif(p_payload->>'mode',''),'invitation'));v_club uuid;v_fed uuid;v_item text;v_id uuid;v_count integer:=0;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_evento_puede_gestionar_v160(p_evento_id) then raise exception 'KOMBAX_EVENT_MANAGE_REQUIRED';end if;
  if v_mode not in ('public','kombax','network','club','federation','selected_clubs','invitation') then raise exception 'KOMBAX_EVENT_VISIBILITY_INVALID';end if;
  begin v_club:=nullif(p_payload->>'target_club_id','')::uuid;v_fed:=nullif(p_payload->>'target_federation_social_id','')::uuid;exception when others then raise exception 'KOMBAX_EVENT_VISIBILITY_TARGET_INVALID';end;
  if v_mode='club' and (v_club is null or not exists(select 1 from public.clubes c where c.id=v_club and c.activo)) then raise exception 'KOMBAX_EVENT_VISIBILITY_CLUB_REQUIRED';end if;
  if v_mode='federation' and (v_fed is null or not exists(select 1 from public.kombax_social_perfiles sp join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id where sp.id=v_fed and sp.visible and sp.estado='activo' and d.tipo='federacion')) then raise exception 'KOMBAX_EVENT_VISIBILITY_FEDERATION_REQUIRED';end if;
  if v_mode<>'club' then v_club:=null;end if;if v_mode<>'federation' then v_fed:=null;end if;
  v_count:=jsonb_array_length(case when jsonb_typeof(p_payload->'club_ids')='array' then p_payload->'club_ids' else '[]'::jsonb end);
  if v_count>50 then raise exception 'KOMBAX_EVENT_VISIBILITY_CLUB_LIMIT_50';end if;
  if v_mode='selected_clubs' and v_count<1 then raise exception 'KOMBAX_EVENT_VISIBILITY_CLUB_REQUIRED';end if;
  insert into public.kombax_event_visibility_v236(event_id,mode,target_club_id,target_federation_social_id,updated_by,updated_at)
  values(p_evento_id,v_mode,v_club,v_fed,auth.uid(),now()) on conflict(event_id) do update set mode=excluded.mode,target_club_id=excluded.target_club_id,target_federation_social_id=excluded.target_federation_social_id,updated_by=auth.uid(),updated_at=now();
  delete from public.kombax_event_visibility_clubs_v236 where event_id=p_evento_id;
  if v_mode='selected_clubs' then
    for v_item in select distinct value from jsonb_array_elements_text(case when jsonb_typeof(p_payload->'club_ids')='array' then p_payload->'club_ids' else '[]'::jsonb end) loop
      begin v_id:=v_item::uuid;exception when others then raise exception 'KOMBAX_EVENT_VISIBILITY_CLUB_INVALID';end;
      if not exists(select 1 from public.clubes c where c.id=v_id and c.activo) then raise exception 'KOMBAX_EVENT_VISIBILITY_CLUB_NOT_FOUND';end if;
      insert into public.kombax_event_visibility_clubs_v236(event_id,club_id,created_by) values(p_evento_id,v_id,auth.uid()) on conflict do nothing;
    end loop;
  end if;
  update public.kombax_eventos_publicos set visibilidad=case v_mode when 'public' then 'publico' when 'kombax' then 'kombax' else 'invitacion' end,actualizado_en=now() where id=p_evento_id;
  return public.app_kombax_event_visibility_v236(p_evento_id);
end $$;
revoke all on function public.app_kombax_event_visibility_mutate_v236(uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_event_visibility_mutate_v236(uuid,jsonb) to authenticated;

-- Detail/list readers are intentionally gated by app_kombax_event_can_view_v236 in live R40.
-- Keep a dedicated list endpoint so frontend discovery never falls back to unauthorised rows.
create or replace function public.app_kombax_eventos_visible_page_v236(
  p_query text default '',p_tipo text default null,p_estado text default null,p_phase text default null,
  p_cursor_bucket integer default null,p_cursor_fecha text default null,p_cursor_id uuid default null,p_limit integer default 24)
returns jsonb language sql stable security definer set search_path='' as $$
with params as (select least(48,greatest(1,coalesce(p_limit,24)))::integer lim),
base as materialized (
  select e.id,e.slug,e.tipo,e.nombre,e.resumen,e.descripcion,e.estado,
    case when e.estado='en_curso' then 'ahora' when e.estado='finalizado' then 'finalizado'
      when e.fecha_inicio is not null and e.fecha_inicio<=now() and coalesce(e.fecha_fin,e.fecha_inicio+interval '6 hours')>=now() then 'ahora'
      when e.fecha_inicio is not null and coalesce(e.fecha_fin,e.fecha_inicio)<now() then 'finalizado' else 'proximo' end fase_temporal,
    case when e.fecha_inicio is null then false else (e.fecha_inicio at time zone e.timezone)::date=(now() at time zone e.timezone)::date end es_hoy,
    e.fecha_inicio,e.fecha_fin,e.timezone,e.lugar_nombre,e.direccion,e.codigo_postal,e.municipio,e.provincia,e.pais,e.cartel_url,e.banner_url,e.cartel_focus_x,e.cartel_focus_y,e.banner_focus_x,e.banner_focus_y,e.tema_visual,e.creador_tipo,e.organizador_nombre,
    e.mapa_url,e.web_oficial_url,e.inscripcion_url,e.inscripciones_abren_en,e.inscripciones_cierran_en,e.inscripcion_precio_desde,e.inscripciones_info,public.app_kombax_evento_inscripciones_estado_v173(e.id) inscripciones_estado,
    e.tickets_url,e.tickets_proveedor,e.tickets_abren_en,e.tickets_cierran_en,e.ticket_precio_desde,e.entradas_info,public.app_kombax_evento_entradas_estado_v173(e.id) entradas_estado,e.streaming_url,e.aforo,e.acceso_info,
    public.app_kombax_event_visibility_mode_v236(e.id) visibility_mode,public.app_kombax_event_visibility_label_v236(e.id) visibility_label,
    case when (e.estado='en_curso' or (e.fecha_inicio is not null and e.fecha_inicio<=now() and coalesce(e.fecha_fin,e.fecha_inicio+interval '6 hours')>=now())) then 0 when e.fecha_inicio>=now() then 1 else 2 end sort_bucket,
    coalesce(e.fecha_inicio,'infinity'::timestamptz) sort_fecha
  from public.kombax_eventos_publicos e
  where public.app_kombax_event_can_view_v236(e.id)
    and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
    and (p_tipo is null or p_tipo='' or e.tipo=p_tipo) and (p_estado is null or p_estado='' or e.estado=p_estado)
    and (coalesce(trim(p_query),'')='' or lower(concat_ws(' ',e.nombre,e.resumen,e.descripcion,e.organizador_nombre,e.lugar_nombre,e.direccion,e.municipio,e.provincia,e.pais,e.tickets_proveedor)) like '%'||lower(trim(p_query))||'%')
),eligible as (
  select b.* from base b where (p_phase is null or p_phase='' or b.fase_temporal=p_phase)
    and (p_cursor_bucket is null or p_cursor_id is null or (b.sort_bucket,b.sort_fecha,b.id)>(p_cursor_bucket,coalesce(nullif(p_cursor_fecha,''),'infinity')::timestamptz,p_cursor_id))
  order by b.sort_bucket,b.sort_fecha,b.id limit (select lim+1 from params)
),visible as (select * from eligible order by sort_bucket,sort_fecha,id limit (select lim from params)),
payload as (select coalesce(jsonb_agg(to_jsonb(v)-'sort_bucket'-'sort_fecha' order by v.sort_bucket,v.sort_fecha,v.id),'[]'::jsonb) items from visible v),
last_row as (select v.sort_bucket,v.sort_fecha,v.id from visible v order by v.sort_bucket desc,v.sort_fecha desc,v.id desc limit 1)
select jsonb_build_object('items',(select items from payload),'has_more',(select count(*)>(select lim from params) from eligible),
  'next_cursor',case when exists(select 1 from last_row) then (select jsonb_build_object('bucket',sort_bucket,'fecha',sort_fecha::text,'id',id) from last_row) else null end);
$$;
revoke all on function public.app_kombax_eventos_visible_page_v236(text,text,text,text,integer,text,uuid,integer) from public,anon;
grant execute on function public.app_kombax_eventos_visible_page_v236(text,text,text,text,integer,text,uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;
