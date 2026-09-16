-- KOMBAX RC13 build 20.094 · 164 · Live + Results
-- Extiende exclusivamente KOMBAX Eventos públicos. No consulta Mi Club > Eventos.
begin;

alter table public.kombax_evento_combates_publicos
  add column if not exists resultado_estado text not null default 'pendiente',
  add column if not exists resultado_publicado_en timestamptz,
  add column if not exists resultado_actualizado_por uuid references public.perfiles(id) on delete set null,
  add column if not exists resultado_notas_publicas text not null default '';

do $$ begin
  if not exists(select 1 from pg_constraint where conname='kombax_evento_combate_resultado_estado_ck') then
    alter table public.kombax_evento_combates_publicos
      add constraint kombax_evento_combate_resultado_estado_ck
      check(resultado_estado in ('pendiente','provisional','oficial','anulado'));
  end if;
  if not exists(select 1 from pg_constraint where conname='kombax_evento_combate_resultado_notas_ck') then
    alter table public.kombax_evento_combates_publicos
      add constraint kombax_evento_combate_resultado_notas_ck
      check(char_length(resultado_notas_publicas)<=800);
  end if;
end $$;

create index if not exists idx_kombax_evento_combates_resultado_v164
  on public.kombax_evento_combates_publicos(evento_id,resultado_estado,resultado_publicado_en desc,id)
  where visible_publico;

