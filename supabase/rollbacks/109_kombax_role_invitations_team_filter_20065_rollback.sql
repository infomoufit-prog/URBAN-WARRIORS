begin;

drop function if exists public.app_kombax_solicitudes_equipo_v109(uuid);
drop function if exists public.app_kombax_equipo_solicitar_v109(text,text,text);
drop index if exists public.idx_kombax_solicitudes_equipo_pending_v109;

create or replace function public.app_kombax_club_team_v051(p_club_id uuid)
returns table(perfil_id uuid,nombre text,rol text,coordinacion boolean,permisos text[])
language plpgsql
stable
security definer
set search_path=public,auth
as $$
begin
  if auth.uid() is null or not public.app_kombax_club_permiso_v051(p_club_id,'profile.public.manage') then raise exception 'KOMBAX_CLUB_TEAM_FORBIDDEN';end if;
  return query
  select m.perfil_id,trim(concat_ws(' ',p.nombre,p.apellidos)),m.rol::text,coalesce(m.coordinacion,false),
    coalesce((select array_agg(k.permiso order by k.permiso) from public.kombax_club_team_permissions k where k.club_id=m.club_id and k.perfil_id=m.perfil_id and k.activo),array[]::text[])
  from public.miembros_club m join public.perfiles p on p.id=m.perfil_id
  where m.club_id=p_club_id and m.activo
  order by case when m.rol='direccion' then 0 when coalesce(m.coordinacion,false) then 1 else 2 end,p.nombre,p.apellidos;
end $$;
revoke all on function public.app_kombax_club_team_v051(uuid) from public,anon;
grant execute on function public.app_kombax_club_team_v051(uuid) to authenticated;

alter table public.kombax_solicitudes_equipo_club
  drop constraint if exists kombax_solicitudes_equipo_rol_solicitado_v109;
alter table public.kombax_solicitudes_equipo_club
  drop column if exists rol_solicitado;

commit;
