-- KOMBAX RC13 build 20068 · Showcase para Club, Marca, Federación y Competidor.
-- No crea perfiles ni modifica contenido: amplía capacidades, límites y autorización.
begin;

insert into public.kombax_plan_capacidades(plan_codigo,capacidad_clave) values
  ('competidor_premium','showcase.publish'),
  ('federacion_institucional','showcase.publish')
on conflict do nothing;

insert into public.kombax_plan_limites(plan_codigo,recurso,limite) values
  ('competidor_premium','showcase.items',15),
  ('federacion_institucional','showcase.items',30)
on conflict(plan_codigo,recurso) do update set limite=excluded.limite;

-- Reconciliar únicamente capacidades derivadas del plan; no cambia usuarios ni servicios.
do $$
declare r record;
begin
  for r in
    select d.id
    from public.perfiles_kombax_directos d
    join public.kombax_suscripciones s on s.sujeto_tipo='perfil_directo' and s.sujeto_id=d.id
    where d.tipo in ('competidor','federacion')
      and s.modalidad in ('competidor_premium','federacion_institucional')
      and s.estado in ('prueba','activa','pausada')
  loop
    perform public.app_kombax_reconcile_entitlements_v071(r.id,null);
  end loop;
end $$;

alter table public.kombax_showcase_marcas
  drop constraint if exists kombax_showcase_marcas_sujeto_tipo_check;
alter table public.kombax_showcase_marcas
  add constraint kombax_showcase_marcas_sujeto_tipo_check
  check(sujeto_tipo in ('marca','club','federacion','competidor'));

create or replace function public.app_kombax_showcase_provider_guard_v045()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_tipo text;
begin
  if new.sujeto_tipo='club' then
    if new.club_id is null or new.perfil_directo_id is not null then
      raise exception 'SHOWCASE_CLUB_SUBJECT_INVALID';
    end if;
  else
    select d.tipo into v_tipo from public.perfiles_kombax_directos d where d.id=new.perfil_directo_id;
    if new.perfil_directo_id is null or new.club_id is not null
      or v_tipo is null or v_tipo<>new.sujeto_tipo
      or v_tipo not in ('marca','federacion','competidor') then
      raise exception 'SHOWCASE_DIRECT_SUBJECT_INVALID';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_provider_guard_v045() from public,anon,authenticated;

create or replace function public.app_kombax_showcase_puede_gestionar_v045(p_provider_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    public.app_kombax_es_moderador_v041()
    or exists(
      select 1
      from public.kombax_showcase_marcas m
      join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id and d.tipo=m.sujeto_tipo
      join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id
        and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now()
        and (e.termina_en is null or e.termina_en>now())
      where m.id=p_provider_id and m.sujeto_tipo in ('marca','federacion','competidor')
        and d.estado='activo' and d.verificacion_estado='verificado'
        and d.workflow_estado in ('verified','limited')
        and public.app_kombax_perfil_servicio_activo_v071(d.id)
        and (
          public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')
          or exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=m.id and g.perfil_id=auth.uid() and g.activo)
        )
    )
    or exists(
      select 1 from public.kombax_showcase_marcas m
      join public.miembros_club mc on mc.club_id=m.club_id
      where m.id=p_provider_id and m.sujeto_tipo='club' and mc.perfil_id=auth.uid() and mc.activo
        and (mc.rol in ('direccion','secretaria','comunicacion') or coalesce(mc.coordinacion,false))
    )
  );
