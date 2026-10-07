-- FIX18: shared conversations, identity-scoped history; existing AI quotas and import guards remain.
CREATE OR REPLACE FUNCTION kombax_ai_ops.org_assist_access_allowed(p_uid uuid, p_tenant_ref text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_ref text:=btrim(coalesce(p_tenant_ref,'')); v_id uuid; v_type text;
begin
  if p_uid is null or v_ref='' then return false; end if;
  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then return false; end;
    return exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo and mc.rol::text in ('direccion','coordinacion','secretaria','economia'));
  end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;
    select lower(d.tipo) into v_type from public.perfiles_kombax_directos d where d.id=v_id and d.estado not in ('suspendido','cerrado');
    if not found or v_type not in ('federacion','marca','profesional','competidor') then return false; end if;
    if exists(select 1 from public.perfiles_kombax_directos d where d.id=v_id and d.perfil_id=p_uid and d.estado not in ('suspendido','cerrado')) then return true; end if;
    if exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=v_id and g.perfil_id=p_uid and g.estado='activo' and g.rol in ('owner','admin','editor')) then return true; end if;
    if v_type='federacion' and exists(select 1 from public.kombax_federation_team_v200 ft where ft.federation_profile_id=v_id and ft.perfil_id=p_uid and ft.revoked_at is null and lower(coalesce(ft.status,'')) in ('active','accepted','activo','aceptado')) then return true; end if;
    if v_type='marca' and exists(select 1 from public.kombax_showcase_marcas sm join public.kombax_showcase_gestores sg on sg.marca_id=sm.id where sm.perfil_directo_id=v_id and sg.perfil_id=p_uid and sg.activo and lower(coalesce(sm.estado,'activo')) not in ('inactivo','suspendido','eliminado')) then return true; end if;
  end if;
  return false;
end;$function$
;

CREATE OR REPLACE FUNCTION kombax_ai_ops.resolve_context(p_uid uuid, p_tenant_hint text DEFAULT NULL::text)
 RETURNS TABLE(tenant_ref text, plan text, started_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_hint,''));
  v_id uuid;
  v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;

  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      tenant_ref:='club:'||v_id::text;
      select coalesce(case kombax_commercial.effective_benefit_r97('club',v_id,now()) when 'enterprise' then 'FEDERATION' when 'premium' then 'CLUB_PREMIUM' when 'club' then 'CLUB_BASIC' end,ts.plan_override,case s.modalidad when 'enterprise' then 'FEDERATION' when 'premium' then 'CLUB_PREMIUM' when 'federacion_institucional' then 'FEDERATION' when 'competidor_premium' then 'CLUB_PREMIUM' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),
             coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now())
        into plan,started_at
      from public.clubes c
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by ks.actualizado_en desc limit 1
      ) s on true
      left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text
      where c.id=v_id;
      return next; return;
    end if;
  end if;

  -- Explicit profile hints must never fall back to another identity of the account.
  if v_ref like 'profile:%' and not kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref) then
    raise exception 'ASSIST_CONTEXT_FORBIDDEN' using errcode='42501';
  end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||v_id::text) then
      select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
        into v_direct
      from public.perfiles_kombax_directos d
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
      ) s on true
      where d.id=v_id and d.estado not in ('suspendido','cerrado') and lower(d.tipo) in ('federacion','marca','profesional','competidor');
      if found then
        tenant_ref:='profile:'||v_direct.id::text;
        select coalesce(ts.plan_override,case v_direct.modalidad when 'federacion_institucional' then 'FEDERATION' when 'marca_profesional' then 'CLUB_PREMIUM' else case when lower(v_direct.tipo)='federacion' then 'FEDERATION' when lower(v_direct.tipo)='marca' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end end),
               coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now())
          into plan,started_at
        from (values(1)) x(n)
        left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
        return next; return;
      end if;
    end if;
  end if;

  -- Backwards-compatible raw club UUID hint.
  if v_ref<>'' and v_ref not like '%:%' then
    begin v_id:=v_ref::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return;
    end if;
  end if;

  -- Prefer an accessible Federation/Brand direct profile if one exists.
  select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
    into v_direct
  from public.perfiles_kombax_directos d
  left join lateral (
    select ks.* from public.kombax_suscripciones ks
    where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
      and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
    order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
  ) s on true
  where d.estado='activo'
    and lower(d.tipo) in ('federacion','marca')
    and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||d.id::text)
  order by (lower(d.tipo)='federacion') desc,d.actualizado_en desc
  limit 1;
  if found then
    return query select * from kombax_ai_ops.resolve_context(p_uid,'profile:'||v_direct.id::text); return;
  end if;

  select mc.club_id into v_id
  from public.miembros_club mc
  where mc.perfil_id=p_uid and mc.activo
  order by (mc.rol::text='direccion') desc,mc.creado_en
  limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return; end if;

  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now()) into plan,started_at
  from public.perfiles p
  left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text
  where p.id=p_uid;
  if not found then plan:='CLUB_BASIC'; started_at:=now(); end if;
  return next;
