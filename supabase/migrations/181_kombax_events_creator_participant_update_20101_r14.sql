begin;

-- KOMBAX 20.101 R14 · Event Creator Complete
-- Adds a narrowly-scoped participant update operation for organizers.
-- Existing event/media/fight domains and workspace isolation remain authoritative.

create or replace function public.app_kombax_eventos_mutate_v181(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_existing public.app_mutation_requests;
  v_participant public.kombax_evento_participantes_publicos;
  v_workspace uuid;
  v_manage boolean:=false;
  v_result jsonb;
begin
  if p_operation<>'event.participant.update' then
    return public.app_kombax_eventos_mutate_v178(p_operation,v_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  if nullif(v_payload->>'participant_id','') is null then raise exception 'EVENT_PARTICIPANT_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,null,p_operation);
  end if;

  select * into v_participant
  from public.kombax_evento_participantes_publicos
  where id=(v_payload->>'participant_id')::uuid
  for update;
  if v_participant.id is null then raise exception 'EVENT_PARTICIPANT_NOT_FOUND'; end if;

  if nullif(v_payload->>'workspace_club_id','') is not null then
    v_workspace:=(v_payload->>'workspace_club_id')::uuid;
    select x.puede_gestionar into v_manage
    from public.app_kombax_evento_contexto_gestion_v171(v_participant.evento_id,v_workspace) x;
  else
    v_manage:=public.app_kombax_evento_puede_gestionar_v160(v_participant.evento_id);
  end if;
  if not coalesce(v_manage,false) then raise exception 'EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN'; end if;

  update public.kombax_evento_participantes_publicos p set
    nombre_publico=case when p.origen='externa' and v_payload ? 'nombre_publico' then left(btrim(coalesce(v_payload->>'nombre_publico',p.nombre_publico)),180) else p.nombre_publico end,
    foto_url_externa=case when p.origen='externa' and v_payload ? 'foto_url' then nullif(v_payload->>'foto_url','') else p.foto_url_externa end,
    club_nombre=case when v_payload ? 'club_nombre' then left(coalesce(v_payload->>'club_nombre',''),180) else p.club_nombre end,
    disciplina=case when v_payload ? 'disciplina' then left(coalesce(v_payload->>'disciplina',''),120) else p.disciplina end,
    categoria=case when v_payload ? 'categoria' then left(coalesce(v_payload->>'categoria',''),120) else p.categoria end,
    peso=case when v_payload ? 'peso' then nullif(v_payload->>'peso','')::numeric else p.peso end,
    visible_publico=case when v_payload ? 'visible_publico' then coalesce((v_payload->>'visible_publico')::boolean,p.visible_publico) else p.visible_publico end,
    actualizado_en=now()
  where p.id=v_participant.id
  returning * into v_participant;

  if v_participant.origen='externa' and char_length(btrim(coalesce(v_participant.nombre_publico,'')))<2 then
    raise exception 'EVENT_PARTICIPANT_NAME_REQUIRED';
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_participant)-'creado_por');
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
end $$;

revoke all on function public.app_kombax_eventos_mutate_v181(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_eventos_mutate_v181(text,jsonb,uuid) to authenticated;
comment on function public.app_kombax_eventos_mutate_v181(text,jsonb,uuid) is '20.101 R14 Event Creator Complete: organizer-scoped participant editing/photo replacement; preserves v178/v175/v171 contracts.';

notify pgrst,'reload schema';
commit;
