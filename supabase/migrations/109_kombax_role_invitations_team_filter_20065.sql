-- KOMBAX RC13 build 20065
-- Invitaciones de equipo con rol solicitado + Equipo sin alumnos/familias.
-- Independiente de la migración 108 de acceso maestro: puede aplicarse antes de 108.

begin;

alter table public.kombax_solicitudes_equipo_club
  add column if not exists rol_solicitado text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='kombax_solicitudes_equipo_rol_solicitado_v109'
      and conrelid='public.kombax_solicitudes_equipo_club'::regclass
  ) then
    alter table public.kombax_solicitudes_equipo_club
      add constraint kombax_solicitudes_equipo_rol_solicitado_v109
      check (rol_solicitado is null or rol_solicitado in ('coordinacion','secretaria','economia','comunicacion','monitor'));
  end if;
end $$;

create index if not exists idx_kombax_solicitudes_equipo_pending_v109
  on public.kombax_solicitudes_equipo_club(club_id,creado_en desc)
  where estado='pendiente';

-- La invitación expresa el rol previsto, pero nunca concede permisos.
create or replace function public.app_kombax_equipo_solicitar_v109(
  p_club_slug text,
  p_codigo text,
  p_rol_solicitado text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  uid uuid:=auth.uid();
  chk jsonb;
  cid uuid;
  ver integer;
  row public.kombax_solicitudes_equipo_club;
  mail text:=lower(coalesce(auth.jwt()->>'email',''));
  requested text:=lower(trim(coalesce(p_rol_solicitado,'')));
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if requested='' then requested:=null; end if;
  if requested is not null and requested not in ('coordinacion','secretaria','economia','comunicacion','monitor') then
    raise exception 'Selecciona un rol de equipo válido';
  end if;

  chk:=public.app_kombax_codigo_validar_v060(p_club_slug,'equipo',p_codigo);
  if coalesce((chk->>'valid')::boolean,false) is not true then
    return jsonb_build_object('ok',false,'message',coalesce(chk->>'message','Código de equipo no válido.'));
  end if;

  cid:=(chk->>'club_id')::uuid;
  ver:=(chk->>'version')::integer;

  if exists(
    select 1 from public.miembros_club m
    where m.club_id=cid and m.perfil_id=uid and m.activo
      and m.rol in ('direccion','secretaria','economia','comunicacion','monitor')
  ) then
    raise exception 'Tu cuenta ya pertenece al equipo de este club';
  end if;

  insert into public.perfiles(id,nombre,apellidos)
  values(
    uid,
    coalesce(nullif(auth.jwt()->'user_metadata'->>'nombre',''),split_part(mail,'@',1)),
    coalesce(auth.jwt()->'user_metadata'->>'apellidos','')
  )
  on conflict(id) do nothing;

  insert into public.kombax_solicitudes_equipo_club(
    club_id,perfil_id,email,estado,codigo_version,creado_en,actualizado_en,
    revisado_en,revisado_por,rol_asignado,coordinacion,nota_revision,rol_solicitado
  )
  values(
    cid,uid,mail,'pendiente',ver,now(),now(),null,null,null,false,null,requested
  )
  on conflict(club_id,perfil_id) do update set
    email=excluded.email,
    estado='pendiente',
    codigo_version=excluded.codigo_version,
    actualizado_en=now(),
    revisado_en=null,
    revisado_por=null,
    rol_asignado=null,
    coordinacion=false,
    nota_revision=null,
    rol_solicitado=excluded.rol_solicitado
  returning * into row;

  return jsonb_build_object(
    'ok',true,
    'id',row.id,
    'club_id',row.club_id,
    'club_slug',chk->>'club_slug',
    'club_nombre',chk->>'club_nombre',
    'estado',row.estado,
    'rol_solicitado',row.rol_solicitado,
    'creado_en',row.creado_en
  );
end $$;
revoke all on function public.app_kombax_equipo_solicitar_v109(text,text,text) from public,anon;
grant execute on function public.app_kombax_equipo_solicitar_v109(text,text,text) to authenticated;

create or replace function public.app_kombax_solicitudes_equipo_v109(p_club_id uuid)
returns table(
  id uuid,
  perfil_id uuid,
  email text,
  nombre text,
  apellidos text,
  estado text,
  creado_en timestamptz,
  revisado_en timestamptz,
  rol_asignado text,
  coordinacion boolean,
  rol_solicitado text
)
language sql
stable
security definer
set search_path=public,auth
as $$
  select
    s.id,s.perfil_id,s.email,p.nombre,p.apellidos,s.estado,s.creado_en,s.revisado_en,
    s.rol_asignado::text,s.coordinacion,s.rol_solicitado
  from public.kombax_solicitudes_equipo_club s
  left join public.perfiles p on p.id=s.perfil_id
  where s.club_id=p_club_id
    and public.app_puede_gestionar_perfil_club_v035(p_club_id)
  order by case s.estado when 'pendiente' then 0 else 1 end,s.creado_en desc;
$$;
revoke all on function public.app_kombax_solicitudes_equipo_v109(uuid) from public,anon;
grant execute on function public.app_kombax_solicitudes_equipo_v109(uuid) to authenticated;

-- Contrato de Equipo: nunca devuelve perfiles cuyo único rol es Alumno/Familia.
create or replace function public.app_kombax_club_team_v051(p_club_id uuid)
returns table(perfil_id uuid,nombre text,rol text,coordinacion boolean,permisos text[])
language plpgsql
stable
security definer
set search_path=public,auth
as $$
begin
  if auth.uid() is null or not public.app_kombax_club_permiso_v051(p_club_id,'profile.public.manage') then
    raise exception 'KOMBAX_CLUB_TEAM_FORBIDDEN';
  end if;
  return query
  select
    m.perfil_id,
    trim(concat_ws(' ',p.nombre,p.apellidos)),
    m.rol::text,
    coalesce(m.coordinacion,false),
    coalesce((
      select array_agg(k.permiso order by k.permiso)
      from public.kombax_club_team_permissions k
      where k.club_id=m.club_id and k.perfil_id=m.perfil_id and k.activo
    ),array[]::text[])
  from public.miembros_club m
  join public.perfiles p on p.id=m.perfil_id
  where m.club_id=p_club_id
    and m.activo
    and m.rol in ('direccion','secretaria','economia','comunicacion','monitor')
  order by case when m.rol='direccion' then 0 when coalesce(m.coordinacion,false) then 1 else 2 end,p.nombre,p.apellidos;
end $$;
revoke all on function public.app_kombax_club_team_v051(uuid) from public,anon;
grant execute on function public.app_kombax_club_team_v051(uuid) to authenticated;

commit;
