-- KOMBAX RC13 build 20.093 · 162 · Events Social & Viral Sharing
-- Engagement + Social bridge + public slug landing. RPC-only tables; no direct Data API table exposure.
begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('events.public.engage','Guardar interés y avisos sobre KOMBAX Eventos',false),
 ('events.public.share.social','Compartir KOMBAX Eventos y combates en KOMBAX Social',false)
on conflict(clave) do nothing;

insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave)
select distinct pc.plan_codigo,v.clave
from public.kombax_plan_capacidades pc
cross join (values('events.public.engage'),('events.public.share.social')) v(clave)
where pc.capacidad_clave='social.read'
on conflict do nothing;

create table if not exists public.kombax_evento_interes(
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 perfil_id uuid not null references public.perfiles(id) on delete cascade,
 estado text not null default 'interesado' check(estado in ('interesado','asistire')),
 notificaciones boolean not null default true,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 primary key(evento_id,perfil_id)
);
create index if not exists idx_kombax_evento_interes_public_v162 on public.kombax_evento_interes(evento_id,estado,actualizado_en desc);
alter table public.kombax_evento_interes enable row level security;
revoke all on public.kombax_evento_interes from public,anon,authenticated;

create table if not exists public.kombax_evento_social_links(
 publicacion_id uuid primary key references public.kombax_social_publicaciones(id) on delete cascade,
 evento_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
 combate_id uuid references public.kombax_evento_combates_publicos(id) on delete set null,
 tipo text not null check(tipo in ('evento','combate','resultado')),
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_evento_social_links_event_v162 on public.kombax_evento_social_links(evento_id,creado_en desc);
create index if not exists idx_kombax_evento_social_links_fight_v162 on public.kombax_evento_social_links(combate_id,creado_en desc) where combate_id is not null;
alter table public.kombax_evento_social_links enable row level security;
revoke all on public.kombax_evento_social_links from public,anon,authenticated;

create or replace function public.app_kombax_evento_engagement_v162(p_evento_id uuid)
returns table(interesados bigint,asistiran bigint,mi_estado text,mis_notificaciones boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_visible boolean:=false;
begin
 select exists(
   select 1 from public.kombax_eventos_publicos e
   where e.id=p_evento_id and e.visibilidad='publico'
     and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 ) into v_visible;
 if not v_visible and not (auth.uid() is not null and public.app_kombax_evento_puede_gestionar_v160(p_evento_id)) then return; end if;
 return query
 select count(*) filter(where i.estado='interesado'),count(*) filter(where i.estado='asistire'),
   max(i.estado) filter(where i.perfil_id=auth.uid()),
   coalesce(bool_or(i.notificaciones) filter(where i.perfil_id=auth.uid()),false)
 from public.kombax_evento_interes i where i.evento_id=p_evento_id;
end $$;
revoke all on function public.app_kombax_evento_engagement_v162(uuid) from public;
grant execute on function public.app_kombax_evento_engagement_v162(uuid) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_slug_v162(p_slug text)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_id uuid;v_base jsonb;v_eng jsonb;
begin
 select e.id into v_id from public.kombax_eventos_publicos e
 where e.slug=lower(btrim(coalesce(p_slug,''))) and e.visibilidad='publico'
   and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') limit 1;
 if v_id is null then return null; end if;
 v_base:=public.app_kombax_evento_publico_detalle_v161(v_id);
 if v_base is null then return null; end if;
 select to_jsonb(x) into v_eng from public.app_kombax_evento_engagement_v162(v_id) x;
 return v_base || jsonb_build_object('engagement',coalesce(v_eng,jsonb_build_object('interesados',0,'asistiran',0,'mi_estado',null,'mis_notificaciones',false)));
end $$;
revoke all on function public.app_kombax_evento_publico_slug_v162(text) from public;
grant execute on function public.app_kombax_evento_publico_slug_v162(text) to anon,authenticated;

create or replace function public.app_kombax_eventos_social_links_v162(p_publicacion_ids uuid[])
returns table(
 publicacion_id uuid,link_tipo text,evento_id uuid,evento_slug text,evento_nombre text,evento_tipo text,evento_estado text,
 fecha_inicio timestamptz,lugar_nombre text,municipio text,cartel_url text,tema_visual text,combate_id uuid,
 a_nombre text,a_foto_url text,a_club text,b_nombre text,b_foto_url text,b_club text,combate_estado text,resultado text,ganador_participante_id uuid
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
 if auth.uid() is null or p_publicacion_ids is null or coalesce(array_length(p_publicacion_ids,1),0)=0 then return; end if;
 if array_length(p_publicacion_ids,1)>60 then raise exception 'EVENT_SOCIAL_LINK_BATCH_TOO_LARGE'; end if;
 return query
 select l.publicacion_id,l.tipo,e.id,e.slug,e.nombre,e.tipo,e.estado,e.fecha_inicio,e.lugar_nombre,e.municipio,e.cartel_url,e.tema_visual,f.id,
   a.nombre_publico,case when a.origen='kombax' then public.app_kombax_social_avatar_url_v063(asp.id) else a.foto_url_externa end,coalesce(nullif(a.club_nombre,''),acl.nombre_publico,''),
   b.nombre_publico,case when b.origen='kombax' then public.app_kombax_social_avatar_url_v063(bsp.id) else b.foto_url_externa end,coalesce(nullif(b.club_nombre,''),bcl.nombre_publico,''),
   f.estado,f.resultado,f.ganador_participante_id
 from public.kombax_evento_social_links l
 join public.kombax_social_publicaciones p on p.id=l.publicacion_id and p.estado='activa'
 join public.kombax_eventos_publicos e on e.id=l.evento_id and e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 left join public.kombax_evento_combates_publicos f on f.id=l.combate_id and f.evento_id=e.id and f.visible_publico
 left join public.kombax_evento_participantes_publicos a on a.id=f.participante_a_id
 left join public.kombax_evento_participantes_publicos b on b.id=f.participante_b_id
 left join public.kombax_social_perfiles asp on asp.id=a.competidor_social_profile_id
 left join public.kombax_social_perfiles bsp on bsp.id=b.competidor_social_profile_id
 left join public.kombax_social_perfiles acl on acl.id=a.club_social_profile_id
 left join public.kombax_social_perfiles bcl on bcl.id=b.club_social_profile_id
 where l.publicacion_id=any(p_publicacion_ids);
end $$;
revoke all on function public.app_kombax_eventos_social_links_v162(uuid[]) from public,anon;
grant execute on function public.app_kombax_eventos_social_links_v162(uuid[]) to authenticated;

create or replace function public.app_kombax_eventos_mutate_v162(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
 v_event_id uuid;v_state text;v_notify boolean;v_post public.kombax_social_publicaciones;v_fight public.kombax_evento_combates_publicos;v_type text;
begin
 if p_operation in ('event.save','event.entity.add','event.entity.remove','event.entity.respond','event.participant.submit','event.participant.status','event.participant.withdraw','event.fight.save','event.fight.remove') then
   return public.app_kombax_eventos_mutate_v161(p_operation,v_payload,p_request_id);
 end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 if p_operation not in ('event.interest.set','event.social.link') then raise exception 'EVENTS_OPERATION_NOT_ALLOWED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 else
   insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
 end if;

 v_event_id:=nullif(v_payload->>'evento_id','')::uuid;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=v_event_id and e.visibilidad in ('publico','kombax') and e.estado not in ('borrador','cancelado')) then raise exception 'EVENT_NOT_AVAILABLE'; end if;

 if p_operation='event.interest.set' then
   v_state:=coalesce(nullif(v_payload->>'estado',''),'interesado');v_notify:=coalesce((v_payload->>'notificaciones')::boolean,true);
   if v_state='none' then
     delete from public.kombax_evento_interes where evento_id=v_event_id and perfil_id=v_uid;
   elsif v_state in ('interesado','asistire') then
     insert into public.kombax_evento_interes(evento_id,perfil_id,estado,notificaciones)
     values(v_event_id,v_uid,v_state,v_notify)
     on conflict(evento_id,perfil_id) do update set estado=excluded.estado,notificaciones=excluded.notificaciones,actualizado_en=now();
   else raise exception 'EVENT_INTEREST_STATE_INVALID'; end if;
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('evento_id',v_event_id,'estado',case when v_state='none' then null else v_state end,'notificaciones',case when v_state='none' then false else v_notify end));
 else
   select * into v_post from public.kombax_social_publicaciones where id=nullif(v_payload->>'publicacion_id','')::uuid for update;
   if v_post.id is null or v_post.estado<>'activa' then raise exception 'EVENT_SOCIAL_POST_INVALID'; end if;
   if not public.app_kombax_social_puede_actuar_v051(v_post.autor_perfil_id) then raise exception 'EVENT_SOCIAL_POST_AUTHOR_DENIED'; end if;
   v_type:=coalesce(nullif(v_payload->>'tipo',''),'evento');
   if v_type not in ('evento','combate','resultado') then raise exception 'EVENT_SOCIAL_LINK_TYPE_INVALID'; end if;
   if nullif(v_payload->>'combate_id','') is not null then
     select * into v_fight from public.kombax_evento_combates_publicos where id=(v_payload->>'combate_id')::uuid and evento_id=v_event_id and visible_publico;
     if v_fight.id is null then raise exception 'EVENT_SOCIAL_FIGHT_INVALID'; end if;
   end if;
   insert into public.kombax_evento_social_links(publicacion_id,evento_id,combate_id,tipo,creado_por)
   values(v_post.id,v_event_id,v_fight.id,v_type,v_uid)
   on conflict(publicacion_id) do update set evento_id=excluded.evento_id,combate_id=excluded.combate_id,tipo=excluded.tipo,actualizado_en=now();
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('publicacion_id',v_post.id,'evento_id',v_event_id,'combate_id',v_fight.id,'tipo',v_type));
 end if;
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v162(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v162(text,jsonb,uuid) to authenticated;

comment on table public.kombax_evento_interes is 'Engagement personal de KOMBAX Eventos. Reutilizable por futuras cuentas Espectador sin activarlas todavía.';
comment on table public.kombax_evento_social_links is 'Puente de referencia entre publicaciones Social y su fuente de verdad en KOMBAX Eventos/Fight Cards.';
comment on function public.app_kombax_evento_publico_slug_v162(text) is 'Landing pública por slug para deep-link/QR. Solo devuelve eventos públicos visibles.';
notify pgrst,'reload schema';
commit;
