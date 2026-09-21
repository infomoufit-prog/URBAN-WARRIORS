-- KOMBAX RC13 build 20077 · 140 · Owner support mode without fake memberships
-- Owner opens an audited entity session and receives temporary support authorization.

begin;

create or replace function public.app_kombax_support_entity_v140(p_tipo text,p_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select auth.uid() is not null
    and public.app_kombax_es_platform_admin_v055()
    and exists(
      select 1
      from public.kombax_platform_entity_sessions e
      join public.kombax_platform_admin_sessions s on s.id=e.platform_session_id
      where e.actor_perfil_id=auth.uid()
        and e.auth_session_id=nullif(auth.jwt()->>'session_id','')
        and e.entidad_tipo=lower(btrim(coalesce(p_tipo,'')))
        and e.entidad_id=p_id
        and e.terminado_en is null and e.expira_en>now()
        and s.terminado_en is null and s.expira_en>now()
    );
$$;
revoke all on function public.app_kombax_support_entity_v140(text,uuid) from public,anon;
grant execute on function public.app_kombax_support_entity_v140(text,uuid) to authenticated;

create or replace function public.app_kombax_support_club_v140(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_entity_v140('club',p_club_id);
$$;
revoke all on function public.app_kombax_support_club_v140(uuid) from public,anon;
grant execute on function public.app_kombax_support_club_v140(uuid) to authenticated;

create or replace function public.app_kombax_support_direct_profile_v140(p_perfil_directo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.perfiles_kombax_directos d
    where d.id=p_perfil_directo_id
      and public.app_kombax_support_entity_v140(d.tipo,d.id)
  );
$$;
revoke all on function public.app_kombax_support_direct_profile_v140(uuid) from public,anon;
grant execute on function public.app_kombax_support_direct_profile_v140(uuid) to authenticated;

-- Central club guards: a support session behaves like Direction for the selected club only.
create or replace function public.es_miembro_club(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo);
$$;

create or replace function public.tiene_rol_club(p_club_id uuid, variadic p_roles public.rol_club[])
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol=any(p_roles));
$$;

create or replace function public.app_puede_gestionar_perfil_club_v035(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol='direccion' or coalesce(m.coordinacion,false)));
$$;

create or replace function public.app_puede_gestionar_ciclo_v038(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria') or coalesce(m.coordinacion,false)));
$$;

create or replace function public.app_puede_gestionar_eventos_v033(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','monitor') or coalesce(m.coordinacion,false)));
$$;

create or replace function public.app_puede_publicar_branding_v039(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol='direccion' or coalesce(m.coordinacion,false)));
$$;

create or replace function public.app_puede_moderar_comunidad_v036(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)));
$$;

-- Direct professional identities: Owner support session receives admin/edit/social scopes only for target.
create or replace function public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id uuid,p_scope text default 'read')
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    public.app_kombax_support_direct_profile_v140(p_perfil_directo_id)
    or exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=p_perfil_directo_id and (
        d.perfil_id=auth.uid()
        or exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'
          and case lower(coalesce(p_scope,'read')) when 'admin' then g.rol in ('owner','admin') when 'edit' then g.rol in ('owner','admin','editor') when 'social' then g.rol in ('owner','admin','editor','comunicacion') else true end)
      )
    )
  );
$$;

-- A support target appears in the normal professional-profile management hub without becoming its owner/manager.
create or replace function public.app_kombax_mis_perfiles_v072()
returns table(id uuid,tipo text,slug text,nombre_publico text,descripcion text,workflow_estado text,verificacion_estado text,publico boolean,ubicacion text,disciplinas text[],categoria text,club_declarado text,web_publica text,avatar_path text,banner_path text,origen_identidad_social_id uuid,manager_role text,servicio_estado text,plan_codigo text,social_profile_id uuid,actualizado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select d.id,d.tipo,d.slug,d.nombre_publico,d.descripcion,d.workflow_estado,d.verificacion_estado,d.publico,d.ubicacion,d.disciplinas,d.categoria,d.club_declarado,d.web_publica,d.avatar_path,d.banner_path,
    d.origen_identidad_social_id,
    case when public.app_kombax_support_direct_profile_v140(d.id) then 'owner_support' when d.perfil_id=auth.uid() then 'owner' else g.rol end,
    coalesce(s.estado,'inactiva'),s.modalidad,(select sp.id from public.kombax_social_perfiles sp where sp.perfil_directo_id=d.id limit 1),d.actualizado_en
  from public.perfiles_kombax_directos d
  left join public.kombax_perfil_gestores g on g.perfil_directo_id=d.id and g.perfil_id=auth.uid() and g.estado='activo'
  left join lateral(select x.estado,x.modalidad from public.kombax_suscripciones x where x.sujeto_tipo='perfil_directo' and x.sujeto_id=d.id order by x.actualizado_en desc limit 1)s on true
  where d.perfil_id=auth.uid() or g.id is not null or public.app_kombax_support_direct_profile_v140(d.id)
  order by case when public.app_kombax_support_direct_profile_v140(d.id) then 0 else 1 end,d.creado_en;
$$;

-- Showcase club management needs to honour the support context instead of inserting Owner into the club team.
create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_marcas m where m.id=p_provider_id and m.sujeto_tipo='club' and public.app_kombax_support_club_v140(m.club_id))
    or exists(select 1 from public.kombax_showcase_marcas m where m.id=p_provider_id and m.perfil_directo_id is not null and public.app_kombax_support_direct_profile_v140(m.perfil_directo_id))
    or exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_provider_id and g.perfil_id=auth.uid() and g.activo)
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_provider_id and m.sujeto_tipo='marca' and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado')
    or exists(select 1 from public.kombax_showcase_marcas m join public.miembros_club mc on mc.club_id=m.club_id where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false)));
