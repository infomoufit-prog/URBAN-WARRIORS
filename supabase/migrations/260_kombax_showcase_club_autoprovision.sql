-- KOMBAX R74 / 260 · Showcase club autoprovision and manager-link repair.
-- Source of truth: R73. Idempotent, reuses the unique club provider and never touches Stripe/products.
begin;

create or replace function public.app_kombax_showcase_ensure_club_v045(p_club_id uuid)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_club public.clubes;
  v_pc public.perfiles_club_publicos;
  v_plan text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_club_id is null then raise exception 'SHOWCASE_CLUB_REQUIRED'; end if;

  -- Creation/linking authority follows the canonical club-profile management gate:
  -- Dirección / Coordinación (plus authorized support mode already implemented there).
  if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then
    raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';
  end if;

  v_plan := kombax_commercial.active_plan_r64('club',p_club_id);
  -- Basic Club has catalog/Seller Center access; Commerce remains a separate entitlement.
  if coalesce(v_plan,'') not in ('club','premium','enterprise','club_saas','club_pro') then
    raise exception 'SHOWCASE_PLAN_REQUIRED';
  end if;

  select m.id into v_id
  from public.kombax_showcase_marcas m
  where m.sujeto_tipo='club' and m.club_id=p_club_id
  limit 1;

  if v_id is null then
    select * into v_club from public.clubes where id=p_club_id and activo;
    if v_club.id is null then raise exception 'SHOWCASE_CLUB_NOT_FOUND'; end if;
    select * into v_pc from public.perfiles_club_publicos where club_id=p_club_id;

    insert into public.kombax_showcase_marcas(
      sujeto_tipo,club_id,slug,nombre,descripcion,logo_url,banner_url,web_url,verificada,estado,creada_por
    ) values(
      'club',p_club_id,'club-'||v_club.slug,
      coalesce(nullif(v_pc.nombre_publico,''),v_club.nombre),coalesce(v_pc.descripcion,v_club.lema),
      coalesce(v_pc.logo_url,v_club.logo_url),coalesce(v_pc.portada_url,v_club.portada_url),v_pc.web_publica,
      true,'publicada',v_uid
    )
    on conflict (club_id) where (sujeto_tipo='club' and club_id is not null)
    do update set actualizado_en=now()
    returning id into v_id;
  end if;

  -- Crucial repair: an existing provider must still link the eligible current manager.
  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,activo,asignado_por)
  values(v_id,v_uid,'responsable',true,v_uid)
  on conflict(marca_id,perfil_id) do update
    set activo=true,
        rol=case when public.kombax_showcase_gestores.rol='responsable' then public.kombax_showcase_gestores.rol else 'responsable' end,
        asignado_por=excluded.asignado_por;

  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen,asignada_por)
  values('club',p_club_id,'showcase.publish',true,'suscripcion',v_uid)
  on conflict do nothing;

  return v_id;
end
$function$;

revoke all on function public.app_kombax_showcase_ensure_club_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_club_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(
  id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,
  contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  r record;
  v_id uuid;
  v_plan text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  if p_club_id is not null and public.app_puede_gestionar_perfil_club_v035(p_club_id) then
    v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
    if coalesce(v_plan,'') in ('club','premium','enterprise','club_saas','club_pro') then
      v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);
    end if;
  end if;

  for r in
    select d.id
    from public.perfiles_kombax_directos d
    where d.tipo in('marca','federacion','competidor')
      and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited')
      and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')
      and public.app_kombax_perfil_servicio_activo_v071(d.id)
  loop
    begin
      v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id);
    exception when sqlstate 'P0001' then
      if sqlerrm<>'SHOWCASE_PLAN_CAPABILITY_REQUIRED' then raise; end if;
    end;
  end loop;

  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m
  where public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'club' then 0 when 'federacion' then 1 when 'marca' then 2 else 3 end,m.nombre;
end
$function$;

revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

-- Backfill valid Dirección/Coordinación managers for already-existing club providers.
-- This is deliberately generic (no club-specific ID) and idempotent.
insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,activo,asignado_por)
select sm.id,mc.perfil_id,'responsable',true,mc.perfil_id
from public.kombax_showcase_marcas sm
join public.miembros_club mc on mc.club_id=sm.club_id and mc.activo
where sm.sujeto_tipo='club'
  and sm.club_id is not null
  and (mc.rol='direccion' or coalesce(mc.coordinacion,false))
  and coalesce(kombax_commercial.active_plan_r64('club',sm.club_id),'') in ('club','premium','enterprise','club_saas','club_pro')
on conflict(marca_id,perfil_id) do update
set activo=true,
    rol=case when public.kombax_showcase_gestores.rol='responsable' then public.kombax_showcase_gestores.rol else 'responsable' end;

commit;
