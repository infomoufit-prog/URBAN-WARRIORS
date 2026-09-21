-- KOMBAX 20.110 R60 PILOT FINAL · profile/chat/network/media corrective pack
-- Scope:
-- 1) Mi red has its own actor permission: an active member may network even when social.publish is not granted.
-- 2) Relation request/list/state use that dedicated permission without opening private chat permissions.
-- 3) Public profile activity includes authorised image/video metadata.
-- 4) Assist-history deletion targets MANAGEMENT only; Support remains a separate formal channel.
begin;

create or replace function public.app_kombax_social_network_actor_allowed_v255(p_social_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1
    from public.kombax_social_perfiles sp
    where sp.id=p_social_id
      and sp.visible=true
      and sp.estado='activo'
      and (
        (sp.sujeto_tipo='miembro' and exists(
          select 1
          from public.identidades_sociales i
          join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
          where i.id=sp.identidad_social_id
            and i.perfil_id=auth.uid()
            and i.estado='activa'
            and s.estado='activo'
            and s.fecha_nacimiento is not null
            and extract(year from age(current_date,s.fecha_nacimiento))>=14
        ))
        or
        (sp.sujeto_tipo='club'
          and sp.club_id is not null
          and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
        or
        (sp.sujeto_tipo='perfil_directo' and exists(
          select 1
          from public.perfiles_kombax_directos d
          where d.id=sp.perfil_directo_id
            and d.perfil_id=auth.uid()
            and d.estado='activo'
            and d.verificacion_estado='verificado'
            and d.social_activo=true
        ))
      )
  );
$$;
revoke all on function public.app_kombax_social_network_actor_allowed_v255(uuid) from public,anon;
grant execute on function public.app_kombax_social_network_actor_allowed_v255(uuid) to authenticated;
comment on function public.app_kombax_social_network_actor_allowed_v255(uuid) is
'R60 pilot final: dedicated ownership/eligibility check for private Mi red. It does not grant social.publish or private-chat permission.';

create or replace function public.app_kombax_social_network_profiles_v255(p_club_id uuid default null)
returns table(
  id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,avatar_path text,
  banner_url text,banner_path text,verificado boolean,contacto_habilitado boolean,
  perfil_directo_id uuid,perfil_tipo text,club_id uuid,club_nombre text,identity_label text
)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
    public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),
    sp.verificado,public.app_kombax_social_contactable_v041(sp.id),sp.perfil_directo_id,
    public.app_kombax_social_tipo_v051(sp.id),coalesce(sp.club_id,i.club_origen_id),c.nombre,
    case
      when sp.sujeto_tipo='club' then c.nombre||' · Club'
      when sp.sujeto_tipo='miembro' then sp.nombre_publico||' · Miembro'||case when c.nombre is not null then ' de '||c.nombre else '' end
      else sp.nombre_publico||' · '||initcap(public.app_kombax_social_tipo_v051(sp.id))
    end
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  where public.app_kombax_social_network_actor_allowed_v255(sp.id)
    and (p_club_id is null or sp.sujeto_tipo<>'club' or sp.club_id=p_club_id)
  order by case when sp.sujeto_tipo='miembro' then 0 when p_club_id is not null and sp.sujeto_tipo='club' and sp.club_id=p_club_id then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_network_profiles_v255(uuid) from public,anon;
grant execute on function public.app_kombax_social_network_profiles_v255(uuid) to authenticated;

