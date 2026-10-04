begin;
CREATE OR REPLACE FUNCTION public.app_kombax_content_action_r118(p_channel text, p_id uuid, p_action text, p_reason text, p_patch jsonb DEFAULT '{}'::jsonb, p_confirmation text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_before jsonb;v_after jsonb;v_author uuid;v_state text;v_lock kombax_moderation.content_state;
begin
 if auth.uid() is null or not coalesce(public.app_kombax_es_moderador_v041(),false) then raise exception 'MODERATOR_REQUIRED';end if;
 if p_action is null or p_action not in ('edit','hide','restore','delete','warn') or p_channel is null or p_channel not in ('social','showcase') then raise exception 'INVALID_ACTION';end if;
 if length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'REASON_REQUIRED';end if;
 if p_action='edit' and (length(btrim(coalesce(p_patch->>'text',''))) not between 1 and 10000 or (p_channel='social' and length(p_patch->>'text')>1500) or (p_channel='showcase' and length(btrim(coalesce(p_patch->>'title',''))) not between 1 and 160)) then raise exception 'INVALID_EDIT';end if;
 if p_action='delete' then
  if not coalesce(public.app_kombax_es_platform_admin_v055(),false) then raise exception 'Necesitas una sesión Owner válida para eliminar. Vuelve a entrar en administración Owner.';end if;
  if coalesce(p_confirmation,'')<>'ELIMINAR' then raise exception 'Escribe ELIMINAR para confirmar la retirada definitiva.';end if;
 end if;
 if p_channel='social' then
  select to_jsonb(p),p.estado into v_before,v_state from public.kombax_social_publicaciones p where p.id=p_id for update;
  select coalesce(d.perfil_id,i.perfil_id) into v_author from public.kombax_social_perfiles s left join public.perfiles_kombax_directos d on d.id=s.perfil_directo_id left join public.identidades_sociales i on i.id=s.identidad_social_id where s.id=(v_before->>'autor_perfil_id')::uuid;
 else select to_jsonb(e),e.estado,e.creado_por into v_before,v_state,v_author from public.kombax_showcase_elementos e where e.id=p_id for update;end if;
 if v_before is null then raise exception 'CONTENT_NOT_FOUND';end if;
 select * into v_lock from kombax_moderation.content_state where channel=p_channel and content_id=p_id;
 if v_lock.state='deleted' then raise exception 'CONTENT_ALREADY_DELETED';end if;
 if p_action in ('hide','delete') then
  insert into kombax_moderation.content_state(channel,content_id,state,reason,previous_state,previous_commerce)
  values(p_channel,p_id,case when p_action='delete' then 'deleted' else 'hidden' end,p_reason,v_state,(v_before->>'commerce_enabled')::boolean)
  on conflict(channel,content_id) do update set state=excluded.state,reason=excluded.reason;
 elsif p_action='restore' then
  if v_lock.content_id is null then raise exception 'CONTENT_NOT_WITHDRAWN';end if;
  if kombax_moderation.prohibited_offer(p_channel,case when p_channel='social' then v_before->>'texto' else (v_before->>'nombre')||' '||coalesce(v_before->>'resumen','')||' '||coalesce(v_before->>'descripcion','') end) then raise exception 'PROHIBITED_OFFER_CORRECT_BEFORE_RESTORE';end if;
  delete from kombax_moderation.content_state where channel=p_channel and content_id=p_id;
 end if;
 if p_channel='social' then
  update public.kombax_social_publicaciones set
   texto=case when p_action='edit' then p_patch->>'text' else texto end,
   estado=case when p_action='delete' then 'retirada' when p_action='hide' then 'oculta' when p_action='restore' then v_lock.previous_state else estado end,
   moderada_por=auth.uid(),moderacion_motivo=p_reason,actualizado_en=now() where id=p_id returning to_jsonb(kombax_social_publicaciones.*) into v_after;
 else
  update public.kombax_showcase_elementos set
   nombre=case when p_action='edit' then coalesce(p_patch->>'title',nombre) else nombre end,
   descripcion=case when p_action='edit' then p_patch->>'text' else descripcion end,
   resumen=case when p_action='edit' then coalesce(p_patch->>'summary',resumen) else resumen end,
   estado=case when p_action='delete' then 'archivado' when p_action='hide' then 'oculto' when p_action='restore' then v_lock.previous_state else estado end,
   commerce_enabled=case when p_action in ('hide','delete') then false when p_action='restore' then coalesce(v_lock.previous_commerce,false) else commerce_enabled end,
   actualizado_por=auth.uid(),actualizado_en=now() where id=p_id returning to_jsonb(kombax_showcase_elementos.*) into v_after;
 end if;
 insert into kombax_moderation.history(channel,content_id,actor_id,action,reason,before_data,after_data) values(p_channel,p_id,auth.uid(),p_action,p_reason,kombax_moderation.snapshot(v_before),kombax_moderation.snapshot(v_after));
 perform kombax_moderation.notify(p_channel,p_id,p_action,p_reason,v_author);
 return jsonb_build_object('ok',true,'state',v_after->>'estado');
end $function$;

commit;
