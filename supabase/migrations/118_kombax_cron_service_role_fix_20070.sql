-- KOMBAX RC13 build 20070 · compatibilidad PostgREST actual para el worker recurrente.
begin;
create or replace function public.app_generar_sesiones_recurrentes(p_club_id uuid,p_horizonte_dias integer default 84)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare
  v_count integer:=0;v_s public.series_sesiones;v_d date;v_elevated boolean;
  v_service boolean:=coalesce(auth.jwt()->>'role',current_setting('request.jwt.claim.role',true),'')='service_role';
begin
  if not v_service and (auth.uid() is null or not public.es_miembro_club(p_club_id)) then raise exception 'Sin contexto de club';end if;
  v_elevated:=v_service or public.tiene_rol_club(p_club_id,'direccion','secretaria');
  if not v_elevated and not public.tiene_rol_club(p_club_id,'monitor') then raise exception 'No tienes permiso para generar sesiones';end if;
  if p_horizonte_dias<7 or p_horizonte_dias>180 then p_horizonte_dias:=84;end if;
  for v_s in select * from public.series_sesiones where club_id=p_club_id and activa and (v_elevated or public.monitor_asignado_a_grupo_v057(grupo_id)) loop
    for v_d in select gs::date from generate_series(greatest(current_date,v_s.fecha_inicio),least(current_date+p_horizonte_dias,coalesce(v_s.fecha_fin,current_date+p_horizonte_dias)),interval '1 day') gs
      where extract(isodow from gs)::int=any(v_s.dias_semana)
    loop
      insert into public.sesiones_entrenamiento(club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado,observacion_general,codigo_acceso,serie_id,sala)
      values(v_s.club_id,v_s.grupo_id,v_d,v_s.hora_inicio,v_s.hora_fin,v_s.monitor_nombre,'programada','Sesión recurrente',null,v_s.id,v_s.sala)
      on conflict do nothing;
      if found then v_count:=v_count+1;end if;
    end loop;
  end loop;
  return v_count;
end $$;
revoke all on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon;
grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
