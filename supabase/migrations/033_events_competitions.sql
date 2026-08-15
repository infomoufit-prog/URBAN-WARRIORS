-- Urban Warriors RC13 MVP · eventos, inscripciones y combates.
-- Participantes externos no requieren cuenta. Sin bracket automático.
-- Requiere 032 para encadenar el gateway vigente.

begin;

-- Permiso de gestión definido antes de las políticas RLS que lo consumen.
create or replace function public.app_puede_gestionar_eventos_v033(p_club_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select exists(
    select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol in ('direccion','secretaria','monitor') or coalesce(m.coordinacion,false))
  );
$$;
revoke all on function public.app_puede_gestionar_eventos_v033(uuid) from public,anon;
grant execute on function public.app_puede_gestionar_eventos_v033(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 1. EVENTOS / COMPETICIONES
-- --------------------------------------------------------------------------
create table if not exists public.eventos_competicion (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  disciplina_id uuid,
  nombre text not null,
  descripcion text,
  fecha date not null,
  hora_inicio time,
  hora_fin time,
  lugar text,
  organizador text,
  fecha_limite_inscripcion date,
  estado text not null default 'borrador' check(estado in ('borrador','abierto','cerrado','finalizado','cancelado')),
  edad_min smallint,
  edad_max smallint,
  peso_min numeric(6,2),
  peso_max numeric(6,2),
  categoria_texto text,
  grado_minimo_texto text,
  documentacion_requerida text,
  autorizacion_requerida boolean not null default false,
  cuota_inscripcion numeric(10,2),
  observaciones_requisitos text,
  creado_por uuid references public.perfiles(id) on delete set null,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(club_id,id),
  foreign key(disciplina_id) references public.disciplinas(id) on delete set null,
  check (char_length(nombre)<=180),
  check (char_length(coalesce(descripcion,''))<=4000),
  check (char_length(coalesce(lugar,''))<=240),
  check (char_length(coalesce(organizador,''))<=180),
  check (char_length(coalesce(categoria_texto,''))<=180),
  check (char_length(coalesce(grado_minimo_texto,''))<=180),
  check (char_length(coalesce(documentacion_requerida,''))<=1500),
  check (char_length(coalesce(observaciones_requisitos,''))<=2000),
  check (fecha_limite_inscripcion is null or fecha_limite_inscripcion<=fecha),
  check (hora_fin is null or hora_inicio is null or hora_fin>hora_inicio),
  check (edad_min is null or edad_min between 0 and 120),
  check (edad_max is null or (edad_max between 0 and 120 and edad_max>=coalesce(edad_min,0))),
  check (peso_min is null or peso_min between 0 and 1000),
  check (peso_max is null or (peso_max between 0 and 1000 and peso_max>=coalesce(peso_min,0))),
  check (cuota_inscripcion is null or cuota_inscripcion>=0)
);
create index if not exists idx_eventos_competicion_club_fecha_v033
  on public.eventos_competicion(club_id,fecha desc,estado,id);
alter table public.eventos_competicion enable row level security;
drop policy if exists eventos_competicion_lectura_v033 on public.eventos_competicion;
create policy eventos_competicion_lectura_v033 on public.eventos_competicion
for select to authenticated using(
  public.es_miembro_club(club_id)
  and (estado<>'borrador' or public.app_puede_gestionar_eventos_v033(club_id))
);
revoke all on public.eventos_competicion from public,anon,authenticated;
grant select on public.eventos_competicion to authenticated;

-- --------------------------------------------------------------------------
-- 2. INSCRITOS: SOCIOS O EXTERNOS
-- --------------------------------------------------------------------------
create table if not exists public.evento_participantes (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  evento_id uuid not null,
  socio_id uuid,
  externo boolean not null default false,
  nombre text not null,
  apellidos text,
  club_origen text,
  disciplina_texto text,
  categoria_texto text,
  peso numeric(6,2),
  grado_texto text,
  edad smallint,
  estado text not null default 'solicitado' check(estado in ('solicitado','confirmado','rechazado','baja')),
  observaciones text,
  creado_por uuid references public.perfiles(id) on delete set null,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(club_id,id),
  foreign key(club_id,evento_id) references public.eventos_competicion(club_id,id) on delete cascade,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete cascade,
  check ((externo and socio_id is null) or (not externo and socio_id is not null)),
  check (peso is null or peso>=0),
  check (edad is null or edad between 0 and 120),
  check (char_length(nombre)<=120),
  check (char_length(coalesce(apellidos,''))<=180),
  check (char_length(coalesce(club_origen,''))<=180),
  check (char_length(coalesce(disciplina_texto,''))<=160),
  check (char_length(coalesce(categoria_texto,''))<=160),
  check (char_length(coalesce(grado_texto,''))<=160),
  check (char_length(coalesce(observaciones,''))<=1000)
);
create unique index if not exists uq_evento_participante_socio_v033
  on public.evento_participantes(club_id,evento_id,socio_id) where socio_id is not null;
create index if not exists idx_evento_participantes_evento_estado_v033
  on public.evento_participantes(club_id,evento_id,estado,creado_en,id);
alter table public.evento_participantes enable row level security;
drop policy if exists evento_participantes_lectura_v033 on public.evento_participantes;
create policy evento_participantes_lectura_v033 on public.evento_participantes
for select to authenticated using(
  public.es_miembro_club(club_id)
  and exists(
    select 1 from public.eventos_competicion e
    where e.club_id=evento_participantes.club_id and e.id=evento_participantes.evento_id
      and (e.estado<>'borrador' or public.app_puede_gestionar_eventos_v033(e.club_id))
  )
);
revoke all on public.evento_participantes from public,anon,authenticated;
-- Lectura únicamente mediante RPC segura para ocultar estados/datos sensibles de terceros.

-- --------------------------------------------------------------------------
-- 3. COMBATES MANUALES
-- --------------------------------------------------------------------------
create table if not exists public.evento_combates (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  evento_id uuid not null,
  participante_a_id uuid not null,
  participante_b_id uuid not null,
  disciplina_texto text,
  categoria_texto text,
  tatami_ring text,
  orden integer,
  hora_aprox time,
  estado text not null default 'pendiente' check(estado in ('pendiente','en_curso','finalizado','cancelado')),
  resultado text,
  ganador_participante_id uuid,
  observaciones text,
  creado_por uuid references public.perfiles(id) on delete set null,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(club_id,id),
  foreign key(club_id,evento_id) references public.eventos_competicion(club_id,id) on delete cascade,
  foreign key(club_id,participante_a_id) references public.evento_participantes(club_id,id) on delete cascade,
  foreign key(club_id,participante_b_id) references public.evento_participantes(club_id,id) on delete cascade,
  foreign key(ganador_participante_id) references public.evento_participantes(id) on delete set null,
  check(participante_a_id<>participante_b_id),
  check(ganador_participante_id is null or ganador_participante_id in (participante_a_id,participante_b_id)),
  check(orden is null or orden>0),
  check(char_length(coalesce(disciplina_texto,''))<=160),
  check(char_length(coalesce(categoria_texto,''))<=160),
  check(char_length(coalesce(tatami_ring,''))<=120),
  check(char_length(coalesce(resultado,''))<=500),
  check(char_length(coalesce(observaciones,''))<=1000)
);
create index if not exists idx_evento_combates_evento_orden_v033
  on public.evento_combates(club_id,evento_id,orden,hora_aprox,id);
alter table public.evento_combates enable row level security;
drop policy if exists evento_combates_lectura_v033 on public.evento_combates;
create policy evento_combates_lectura_v033 on public.evento_combates
for select to authenticated using(
  public.es_miembro_club(club_id)
  and exists(
    select 1 from public.eventos_competicion e
    where e.club_id=evento_combates.club_id and e.id=evento_combates.evento_id
      and (e.estado<>'borrador' or public.app_puede_gestionar_eventos_v033(e.club_id))
  )
);
revoke all on public.evento_combates from public,anon,authenticated;

-- Lecturas seguras: el equipo ve la ficha operativa completa; el resto del club
-- solo ve inscritos confirmados y datos deportivos necesarios. Edad, peso y
-- observaciones de terceros no se exponen por lectura directa.
create or replace function public.app_evento_participantes_visibles_v033(p_club_id uuid,p_evento_id uuid)
returns table(
  id uuid,club_id uuid,evento_id uuid,socio_id uuid,externo boolean,nombre text,apellidos text,club_origen text,
  disciplina_texto text,categoria_texto text,peso numeric,grado_texto text,edad smallint,estado text,observaciones text,
  creado_en timestamptz,actualizado_en timestamptz
)
language sql stable security definer set search_path=public,auth
as $$
  select ep.id,ep.club_id,ep.evento_id,ep.socio_id,ep.externo,ep.nombre,ep.apellidos,ep.club_origen,
    ep.disciplina_texto,ep.categoria_texto,
    case when public.app_puede_gestionar_eventos_v033(ep.club_id) or (not ep.externo and public.puede_ver_socio(ep.socio_id)) then ep.peso else null end,
    ep.grado_texto,
    case when public.app_puede_gestionar_eventos_v033(ep.club_id) or (not ep.externo and public.puede_ver_socio(ep.socio_id)) then ep.edad else null end,
    ep.estado,
    case when public.app_puede_gestionar_eventos_v033(ep.club_id) or (not ep.externo and public.puede_ver_socio(ep.socio_id)) then ep.observaciones else null end,
    ep.creado_en,ep.actualizado_en
  from public.evento_participantes ep
  where ep.club_id=p_club_id and ep.evento_id=p_evento_id
    and public.es_miembro_club(ep.club_id)
    and exists(
      select 1 from public.eventos_competicion e
      where e.club_id=ep.club_id and e.id=ep.evento_id
        and (e.estado<>'borrador' or public.app_puede_gestionar_eventos_v033(e.club_id))
    )
    and (
      public.app_puede_gestionar_eventos_v033(ep.club_id)
      or ep.estado='confirmado'
      or (not ep.externo and public.puede_ver_socio(ep.socio_id))
    )
  order by case ep.estado when 'confirmado' then 0 when 'solicitado' then 1 when 'rechazado' then 2 else 3 end,ep.apellidos,ep.nombre,ep.id;
$$;
revoke all on function public.app_evento_participantes_visibles_v033(uuid,uuid) from public,anon;
grant execute on function public.app_evento_participantes_visibles_v033(uuid,uuid) to authenticated;

create or replace function public.app_evento_combates_visibles_v033(p_club_id uuid,p_evento_id uuid)
returns table(
  id uuid,club_id uuid,evento_id uuid,participante_a_id uuid,participante_b_id uuid,disciplina_texto text,categoria_texto text,
  tatami_ring text,orden integer,hora_aprox time,estado text,resultado text,ganador_participante_id uuid,observaciones text,creado_en timestamptz
)
language sql stable security definer set search_path=public,auth
as $$
  select c.id,c.club_id,c.evento_id,c.participante_a_id,c.participante_b_id,c.disciplina_texto,c.categoria_texto,
    c.tatami_ring,c.orden,c.hora_aprox,c.estado,c.resultado,c.ganador_participante_id,
    case when public.app_puede_gestionar_eventos_v033(c.club_id) then c.observaciones else null end,c.creado_en
  from public.evento_combates c
  where c.club_id=p_club_id and c.evento_id=p_evento_id
    and public.es_miembro_club(c.club_id)
    and exists(
      select 1 from public.eventos_competicion e
      where e.club_id=c.club_id and e.id=c.evento_id
        and (e.estado<>'borrador' or public.app_puede_gestionar_eventos_v033(e.club_id))
    )
  order by c.orden nulls last,c.hora_aprox nulls last,c.creado_en,c.id;
$$;
revoke all on function public.app_evento_combates_visibles_v033(uuid,uuid) from public,anon;
grant execute on function public.app_evento_combates_visibles_v033(uuid,uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 4. CONTRATO RUNTIME: AÑADE EVENTOS AL CONTRATO YA EXTENDIDO POR 032
-- --------------------------------------------------------------------------
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_events_033(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '033: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_events_033;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_events_033(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_events_033(p_club_id);
  return jsonb_set(
    v_base,
    '{operations}',
    coalesce(v_base->'operations','[]'::jsonb) || jsonb_build_array(
      'evento.guardar','evento.estado','evento.participante.externo','evento.inscripcion.solicitar',
      'evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar'
    ),
    true
  );
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 5. GATEWAY DE MUTACIONES
-- --------------------------------------------------------------------------
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_events_033(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '033: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_events_033;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_events_033(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_data jsonb;
  v_result jsonb;
  v_id uuid;
  v_event public.eventos_competicion;
  v_part public.evento_participantes;
  v_fight public.evento_combates;
  v_socio public.socios;
  v_a public.evento_participantes;
  v_b public.evento_participantes;
  v_discipline text;
  v_grade text;
  v_age smallint;
  v_status text;
  v_winner uuid;
begin
  if p_operation not in (
    'evento.guardar','evento.estado','evento.participante.externo','evento.inscripcion.solicitar',
    'evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar'
  ) then
    return public.app_mutate_v160_pre_events_033(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='evento.guardar' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para gestionar eventos'; end if;
    begin v_id:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'EVENTO_ID_INVALIDO'; end;
    if nullif(trim(v_payload->>'nombre'),'') is null then raise exception 'El evento necesita nombre'; end if;
    if nullif(v_payload->>'fecha','') is null then raise exception 'El evento necesita fecha'; end if;
    v_status:=lower(trim(coalesce(nullif(v_payload->>'estado',''),'borrador')));
    if v_status not in ('borrador','abierto','cerrado','finalizado','cancelado') then raise exception 'Estado de evento inválido'; end if;
    if nullif(v_payload->>'disciplina_id','') is not null and not exists(
      select 1 from public.disciplinas d where d.club_id=v_club and d.id=(v_payload->>'disciplina_id')::uuid and d.activa
    ) then raise exception 'Disciplina no disponible'; end if;

    if v_id is null then
      insert into public.eventos_competicion(
        club_id,disciplina_id,nombre,descripcion,fecha,hora_inicio,hora_fin,lugar,organizador,fecha_limite_inscripcion,estado,
        edad_min,edad_max,peso_min,peso_max,categoria_texto,grado_minimo_texto,documentacion_requerida,
        autorizacion_requerida,cuota_inscripcion,observaciones_requisitos,creado_por,actualizado_por
      ) values(
        v_club,nullif(v_payload->>'disciplina_id','')::uuid,trim(v_payload->>'nombre'),nullif(trim(v_payload->>'descripcion'),''),
        (v_payload->>'fecha')::date,nullif(v_payload->>'hora_inicio','')::time,nullif(v_payload->>'hora_fin','')::time,
        nullif(trim(v_payload->>'lugar'),''),nullif(trim(v_payload->>'organizador'),''),nullif(v_payload->>'fecha_limite_inscripcion','')::date,
        v_status,nullif(v_payload->>'edad_min','')::smallint,nullif(v_payload->>'edad_max','')::smallint,
        nullif(v_payload->>'peso_min','')::numeric,nullif(v_payload->>'peso_max','')::numeric,nullif(trim(v_payload->>'categoria_texto'),''),
        nullif(trim(v_payload->>'grado_minimo_texto'),''),nullif(trim(v_payload->>'documentacion_requerida'),''),
        coalesce((v_payload->>'autorizacion_requerida')::boolean,false),nullif(v_payload->>'cuota_inscripcion','')::numeric,
        nullif(trim(v_payload->>'observaciones_requisitos'),''),v_uid,v_uid
      ) returning * into v_event;
    else
      update public.eventos_competicion set
        disciplina_id=nullif(v_payload->>'disciplina_id','')::uuid,
        nombre=trim(v_payload->>'nombre'),descripcion=nullif(trim(v_payload->>'descripcion'),''),fecha=(v_payload->>'fecha')::date,
        hora_inicio=nullif(v_payload->>'hora_inicio','')::time,hora_fin=nullif(v_payload->>'hora_fin','')::time,
        lugar=nullif(trim(v_payload->>'lugar'),''),organizador=nullif(trim(v_payload->>'organizador'),''),
        fecha_limite_inscripcion=nullif(v_payload->>'fecha_limite_inscripcion','')::date,
        estado=v_status,
        edad_min=nullif(v_payload->>'edad_min','')::smallint,edad_max=nullif(v_payload->>'edad_max','')::smallint,
        peso_min=nullif(v_payload->>'peso_min','')::numeric,peso_max=nullif(v_payload->>'peso_max','')::numeric,
        categoria_texto=nullif(trim(v_payload->>'categoria_texto'),''),grado_minimo_texto=nullif(trim(v_payload->>'grado_minimo_texto'),''),
        documentacion_requerida=nullif(trim(v_payload->>'documentacion_requerida'),''),
        autorizacion_requerida=coalesce((v_payload->>'autorizacion_requerida')::boolean,false),
        cuota_inscripcion=nullif(v_payload->>'cuota_inscripcion','')::numeric,
        observaciones_requisitos=nullif(trim(v_payload->>'observaciones_requisitos'),''),actualizado_por=v_uid,actualizado_en=now()
      where club_id=v_club and id=v_id returning * into v_event;
      if v_event.id is null then raise exception 'Evento no encontrado'; end if;
    end if;
    v_data:=to_jsonb(v_event);

  elsif p_operation='evento.estado' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para gestionar eventos'; end if;
    v_id:=(v_payload->>'evento_id')::uuid;
    v_status:=lower(trim(coalesce(v_payload->>'estado','')));
    if v_status not in ('borrador','abierto','cerrado','finalizado','cancelado') then raise exception 'Estado de evento inválido'; end if;
    update public.eventos_competicion set estado=v_status,actualizado_por=v_uid,actualizado_en=now()
    where club_id=v_club and id=v_id returning * into v_event;
    if v_event.id is null then raise exception 'Evento no encontrado'; end if;
    v_data:=jsonb_build_object('id',v_event.id,'estado',v_event.estado);

  elsif p_operation='evento.participante.externo' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para gestionar participantes'; end if;
    begin v_id:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'PARTICIPANTE_ID_INVALIDO'; end;
    select * into v_event from public.eventos_competicion where club_id=v_club and id=(v_payload->>'evento_id')::uuid;
    if v_event.id is null or v_event.estado in ('finalizado','cancelado') then raise exception 'Evento no disponible'; end if;
    if nullif(trim(v_payload->>'nombre'),'') is null then raise exception 'Indica el nombre del participante'; end if;
    v_status:=lower(trim(coalesce(nullif(v_payload->>'estado',''),'confirmado')));
    if v_status not in ('solicitado','confirmado','rechazado','baja') then raise exception 'Estado de inscripción inválido'; end if;
    if v_id is null then
      insert into public.evento_participantes(
        club_id,evento_id,socio_id,externo,nombre,apellidos,club_origen,disciplina_texto,categoria_texto,peso,grado_texto,edad,estado,observaciones,creado_por,actualizado_por
      ) values(
        v_club,v_event.id,null,true,trim(v_payload->>'nombre'),nullif(trim(v_payload->>'apellidos'),''),nullif(trim(v_payload->>'club_origen'),''),
        nullif(trim(v_payload->>'disciplina_texto'),''),nullif(trim(v_payload->>'categoria_texto'),''),nullif(v_payload->>'peso','')::numeric,
        nullif(trim(v_payload->>'grado_texto'),''),nullif(v_payload->>'edad','')::smallint,v_status,
        nullif(trim(v_payload->>'observaciones'),''),v_uid,v_uid
      ) returning * into v_part;
    else
      update public.evento_participantes set
        nombre=trim(v_payload->>'nombre'),apellidos=nullif(trim(v_payload->>'apellidos'),''),club_origen=nullif(trim(v_payload->>'club_origen'),''),
        disciplina_texto=nullif(trim(v_payload->>'disciplina_texto'),''),categoria_texto=nullif(trim(v_payload->>'categoria_texto'),''),
        peso=nullif(v_payload->>'peso','')::numeric,grado_texto=nullif(trim(v_payload->>'grado_texto'),''),edad=nullif(v_payload->>'edad','')::smallint,
        observaciones=nullif(trim(v_payload->>'observaciones'),''),actualizado_por=v_uid,actualizado_en=now()
      where club_id=v_club and evento_id=v_event.id and id=v_id and externo=true returning * into v_part;
      if v_part.id is null then raise exception 'Participante externo no encontrado'; end if;
    end if;
    v_data:=to_jsonb(v_part);

  elsif p_operation='evento.inscripcion.solicitar' then
    v_id:=(v_payload->>'evento_id')::uuid;
    select * into v_event from public.eventos_competicion where club_id=v_club and id=v_id;
    if v_event.id is null then raise exception 'Evento no disponible'; end if;
    if public.app_puede_gestionar_eventos_v033(v_club) then
      if v_event.estado in ('finalizado','cancelado') then raise exception 'No se pueden añadir participantes a un evento finalizado o cancelado'; end if;
    else
      if v_event.estado<>'abierto' then raise exception 'Las inscripciones no están abiertas'; end if;
      if v_event.fecha_limite_inscripcion is not null and current_date>v_event.fecha_limite_inscripcion then raise exception 'La fecha límite de inscripción ha pasado'; end if;
    end if;
    select * into v_socio from public.socios where club_id=v_club and id=(v_payload->>'socio_id')::uuid and estado='activo';
    if v_socio.id is null then raise exception 'Alumno no disponible'; end if;
    if not public.puede_ver_socio(v_socio.id) then raise exception 'No puedes inscribir a este alumno'; end if;

    select d.nombre,g.nombre into v_discipline,v_grade
    from public.socio_disciplinas sd
    join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
    left join public.grados g on g.club_id=sd.club_id and g.id=sd.grado_id
    where sd.club_id=v_club and sd.socio_id=v_socio.id and sd.activa
      and (v_event.disciplina_id is null or sd.disciplina_id=v_event.disciplina_id)
    order by case when sd.disciplina_id=v_event.disciplina_id then 0 else 1 end,sd.fecha_inicio
    limit 1;
    if v_socio.fecha_nacimiento is not null then v_age:=extract(year from age(v_socio.fecha_nacimiento))::smallint; end if;

    insert into public.evento_participantes(
      club_id,evento_id,socio_id,externo,nombre,apellidos,club_origen,disciplina_texto,categoria_texto,peso,grado_texto,edad,estado,observaciones,creado_por,actualizado_por
    ) values(
      v_club,v_event.id,v_socio.id,false,v_socio.nombre,v_socio.apellidos,null,coalesce(v_discipline,nullif(v_payload->>'disciplina_texto','')),
      nullif(trim(v_payload->>'categoria_texto'),''),nullif(v_payload->>'peso','')::numeric,coalesce(v_grade,nullif(v_payload->>'grado_texto','')),
      v_age,'solicitado',nullif(trim(v_payload->>'observaciones'),''),v_uid,v_uid
    )
    on conflict(club_id,evento_id,socio_id) where socio_id is not null do update set
      estado=case when public.evento_participantes.estado='confirmado' then 'confirmado' else 'solicitado' end,
      categoria_texto=coalesce(excluded.categoria_texto,public.evento_participantes.categoria_texto),
      peso=coalesce(excluded.peso,public.evento_participantes.peso),
      disciplina_texto=coalesce(excluded.disciplina_texto,public.evento_participantes.disciplina_texto),
      grado_texto=coalesce(excluded.grado_texto,public.evento_participantes.grado_texto),
      edad=coalesce(excluded.edad,public.evento_participantes.edad),
      observaciones=excluded.observaciones,actualizado_por=v_uid,actualizado_en=now()
    returning * into v_part;
    v_data:=to_jsonb(v_part);

  elsif p_operation='evento.inscripcion.estado' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para validar inscripciones'; end if;
    v_status:=lower(trim(coalesce(v_payload->>'estado','')));
    if v_status not in ('solicitado','confirmado','rechazado','baja') then raise exception 'Estado de inscripción inválido'; end if;
    if v_status<>'confirmado' and exists(
      select 1 from public.evento_combates c
      where c.club_id=v_club and c.estado<>'cancelado'
        and (c.participante_a_id=(v_payload->>'participante_id')::uuid or c.participante_b_id=(v_payload->>'participante_id')::uuid)
    ) then raise exception 'Cancela o elimina primero los combates activos de este participante'; end if;
    update public.evento_participantes set estado=v_status,actualizado_por=v_uid,actualizado_en=now(),
      observaciones=coalesce(nullif(trim(v_payload->>'observaciones'),''),observaciones)
    where club_id=v_club and id=(v_payload->>'participante_id')::uuid returning * into v_part;
    if v_part.id is null then raise exception 'Inscripción no encontrada'; end if;
    v_data:=jsonb_build_object('id',v_part.id,'estado',v_part.estado);

  elsif p_operation='evento.inscripcion.baja' then
    if exists(
      select 1 from public.evento_combates c
      where c.club_id=v_club and c.estado<>'cancelado'
        and (c.participante_a_id=(v_payload->>'participante_id')::uuid or c.participante_b_id=(v_payload->>'participante_id')::uuid)
    ) then raise exception 'No puedes darte de baja mientras tengas un combate activo'; end if;
    update public.evento_participantes ep set estado='baja',actualizado_por=v_uid,actualizado_en=now(),
      observaciones=coalesce(nullif(trim(v_payload->>'observaciones'),''),ep.observaciones)
    where ep.club_id=v_club and ep.id=(v_payload->>'participante_id')::uuid and ep.externo=false
      and public.puede_ver_socio(ep.socio_id)
      and exists(select 1 from public.eventos_competicion e where e.club_id=ep.club_id and e.id=ep.evento_id and e.estado not in ('finalizado','cancelado'))
    returning ep.* into v_part;
    if v_part.id is null then raise exception 'No puedes dar de baja esta inscripción'; end if;
    v_data:=jsonb_build_object('id',v_part.id,'estado',v_part.estado);

  elsif p_operation='evento.combate.guardar' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para gestionar combates'; end if;
    v_id:=nullif(v_payload->>'id','')::uuid;
    select * into v_event from public.eventos_competicion where club_id=v_club and id=(v_payload->>'evento_id')::uuid;
    if v_event.id is null or v_event.estado='cancelado' then raise exception 'Evento no disponible'; end if;
    select * into v_a from public.evento_participantes where club_id=v_club and evento_id=v_event.id and id=(v_payload->>'participante_a_id')::uuid;
    select * into v_b from public.evento_participantes where club_id=v_club and evento_id=v_event.id and id=(v_payload->>'participante_b_id')::uuid;
    if v_a.id is null or v_b.id is null or v_a.id=v_b.id then raise exception 'Selecciona dos participantes distintos del mismo evento'; end if;
    if v_a.estado<>'confirmado' or v_b.estado<>'confirmado' then raise exception 'Los dos participantes deben estar confirmados'; end if;
    v_status:=lower(trim(coalesce(nullif(v_payload->>'estado',''),'pendiente')));
    if v_status not in ('pendiente','en_curso','finalizado','cancelado') then raise exception 'Estado de combate inválido'; end if;
    begin v_winner:=nullif(v_payload->>'ganador_participante_id','')::uuid; exception when others then raise exception 'Ganador inválido'; end;
    if v_winner is not null and v_winner<>v_a.id and v_winner<>v_b.id then raise exception 'Ganador inválido'; end if;

    if v_id is null then
      insert into public.evento_combates(
        club_id,evento_id,participante_a_id,participante_b_id,disciplina_texto,categoria_texto,tatami_ring,orden,hora_aprox,estado,resultado,ganador_participante_id,observaciones,creado_por,actualizado_por
      ) values(
        v_club,v_event.id,v_a.id,v_b.id,nullif(trim(v_payload->>'disciplina_texto'),''),nullif(trim(v_payload->>'categoria_texto'),''),
        nullif(trim(v_payload->>'tatami_ring'),''),nullif(v_payload->>'orden','')::integer,nullif(v_payload->>'hora_aprox','')::time,
        v_status,nullif(trim(v_payload->>'resultado'),''),v_winner,
        nullif(trim(v_payload->>'observaciones'),''),v_uid,v_uid
      ) returning * into v_fight;
    else
      update public.evento_combates set
        participante_a_id=v_a.id,participante_b_id=v_b.id,disciplina_texto=nullif(trim(v_payload->>'disciplina_texto'),''),
        categoria_texto=nullif(trim(v_payload->>'categoria_texto'),''),tatami_ring=nullif(trim(v_payload->>'tatami_ring'),''),
        orden=nullif(v_payload->>'orden','')::integer,hora_aprox=nullif(v_payload->>'hora_aprox','')::time,
        estado=v_status,resultado=nullif(trim(v_payload->>'resultado'),''),
        ganador_participante_id=v_winner,observaciones=nullif(trim(v_payload->>'observaciones'),''),
        actualizado_por=v_uid,actualizado_en=now()
      where club_id=v_club and evento_id=v_event.id and id=v_id returning * into v_fight;
      if v_fight.id is null then raise exception 'Combate no encontrado'; end if;
    end if;
    v_data:=to_jsonb(v_fight);

  elsif p_operation='evento.combate.eliminar' then
    if not public.app_puede_gestionar_eventos_v033(v_club) then raise exception 'No tienes permiso para gestionar combates'; end if;
    delete from public.evento_combates where club_id=v_club and id=(v_payload->>'combate_id')::uuid returning * into v_fight;
    if v_fight.id is null then raise exception 'Combate no encontrado'; end if;
    v_data:=jsonb_build_object('id',v_fight.id,'eliminado',true);
  end if;

  v_result:=jsonb_build_object(
    'ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,
    'data',coalesce(v_data,'{}'::jsonb)
  );
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
