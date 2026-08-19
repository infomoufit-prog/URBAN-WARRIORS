-- KOMBAX RC13 build 20044 · 073 · kombax competitor identity continuity

begin;

-- ---------------------------------------------------------------------------
-- 2. Upgrade reversible Miembro ↔ Competidor. El ID Social nunca cambia.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_social_switch_competitor_v072(p_perfil_directo_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_d public.perfiles_kombax_directos; v_i public.identidades_sociales; v_s public.socios;
  v_member public.kombax_social_perfiles; v_direct public.kombax_social_perfiles; v_id uuid;
  v_service boolean:=false; v_official boolean:=false; v_adult boolean:=false;
begin
  select * into v_d from public.perfiles_kombax_directos where id=p_perfil_directo_id and tipo='competidor';
  if v_d.id is null then return null; end if;
  v_service:=public.app_kombax_perfil_servicio_activo_v071(v_d.id);
  v_official:=v_d.verificacion_estado='verificado' and v_d.workflow_estado in ('verified','limited') and v_d.estado='activo' and v_service and v_d.publico;
  if v_d.origen_identidad_social_id is not null then
    select * into v_i from public.identidades_sociales where id=v_d.origen_identidad_social_id;
    if v_i.id is not null then
      select * into v_s from public.socios where id=v_i.socio_origen_id and club_id=v_i.club_origen_id;
      v_adult:=v_s.fecha_nacimiento is not null and extract(year from age(current_date,v_s.fecha_nacimiento))>=18;
    end if;
  end if;
  select * into v_member from public.kombax_social_perfiles where sujeto_tipo='miembro' and identidad_social_id=v_d.origen_identidad_social_id limit 1;
  select * into v_direct from public.kombax_social_perfiles where sujeto_tipo='perfil_directo' and perfil_directo_id=v_d.id limit 1;

  if v_official then
    if v_member.id is not null and v_direct.id is not null and v_member.id<>v_direct.id then raise exception 'KOMBAX_COMPETITOR_SOCIAL_DUPLICATE'; end if;
    if v_member.id is not null then
      update public.kombax_social_perfiles set
        sujeto_tipo='perfil_directo',identidad_social_id=null,perfil_directo_id=v_d.id,
        nombre_publico=v_d.nombre_publico,bio=coalesce(v_d.descripcion,bio),avatar_path=coalesce(v_d.avatar_path,avatar_path),banner_path=coalesce(v_d.banner_path,banner_path),
        verificado=true,visible=true,publicar_habilitado=true,contacto_habilitado=v_adult,estado='activo',actualizado_en=now()
      where id=v_member.id returning id into v_id;
      insert into public.kombax_verificacion_eventos(perfil_directo_id,actor_perfil_id,evento,detalle)
      select v_d.id,v_d.perfil_id,'member_promoted',jsonb_build_object('social_id',v_id,'identity_social_id',v_d.origen_identidad_social_id)
      where not exists(select 1 from public.kombax_verificacion_eventos e where e.perfil_directo_id=v_d.id and e.evento='member_promoted');
    elsif v_direct.id is not null then
      update public.kombax_social_perfiles set nombre_publico=v_d.nombre_publico,bio=v_d.descripcion,avatar_path=v_d.avatar_path,banner_path=v_d.banner_path,
        verificado=true,visible=true,publicar_habilitado=true,contacto_habilitado=v_adult,estado='activo',actualizado_en=now() where id=v_direct.id returning id into v_id;
    else
      insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
      values('perfil_directo',v_d.id,v_d.slug,v_d.nombre_publico,v_d.descripcion,v_d.avatar_path,v_d.banner_path,true,true,true,v_adult,'activo') returning id into v_id;
    end if;
  else
    if v_d.origen_identidad_social_id is not null and v_i.id is not null then
      if v_direct.id is not null and v_member.id is not null and v_direct.id<>v_member.id then raise exception 'KOMBAX_COMPETITOR_SOCIAL_DUPLICATE'; end if;
      if v_direct.id is not null then
        update public.kombax_social_perfiles set
          sujeto_tipo='miembro',perfil_directo_id=null,identidad_social_id=v_i.id,
          slug=v_i.slug,nombre_publico=v_i.nombre_publico,verificado=false,visible=v_i.estado='activa',publicar_habilitado=v_i.estado='activa',contacto_habilitado=v_i.estado='activa' and v_adult,
          estado=case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end,actualizado_en=now()
        where id=v_direct.id returning id into v_id;
      elsif v_member.id is not null then
        update public.kombax_social_perfiles set verificado=false,visible=v_i.estado='activa',publicar_habilitado=v_i.estado='activa',contacto_habilitado=v_i.estado='activa' and v_adult,
          estado=case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end,actualizado_en=now()
        where id=v_member.id returning id into v_id;
      else
        insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
        values('miembro',v_i.id,v_i.slug,v_i.nombre_publico,false,v_i.estado='activa',v_i.estado='activa',v_i.estado='activa' and v_adult,
          case v_i.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end) returning id into v_id;
      end if;
    elsif v_direct.id is not null then
      update public.kombax_social_perfiles set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,estado='limitado',actualizado_en=now()
      where id=v_direct.id returning id into v_id;
    end if;
  end if;
  return v_id;
end $$;
revoke all on function public.app_kombax_social_switch_competitor_v072(uuid) from public,anon,authenticated;

-- Sincronizador final de Miembro: nunca recrea un duplicado mientras una identidad esté promovida.
create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_comp uuid;v_socio public.socios;v_apodo text;v_bio text;v_adulto boolean:=false;
begin
  select d.id into v_comp from public.perfiles_kombax_directos d where d.tipo='competidor' and d.origen_identidad_social_id=new.id order by d.creado_en limit 1;
  if v_comp is not null then perform public.app_kombax_social_switch_competitor_v072(v_comp); return new; end if;
  select * into v_socio from public.socios s where s.id=new.socio_origen_id and s.club_id=new.club_origen_id;
  select nullif(pd.apodo,''),nullif(pd.presentacion,'') into v_apodo,v_bio from public.perfiles_deportivos pd where pd.club_id=new.club_origen_id and pd.socio_id=new.socio_origen_id;
  v_adulto:=v_socio.fecha_nacimiento is not null and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('miembro',new.id,new.slug,coalesce(v_apodo,new.nombre_publico),v_bio,false,new.estado='activa',new.estado='activa',new.estado='activa' and v_adulto,
    case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end)
  on conflict(identidad_social_id) where sujeto_tipo='miembro' do update set slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,verificado=false,
    visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_miembro_v041() from public,anon,authenticated;

-- Sincronizador final de perfiles directos. Profesional/Espectador nunca salen como oficiales.
create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_service boolean:=false;v_badge boolean:=false;
begin
  if new.tipo='competidor' and new.origen_identidad_social_id is not null then perform public.app_kombax_social_switch_competitor_v072(new.id); return new; end if;
  v_service:=public.app_kombax_perfil_servicio_activo_v071(new.id);
  v_badge:=new.tipo in ('competidor','marca','federacion') and new.verificacion_estado='verificado' and new.workflow_estado in ('verified','limited') and new.estado='activo' and v_service;
  if new.tipo not in ('competidor','marca','federacion') then
    update public.kombax_social_perfiles set verificado=false,visible=false,publicar_habilitado=false,contacto_habilitado=false,estado='limitado',actualizado_en=now()
    where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id; return new;
  end if;
  insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,v_badge,
    new.publico and v_service and new.estado='activo',new.publico and v_service and new.estado='activo' and new.verificacion_estado='verificado',
    new.publico and v_service and new.estado='activo' and new.verificacion_estado='verificado',
    case when new.estado='activo' and v_service then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end)
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
    avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,verificado=excluded.verificado,visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
