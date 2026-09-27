-- R101: una membresía existe aunque Social siga sin activar; Media/Creador y
-- Competidor verificado pueden llegar al centro vendedor según capacidades.
begin;

create or replace function public.app_kombax_account_type_lock_r100()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=new.perfil_id;
  v_type text:=new.tipo;
  v_member boolean;
  v_club_admin boolean;
  v_intended text;
  v_locked text;
begin
  if v_type='espectador' then return new; end if;
  select exists(select 1 from public.miembros_club m where m.perfil_id=v_uid
                and m.activo and (m.rol='direccion' or m.coordinacion)) into v_club_admin;
  select (
    exists(select 1 from public.miembros_club m where m.perfil_id=v_uid and m.activo and m.rol='alumno')
    or exists(select 1 from public.socios s where s.perfil_id=v_uid and s.estado='activo'
              and s.kombax_acceso_estado='activo')
    or exists(select 1 from public.identidades_sociales i where i.perfil_id=v_uid and i.estado='activa')
  ) into v_member;
  v_intended:=case when v_club_admin then 'club'
                   when v_member then 'miembro'
                   else v_type end;
  insert into public.kombax_account_types_r100(user_id,account_type)
  values(v_uid,v_intended) on conflict(user_id) do nothing;
  select account_type into v_locked from public.kombax_account_types_r100
  where user_id=v_uid for update;
  if v_locked<>v_type and not (v_locked='miembro' and v_type='competidor') then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_account_type_lock_r100() from public,anon,authenticated;

-- R75 mantenía el alcance multiclub pero omitía Media/Creador. Conservamos la
-- selección explícita del club y ampliamos solo el conjunto de perfiles directos.
create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(
  id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,
  contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer
)
language plpgsql security definer set search_path='' as $function$
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
    where m.id=v_id and m.sujeto_tipo='club' and m.club_id=p_club_id
      and public.app_kombax_showcase_puede_gestionar_v045(m.id);
    return;
  end if;

  for r in
    select d.id from public.perfiles_kombax_directos d
    where d.tipo in ('marca','media','federacion','competidor','profesional')
      and d.estado='activo' and d.verificacion_estado='verificado'
      and d.workflow_estado in ('verified','limited')
      and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')
      and (d.tipo='profesional' or public.app_kombax_perfil_servicio_activo_v071(d.id))
  loop
    begin
      v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id);
    exception when sqlstate 'P0001' then
      if sqlerrm not in ('SHOWCASE_PLAN_CAPABILITY_REQUIRED','SHOWCASE_ACTIVE_SERVICE_REQUIRED') then raise; end if;
    end;
  end loop;

  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    nullif(kombax_commercial.provider_showcase_capacity_r72(m.id)->>'total_limit','')::integer,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m
  where m.sujeto_tipo in ('marca','media','federacion','competidor','profesional')
    and public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'federacion' then 1 when 'marca' then 2 when 'media' then 3 when 'competidor' then 4 else 5 end,m.nombre;
end
$function$;
revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

commit;
notify pgrst,'reload schema';