create or replace function public.app_kombax_evento_estado_temporal_v164(p_evento_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when e.id is null then null
    when e.estado='cancelado' then 'cancelado'
    when e.estado='en_curso' then 'ahora'
    when e.estado='finalizado' then 'finalizado'
    when e.fecha_inicio is not null and e.fecha_inicio<=now() and coalesce(e.fecha_fin,e.fecha_inicio+interval '6 hours')>=now() then 'ahora'
    when e.fecha_inicio is not null and coalesce(e.fecha_fin,e.fecha_inicio)<now() then 'finalizado'
    else 'proximo'
  end
  from public.kombax_eventos_publicos e where e.id=p_evento_id limit 1;
$$;
revoke all on function public.app_kombax_evento_estado_temporal_v164(uuid) from public;
grant execute on function public.app_kombax_evento_estado_temporal_v164(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_live_v164(p_limit integer default 80)
returns table(
 id uuid,slug text,tipo text,nombre text,resumen text,estado text,fase_temporal text,fecha_inicio timestamptz,fecha_fin timestamptz,
 lugar_nombre text,municipio text,provincia text,pais text,cartel_url text,banner_url text,tema_visual text,organizador_nombre text,
 combates integer,resultados_oficiales integer
) language sql stable security definer set search_path=public as $$
 select e.id,e.slug,e.tipo,e.nombre,e.resumen,e.estado,public.app_kombax_evento_estado_temporal_v164(e.id),e.fecha_inicio,e.fecha_fin,
   e.lugar_nombre,e.municipio,e.provincia,e.pais,e.cartel_url,e.banner_url,e.tema_visual,e.organizador_nombre,
   (select count(*)::integer from public.kombax_evento_combates_publicos f where f.evento_id=e.id and f.visible_publico and f.estado<>'cancelado'),
   (select count(*)::integer from public.kombax_evento_combates_publicos f where f.evento_id=e.id and f.visible_publico and f.resultado_estado='oficial')
 from public.kombax_eventos_publicos e
 where e.visibilidad='publico' and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 order by case public.app_kombax_evento_estado_temporal_v164(e.id) when 'ahora' then 0 when 'proximo' then 1 else 2 end,
          case when public.app_kombax_evento_estado_temporal_v164(e.id)='finalizado' then e.fecha_inicio end desc nulls last,
          e.fecha_inicio asc nulls last,e.id
 limit least(120,greatest(1,coalesce(p_limit,80)));
$$;
revoke all on function public.app_kombax_eventos_live_v164(integer) from public;
grant execute on function public.app_kombax_eventos_live_v164(integer) to anon,authenticated;

create or replace function public.app_kombax_evento_resultados_v164(p_evento_id uuid)
returns table(
 id uuid,evento_id uuid,participante_a_id uuid,participante_b_id uuid,
 a_nombre text,a_foto_url text,a_club text,b_nombre text,b_foto_url text,b_club text,
 disciplina text,categoria text,peso_texto text,tatami_ring text,orden integer,hora_programada timestamptz,
 estado text,resultado text,metodo_resultado text,ganador_participante_id uuid,asalto smallint,tiempo_resultado text,destacado boolean,
 resultado_estado text,resultado_publicado_en timestamptz,resultado_notas_publicas text
) language plpgsql stable security definer set search_path=public,auth as $$
begin
 return query
 select x.id,x.evento_id,x.participante_a_id,x.participante_b_id,x.a_nombre,x.a_foto_url,x.a_club,x.b_nombre,x.b_foto_url,x.b_club,
   x.disciplina,x.categoria,x.peso_texto,x.tatami_ring,x.orden,x.hora_programada,x.estado,x.resultado,x.metodo_resultado,x.ganador_participante_id,x.asalto,x.tiempo_resultado,x.destacado,
   f.resultado_estado,f.resultado_publicado_en,f.resultado_notas_publicas
 from public.app_kombax_evento_combates_v161(p_evento_id) x
 join public.kombax_evento_combates_publicos f on f.id=x.id
 order by x.destacado desc,x.orden nulls last,x.hora_programada nulls last,x.id;
end $$;
revoke all on function public.app_kombax_evento_resultados_v164(uuid) from public;
grant execute on function public.app_kombax_evento_resultados_v164(uuid) to anon,authenticated;

create or replace function public.app_kombax_eventos_mutate_v164(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
 v_fight public.kombax_evento_combates_publicos;v_state text;v_winner uuid;
begin
 if p_operation<>'event.fight.result.set' then
   return public.app_kombax_eventos_mutate_v162(p_operation,v_payload,p_request_id);
 end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
   if v_existing.result is not null then return v_existing.result; end if;
 else
   insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
 end if;
 select * into v_fight from public.kombax_evento_combates_publicos where id=nullif(v_payload->>'fight_id','')::uuid for update;
 if v_fight.id is null then raise exception 'EVENT_FIGHT_NOT_FOUND'; end if;
 if not public.app_kombax_evento_puede_gestionar_v160(v_fight.evento_id) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
 v_state:=coalesce(nullif(v_payload->>'resultado_estado',''),'oficial');
 if v_state not in ('pendiente','provisional','oficial','anulado') then raise exception 'EVENT_RESULT_STATE_INVALID'; end if;
 v_winner:=nullif(v_payload->>'ganador_participante_id','')::uuid;
 if v_winner is not null and v_winner not in (v_fight.participante_a_id,v_fight.participante_b_id) then raise exception 'EVENT_FIGHT_WINNER_INVALID'; end if;
 if v_state in ('provisional','oficial') and char_length(btrim(coalesce(v_payload->>'resultado',''))) < 2 then raise exception 'EVENT_RESULT_TEXT_REQUIRED'; end if;
 update public.kombax_evento_combates_publicos set
   resultado_estado=v_state,
   resultado=case when v_state='pendiente' then '' else left(coalesce(v_payload->>'resultado',resultado),500) end,
   metodo_resultado=case when v_state='pendiente' then '' else left(coalesce(v_payload->>'metodo_resultado',metodo_resultado),120) end,
   ganador_participante_id=case when v_state in ('pendiente','anulado') then null else v_winner end,
   asalto=case when v_state='pendiente' then null when v_payload ? 'asalto' then nullif(v_payload->>'asalto','')::smallint else asalto end,
   tiempo_resultado=case when v_state='pendiente' then '' else left(coalesce(v_payload->>'tiempo_resultado',tiempo_resultado),40) end,
   resultado_notas_publicas=case when v_state='pendiente' then '' else left(coalesce(v_payload->>'notas_publicas',''),800) end,
   resultado_publicado_en=case when v_state in ('provisional','oficial','anulado') then now() else null end,
   resultado_actualizado_por=v_uid,
   estado=case when v_state in ('provisional','oficial','anulado') then 'finalizado' else estado end,
   actualizado_en=now()
 where id=v_fight.id returning * into v_fight;
 insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
 values(v_uid,null,'kombax.events.fight.result.set','kombax_event_fight',v_fight.id,
   jsonb_build_object('evento_id',v_fight.evento_id,'resultado_estado',v_state,'ganador_participante_id',v_fight.ganador_participante_id));
 v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_fight)-'creado_por'-'resultado_actualizado_por');
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
end $$;
revoke all on function public.app_kombax_eventos_mutate_v164(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v164(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
