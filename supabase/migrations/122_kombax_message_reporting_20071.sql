-- KOMBAX RC13 build 20071 · 122
-- Denuncia de mensajes privados con evidencia acotada al mensaje denunciado.
begin;

alter table public.kombax_social_contacto_mensajes
  add column if not exists moderation_hidden boolean not null default false,
  add column if not exists moderated_by uuid references public.perfiles(id) on delete set null,
  add column if not exists moderated_at timestamptz,
  add column if not exists moderation_reason text;

alter table public.kombax_social_reportes drop constraint if exists kombax_social_reportes_objetivo_tipo_check;
alter table public.kombax_social_reportes add constraint kombax_social_reportes_objetivo_tipo_check check(objetivo_tipo in ('publicacion','comentario','perfil','mensaje'));
alter table public.kombax_social_moderacion drop constraint if exists kombax_social_moderacion_objetivo_tipo_check;
alter table public.kombax_social_moderacion add constraint kombax_social_moderacion_objetivo_tipo_check check(objetivo_tipo in ('publicacion','comentario','perfil','mensaje','reporte'));
alter table public.kombax_moderation_decisions_v114 drop constraint if exists kombax_moderation_decisions_v114_objetivo_tipo_check;
alter table public.kombax_moderation_decisions_v114 add constraint kombax_moderation_decisions_v114_objetivo_tipo_check check(objetivo_tipo in ('publicacion','comentario','perfil','mensaje','reporte'));

create table if not exists public.kombax_message_report_evidence_v122(
  report_id uuid primary key references public.kombax_social_reportes(id) on delete cascade,
  contacto_id uuid not null references public.kombax_social_contactos(id) on delete cascade,
  message_id uuid not null references public.kombax_social_contacto_mensajes(id) on delete cascade,
  ordinal integer not null,
  author_social_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  author_name_snapshot text not null,
  text_snapshot text not null check(char_length(text_snapshot)<=500),
  message_created_at timestamptz not null,
  captured_at timestamptz not null default now()
);
alter table public.kombax_message_report_evidence_v122 enable row level security;
revoke all on public.kombax_message_report_evidence_v122 from public,anon,authenticated;

