-- KOMBAX RC13 build 20.092 · 161 · Fighters & Fight Cards
-- Fase 3 de KOMBAX Eventos. Participantes y combates PÚBLICOS del dominio transversal.
-- NO consulta, copia ni migra public.eventos_competicion, public.evento_participantes ni public.evento_combates (Mi Club).
begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('events.public.participate','Solicitar participación en KOMBAX Eventos públicos',true),
 ('events.public.fights.manage','Gestionar participantes y combates públicos de KOMBAX Eventos',true),
 ('events.public.fightcards.read','Consultar Fight Cards públicas de KOMBAX Eventos',false)
on conflict(clave) do nothing;

-- Los organizadores nativos de Federación heredan la gestión de combates.
insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select 'federacion_institucional',v.clave from (values('events.public.participate'),('events.public.fights.manage'),('events.public.fightcards.read')) v(clave)
where exists(select 1 from public.kombax_planes p where p.codigo='federacion_institucional')
on conflict do nothing;

-- Lectura/participación base: añadir a los planes existentes que ya tengan Social público activo,
-- sin convertirlos en organizadores ni conceder gestión de combates.
insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select distinct pc.plan_codigo,v.clave
from public.kombax_plan_capacidades pc
cross join (values('events.public.participate'),('events.public.fightcards.read')) v(clave)
where pc.capacidad_clave='social.read'
on conflict do nothing;

create table if not exists public.kombax_evento_participantes_publicos(
 id uuid primary key default gen_random_uuid(),
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 origen text not null default 'externa' check(origen in ('kombax','externa')),
 competidor_social_profile_id uuid references public.kombax_social_perfiles(id) on delete restrict,
 presentado_por_social_profile_id uuid references public.kombax_social_perfiles(id) on delete restrict,
 club_social_profile_id uuid references public.kombax_social_perfiles(id) on delete restrict,
 nombre_publico text not null check(char_length(btrim(nombre_publico)) between 2 and 180),
 foto_url_externa text,
 club_nombre text not null default '' check(char_length(club_nombre)<=180),
 disciplina text not null default '' check(char_length(disciplina)<=120),
 categoria text not null default '' check(char_length(categoria)<=120),
 peso numeric(6,2) check(peso is null or (peso>0 and peso<500)),
 estado_inscripcion text not null default 'pendiente' check(estado_inscripcion in ('pendiente','aceptada','rechazada','retirada')),
 visible_publico boolean not null default true,
 notas_publicas text not null default '' check(char_length(notas_publicas)<=500),
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_evento_participante_origen_ck check(
   (origen='kombax' and competidor_social_profile_id is not null and foto_url_externa is null)
   or (origen='externa' and competidor_social_profile_id is null)
 ),
 constraint kombax_evento_participante_foto_ck check(foto_url_externa is null or foto_url_externa ~* '^https://[^[:space:]]+$')
);
create unique index if not exists uq_kombax_evento_participante_kombax_v161
 on public.kombax_evento_participantes_publicos(evento_id,competidor_social_profile_id)
 where competidor_social_profile_id is not null and estado_inscripcion<>'retirada';
create index if not exists idx_kombax_evento_participantes_public_v161
 on public.kombax_evento_participantes_publicos(evento_id,estado_inscripcion,visible_publico,creado_en,id);
create index if not exists idx_kombax_evento_participantes_presenter_v161
 on public.kombax_evento_participantes_publicos(presentado_por_social_profile_id,estado_inscripcion,creado_en desc);
alter table public.kombax_evento_participantes_publicos enable row level security;
revoke all on public.kombax_evento_participantes_publicos from public,anon,authenticated;