end;
$function$
;

CREATE OR REPLACE FUNCTION kombax_ai_ops.migration_access_allowed(p_uid uuid, p_tenant_ref text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_ref text:=btrim(coalesce(p_tenant_ref,''));v_id uuid;v_type text;
begin
  if p_uid is null or v_ref='' then return false; end if;
  if v_ref like 'club:%' then return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref); end if;
  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then return false; end;
    select lower(d.tipo) into v_type from public.perfiles_kombax_directos d where d.id=v_id and d.estado not in ('suspendido','cerrado');
    if v_type not in('federacion','marca','profesional','competidor') then return false; end if;
    return kombax_ai_ops.org_assist_access_allowed(p_uid,v_ref);
  end if;
  return false;
end $function$
;

CREATE OR REPLACE FUNCTION kombax_ai_ops.assistant_identity_context_fix16(p_uid uuid, p_tenant_ref text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;v_type text;v_name text;
begin
 if p_uid is null or not kombax_ai_ops.org_assist_access_allowed(p_uid,p_tenant_ref) then raise exception 'ASSIST_CONTEXT_FORBIDDEN' using errcode='42501';end if;
 if p_tenant_ref like 'club:%' then
  v_id:=substring(p_tenant_ref from 6)::uuid;
  select nombre into strict v_name from public.clubes where id=v_id and activo;
  return jsonb_build_object('entity_type','club','entity_id',v_id,'entity_name',v_name,'scope','authorized_catalog',
    'disciplines',coalesce((select jsonb_agg(x) from(select id,nombre from public.disciplinas where club_id=v_id and activa order by nombre limit 100)x),'[]'::jsonb),
    'groups',coalesce((select jsonb_agg(x) from(select id,nombre,disciplina_id from public.grupos where club_id=v_id and activo order by nombre limit 100)x),'[]'::jsonb),
    'tariffs',coalesce((select jsonb_agg(x) from(select id,nombre,disciplina_id from public.tarifas where club_id=v_id and activa order by nombre limit 100)x),'[]'::jsonb));
 end if;
 if p_tenant_ref like 'profile:%' then
  v_id:=substring(p_tenant_ref from 9)::uuid;
  select tipo,nombre_publico into strict v_type,v_name from public.perfiles_kombax_directos where id=v_id and estado not in ('suspendido','cerrado');
  return jsonb_build_object('entity_type',v_type,'entity_id',v_id,'entity_name',v_name,'scope','authorized_identity','disciplines','[]'::jsonb,'groups','[]'::jsonb,'tariffs','[]'::jsonb);
 end if;
 raise exception 'ASSIST_ORGANIZATION_REQUIRED' using errcode='42501';
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_org_guide_access_r60(p_tenant_ref text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_ctx record;
  v_allowed boolean:=false;
  v_kind text:=null;
  v_profile_type text:=null;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_uid,p_tenant_ref);
  v_allowed:=kombax_ai_ops.migration_access_allowed(v_uid,v_ctx.tenant_ref);
  if v_allowed then
    if v_ctx.tenant_ref like 'club:%' then
      v_kind:='club';
    elsif v_ctx.tenant_ref like 'profile:%' then
      select lower(d.tipo) into v_profile_type
      from public.perfiles_kombax_directos d
      where d.id=replace(v_ctx.tenant_ref,'profile:','')::uuid and d.estado not in ('suspendido','cerrado');
      v_kind:=case when v_profile_type in('federacion','marca','profesional','competidor') then v_profile_type else null end;
    end if;
  end if;
  return jsonb_build_object(
    'allowed',v_allowed,
    'tenant_ref',v_ctx.tenant_ref,
    'organization_type',v_kind,
    'guide','KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf',
    'brand_catalog_migrations',v_kind='marca'
  );
end $function$
;

CREATE OR REPLACE FUNCTION public.app_kombax_profile_contacts_fix18(p_social_id uuid, p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, remitente_id uuid, remitente_nombre text, destinatario_id uuid, destinatario_nombre text, motivo text, estado text, creado_en timestamp with time zone, respondido_en timestamp with time zone, cerrado_en timestamp with time zone, direccion text, gestionable boolean, ultimo_mensaje text, ultimo_mensaje_en timestamp with time zone, no_leidos integer, puede_chat boolean, puede_cerrar boolean, canal text, showcase_elemento_id uuid, showcase_producto_nombre text, showcase_producto_imagen_url text, showcase_marca_nombre text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$ select c.* from public.app_kombax_contactos_v107() c where p_social_id in (c.remitente_id,c.destinatario_id) limit least(greatest(coalesce(p_limit,50),1),200); $function$
;
revoke all on function public.app_kombax_profile_contacts_fix18(uuid,integer) from public,anon;
grant execute on function public.app_kombax_profile_contacts_fix18(uuid,integer) to authenticated;

