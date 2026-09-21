-- KOMBAX R75 / 264 · Showcase multiclub context separation.
-- Direct architecture: public exploration never depends on private workspaces;
-- private Club Showcase is resolved only for the active club_id.
begin;

-- Historical validator 042 assumed every direct Showcase provider was a Brand.
-- Subject integrity is already enforced by showcase_provider_guard_v045, which supports
-- club / marca / federacion / competidor. Keep 042 only for HTTPS/url normalization.
create or replace function public.app_kombax_showcase_validar_marca_v042()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if not public.app_kombax_showcase_url_v042(new.logo_url)
     or not public.app_kombax_showcase_url_v042(new.banner_url)
     or not public.app_kombax_showcase_url_v042(new.web_url)
     or not public.app_kombax_showcase_url_v042(new.contacto_url) then
    raise exception 'SHOWCASE_HTTPS_URL_REQUIRED';
  end if;
  new.actualizado_en:=now();
  return new;
end
$function$;
revoke all on function public.app_kombax_showcase_validar_marca_v042() from public,anon,authenticated;

-- A club context and a direct-profile context are different workspaces.
-- p_club_id != null: return/provision ONLY that active club.
-- p_club_id == null: resolve ONLY direct profiles owned/managed by the user.
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

  if p_club_id is not null then
    if not public.app_puede_gestionar_perfil_club_v035(p_club_id) then
      raise exception 'SHOWCASE_CLUB_MANAGEMENT_REQUIRED';
    end if;

    v_plan:=kombax_commercial.active_plan_r64('club',p_club_id);
    if coalesce(v_plan,'') not in ('club','premium','enterprise','club_saas','club_pro') then
      raise exception 'SHOWCASE_PLAN_REQUIRED';
    end if;

    v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);

    return query
    select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
      nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
      (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
    from public.kombax_showcase_marcas m
    where m.id=v_id
      and m.sujeto_tipo='club'
      and m.club_id=p_club_id
      and public.app_kombax_showcase_puede_gestionar_v045(m.id);
    return;
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
  where m.sujeto_tipo in('marca','federacion','competidor')
    and public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'federacion' then 1 when 'marca' then 2 else 3 end,m.nombre;
end
$function$;

revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