$$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v045(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v045(uuid) to authenticated;

create or replace function public.app_kombax_showcase_ensure_direct_v113(p_perfil_directo_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;v_d public.perfiles_kombax_directos;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  select * into v_d from public.perfiles_kombax_directos where id=p_perfil_directo_id;
  if v_d.id is null or v_d.tipo not in ('marca','federacion','competidor')
    or v_d.estado<>'activo' or v_d.verificacion_estado<>'verificado'
    or v_d.workflow_estado not in ('verified','limited')
    or not public.app_kombax_perfil_servicio_activo_v071(v_d.id) then
    raise exception 'SHOWCASE_VERIFIED_ACTIVE_PROFILE_REQUIRED';
  end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(v_d.id,'social')
    and not public.app_kombax_es_moderador_v041() then
    raise exception 'SHOWCASE_PROFILE_MANAGEMENT_REQUIRED';
  end if;
  if not exists(
    select 1 from public.kombax_entitlements e
    where e.sujeto_tipo='perfil_directo' and e.sujeto_id=v_d.id
      and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now()
      and (e.termina_en is null or e.termina_en>now())
  ) then raise exception 'SHOWCASE_PLAN_CAPABILITY_REQUIRED';end if;

  select id into v_id from public.kombax_showcase_marcas where perfil_directo_id=v_d.id;
  if v_id is null then
    insert into public.kombax_showcase_marcas(
      sujeto_tipo,perfil_directo_id,slug,nombre,descripcion,logo_url,banner_url,
      web_url,contacto_url,verificada,estado,creada_por
    ) values(
      v_d.tipo,v_d.id,v_d.slug,v_d.nombre_publico,v_d.descripcion,null,null,
      v_d.web_publica,v_d.web_publica,true,'publicada',auth.uid()
    ) returning id into v_id;
  else
    update public.kombax_showcase_marcas
      set sujeto_tipo=v_d.tipo,verificada=true,
          estado=case when estado='suspendida' then estado else 'publicada' end,
          actualizado_en=now()
      where id=v_id;
  end if;
  insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por)
    values(v_id,v_d.perfil_id,'responsable',auth.uid()) on conflict do nothing;
  return v_id;
end $$;
revoke all on function public.app_kombax_showcase_ensure_direct_v113(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_direct_v113(uuid) to authenticated;

-- Compatibilidad total con clientes anteriores.
create or replace function public.app_kombax_showcase_ensure_brand_v048(p_perfil_directo_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
begin
  if not exists(select 1 from public.perfiles_kombax_directos where id=p_perfil_directo_id and tipo='marca') then
    raise exception 'SHOWCASE_VERIFIED_BRAND_REQUIRED';
  end if;
  return public.app_kombax_showcase_ensure_direct_v113(p_perfil_directo_id);
end $$;
revoke all on function public.app_kombax_showcase_ensure_brand_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_brand_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path=public,auth as $$
declare r record;v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and public.app_puede_gestionar_perfil_club_v035(p_club_id) then
    v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);
  end if;
  for r in
    select d.id from public.perfiles_kombax_directos d
    where d.tipo in ('marca','federacion','competidor')
      and d.estado='activo' and d.verificacion_estado='verificado'
      and d.workflow_estado in ('verified','limited')
      and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')
      and public.app_kombax_perfil_servicio_activo_v071(d.id)
  loop
    begin
      v_id:=public.app_kombax_showcase_ensure_direct_v113(r.id);
    exception when sqlstate 'P0001' then
      if sqlerrm<>'SHOWCASE_PLAN_CAPABILITY_REQUIRED' then raise;end if;
    end;
  end loop;
  return query
  select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    case when m.sujeto_tipo='club' then 15
      else coalesce(nullif(public.app_kombax_plan_limite_v071(m.perfil_directo_id,'showcase.items'),0),case when m.sujeto_tipo='competidor' then 15 else 30 end)
    end,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m
  where public.app_kombax_showcase_puede_gestionar_v045(m.id)
  order by case m.sujeto_tipo when 'club' then 0 when 'federacion' then 1 when 'marca' then 2 else 3 end,m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_item_guard_v045()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type text;v_direct uuid;v_limit integer;v_count integer;
begin
  if jsonb_typeof(coalesce(new.galeria,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(new.galeria,'[]'::jsonb))>3 then
    raise exception 'SHOWCASE_GALLERY_MAX_3_ADDITIONAL';
  end if;
  if new.estado='publicado' and (tg_op='INSERT' or old.estado is distinct from 'publicado' or old.marca_id is distinct from new.marca_id) then
    select sujeto_tipo,perfil_directo_id into v_type,v_direct from public.kombax_showcase_marcas where id=new.marca_id;
    v_limit:=case when v_type='club' then 15
      else coalesce(nullif(public.app_kombax_plan_limite_v071(v_direct,'showcase.items'),0),case when v_type='competidor' then 15 else 30 end)
    end;
    select count(*) into v_count from public.kombax_showcase_elementos where marca_id=new.marca_id and estado='publicado' and id<>new.id;
    if v_count>=v_limit then raise exception 'SHOWCASE_VISIBLE_LIMIT_REACHED_%',v_limit;end if;
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_showcase_item_guard_v045() from public,anon,authenticated;

-- El perfil público canónico muestra Showcase para los cuatro tipos admitidos.
create or replace function public.app_kombax_perfil_publico_v094(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_sports jsonb;v_showcase jsonb;v_sp public.kombax_social_perfiles;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  v:=public.app_kombax_perfil_publico_v083(p_social_id);
  if v is null then return null;end if;
  select * into v_sp from public.kombax_social_perfiles where id=p_social_id;
  if coalesce(v->>'perfil_tipo',v->>'sujeto_tipo','')='miembro' then
    select jsonb_strip_nulls(jsonb_build_object(
      'apodo_deportivo',i.apodo_deportivo,'disciplinas_publicas',i.disciplinas_publicas,'experiencia_anos',i.experiencia_anos,
      'guardia',i.guardia,'tecnica_favorita',i.tecnica_favorita,'especialidad',i.especialidad,
      'trayectoria_declarada',i.trayectoria_declarada,'objetivos',i.objetivos
    )) into v_sports
    from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id
    where sp.id=p_social_id and sp.sujeto_tipo='miembro';
    v:=jsonb_set(v,'{sports}',coalesce(v_sports,'{}'::jsonb),true);
  end if;
  if v_sp.sujeto_tipo='club' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url) order by e.destacado desc,e.publicado_en desc),'[]'::jsonb)
    into v_showcase from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado'
    where m.sujeto_tipo='club' and m.club_id=v_sp.club_id and m.estado='publicada';
  elsif v_sp.sujeto_tipo='perfil_directo' then
    select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'nombre',e.nombre,'resumen',e.resumen,'imagen_url',e.imagen_url,'precio_orientativo',e.precio_orientativo,'moneda',e.moneda,'visitar_url',e.visitar_url,'contacto_url',e.contacto_url,'donde_encontrar_url',e.donde_encontrar_url) order by e.destacado desc,e.publicado_en desc),'[]'::jsonb)
    into v_showcase from public.kombax_showcase_marcas m join public.kombax_showcase_elementos e on e.marca_id=m.id and e.estado='publicado'
    where m.sujeto_tipo in ('marca','federacion','competidor') and m.perfil_directo_id=v_sp.perfil_directo_id and m.estado='publicada';
  end if;
  v:=jsonb_set(v,'{showcase}',coalesce(v_showcase,'[]'::jsonb),true);
  return v-'relations';
end $$;
revoke all on function public.app_kombax_perfil_publico_v094(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v094(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