create table if not exists public.kombax_evento_combates_publicos(
 id uuid primary key default gen_random_uuid(),
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 participante_a_id uuid not null references public.kombax_evento_participantes_publicos(id) on delete restrict,
 participante_b_id uuid not null references public.kombax_evento_participantes_publicos(id) on delete restrict,
 disciplina text not null default '' check(char_length(disciplina)<=120),
 categoria text not null default '' check(char_length(categoria)<=120),
 peso_texto text not null default '' check(char_length(peso_texto)<=80),
 tatami_ring text not null default '' check(char_length(tatami_ring)<=80),
 orden integer check(orden is null or orden between 1 and 999),
 hora_programada timestamptz,
 estado text not null default 'propuesto' check(estado in ('propuesto','confirmado','programado','en_curso','finalizado','cancelado')),
 resultado text not null default '' check(char_length(resultado)<=500),
 metodo_resultado text not null default '' check(char_length(metodo_resultado)<=120),
 ganador_participante_id uuid references public.kombax_evento_participantes_publicos(id) on delete restrict,
 asalto smallint check(asalto is null or asalto between 1 and 30),
 tiempo_resultado text not null default '' check(char_length(tiempo_resultado)<=40),
 visible_publico boolean not null default true,
 destacado boolean not null default false,
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_evento_combate_distintos_ck check(participante_a_id<>participante_b_id),
 constraint kombax_evento_combate_ganador_ck check(ganador_participante_id is null or ganador_participante_id in (participante_a_id,participante_b_id))
);
create index if not exists idx_kombax_evento_combates_public_v161
 on public.kombax_evento_combates_publicos(evento_id,visible_publico,estado,orden,hora_programada,id);
create unique index if not exists uq_kombax_evento_combate_pair_v161
 on public.kombax_evento_combates_publicos(evento_id,least(participante_a_id,participante_b_id),greatest(participante_a_id,participante_b_id))
 where estado<>'cancelado';
alter table public.kombax_evento_combates_publicos enable row level security;
revoke all on public.kombax_evento_combates_publicos from public,anon,authenticated;

create or replace function public.app_kombax_eventos_actor_puede_participar_v161(p_evento_id uuid,p_social_profile_id uuid)
returns boolean language plpgsql stable security definer set search_path=public,auth as $$
declare v_tipo text; v_evt public.kombax_eventos_publicos;
begin
 if auth.uid() is null or p_evento_id is null or p_social_profile_id is null then return false; end if;
 if not public.app_kombax_eventos_puede_actuar_social_v160(p_social_profile_id) then return false; end if;
 select public.app_kombax_social_tipo_v051(sp.id) into v_tipo from public.kombax_social_perfiles sp where sp.id=p_social_profile_id and sp.visible and sp.estado='activo';
 if v_tipo not in ('club','federacion','profesional','competidor') then return false; end if;
 select * into v_evt from public.kombax_eventos_publicos where id=p_evento_id;
 if v_evt.id is null then return false; end if;
 if public.app_kombax_evento_puede_gestionar_v160(p_evento_id) then return true; end if;
 if v_evt.estado<>'inscripciones_abiertas' then return false; end if;
 return v_evt.visibilidad in ('publico','kombax');
