-- KOMBAX 20.110 R60 PILOT FINAL · keep legacy relation types compatible with the new Mi red actor rule.
begin;
create or replace function public.app_kombax_relation_state_v255(
  p_relacion_id uuid,
  p_estado text,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_rel public.kombax_relaciones;v_state text:=lower(coalesce(p_estado,''));v_network boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_relacion_id is null then raise exception 'KOMBAX_RELATION_ID_INVALID';end if;
  if v_state not in ('confirmed','rejected','ended','suspended') then raise exception 'KOMBAX_RELATION_STATE_INVALID';end if;
  select * into v_rel from public.kombax_relaciones where id=p_relacion_id for update;
  if v_rel.id is null then raise exception 'KOMBAX_RELATION_NOT_FOUND';end if;
  v_network:=v_rel.tipo='conexion_kombax';

  if v_state in ('confirmed','rejected') then
    if v_network then
      if not public.app_kombax_social_network_actor_allowed_v255(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_CONFIRM_FORBIDDEN';end if;
    else
      if not public.app_kombax_social_puede_publicar_v041(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_CONFIRM_FORBIDDEN';end if;
    end if;
  end if;
  if v_state='ended' then
    if v_network then
      if not public.app_kombax_social_network_actor_allowed_v255(v_rel.origen_social_id) and not public.app_kombax_social_network_actor_allowed_v255(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_END_FORBIDDEN';end if;
    else
      if not public.app_kombax_social_puede_publicar_v041(v_rel.origen_social_id) and not public.app_kombax_social_puede_publicar_v041(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_RELATION_END_FORBIDDEN';end if;
    end if;
  end if;
  if v_state='suspended' and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;

  update public.kombax_relaciones
  set estado=v_state,
      confirmado_por=case when v_state='confirmed' then v_uid else confirmado_por end,
      confirmado_en=case when v_state='confirmed' then now() else confirmado_en end,
      finalizado_en=case when v_state in ('rejected','ended','suspended') then now() else finalizado_en end,
      moderado_por=case when v_state='suspended' then v_uid else moderado_por end
  where id=p_relacion_id returning * into v_rel;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'data',jsonb_build_object('id',v_rel.id,'estado',v_rel.estado));
end $$;
revoke all on function public.app_kombax_relation_state_v255(uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_relation_state_v255(uuid,text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
