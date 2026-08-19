-- KOMBAX RC13 build 20044 · 069 · política canónica de insignia verificada.
-- Solo Club, Competidor, Federación y Marca pueden mostrar insignia KOMBAX.
-- La afiliación Miembro ↔ Club permanece verificada pero NO concede insignia al Miembro.

begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
  ('profile.verified.badge','Insignia pública KOMBAX para identidad oficial validada',true)
on conflict(clave) do nothing;

create or replace function public.app_kombax_badge_tipo_v069(p_social_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when sp.sujeto_tipo='club' and sp.club_id is not null then 'club'
    when sp.sujeto_tipo='perfil_directo'
      and d.tipo in ('competidor','marca','federacion')
      and d.verificacion_estado='verificado'
      and d.workflow_estado in ('verified','limited')
      and d.estado='activo'
      then d.tipo
    else null
  end
  from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where sp.id=p_social_id;
$$;
revoke all on function public.app_kombax_badge_tipo_v069(uuid) from public,anon;
grant execute on function public.app_kombax_badge_tipo_v069(uuid) to authenticated;
comment on function public.app_kombax_badge_tipo_v069(uuid) is 'Tipo de insignia KOMBAX elegible. Miembro y Profesional nunca devuelven insignia.';

create or replace function public.app_kombax_badge_visible_v069(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.app_kombax_badge_tipo_v069(p_social_id) is not null;
$$;
revoke all on function public.app_kombax_badge_visible_v069(uuid) from public,anon;
grant execute on function public.app_kombax_badge_visible_v069(uuid) to authenticated;

-- Defensa en profundidad: ni una escritura directa ni un trigger histórico pueden convertir
-- un Miembro/Profesional en perfil con insignia.
create or replace function public.app_kombax_social_badge_guard_v069()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_type text;v_valid boolean:=false;
begin
  if new.sujeto_tipo='club' then
    v_valid:=new.club_id is not null and exists(select 1 from public.clubes c where c.id=new.club_id);
  elsif new.sujeto_tipo='perfil_directo' and new.perfil_directo_id is not null then
    select d.tipo into v_type from public.perfiles_kombax_directos d where d.id=new.perfil_directo_id;
    v_valid:=v_type in ('competidor','marca','federacion') and exists(
      select 1 from public.perfiles_kombax_directos d
      where d.id=new.perfil_directo_id and d.verificacion_estado='verificado'
        and d.workflow_estado in ('verified','limited') and d.estado='activo'
    );
  end if;
  new.verificado:=coalesce(v_valid,false);
  return new;
end $$;
revoke all on function public.app_kombax_social_badge_guard_v069() from public,anon,authenticated;
drop trigger if exists kombax_social_badge_guard_v069 on public.kombax_social_perfiles;
create trigger kombax_social_badge_guard_v069
before insert or update of sujeto_tipo,club_id,perfil_directo_id,verificado
on public.kombax_social_perfiles
for each row execute function public.app_kombax_social_badge_guard_v069();

-- Sustituye el trigger histórico que daba verificado=true a todo Miembro.
create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_socio public.socios;v_apodo text;v_bio text;v_adulto boolean:=false;
begin
  select * into v_socio from public.socios s where s.id=new.socio_origen_id and s.club_id=new.club_origen_id;
  select nullif(pd.apodo,''),nullif(pd.presentacion,'') into v_apodo,v_bio
  from public.perfiles_deportivos pd where pd.club_id=new.club_origen_id and pd.socio_id=new.socio_origen_id;
  v_adulto:=v_socio.fecha_nacimiento is not null and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  insert into public.kombax_social_perfiles(
    sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'miembro',new.id,new.slug,coalesce(v_apodo,new.nombre_publico),v_bio,false,
    new.estado='activa',new.estado='activa',new.estado='activa' and v_adulto,
    case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end
  )
  on conflict(identidad_social_id) where sujeto_tipo='miembro' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,verificado=false,
    visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_miembro_v041() from public,anon,authenticated;
drop trigger if exists identidades_sync_kombax_social_v041 on public.identidades_sociales;
create trigger identidades_sync_kombax_social_v041
after insert or update on public.identidades_sociales
for each row execute function public.app_kombax_social_sync_miembro_v041();

-- Perfil directo: la verificación técnica solo se materializa en insignia para los tres tipos oficiales directos.
create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_badge boolean;
begin
  v_badge:=new.tipo in ('competidor','marca','federacion')
    and new.verificacion_estado='verificado' and new.workflow_estado in ('verified','limited') and new.estado='activo';
  insert into public.kombax_social_perfiles(
    sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,avatar_path,banner_path,verificado,
    visible,publicar_habilitado,contacto_habilitado,estado
  ) values(
    'perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.avatar_path,new.banner_path,v_badge,
    new.publico and new.estado='activo',new.publico and new.estado='activo' and new.verificacion_estado='verificado',
    new.publico and new.estado='activo' and new.verificacion_estado='verificado',
    case when new.estado='activo' then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end
  )
  on conflict(perfil_directo_id) where sujeto_tipo='perfil_directo' do update set
    slug=excluded.slug,nombre_publico=excluded.nombre_publico,bio=excluded.bio,
    avatar_path=excluded.avatar_path,banner_path=excluded.banner_path,verificado=excluded.verificado,
    visible=excluded.visible,publicar_habilitado=excluded.publicar_habilitado,
    contacto_habilitado=excluded.contacto_habilitado,estado=excluded.estado,actualizado_en=now();
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;
drop trigger if exists directos_sync_kombax_social_v041 on public.perfiles_kombax_directos;
create trigger directos_sync_kombax_social_v041
after insert or update on public.perfiles_kombax_directos
for each row execute function public.app_kombax_social_sync_directo_v041();

-- Backfill inmediato: retira insignia de Miembros y de cualquier tipo directo no elegible.
update public.kombax_social_perfiles set verificado=false,actualizado_en=now()
where sujeto_tipo='miembro' and verificado;

update public.kombax_social_perfiles sp set
  verificado=(d.tipo in ('competidor','marca','federacion') and d.verificacion_estado='verificado'
    and d.workflow_estado in ('verified','limited') and d.estado='activo'),
  actualizado_en=now()
from public.perfiles_kombax_directos d
where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=d.id;

-- Club conserva insignia de organización oficial; no afecta la afiliación privada del Miembro.
update public.kombax_social_perfiles set verificado=true,actualizado_en=now()
where sujeto_tipo='club' and club_id is not null;

notify pgrst,'reload schema';
commit;