create or replace function public.app_kombax_contact_message_report_v122(p_message_id uuid,p_motivo text,p_detalle text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_msg public.kombax_social_contacto_mensajes;v_contact public.kombax_social_contactos;v_actor_ids uuid[];v_reason text:=lower(btrim(coalesce(p_motivo,'')));v_detail text:=left(nullif(btrim(p_detalle),''),1500);v_report public.kombax_social_reportes;v_author text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if v_reason not in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro') then raise exception 'KOMBAX_REPORT_REASON_INVALID';end if;
  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids from public.app_kombax_my_social_actor_ids_v106() a;
  select * into v_msg from public.kombax_social_contacto_mensajes where id=p_message_id;
  if v_msg.id is null then raise exception 'KOMBAX_MESSAGE_NOT_FOUND';end if;
  select * into v_contact from public.kombax_social_contactos where id=v_msg.contacto_id;
  if v_contact.id is null or not (v_contact.remitente_social_id=any(v_actor_ids) or v_contact.destinatario_social_id=any(v_actor_ids)) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  if v_msg.autor_social_id=any(v_actor_ids) then raise exception 'KOMBAX_REPORT_OWN_MESSAGE_NOT_ALLOWED';end if;
  select nombre_publico into v_author from public.kombax_social_perfiles where id=v_msg.autor_social_id;
  insert into public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id,motivo,detalle)
  values(v_uid,'mensaje',v_msg.id,v_reason,v_detail)
  on conflict(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision')
  do update set motivo=excluded.motivo,detalle=excluded.detalle,creado_en=now()
  returning * into v_report;
  insert into public.kombax_message_report_evidence_v122(report_id,contacto_id,message_id,ordinal,author_social_id,author_name_snapshot,text_snapshot,message_created_at,captured_at)
  values(v_report.id,v_msg.contacto_id,v_msg.id,v_msg.ordinal,v_msg.autor_social_id,coalesce(v_author,'Perfil KOMBAX'),v_msg.texto,v_msg.creado_en,now())
  on conflict(report_id) do update set text_snapshot=excluded.text_snapshot,author_name_snapshot=excluded.author_name_snapshot,captured_at=now();
  return jsonb_build_object('ok',true,'report_id',v_report.id,'estado',v_report.estado,'evidence_scope','single_message');
end $$;
revoke all on function public.app_kombax_contact_message_report_v122(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_contact_message_report_v122(uuid,text,text) to authenticated;

create or replace function public.app_kombax_moderation_queue_v050(p_limit integer default 100)
returns table(id uuid,objetivo_tipo text,objetivo_id uuid,motivo text,detalle text,estado text,creado_en timestamptz,objetivo_resumen text,autor_objetivo text)
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
      when 'mensaje' then left(coalesce(me.text_snapshot,''),280)
      else '' end,
    case r.objetivo_tipo
      when 'publicacion' then coalesce(spp.nombre_publico,'')
      when 'comentario' then coalesce(spc.nombre_publico,'')
      when 'perfil' then coalesce(sp.nombre_publico,'')
      when 'mensaje' then coalesce(me.author_name_snapshot,'')
      else '' end
  from public.kombax_social_reportes r
  left join public.kombax_social_publicaciones p on r.objetivo_tipo='publicacion' and p.id=r.objetivo_id
  left join public.kombax_social_perfiles spp on spp.id=p.autor_perfil_id
  left join public.kombax_social_comentarios c on r.objetivo_tipo='comentario' and c.id=r.objetivo_id
  left join public.kombax_social_perfiles spc on spc.id=c.autor_social_id
  left join public.kombax_social_perfiles sp on r.objetivo_tipo='perfil' and sp.id=r.objetivo_id
  left join public.kombax_message_report_evidence_v122 me on r.objetivo_tipo='mensaje' and me.report_id=r.id
  where r.estado in ('pendiente','en_revision')
  order by case r.motivo when 'sexual_menores' then 0 when 'violencia' then 1 when 'acoso' then 2 else 3 end,r.creado_en
  limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_moderation_queue_v050(integer) from public,anon;
grant execute on function public.app_kombax_moderation_queue_v050(integer) to authenticated;

create or replace function public.app_kombax_moderation_decide_v114(p_reporte_id uuid,p_decision_state text,p_reason_code text,p_reason_text text,p_confidence numeric default null,p_evidence jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare r public.kombax_social_reportes;v_state text:=lower(coalesce(p_decision_state,''));v_action text;v_reason text:=btrim(coalesce(p_reason_text,''));v_code text:=lower(btrim(coalesce(p_reason_code,'')));v_id uuid;
begin
  if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
  if v_state not in ('allowed','review','hidden','warning','suspended','escalated') then raise exception 'KOMBAX_MODERATION_DECISION_INVALID';end if;
  if char_length(v_reason)<3 or v_code!~'^[a-z][a-z0-9_]{2,79}$' then raise exception 'KOMBAX_MODERATION_REASON_REQUIRED';end if;
  if p_confidence is not null and (p_confidence<0 or p_confidence>1) then raise exception 'KOMBAX_MODERATION_CONFIDENCE_INVALID';end if;
  select * into r from public.kombax_social_reportes where id=p_reporte_id for update;if r.id is null then raise exception 'KOMBAX_REPORT_NOT_FOUND';end if;
  v_action:=case v_state when 'allowed' then 'restore' when 'review' then 'review' when 'hidden' then 'hide' when 'warning' then 'warn' when 'suspended' then 'suspend' else 'escalate' end;
  if v_state='hidden' then
    if r.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='oculta',moderada_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='comentario' then update public.kombax_social_comentarios set estado='hidden',moderado_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='mensaje' then update public.kombax_social_contacto_mensajes set moderation_hidden=true,moderated_by=auth.uid(),moderated_at=now(),moderation_reason=v_reason where id=r.objetivo_id;
    else raise exception 'KOMBAX_MODERATION_ACTION_TARGET_MISMATCH';end if;
  elsif v_state='allowed' then
    if r.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='activa',moderada_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='comentario' then update public.kombax_social_comentarios set estado='active',moderado_por=auth.uid(),moderacion_motivo=v_reason,actualizado_en=now() where id=r.objetivo_id;
    elsif r.objetivo_tipo='mensaje' then update public.kombax_social_contacto_mensajes set moderation_hidden=false,moderated_by=auth.uid(),moderated_at=now(),moderation_reason=v_reason where id=r.objetivo_id;end if;
  elsif v_state='suspended' then
    if r.objetivo_tipo<>'perfil' then raise exception 'KOMBAX_MODERATION_ACTION_TARGET_MISMATCH';end if;
    update public.kombax_social_perfiles set estado='suspendido',visible=false,publicar_habilitado=false,contacto_habilitado=false,actualizado_en=now() where id=r.objetivo_id;
  end if;
  update public.kombax_social_reportes set estado=case when v_state in ('review','escalated') then 'en_revision' else 'resuelta' end,revisado_por=auth.uid(),resolucion=v_reason,revisado_en=now() where id=r.id;
  insert into public.kombax_moderation_decisions_v114(reporte_id,moderador_id,objetivo_tipo,objetivo_id,decision_state,accion,confidence,reason_code,reason_text,evidence)
    values(r.id,auth.uid(),r.objetivo_tipo,r.objetivo_id,v_state,v_action,p_confidence,v_code,v_reason,coalesce(p_evidence,'{}'::jsonb)) returning id into v_id;
  return jsonb_build_object('ok',true,'decision_id',v_id,'report_id',r.id,'decision_state',v_state,'action',v_action,'audited',true);
end $$;
revoke all on function public.app_kombax_moderation_decide_v114(uuid,text,text,text,numeric,jsonb) from public,anon;
grant execute on function public.app_kombax_moderation_decide_v114(uuid,text,text,text,numeric,jsonb) to authenticated;

create or replace function public.app_kombax_contact_mensajes_v106(p_contacto_id uuid,p_before_ordinal integer default null,p_after_ordinal integer default null,p_limit integer default 30)
returns table(id uuid,contacto_id uuid,autor_social_id uuid,autor_nombre text,ordinal integer,texto text,creado_en timestamptz,leido_en timestamptz,propio boolean,older_available boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_limit integer:=least(50,greatest(1,coalesce(p_limit,30)));v_actor_ids uuid[];
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_before_ordinal is not null and p_after_ordinal is not null then raise exception 'KOMBAX_CONTACT_CURSOR_INVALID';end if;
  select coalesce(array_agg(a.social_id),'{}'::uuid[]) into v_actor_ids from public.app_kombax_my_social_actor_ids_v106() a;
  if not exists(select 1 from public.kombax_social_contactos c where c.id=p_contacto_id and ((c.remitente_social_id=any(v_actor_ids) and c.eliminado_remitente_en is null) or (c.destinatario_social_id=any(v_actor_ids) and c.eliminado_destinatario_en is null))) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  if p_after_ordinal is not null then
    return query select m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal,case when m.moderation_hidden then '[Mensaje retirado por moderación]' else m.texto end,m.creado_en,m.leido_en,m.autor_social_id=any(v_actor_ids),false
    from public.kombax_social_contacto_mensajes m join public.kombax_social_perfiles sp on sp.id=m.autor_social_id where m.contacto_id=p_contacto_id and m.ordinal>p_after_ordinal order by m.ordinal asc,m.id asc limit v_limit;
  else
    return query with picked as(select m.* from public.kombax_social_contacto_mensajes m where m.contacto_id=p_contacto_id and (p_before_ordinal is null or m.ordinal<p_before_ordinal) order by m.ordinal desc,m.id desc limit v_limit),meta as(select min(p.ordinal) min_ordinal from picked p)
    select p.id,p.contacto_id,p.autor_social_id,sp.nombre_publico,p.ordinal,case when p.moderation_hidden then '[Mensaje retirado por moderación]' else p.texto end,p.creado_en,p.leido_en,p.autor_social_id=any(v_actor_ids),exists(select 1 from public.kombax_social_contacto_mensajes older where older.contacto_id=p_contacto_id and older.ordinal<(select min_ordinal from meta))
    from picked p join public.kombax_social_perfiles sp on sp.id=p.autor_social_id order by p.ordinal asc,p.id asc;
  end if;
end $$;
revoke all on function public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer) to authenticated;

notify pgrst,'reload schema';
commit;