create or replace function public.app_kombax_relaciones_v068(p_social_id uuid)
returns table(
  id uuid,origen_social_id uuid,origen_nombre text,destino_social_id uuid,destino_nombre text,
  tipo text,estado text,nota text,creado_en timestamptz,confirmado_en timestamptz,gestionable boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  if p_social_id is null or not public.app_kombax_social_network_actor_allowed_v255(p_social_id) then
    raise exception 'KOMBAX_RELATIONS_PRIVATE';
  end if;
  return query
  select r.id,r.origen_social_id,o.nombre_publico,r.destino_social_id,d.nombre_publico,
    r.tipo,r.estado,r.nota,r.creado_en,r.confirmado_en,
    r.estado='pending' and public.app_kombax_social_network_actor_allowed_v255(r.destino_social_id)
  from public.kombax_relaciones r
  join public.kombax_social_perfiles o on o.id=r.origen_social_id
  join public.kombax_social_perfiles d on d.id=r.destino_social_id
  where r.origen_social_id=p_social_id or r.destino_social_id=p_social_id
  order by case r.estado when 'confirmed' then 0 when 'pending' then 1 else 2 end,r.creado_en desc;
end $$;
revoke all on function public.app_kombax_relaciones_v068(uuid) from public,anon;
grant execute on function public.app_kombax_relaciones_v068(uuid) to authenticated;

create or replace function public.app_kombax_relation_request_v255(
  p_origen_social_id uuid,
  p_destino_social_id uuid,
  p_nota text default null,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_existing public.kombax_relaciones;v_rel public.kombax_relaciones;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_origen_social_id is null or p_destino_social_id is null or p_origen_social_id=p_destino_social_id then raise exception 'KOMBAX_RELATION_PROFILES_INVALID';end if;
  if not public.app_kombax_social_network_actor_allowed_v255(p_origen_social_id) then raise exception 'KOMBAX_RELATION_SOURCE_NOT_OWNED';end if;
  if not exists(select 1 from public.kombax_social_perfiles where id=p_destino_social_id and visible and estado='activo') then raise exception 'KOMBAX_RELATION_TARGET_NOT_AVAILABLE';end if;

  select * into v_existing
  from public.kombax_relaciones r
  where r.tipo='conexion_kombax' and r.estado in ('pending','confirmed')
    and ((r.origen_social_id=p_origen_social_id and r.destino_social_id=p_destino_social_id)
      or (r.origen_social_id=p_destino_social_id and r.destino_social_id=p_origen_social_id))
  order by case r.estado when 'confirmed' then 0 else 1 end,r.creado_en desc
  limit 1;
  if v_existing.id is not null then
    return jsonb_build_object('ok',true,'existing',true,'request_id',p_request_id,'data',to_jsonb(v_existing));
  end if;

  insert into public.kombax_relaciones(origen_social_id,destino_social_id,tipo,solicitado_por,nota)
  values(p_origen_social_id,p_destino_social_id,'conexion_kombax',v_uid,left(nullif(btrim(p_nota),''),500))
  returning * into v_rel;
  return jsonb_build_object('ok',true,'existing',false,'request_id',p_request_id,'data',to_jsonb(v_rel));
end $$;
revoke all on function public.app_kombax_relation_request_v255(uuid,uuid,text,uuid) from public,anon;
grant execute on function public.app_kombax_relation_request_v255(uuid,uuid,text,uuid) to authenticated;

create or replace function public.app_kombax_relation_state_v255(
  p_relacion_id uuid,
  p_estado text,
  p_request_id uuid default gen_random_uuid()
)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_rel public.kombax_relaciones;v_state text:=lower(coalesce(p_estado,''));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_relacion_id is null then raise exception 'KOMBAX_RELATION_ID_INVALID';end if;
  if v_state not in ('confirmed','rejected','ended','suspended') then raise exception 'KOMBAX_RELATION_STATE_INVALID';end if;
  select * into v_rel from public.kombax_relaciones where id=p_relacion_id for update;
  if v_rel.id is null then raise exception 'KOMBAX_RELATION_NOT_FOUND';end if;
  if v_rel.tipo<>'conexion_kombax' then
    raise exception 'KOMBAX_RELATION_STATE_USE_LEGACY';
  end if;
  if v_state in ('confirmed','rejected') and not public.app_kombax_social_network_actor_allowed_v255(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then
    raise exception 'KOMBAX_RELATION_CONFIRM_FORBIDDEN';
  end if;
  if v_state='ended' and not public.app_kombax_social_network_actor_allowed_v255(v_rel.origen_social_id) and not public.app_kombax_social_network_actor_allowed_v255(v_rel.destino_social_id) and not public.app_kombax_es_moderador_v041() then
    raise exception 'KOMBAX_RELATION_END_FORBIDDEN';
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

create or replace function public.app_kombax_social_profile_posts_v255(
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
declare v_limit integer:=least(greatest(coalesce(p_limit,10),1),10);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if not public.app_kombax_social_network_actor_allowed_v255(p_social_id) and not exists(
    select 1 from public.kombax_social_perfiles sp where sp.id=p_social_id and sp.visible=true and sp.estado='activo'
  ) then raise exception 'KOMBAX_PROFILE_NOT_AVAILABLE';end if;

  return query
  select p.id,p.tipo,p.texto,p.creado_en,p.likes_count,p.comentarios_count,p.comentarios_estado,p.audiencia,
         public.app_kombax_social_audiencia_label_v083(p.id),
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
revoke all on function public.app_kombax_social_profile_posts_v255(uuid,timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_profile_posts_v255(uuid,timestamptz,uuid,integer) to authenticated;

-- Keep formal Support out of Assist history deletion. Accept the UI alias `management` defensively.
create or replace function public.app_kombax_customer_history_delete_plan_r60(
  p_ticket_id text default null,
  p_mode text default null,
  p_tenant_ref text default null
)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();v_ctx record;v_mode text:=lower(btrim(coalesce(p_mode,'')));
  v_ticket_ids text[]:='{}'::text[];v_paths text[]:='{}'::text[];v_count integer:=0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
  if v_mode='management' then v_mode:='assist';end if;
  if v_mode not in ('','assist','migration') then raise exception 'KOMBAX_HISTORY_DELETE_MODE_INVALID';end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  if not kombax_ai_ops.org_assist_access_allowed(v_uid,v_ctx.tenant_ref) then raise exception 'KOMBAX_ORG_HISTORY_ONLY' using errcode='42501';end if;

  select coalesce(array_agg(t.ticket_id order by t.updated_at desc),'{}'::text[]) into v_ticket_ids
  from kombax_customer_ops.tickets t
  where t.user_ref=v_uid and t.tenant_ref=v_ctx.tenant_ref
    and (p_ticket_id is null or t.ticket_id=p_ticket_id)
    and (v_mode='' or (v_mode='migration' and t.category='MIGRATION') or (v_mode='assist' and t.category='MANAGEMENT'));

  v_count:=coalesce(cardinality(v_ticket_ids),0);
  if v_count=0 then return jsonb_build_object('ok',true,'tenant_ref',v_ctx.tenant_ref,'ticket_ids','[]'::jsonb,'storage_paths','[]'::jsonb,'tickets',0,'mode',coalesce(nullif(v_mode,''),'mixed'));end if;
  select coalesce(array_agg(f.storage_path order by f.created_at),'{}'::text[]) into v_paths
  from kombax_customer_ops.migration_files f where f.user_ref=v_uid and f.ticket_id=any(v_ticket_ids);
  return jsonb_build_object('ok',true,'tenant_ref',v_ctx.tenant_ref,'ticket_ids',to_jsonb(v_ticket_ids),'storage_paths',to_jsonb(v_paths),'tickets',v_count,'mode',coalesce(nullif(v_mode,''),'mixed'));
end $$;
revoke all on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) from public,anon,service_role;
grant execute on function public.app_kombax_customer_history_delete_plan_r60(text,text,text) to authenticated;

notify pgrst,'reload schema';
commit;
