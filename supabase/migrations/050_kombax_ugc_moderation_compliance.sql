begin;

-- KOMBAX 050 · UGC: denuncia de comentarios + cola de moderación global.
-- Completa el ciclo publicación / comentario / perfil sin abrir acceso directo a tablas.

alter table public.kombax_social_reportes drop constraint if exists kombax_social_reportes_objetivo_tipo_check;
alter table public.kombax_social_reportes add constraint kombax_social_reportes_objetivo_tipo_check
  check(objetivo_tipo in ('publicacion','comentario','perfil'));

alter table public.kombax_social_moderacion drop constraint if exists kombax_social_moderacion_objetivo_tipo_check;
alter table public.kombax_social_moderacion add constraint kombax_social_moderacion_objetivo_tipo_check
  check(objetivo_tipo in ('publicacion','comentario','perfil','reporte'));

create or replace function public.app_kombax_moderation_queue_v050(p_limit integer default 100)
returns table(
  id uuid,objetivo_tipo text,objetivo_id uuid,motivo text,detalle text,estado text,creado_en timestamptz,
  objetivo_resumen text,autor_objetivo text
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
  return query
  select r.id,r.objetivo_tipo,r.objetivo_id,r.motivo,r.detalle,r.estado,r.creado_en,
    case r.objetivo_tipo
      when 'publicacion' then left(coalesce(p.texto,''),280)
      when 'comentario' then left(coalesce(c.texto,''),280)
      when 'perfil' then coalesce(sp.bio,sp.nombre_publico,'')
      else '' end,
    case r.objetivo_tipo
      when 'publicacion' then coalesce(spp.nombre_publico,'')
      when 'comentario' then coalesce(spc.nombre_publico,'')
      when 'perfil' then coalesce(sp.nombre_publico,'')
      else '' end
  from public.kombax_social_reportes r
  left join public.kombax_social_publicaciones p on r.objetivo_tipo='publicacion' and p.id=r.objetivo_id
  left join public.kombax_social_perfiles spp on spp.id=p.autor_perfil_id
  left join public.kombax_social_comentarios c on r.objetivo_tipo='comentario' and c.id=r.objetivo_id
  left join public.kombax_social_perfiles spc on spc.id=c.autor_social_id
  left join public.kombax_social_perfiles sp on r.objetivo_tipo='perfil' and sp.id=r.objetivo_id
  where r.estado in ('pendiente','en_revision')
  order by case r.motivo when 'sexual_menores' then 0 when 'violencia' then 1 when 'acoso' then 2 else 3 end,r.creado_en
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_moderation_queue_v050(integer) from public,anon;
grant execute on function public.app_kombax_moderation_queue_v050(integer) to authenticated;

create or replace function public.app_kombax_social_mutate_v050(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_target uuid;v_report public.kombax_social_reportes;v_type text;v_reason text;v_status text;v_action text;v_detail text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;

  -- 049 sigue siendo el gateway para todas las operaciones que no cambian en 050.
  if p_operation not in ('kombax.social.denunciar','kombax.social.moderar') then
    return public.app_kombax_social_mutate_v049(p_operation,p_payload,p_request_id);
  end if;

  if not public.app_kombax_social_acceso_v041() and p_operation='kombax.social.denunciar' then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if p_operation='kombax.social.moderar' and not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;

  if p_operation='kombax.social.denunciar' then
    v_type:=lower(coalesce(v_payload->>'objetivo_tipo',''));
    if v_type not in ('publicacion','comentario','perfil') then raise exception 'KOMBAX_REPORT_TARGET_TYPE_INVALID';end if;
    begin v_target:=(v_payload->>'objetivo_id')::uuid;exception when others then raise exception 'KOMBAX_REPORT_TARGET_INVALID';end;
    if v_type='publicacion' and not exists(select 1 from public.kombax_social_publicaciones where id=v_target) then raise exception 'KOMBAX_POST_NOT_FOUND';end if;
    if v_type='comentario' and not exists(select 1 from public.kombax_social_comentarios where id=v_target) then raise exception 'KOMBAX_COMMENT_NOT_FOUND';end if;
    if v_type='perfil' and not exists(select 1 from public.kombax_social_perfiles where id=v_target) then raise exception 'KOMBAX_PROFILE_NOT_FOUND';end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));
    if v_reason not in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro') then raise exception 'KOMBAX_REPORT_REASON_INVALID';end if;
    v_detail:=left(nullif(btrim(v_payload->>'detalle'),''),1500);
    insert into public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id,motivo,detalle)
    values(v_uid,v_type,v_target,v_reason,v_detail)
    on conflict(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision')
    do update set motivo=excluded.motivo,detalle=excluded.detalle,creado_en=now()
    returning * into v_report;
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado,'objetivo_tipo',v_report.objetivo_tipo);

  else
    begin v_target:=(v_payload->>'reporte_id')::uuid;exception when others then raise exception 'KOMBAX_REPORT_ID_INVALID';end;
    v_status:=lower(coalesce(v_payload->>'estado',''));
    if v_status not in ('en_revision','resuelta','descartada') then raise exception 'KOMBAX_REPORT_STATE_INVALID';end if;
    v_reason:=left(nullif(btrim(v_payload->>'resolucion'),''),1500);
    v_action:=lower(coalesce(v_payload->>'accion','ninguna'));
    if v_action not in ('ninguna','ocultar','limitar','suspender') then raise exception 'KOMBAX_MODERATION_ACTION_INVALID';end if;
    select * into v_report from public.kombax_social_reportes where id=v_target for update;
    if v_report.id is null then raise exception 'KOMBAX_REPORT_NOT_FOUND';end if;

    if v_status='resuelta' then
      if v_report.objetivo_tipo='publicacion' and v_action='ocultar' then
        update public.kombax_social_publicaciones set estado='oculta',moderada_por=v_uid,moderacion_motivo=coalesce(v_reason,'Ocultada por moderación'),actualizado_en=now() where id=v_report.objetivo_id;
      elsif v_report.objetivo_tipo='comentario' and v_action='ocultar' then
        update public.kombax_social_comentarios set estado='hidden',moderado_por=v_uid,moderacion_motivo=coalesce(v_reason,'Ocultado por moderación'),actualizado_en=now() where id=v_report.objetivo_id;
      elsif v_report.objetivo_tipo='perfil' and v_action='limitar' then
        update public.kombax_social_perfiles set estado='limitado',publicar_habilitado=false,contacto_habilitado=false,actualizado_en=now() where id=v_report.objetivo_id;
      elsif v_report.objetivo_tipo='perfil' and v_action='suspender' then
        update public.kombax_social_perfiles set estado='suspendido',visible=false,publicar_habilitado=false,contacto_habilitado=false,actualizado_en=now() where id=v_report.objetivo_id;
      elsif v_action<>'ninguna' then
        raise exception 'KOMBAX_MODERATION_ACTION_TARGET_MISMATCH';
      end if;
    elsif v_action<>'ninguna' then
      raise exception 'KOMBAX_MODERATION_ACTION_REQUIRES_RESOLUTION';
    end if;

    update public.kombax_social_reportes set estado=v_status,revisado_por=v_uid,resolucion=v_reason,revisado_en=now() where id=v_target returning * into v_report;
    insert into public.kombax_social_moderacion(moderador_id,objetivo_tipo,objetivo_id,accion,motivo)
    values(v_uid,v_report.objetivo_tipo,v_report.objetivo_id,
      case when v_status='descartada' then 'descartar' when v_action in ('ocultar','limitar','suspender') then v_action else 'resolver' end,
      coalesce(v_reason,case when v_status='descartada' then 'Denuncia descartada' else 'Denuncia resuelta' end));
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado,'accion',v_action,'objetivo_tipo',v_report.objetivo_tipo);
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v050(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v050(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
