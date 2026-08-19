-- KOMBAX RC13 build 20044 · 079 · kombax verified profiles admin hardening

begin;

-- ---------------------------------------------------------------------------
-- 7. Vista privada de administración de una solicitud + dashboard 20044.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_platform_application_v072(p_solicitud_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  select jsonb_build_object(
    'application',to_jsonb(s),
    'direct_profile',case when d.id is null then null else to_jsonb(d) end,
    'documents',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'tipo_documento',x.tipo_documento,'storage_path',x.storage_path,'mime_type',x.mime_type,'bytes',x.bytes,'estado',x.estado,'creado_en',x.creado_en) order by x.creado_en) from public.kombax_verificacion_documentos x where x.solicitud_id=s.id),'[]'::jsonb),
    'events',coalesce((select jsonb_agg(jsonb_build_object('evento',e.evento,'actor_perfil_id',e.actor_perfil_id,'detalle',e.detalle,'creado_en',e.creado_en) order by e.creado_en) from public.kombax_verificacion_eventos e where e.solicitud_id=s.id or (s.perfil_directo_id is not null and e.perfil_directo_id=s.perfil_directo_id)),'[]'::jsonb),
    'service',case when d.id is null then null else public.app_kombax_perfil_servicio_v071(d.id) end
  ) into v from public.kombax_solicitudes_alta s left join public.perfiles_kombax_directos d on d.id=s.perfil_directo_id where s.id=p_solicitud_id;
  if v is null then raise exception 'KOMBAX_APPLICATION_NOT_FOUND'; end if; return v;
end $$;
revoke all on function public.app_kombax_platform_application_v072(uuid) from public,anon;
grant execute on function public.app_kombax_platform_application_v072(uuid) to authenticated;

create or replace function public.app_kombax_platform_dashboard_v072()
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  v:=public.app_kombax_platform_dashboard_v055();
  v:=jsonb_set(v,'{counts,verified_members_removed}',to_jsonb((select count(*) from public.kombax_social_perfiles where sujeto_tipo='miembro' and verificado)),true);
  v:=jsonb_set(v,'{counts,official_verified_profiles}',to_jsonb((select count(*) from public.kombax_social_perfiles where verificado and public.app_kombax_badge_tipo_v069(id) is not null)),true);
  v:=jsonb_set(v,'{pending_verifications}',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'tipo',a.tipo,'nombre_publico',a.nombre_publico,'estado',a.estado,'perfil_directo_id',a.perfil_directo_id,'declaracion_aceptada',a.declaracion_aceptada,'creado_en',a.creado_en,'actualizado_en',a.actualizado_en) order by a.actualizado_en desc) from public.kombax_solicitudes_alta a where a.estado in ('submitted','under_review','needs_information')),'[]'::jsonb),true);
  return v;
end $$;
revoke all on function public.app_kombax_platform_dashboard_v072() from public,anon;
grant execute on function public.app_kombax_platform_dashboard_v072() to authenticated;

create or replace function public.app_kombax_platform_profiles_v072(p_query text default '',p_limit integer default 100)
returns table(id uuid,nombre_publico text,tipo text,estado text,verificado boolean,badge_type text,club_id uuid,club_nombre text,servicio_estado text,plan_codigo text,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_query text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
  return query select sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.estado,sp.verificado,public.app_kombax_badge_tipo_v069(sp.id),sp.club_id,c.nombre,
    coalesce(s.estado,'inactiva'),s.modalidad,sp.actualizado_en
  from public.kombax_social_perfiles sp left join public.clubes c on c.id=sp.club_id left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join lateral(select x.estado,x.modalidad from public.kombax_suscripciones x where x.sujeto_tipo='perfil_directo' and x.sujeto_id=d.id order by x.actualizado_en desc limit 1)s on true
  where v_query='' or lower(coalesce(sp.nombre_publico,'')||' '||coalesce(c.nombre,'')||' '||coalesce(sp.slug,'')) like '%'||v_query||'%'
  order by sp.actualizado_en desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_platform_profiles_v072(text,integer) from public,anon;
grant execute on function public.app_kombax_platform_profiles_v072(text,integer) to authenticated;

-- Hardening de gobernanza: el propietario canónico nunca puede degradarse/eliminarse mediante la API de gestores.
create or replace function public.app_kombax_profile_manager_mutate_v070(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_profile uuid;v_target uuid;v_role text;v_row public.kombax_perfil_gestores;v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_profile:=(p_payload->>'perfil_directo_id')::uuid;exception when others then raise exception 'KOMBAX_PROFILE_ID_INVALID';end;
  begin v_target:=(p_payload->>'perfil_id')::uuid;exception when others then raise exception 'KOMBAX_MANAGER_ID_INVALID';end;
  if not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'admin') and not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_PROFILE_ADMIN_REQUIRED';end if;
  if not exists(select 1 from public.perfiles where id=v_target) then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
  if exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.perfil_id=v_target) then raise exception 'KOMBAX_OWNER_ROLE_IMMUTABLE';end if;
  if p_operation in ('kombax.profile.manager.add','kombax.profile.manager.update') then
    v_role:=lower(btrim(coalesce(p_payload->>'rol','editor')));
    if v_role not in ('admin','editor','comunicacion') then raise exception 'KOMBAX_MANAGER_ROLE_INVALID';end if;
    insert into public.kombax_perfil_gestores(perfil_directo_id,perfil_id,rol,estado,concedido_por)
    values(v_profile,v_target,v_role,'activo',v_uid)
    on conflict(perfil_directo_id,perfil_id) do update set rol=excluded.rol,estado='activo',concedido_por=v_uid,actualizado_en=now()
    returning * into v_row;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,case when p_operation='kombax.profile.manager.add' then 'manager_added' else 'manager_updated' end,jsonb_build_object('perfil_id',v_target,'rol',v_role));
  elsif p_operation='kombax.profile.manager.remove' then
    update public.kombax_perfil_gestores set estado='revocado',actualizado_en=now()
    where perfil_directo_id=v_profile and perfil_id=v_target and rol<>'owner' returning * into v_row;
    if v_row.id is null then raise exception 'KOMBAX_MANAGER_NOT_FOUND';end if;
    insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
    values(v_profile,v_uid,'manager_removed',jsonb_build_object('perfil_id',v_target,'rol',v_row.rol));
  else raise exception 'KOMBAX_MANAGER_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('perfil_directo_id',v_profile,'perfil_id',v_target,'rol',v_row.rol,'estado',v_row.estado));
  return v_result;
end $$;
revoke all on function public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_profile_manager_mutate_v070(text,jsonb,uuid) to authenticated;

-- Contratos públicos antiguos sensibles quedan cerrados; Relaciones 068 permanece privada.
revoke execute on function public.app_kombax_social_feed_v065(timestamptz,uuid,integer) from authenticated;
revoke execute on function public.app_kombax_social_directorio_v065(text,integer) from authenticated;

notify pgrst,'reload schema';
commit;