end $$;
revoke all on function public.app_kombax_eventos_actor_puede_participar_v161(uuid,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_actor_puede_participar_v161(uuid,uuid) to authenticated;

create or replace function public.app_kombax_evento_participantes_v161(p_evento_id uuid)
returns table(
 id uuid,evento_id uuid,origen text,competidor_social_profile_id uuid,nombre_publico text,foto_url text,
 club_social_profile_id uuid,club_nombre text,disciplina text,categoria text,peso numeric,estado_inscripcion text,
 visible_publico boolean,presentado_por_social_profile_id uuid,presentado_por_nombre text,creado_en timestamptz
) language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false; v_public boolean:=false;
begin
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_evento_id and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')) into v_public;
 if not v_manage and not v_public then return; end if;
 return query
 select p.id,p.evento_id,p.origen,p.competidor_social_profile_id,p.nombre_publico,
   case when p.origen='kombax' then public.app_kombax_social_avatar_url_v063(cp.id) else p.foto_url_externa end,
   p.club_social_profile_id,
   coalesce(nullif(p.club_nombre,''),cl.nombre_publico,''),p.disciplina,p.categoria,p.peso,p.estado_inscripcion,p.visible_publico,p.presentado_por_social_profile_id,pr.nombre_publico,p.creado_en
 from public.kombax_evento_participantes_publicos p
 left join public.kombax_social_perfiles cp on cp.id=p.competidor_social_profile_id
 left join public.kombax_social_perfiles cl on cl.id=p.club_social_profile_id
 left join public.kombax_social_perfiles pr on pr.id=p.presentado_por_social_profile_id
 where p.evento_id=p_evento_id
   and ((p.estado_inscripcion='aceptada' and p.visible_publico) or v_manage or (auth.uid() is not null and p.presentado_por_social_profile_id is not null and public.app_kombax_eventos_puede_actuar_social_v160(p.presentado_por_social_profile_id)))
 order by case p.estado_inscripcion when 'aceptada' then 0 when 'pendiente' then 1 when 'rechazada' then 2 else 3 end,p.creado_en,p.id;
end $$;
revoke all on function public.app_kombax_evento_participantes_v161(uuid) from public;
grant execute on function public.app_kombax_evento_participantes_v161(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_combates_v161(p_evento_id uuid)
returns table(
 id uuid,evento_id uuid,participante_a_id uuid,participante_b_id uuid,
 a_nombre text,a_foto_url text,a_club text,b_nombre text,b_foto_url text,b_club text,
 disciplina text,categoria text,peso_texto text,tatami_ring text,orden integer,hora_programada timestamptz,
 estado text,resultado text,metodo_resultado text,ganador_participante_id uuid,asalto smallint,tiempo_resultado text,destacado boolean
) language plpgsql stable security definer set search_path=public,auth as $$
declare v_manage boolean:=false; v_public boolean:=false;
begin
 if auth.uid() is not null then v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_evento_id); end if;
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_evento_id and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')) into v_public;
 if not v_manage and not v_public then return; end if;
 return query
 select f.id,f.evento_id,f.participante_a_id,f.participante_b_id,
   a.nombre_publico,case when a.origen='kombax' then public.app_kombax_social_avatar_url_v063(asp.id) else a.foto_url_externa end,coalesce(nullif(a.club_nombre,''),acl.nombre_publico,''),
   b.nombre_publico,case when b.origen='kombax' then public.app_kombax_social_avatar_url_v063(bsp.id) else b.foto_url_externa end,coalesce(nullif(b.club_nombre,''),bcl.nombre_publico,''),
   f.disciplina,f.categoria,f.peso_texto,f.tatami_ring,f.orden,f.hora_programada,f.estado,f.resultado,f.metodo_resultado,f.ganador_participante_id,f.asalto,f.tiempo_resultado,f.destacado
 from public.kombax_evento_combates_publicos f
 join public.kombax_evento_participantes_publicos a on a.id=f.participante_a_id and a.evento_id=f.evento_id
 join public.kombax_evento_participantes_publicos b on b.id=f.participante_b_id and b.evento_id=f.evento_id
 left join public.kombax_social_perfiles asp on asp.id=a.competidor_social_profile_id
 left join public.kombax_social_perfiles bsp on bsp.id=b.competidor_social_profile_id
 left join public.kombax_social_perfiles acl on acl.id=a.club_social_profile_id
 left join public.kombax_social_perfiles bcl on bcl.id=b.club_social_profile_id
 where f.evento_id=p_evento_id and (v_manage or (f.visible_publico and a.estado_inscripcion='aceptada' and b.estado_inscripcion='aceptada'))
 order by f.destacado desc,f.orden nulls last,f.hora_programada nulls last,f.creado_en,f.id;
end $$;
revoke all on function public.app_kombax_evento_combates_v161(uuid) from public;
grant execute on function public.app_kombax_evento_combates_v161(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_detalle_v161(p_evento_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb; v_participants jsonb; v_fights jsonb; v_manage boolean:=false;
begin
 v_base:=public.app_kombax_evento_publico_detalle_v160(p_evento_id);
 if v_base is null then return null; end if;
 v_manage:=coalesce((v_base->>'can_manage')::boolean,false);
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_participants from public.app_kombax_evento_participantes_v161(p_evento_id) x;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_fights from public.app_kombax_evento_combates_v161(p_evento_id) x;
 return v_base || jsonb_build_object(
   'participants',coalesce(v_participants,'[]'::jsonb),
   'fights',coalesce(v_fights,'[]'::jsonb),
   'participants_count',(select count(*) from jsonb_array_elements(coalesce(v_participants,'[]'::jsonb))),
   'fights_count',(select count(*) from jsonb_array_elements(coalesce(v_fights,'[]'::jsonb))),
   'can_manage_fights',v_manage
 );
end $$;
revoke all on function public.app_kombax_evento_publico_detalle_v161(uuid) from public;
grant execute on function public.app_kombax_evento_publico_detalle_v161(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v161(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid(); v_payload jsonb:=coalesce(p_payload,'{}'::jsonb); v_existing public.app_mutation_requests; v_result jsonb;
 v_event_id uuid; v_actor uuid; v_origin text; v_competitor uuid; v_club_social uuid; v_name text; v_actor_tipo text; v_manage boolean:=false;
 v_participant public.kombax_evento_participantes_publicos; v_fight public.kombax_evento_combates_publicos;
 v_a public.kombax_evento_participantes_publicos; v_b public.kombax_evento_participantes_publicos; v_winner uuid;
begin
 if p_operation in ('event.save','event.entity.add','event.entity.remove','event.entity.respond') then
   return public.app_kombax_eventos_mutate_v160(p_operation,v_payload,p_request_id);
 end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 if p_operation not in ('event.participant.submit','event.participant.status','event.participant.withdraw','event.fight.save','event.fight.remove') then raise exception 'EVENTS_OPERATION_NOT_ALLOWED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 else
   insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
 end if;

 if p_operation='event.participant.submit' then
   v_event_id:=(v_payload->>'evento_id')::uuid; v_actor:=(v_payload->>'presentado_por_social_profile_id')::uuid;
   if not public.app_kombax_eventos_actor_puede_participar_v161(v_event_id,v_actor) then raise exception 'EVENT_PARTICIPATION_DENIED'; end if;
   v_manage:=public.app_kombax_evento_puede_gestionar_v160(v_event_id);
   select public.app_kombax_social_tipo_v051(sp.id) into v_actor_tipo from public.kombax_social_perfiles sp where sp.id=v_actor;
   v_origin:=coalesce(nullif(v_payload->>'origen',''),'externa');
   if v_origin='kombax' then
     v_competitor:=(v_payload->>'competidor_social_profile_id')::uuid;
     if not exists(select 1 from public.kombax_social_perfiles sp where sp.id=v_competitor and sp.visible and sp.estado='activo' and public.app_kombax_social_tipo_v051(sp.id)='competidor') then raise exception 'EVENT_COMPETITOR_PROFILE_INVALID'; end if;
     if not v_manage and v_actor<>v_competitor then raise exception 'EVENT_COMPETITOR_SELF_ONLY'; end if;
     select sp.nombre_publico into v_name from public.kombax_social_perfiles sp where sp.id=v_competitor;
   elsif v_origin='externa' then
     if not v_manage and v_actor_tipo not in ('club','federacion','profesional') then raise exception 'EVENT_EXTERNAL_PARTICIPANT_ACTOR_INVALID'; end if;
     v_name:=left(btrim(coalesce(v_payload->>'nombre_publico','')),180);
     if char_length(v_name)<2 then raise exception 'EVENT_PARTICIPANT_NAME_REQUIRED'; end if;
   else raise exception 'EVENT_PARTICIPANT_ORIGIN_INVALID'; end if;
   v_club_social:=nullif(v_payload->>'club_social_profile_id','')::uuid;
   if v_club_social is not null and not exists(select 1 from public.kombax_social_perfiles sp where sp.id=v_club_social and sp.visible and sp.estado='activo' and public.app_kombax_social_tipo_v051(sp.id)='club') then raise exception 'EVENT_PARTICIPANT_CLUB_INVALID'; end if;
   insert into public.kombax_evento_participantes_publicos(evento_id,origen,competidor_social_profile_id,presentado_por_social_profile_id,club_social_profile_id,nombre_publico,foto_url_externa,club_nombre,disciplina,categoria,peso,estado_inscripcion,visible_publico,notas_publicas,creado_por)
   values(v_event_id,v_origin,v_competitor,v_actor,v_club_social,v_name,case when v_origin='externa' then nullif(v_payload->>'foto_url','') else null end,left(coalesce(v_payload->>'club_nombre',''),180),left(coalesce(v_payload->>'disciplina',''),120),left(coalesce(v_payload->>'categoria',''),120),nullif(v_payload->>'peso','')::numeric,case when v_manage then 'aceptada' else 'pendiente' end,coalesce((v_payload->>'visible_publico')::boolean,true),left(coalesce(v_payload->>'notas_publicas',''),500),v_uid)
   returning * into v_participant;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_participant)-'creado_por');

 elsif p_operation='event.participant.status' then
   select * into v_participant from public.kombax_evento_participantes_publicos where id=(v_payload->>'participant_id')::uuid for update;
   if v_participant.id is null or not public.app_kombax_evento_puede_gestionar_v160(v_participant.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   if v_payload->>'estado' not in ('pendiente','aceptada','rechazada','retirada') then raise exception 'EVENT_PARTICIPANT_STATUS_INVALID'; end if;
   update public.kombax_evento_participantes_publicos set estado_inscripcion=v_payload->>'estado',actualizado_en=now() where id=v_participant.id returning * into v_participant;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_participant)-'creado_por');

 elsif p_operation='event.participant.withdraw' then
   select * into v_participant from public.kombax_evento_participantes_publicos where id=(v_payload->>'participant_id')::uuid for update;
   if v_participant.id is null then raise exception 'EVENT_PARTICIPANT_NOT_FOUND'; end if;
   if not public.app_kombax_evento_puede_gestionar_v160(v_participant.evento_id)
      and (v_participant.presentado_por_social_profile_id is null or not public.app_kombax_eventos_puede_actuar_social_v160(v_participant.presentado_por_social_profile_id)) then raise exception 'EVENT_PARTICIPANT_WITHDRAW_DENIED'; end if;
   if exists(select 1 from public.kombax_evento_combates_publicos f where f.evento_id=v_participant.evento_id and f.estado not in ('cancelado','finalizado') and v_participant.id in (f.participante_a_id,f.participante_b_id)) then raise exception 'EVENT_PARTICIPANT_HAS_ACTIVE_FIGHT'; end if;
   update public.kombax_evento_participantes_publicos set estado_inscripcion='retirada',actualizado_en=now() where id=v_participant.id returning * into v_participant;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_participant)-'creado_por');

 elsif p_operation='event.fight.save' then
   v_event_id:=(v_payload->>'evento_id')::uuid;
   if not public.app_kombax_evento_puede_gestionar_v160(v_event_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   select * into v_a from public.kombax_evento_participantes_publicos where id=(v_payload->>'participante_a_id')::uuid and evento_id=v_event_id and estado_inscripcion='aceptada';
   select * into v_b from public.kombax_evento_participantes_publicos where id=(v_payload->>'participante_b_id')::uuid and evento_id=v_event_id and estado_inscripcion='aceptada';
   if v_a.id is null or v_b.id is null or v_a.id=v_b.id then raise exception 'EVENT_FIGHT_PARTICIPANTS_INVALID'; end if;
   v_winner:=nullif(v_payload->>'ganador_participante_id','')::uuid;
   if v_winner is not null and v_winner not in (v_a.id,v_b.id) then raise exception 'EVENT_FIGHT_WINNER_INVALID'; end if;
   if nullif(v_payload->>'id','') is null then
     insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,resultado,metodo_resultado,ganador_participante_id,asalto,tiempo_resultado,visible_publico,destacado,creado_por)
     values(v_event_id,v_a.id,v_b.id,left(coalesce(v_payload->>'disciplina',''),120),left(coalesce(v_payload->>'categoria',''),120),left(coalesce(v_payload->>'peso_texto',''),80),left(coalesce(v_payload->>'tatami_ring',''),80),nullif(v_payload->>'orden','')::integer,nullif(v_payload->>'hora_programada','')::timestamptz,coalesce(nullif(v_payload->>'estado',''),'propuesto'),left(coalesce(v_payload->>'resultado',''),500),left(coalesce(v_payload->>'metodo_resultado',''),120),v_winner,nullif(v_payload->>'asalto','')::smallint,left(coalesce(v_payload->>'tiempo_resultado',''),40),coalesce((v_payload->>'visible_publico')::boolean,true),coalesce((v_payload->>'destacado')::boolean,false),v_uid)
     returning * into v_fight;
   else
     select * into v_fight from public.kombax_evento_combates_publicos where id=(v_payload->>'id')::uuid and evento_id=v_event_id for update;
     if v_fight.id is null then raise exception 'EVENT_FIGHT_NOT_FOUND'; end if;
     update public.kombax_evento_combates_publicos set participante_a_id=v_a.id,participante_b_id=v_b.id,disciplina=left(coalesce(v_payload->>'disciplina',disciplina),120),categoria=left(coalesce(v_payload->>'categoria',categoria),120),peso_texto=left(coalesce(v_payload->>'peso_texto',peso_texto),80),tatami_ring=left(coalesce(v_payload->>'tatami_ring',tatami_ring),80),orden=case when v_payload ? 'orden' then nullif(v_payload->>'orden','')::integer else orden end,hora_programada=case when v_payload ? 'hora_programada' then nullif(v_payload->>'hora_programada','')::timestamptz else hora_programada end,estado=coalesce(nullif(v_payload->>'estado',''),estado),resultado=left(coalesce(v_payload->>'resultado',resultado),500),metodo_resultado=left(coalesce(v_payload->>'metodo_resultado',metodo_resultado),120),ganador_participante_id=v_winner,asalto=case when v_payload ? 'asalto' then nullif(v_payload->>'asalto','')::smallint else asalto end,tiempo_resultado=left(coalesce(v_payload->>'tiempo_resultado',tiempo_resultado),40),visible_publico=coalesce((v_payload->>'visible_publico')::boolean,visible_publico),destacado=coalesce((v_payload->>'destacado')::boolean,destacado),actualizado_en=now() where id=v_fight.id returning * into v_fight;
   end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_fight)-'creado_por');

 else
   select * into v_fight from public.kombax_evento_combates_publicos where id=(v_payload->>'fight_id')::uuid for update;
   if v_fight.id is null or not public.app_kombax_evento_puede_gestionar_v160(v_fight.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
   update public.kombax_evento_combates_publicos set estado='cancelado',visible_publico=false,actualizado_en=now() where id=v_fight.id returning * into v_fight;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_fight)-'creado_por');
 end if;
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v161(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v161(text,jsonb,uuid) to authenticated;

comment on table public.kombax_evento_participantes_publicos is 'Participantes públicos de KOMBAX Eventos. No contiene ni refleja automáticamente alumnos o participantes de Mi Club.';
comment on table public.kombax_evento_combates_publicos is 'Combates públicos de KOMBAX Eventos con Fight Cards. Dominio independiente de evento_combates interno.';
comment on function public.app_kombax_eventos_mutate_v161(text,jsonb,uuid) is 'Gateway idempotente Fase 3 para participantes y combates públicos. Conserva v160 para organización.';
notify pgrst,'reload schema';
commit;
