begin;

-- R60 pilot final: public profile activity may enforce audience visibility internally,
-- but the audience choice itself is private metadata. Only the author/authorized manager
-- may receive audience fields; other viewers receive NULL after the visibility check.
create or replace function public.app_kombax_social_profile_posts_v256(
  p_social_id uuid,
  p_cursor timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 10
)
returns table(
  id uuid,tipo text,texto text,creado_en timestamptz,likes_count integer,comentarios_count integer,
  comentarios_estado text,audiencia text,audiencia_label text,
  media_id uuid,media_tipo text,media_path text,media_bucket text,media_mime text,media_duration numeric,media_scope text
)
language plpgsql stable security definer set search_path=public,auth as $$
declare
  v_limit integer:=least(greatest(coalesce(p_limit,10),1),10);
  v_owner boolean:=false;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v_owner:=public.app_kombax_social_network_actor_allowed_v255(p_social_id);
  if not v_owner and not exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible=true and sp.estado='activo'
  ) then raise exception 'KOMBAX_PROFILE_NOT_AVAILABLE';end if;

  return query
  select p.id,p.tipo,p.texto,p.creado_en,p.likes_count,p.comentarios_count,p.comentarios_estado,
         case when v_owner then p.audiencia else null::text end,
         case when v_owner then public.app_kombax_social_audiencia_label_v083(p.id) else null::text end,
         coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),
         case when sm.id is not null then coalesce(sm.storage_bucket,'kombax-public-media') when pm.id is not null then 'kombax-public-media' else null end,
         coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds),
         case when sm.id is not null then 'social_media' when pm.id is not null then 'profile_media' else null end
  from public.kombax_social_publicaciones p
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
  left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  where p.autor_perfil_id=p_social_id and p.estado='activa'
    and public.app_kombax_social_puede_ver_publicacion_v083(p.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and (p_cursor_id is null or p.id<p_cursor_id)))
  order by p.creado_en desc,p.id desc
  limit v_limit;
end $$;
revoke all on function public.app_kombax_social_profile_posts_v256(uuid,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_profile_posts_v256(uuid,timestamptz,uuid,integer) to authenticated;
comment on function public.app_kombax_social_profile_posts_v256(uuid,timestamptz,uuid,integer) is
'R60 pilot final: profile posts preserve server-side audience enforcement but redact audience metadata from non-author viewers.';

-- R60 pilot final: authenticated history finalizer. This deliberately derives user ownership
-- from auth.uid() instead of accepting a user id from the client/edge function. It allows the
-- edge function to use the real user JWT after Storage cleanup, avoiding service-key/JWT ambiguity.
create or replace function public.app_kombax_customer_history_delete_finalize_v256(
  p_ticket_ids text[]
)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_ids text[]:=coalesce(p_ticket_ids,'{}'::text[]);
  v_requested integer:=coalesce(cardinality(v_ids),0);
  v_owned integer:=0;
  v_messages integer:=0;
  v_files integer:=0;
  v_bytes bigint:=0;
  v_tickets integer:=0;
  v_scope text:='MIXED';
  v_tenant_ref text:=null;
  v_tenant_count integer:=0;
begin
  if v_uid is null then raise exception 'KOMBAX_HISTORY_DELETE_AUTH_REQUIRED' using errcode='42501'; end if;
  if v_requested=0 then return jsonb_build_object('ok',true,'tickets_deleted',0,'chat_messages_deleted',0,'migration_files_deleted',0,'migration_bytes_deleted',0,'allowance_preserved',true); end if;
  if v_requested>100 then raise exception 'KOMBAX_HISTORY_DELETE_BATCH_TOO_LARGE'; end if;

  select count(*),min(t.tenant_ref),count(distinct t.tenant_ref)
    into v_owned,v_tenant_ref,v_tenant_count
  from kombax_customer_ops.tickets t
  where t.user_ref=v_uid and t.ticket_id=any(v_ids);
  if v_owned<>v_requested then raise exception 'KOMBAX_HISTORY_DELETE_OWNERSHIP_MISMATCH' using errcode='42501'; end if;
  if v_tenant_count<>1 or v_tenant_ref is null then raise exception 'KOMBAX_HISTORY_DELETE_TENANT_MISMATCH' using errcode='42501'; end if;

  select count(*) into v_messages from kombax_customer_ops.assist_chat_messages m where m.user_ref=v_uid and m.ticket_id=any(v_ids);
  select count(*),coalesce(sum(f.size_bytes),0) into v_files,v_bytes from kombax_customer_ops.migration_files f where f.user_ref=v_uid and f.ticket_id=any(v_ids);
  select case when bool_and(t.category='MIGRATION') then 'MIGRATION' when bool_and(t.category='MANAGEMENT') then 'ASSIST' else 'MIXED' end
    into v_scope from kombax_customer_ops.tickets t where t.user_ref=v_uid and t.ticket_id=any(v_ids);

  delete from kombax_customer_ops.migration_file_analysis a where a.user_ref=v_uid and a.ticket_id=any(v_ids);
  delete from kombax_customer_ops.assist_chat_messages m where m.user_ref=v_uid and m.ticket_id=any(v_ids);
  delete from kombax_customer_ops.migration_files f where f.user_ref=v_uid and f.ticket_id=any(v_ids);
  delete from kombax_customer_ops.email_outbox o where o.ticket_id=any(v_ids);
  delete from kombax_customer_ops.ticket_messages m where m.ticket_id=any(v_ids);

  update kombax_ai_ops.assistance_turns t
    set session_id=null,ticket_id=null,content_deleted_at=coalesce(content_deleted_at,now())
    where t.user_ref=v_uid and t.ticket_id=any(v_ids);

  delete from kombax_customer_ops.guided_sessions s where s.user_ref=v_uid and s.ticket_id=any(v_ids);
  delete from kombax_customer_ops.ticket_events e where e.ticket_id=any(v_ids);
  delete from kombax_customer_ops.tickets t where t.user_ref=v_uid and t.ticket_id=any(v_ids);
  get diagnostics v_tickets=row_count;

  insert into kombax_ai_ops.customer_content_deletions(
    tenant_ref,user_ref,scope,tickets_deleted,chat_messages_deleted,migration_files_deleted,migration_bytes_deleted
  ) values(
    v_tenant_ref,v_uid,coalesce(v_scope,'MIXED'),v_tickets,v_messages,v_files,v_bytes
  );

  return jsonb_build_object('ok',true,'tickets_deleted',v_tickets,'chat_messages_deleted',v_messages,'migration_files_deleted',v_files,'migration_bytes_deleted',v_bytes,'allowance_preserved',true);
end $$;
revoke all on function public.app_kombax_customer_history_delete_finalize_v256(text[]) from public,anon;
grant execute on function public.app_kombax_customer_history_delete_finalize_v256(text[]) to authenticated;
comment on function public.app_kombax_customer_history_delete_finalize_v256(text[]) is
'R60 pilot final: authenticated owner-only deletion finalizer called after migration Storage cleanup; metering remains preserved.';

notify pgrst,'reload schema';
commit;
