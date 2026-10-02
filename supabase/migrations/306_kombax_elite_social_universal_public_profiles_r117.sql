-- KOMBAX R117 build 20171 · Pilot Hotfix
-- Universal basic Elite Social public profiles.
-- Public profile/network != feed publishing != Club-private membership.

create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_verified boolean:=false;
  v_visible boolean:=false;
  v_social_ready boolean:=false;
  v_badge boolean:=false;
  v_adult boolean:=false;
begin
  if new.tipo='competidor' and new.origen_identidad_social_id is not null then
    perform public.app_kombax_social_switch_competitor_v072(new.id);
    return new;
  end if;

  v_visible:=new.estado not in ('suspendido','cerrado');

  if new.tipo='espectador' then
    select exists(
      select 1 from public.kombax_perfil_persona_privada_v196 p
      where p.perfil_directo_id=new.id
        and p.fecha_nacimiento is not null
        and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18
    ) into v_adult;

    insert into public.kombax_social_perfiles(
      sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
      verificado,visible,publicar_habilitado,contacto_habilitado,estado
    ) values(
      'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,
      false,v_visible,false,v_adult,
      case when new.estado='suspendido' then 'suspendido'
           when new.estado='cerrado' then 'cerrado' else 'activo' end
    )
    on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo'
    do update set
      slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
      avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
      verificado=false,visible=excluded.visible,publicar_habilitado=false,
      contacto_habilitado=excluded.contacto_habilitado,
      estado=excluded.estado,actualizado_en=now();
    return new;
  end if;

  if new.tipo not in ('competidor','marca','federacion','profesional','media') then
    update public.kombax_social_perfiles
       set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,
           estado='limitado',actualizado_en=now()
     where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id;
    return new;
  end if;

  v_verified:=new.verificacion_estado='verificado'
    and new.workflow_estado in ('verified','limited')
    and new.estado='activo';

  v_social_ready:=v_verified and coalesce(new.social_activo,false);

  v_badge:=case
    when new.tipo='competidor' then v_verified
    when new.tipo in ('marca','federacion') then v_verified
      and public.app_kombax_subscription_paid_v102('perfil_directo',new.id)
    else false
  end;

  insert into public.kombax_social_perfiles(
    sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,
    verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,
    v_badge,v_visible,v_social_ready,v_visible,
    case
      when new.estado='suspendido' then 'suspendido'
      when new.estado='cerrado' then 'cerrado'
      else 'activo'
    end
  )
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo'
  do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
    avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,
    verificado=excluded.verificado,visible=excluded.visible,
    publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,
    estado=excluded.estado,actualizado_en=now();

  return new;
end $$;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public','auth'
as $$
  select exists(
    select 1
    from public.kombax_social_perfiles sp
    where sp.id=p_social_id
      and sp.visible
      and sp.estado='activo'
      and (
        sp.sujeto_tipo='club'
        or (
          sp.sujeto_tipo='miembro'
          and exists(
            select 1
            from public.identidades_sociales i
            left join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
            left join public.kombax_member_private_r117 priv on priv.perfil_id=i.perfil_id
            where i.id=sp.identidad_social_id
              and i.estado='activa'
              and (
                (s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18)
                or
                (priv.fecha_nacimiento is not null and extract(year from age(current_date,priv.fecha_nacimiento))>=18)
              )
          )
        )
        or (
          sp.sujeto_tipo='perfil_directo'
          and exists(
            select 1
            from public.perfiles_kombax_directos d
            left join public.kombax_perfil_persona_privada_v196 priv on priv.perfil_directo_id=d.id
            where d.id=sp.perfil_directo_id
              and d.estado not in ('suspendido','cerrado')
              and (
                d.tipo in ('marca','federacion','media')
                or
                (d.tipo='espectador'
                  and priv.fecha_nacimiento is not null
                  and public.app_kombax_profile_age_v196(priv.fecha_nacimiento)>=18)
                or
                (d.tipo='competidor'
                  and d.fecha_nacimiento_verificada is not null
                  and d.fecha_nacimiento_verificada<=current_date-interval '18 years')
                or
                (d.tipo='profesional'
                  and priv.fecha_nacimiento is not null
                  and public.app_kombax_profile_age_v196(priv.fecha_nacimiento)>=18)
              )
          )
        )
      )
  );
$$;

do $$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='app_kombax_media_mutate_v072' and p.prokind='f';

  d:=replace(
    d,
    'if not exists(' || chr(10) ||
    '      select 1 from public.perfiles_kombax_directos d' || chr(10) ||
    '      where d.id=v_profile and (' || chr(10) ||
    '        (d.tipo=''espectador'' and d.estado not in (''suspendido'',''cerrado''))' || chr(10) ||
    '        or (d.workflow_estado in (''verified'',''limited'') and d.verificacion_estado=''verificado'' and d.estado=''activo'')' || chr(10) ||
    '      )' || chr(10) ||
    '    ) then raise exception ''KOMBAX_PROFILE_VERIFIED_REQUIRED''; end if;',
    'if not exists(' || chr(10) ||
    '      select 1 from public.perfiles_kombax_directos d' || chr(10) ||
    '      where d.id=v_profile and d.estado not in (''suspendido'',''cerrado'')' || chr(10) ||
    '    ) then raise exception ''KOMBAX_PROFILE_NOT_ACTIVE''; end if;'
  );
  execute d;
end $$;

update public.perfiles_kombax_directos
set actualizado_en=now()
where tipo in ('competidor','marca','federacion','profesional','media','espectador');

notify pgrst,'reload schema';