$$;

create or replace function public.app_kombax_showcase_ensure_club_v045(p_club_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;v_club public.clubes;v_pc public.perfiles_club_publicos;
begin
  if auth.uid() is null or not (
    public.app_kombax_support_club_v140(p_club_id)
    or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)))
  ) then raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';end if;
  select id into v_id from public.kombax_showcase_marcas where sujeto_tipo='club' and club_id=p_club_id;if v_id is not null then return v_id;end if;
  select * into v_club from public.clubes where id=p_club_id and activo;if v_club.id is null then raise exception 'SHOWCASE_CLUB_NOT_FOUND';end if;
  select * into v_pc from public.perfiles_club_publicos where club_id=p_club_id;
  insert into public.kombax_showcase_marcas(sujeto_tipo,club_id,slug,nombre,descripcion,logo_url,banner_url,web_url,verificada,estado,creada_por)
  values('club',p_club_id,'club-'||v_club.slug,coalesce(nullif(v_pc.nombre_publico,''),v_club.nombre),coalesce(v_pc.descripcion,v_club.lema),coalesce(v_pc.logo_url,v_club.logo_url),coalesce(v_pc.portada_url,v_club.portada_url),v_pc.web_publica,true,'publicada',auth.uid()) returning id into v_id;
  -- Deliberately do not add Owner to kombax_showcase_gestores when access comes from support.
  if not public.app_kombax_support_club_v140(p_club_id) then
    insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_id,auth.uid(),'responsable',auth.uid()) on conflict do nothing;
  end if;
  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por) values('club',p_club_id,'showcase.publish',true,'manual',auth.uid()) on conflict do nothing;
  return v_id;
end $$;

create or replace function public.app_kombax_showcase_mis_espacios_v045(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path=public,auth as $$ begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and (public.app_kombax_support_club_v140(p_club_id) or exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false)))) then perform public.app_kombax_showcase_ensure_club_v045(p_club_id);end if;
  return query select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,case m.sujeto_tipo when 'club' then 15 else 30 end,(select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v045(m.id) order by case m.sujeto_tipo when 'club' then 0 else 1 end,m.nombre;
end $$;

-- Explicit audit event when the support workspace is opened/closed from frontend.
create or replace function public.app_kombax_support_audit_v140(p_action text,p_entity_session_id uuid,p_detail jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare e public.kombax_platform_entity_sessions;begin
  select * into e from public.kombax_platform_entity_sessions where id=p_entity_session_id and actor_perfil_id=auth.uid() and auth_session_id=nullif(auth.jwt()->>'session_id','') and expira_en>now();
  if e.id is null then raise exception 'PLATFORM_ENTITY_SESSION_REQUIRED';end if;
  if p_action not in ('support.enter','support.exit') then raise exception 'SUPPORT_AUDIT_ACTION_INVALID';end if;
  insert into public.kombax_platform_privileged_audit(actor_perfil_id,auth_session_id,platform_session_id,entity_session_id,entidad_tipo,entidad_id,accion,resultado,motivo,detalle)
  values(auth.uid(),nullif(auth.jwt()->>'session_id',''),e.platform_session_id,e.id,e.entidad_tipo,e.entidad_id,'kombax.'||p_action,'success',e.motivo,coalesce(p_detail,'{}'::jsonb));
  return jsonb_build_object('ok',true,'action',p_action);
end $$;
revoke all on function public.app_kombax_support_audit_v140(text,uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_support_audit_v140(text,uuid,jsonb) to authenticated;

commit;
