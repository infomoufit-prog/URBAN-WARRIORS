CREATE OR REPLACE FUNCTION public.app_kombax_social_sync_club_public_v051()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_active boolean;
begin
  select coalesce(c.activo,false) into v_active from public.clubes c where c.id=new.club_id;
  update public.kombax_social_perfiles set
    slug=new.slug,nombre_publico=new.nombre_publico,bio=new.descripcion,
    avatar_url=new.logo_url,banner_url=new.portada_url,
    visible=v_active and not new.moderacion_oculta,
    publicar_habilitado=v_active and not new.moderacion_oculta,
    estado=case when v_active and not new.moderacion_oculta then 'activo' else 'limitado' end,
    actualizado_en=now()
  where sujeto_tipo='club' and club_id=new.club_id;
  return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_social_sync_directo_v041()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Basic public visibility is free and does not imply verification or feed publishing.
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
end $function$
;
