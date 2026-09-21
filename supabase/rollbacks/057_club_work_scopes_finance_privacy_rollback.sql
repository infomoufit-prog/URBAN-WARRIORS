-- KOMBAX build 20030 · rollback 057
-- Solo ante incidencia confirmada. Revierte a la semántica previa 005/007/012/016/020/022.
begin;

-- 1) Restaurar gateway previo a 057.
do $rollback$
begin
  if to_regprocedure('public.app_mutate_v160_pre_work_scopes_057(text,jsonb,uuid)') is not null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
      drop function public.app_mutate_v160(text,jsonb,uuid);
    end if;
    alter function public.app_mutate_v160_pre_work_scopes_057(text,jsonb,uuid) rename to app_mutate_v160;
  end if;
end
$rollback$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- 2) Helpers históricos de alcance (005).
create or replace function public.monitor_asignado_a_grupo(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.grupos g where g.id=p_grupo_id and g.activo and g.monitor_principal_id=auth.uid() and public.tiene_rol_club(g.club_id,'monitor'));
$$;
create or replace function public.monitor_puede_ver_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socio_disciplinas sd join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id
    where sd.socio_id=p_socio_id and sd.activa and g.activo and g.monitor_principal_id=auth.uid() and public.tiene_rol_club(sd.club_id,'monitor')
  );
$$;
create or replace function public.puede_ver_grupo(p_grupo_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.grupos g where g.id=p_grupo_id and (
      public.tiene_rol_club(g.club_id,'direccion','secretaria') or public.monitor_asignado_a_grupo(g.id)
      or exists(
        select 1 from public.socio_disciplinas sd join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id
        where sd.club_id=g.club_id and sd.grupo_id=g.id and sd.activa and (
          s.perfil_id=auth.uid() or exists(select 1 from public.tutores_socios ts where ts.club_id=s.club_id and ts.socio_id=s.id and ts.tutor_perfil_id=auth.uid())
        )
      )
    )
  );
$$;
create or replace function public.puede_ver_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.socios s where s.id=p_socio_id and (
      s.perfil_id=auth.uid() or public.tiene_rol_club(s.club_id,'direccion','secretaria','economia')
      or exists(select 1 from public.tutores_socios t where t.club_id=s.club_id and t.socio_id=s.id and t.tutor_perfil_id=auth.uid())
      or public.monitor_puede_ver_socio(s.id)
    )
  );
$$;

-- 3) Políticas históricas de lectura/operativa.
drop policy if exists socios_lectura on public.socios;
create policy socios_lectura on public.socios for select using(public.puede_ver_socio(id));
drop policy if exists grupos_lectura on public.grupos;
create policy grupos_lectura on public.grupos for select using(public.es_miembro_club(club_id));
drop policy if exists horarios_lectura on public.horarios_grupo;
create policy horarios_lectura on public.horarios_grupo for select using(public.es_miembro_club(club_id));
drop policy if exists socio_disc_lectura on public.socio_disciplinas;
create policy socio_disc_lectura on public.socio_disciplinas for select using(public.puede_ver_socio(socio_id));
drop policy if exists graduaciones_lectura on public.graduaciones;
create policy graduaciones_lectura on public.graduaciones for select using(public.puede_ver_socio(socio_id));
drop policy if exists graduaciones_gestion on public.graduaciones;
create policy graduaciones_gestion on public.graduaciones for insert with check(
  public.tiene_rol_club(club_id,'direccion','secretaria') or (public.tiene_rol_club(club_id,'monitor') and public.monitor_puede_ver_socio(socio_id))
);

drop policy if exists asistencia_lectura on public.asistencias;
create policy asistencia_lectura on public.asistencias for select using(public.puede_ver_socio(socio_id));
drop policy if exists asistencia_gestion on public.asistencias;
create policy asistencia_gestion on public.asistencias for all using(
  public.tiene_rol_club(club_id,'direccion') or public.monitor_puede_ver_socio(socio_id)
) with check(
  public.tiene_rol_club(club_id,'direccion') or public.monitor_puede_ver_socio(socio_id)
);

drop policy if exists seguimiento_lectura on public.seguimiento;
create policy seguimiento_lectura on public.seguimiento for select using(
  public.tiene_rol_club(club_id,'direccion','secretaria') or public.monitor_puede_ver_socio(socio_id)
  or (visibilidad='familia' and public.puede_aportar_pago_socio(socio_id))
);
drop policy if exists seguimiento_gestion on public.seguimiento;
create policy seguimiento_gestion on public.seguimiento for all using(
  public.tiene_rol_club(club_id,'direccion') or public.monitor_puede_ver_socio(socio_id)
) with check(
  public.tiene_rol_club(club_id,'direccion') or public.monitor_puede_ver_socio(socio_id)
);

drop policy if exists accesos_lectura on public.registros_acceso_clase;
create policy accesos_lectura on public.registros_acceso_clase for select using(
  public.puede_aportar_pago_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria')
  or exists(select 1 from public.sesiones_entrenamiento se where se.club_id=registros_acceso_clase.club_id and se.id=registros_acceso_clase.sesion_id and public.monitor_asignado_a_grupo(se.grupo_id))
);
drop policy if exists accesos_gestion_equipo on public.registros_acceso_clase;
create policy accesos_gestion_equipo on public.registros_acceso_clase for all using(
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or exists(select 1 from public.sesiones_entrenamiento se where se.club_id=registros_acceso_clase.club_id and se.id=registros_acceso_clase.sesion_id and public.monitor_asignado_a_grupo(se.grupo_id))
) with check(
  public.tiene_rol_club(club_id,'direccion','secretaria')
  or exists(select 1 from public.sesiones_entrenamiento se where se.club_id=registros_acceso_clase.club_id and se.id=registros_acceso_clase.sesion_id and public.monitor_asignado_a_grupo(se.grupo_id))
);

drop policy if exists reservas_sesion_lectura on public.reservas_sesion;
create policy reservas_sesion_lectura on public.reservas_sesion for select to authenticated using(
  public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria','monitor')
);
drop policy if exists series_sesiones_lectura_rc10 on public.series_sesiones;
create policy series_sesiones_lectura_rc10 on public.series_sesiones for select to authenticated using(public.es_miembro_club(club_id));

-- 4) Privacidad documental/recibos previa.
drop policy if exists documentos_socios_lectura on public.documentos_socios;
create policy documentos_socios_lectura on public.documentos_socios for select to authenticated using(
  public.tiene_rol_club(club_id,'direccion','secretaria') or (visible_familia and public.puede_ver_socio(socio_id))
);
drop policy if exists documentos_socios_insertar on public.documentos_socios;
create policy documentos_socios_insertar on public.documentos_socios for insert to authenticated with check(
  public.tiene_rol_club(club_id,'direccion','secretaria') or public.puede_ver_socio(socio_id)
);
drop policy if exists recibos_cuota_lectura on public.recibos_cuota;
create policy recibos_cuota_lectura on public.recibos_cuota for select using(
  public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','economia','secretaria')
);
drop policy if exists member_documents_read on storage.objects;
create policy member_documents_read on storage.objects for select to authenticated using(
  bucket_id='member-documents' and array_length(storage.foldername(name),1)>=2 and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_ver_socio(((storage.foldername(name))[2])::uuid)
  )
);
drop policy if exists member_documents_insert on storage.objects;
create policy member_documents_insert on storage.objects for insert to authenticated with check(
  bucket_id='member-documents' and array_length(storage.foldername(name),1)>=2 and (
    public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria')
    or public.puede_ver_socio(((storage.foldername(name))[2])::uuid)
  )
);

-- 5) Restaurar mutaciones previas (012 / 022).
create or replace function public.app_guardar_asistencia(p_sesion_id uuid,p_socio_id uuid,p_estado public.estado_asistencia,p_observacion text default null)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_id uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if not (public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria') or public.monitor_asignado_a_grupo(v_sesion.grupo_id)) then raise exception 'No tienes permiso para pasar asistencia'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then raise exception 'El alumno no está matriculado en este grupo'; end if;
  select id into v_id from public.asistencias where club_id=v_sesion.club_id and sesion_id=p_sesion_id and socio_id=p_socio_id limit 1;
  if v_id is null then
    insert into public.asistencias(club_id,sesion_id,socio_id,estado,observacion,registrado_por) values(v_sesion.club_id,p_sesion_id,p_socio_id,p_estado,nullif(trim(coalesce(p_observacion,'')),''),auth.uid()) returning id into v_id;
  else
    update public.asistencias set estado=p_estado,observacion=nullif(trim(coalesce(p_observacion,'')),''),registrado_por=auth.uid(),registrado_en=now() where id=v_id;
  end if;
  return v_id;
end; $$;

create or replace function public.app_guardar_seguimiento(p_club_id uuid,p_socio_id uuid,p_tipo text,p_nota text,p_visibilidad public.visibilidad_seguimiento,p_fecha date default current_date)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.socios where id=p_socio_id and club_id=p_club_id) then raise exception 'Alumno no encontrado'; end if;
  if not (public.tiene_rol_club(p_club_id,'direccion','secretaria') or public.monitor_puede_ver_socio(p_socio_id)) then raise exception 'No tienes permiso para registrar seguimiento'; end if;
  if nullif(trim(coalesce(p_tipo,'')),'') is null or nullif(trim(coalesce(p_nota,'')),'') is null then raise exception 'Tipo y nota son obligatorios'; end if;
  insert into public.seguimiento(club_id,socio_id,tipo,nota,visibilidad,registrado_por,fecha)
  values(p_club_id,p_socio_id,trim(p_tipo),trim(p_nota),coalesce(p_visibilidad,'equipo'::public.visibilidad_seguimiento),auth.uid(),coalesce(p_fecha,current_date)) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.app_registrar_checkin(p_sesion_id uuid,p_socio_id uuid,p_codigo text,p_metodo text default 'codigo')
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_sesion public.sesiones_entrenamiento; v_acceso uuid;
begin
  select * into v_sesion from public.sesiones_entrenamiento where id=p_sesion_id for update;
  if v_sesion.id is null then raise exception 'Sesión no encontrada'; end if;
  if v_sesion.estado='cancelada' then raise exception 'La sesión está cancelada'; end if;
  if v_sesion.fecha<>current_date then raise exception 'El check-in solo está disponible el día de la sesión'; end if;
  if not public.puede_aportar_pago_socio(p_socio_id) and not public.tiene_rol_club(v_sesion.club_id,'direccion','secretaria','monitor') then raise exception 'No tienes acceso a este alumno'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=v_sesion.club_id and socio_id=p_socio_id and grupo_id=v_sesion.grupo_id and activa) then raise exception 'El alumno no está matriculado en este grupo'; end if;
  if nullif(v_sesion.codigo_acceso,'') is not null and upper(trim(coalesce(p_codigo,'')))<>upper(trim(v_sesion.codigo_acceso)) then raise exception 'El código de acceso no es correcto'; end if;
  if p_metodo not in ('codigo','qr','manual','nfc') then raise exception 'Método de acceso no válido'; end if;
  insert into public.registros_acceso_clase(club_id,sesion_id,socio_id,metodo,resultado,registrado_por) values(v_sesion.club_id,v_sesion.id,p_socio_id,p_metodo,'permitido',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set resultado='permitido',registrado_en=now(),registrado_por=auth.uid() returning id into v_acceso;
  insert into public.asistencias(club_id,sesion_id,socio_id,estado,registrado_por) values(v_sesion.club_id,v_sesion.id,p_socio_id,'presente',auth.uid())
  on conflict(club_id,sesion_id,socio_id) do update set estado='presente',registrado_por=auth.uid(),registrado_en=now();
  return v_acceso;
end; $$;

create or replace function public.app_registrar_graduacion(p_club_id uuid,p_socio_id uuid,p_disciplina_id uuid,p_grado_id uuid,p_fecha date,p_examinador text,p_nota text)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid; v_anterior uuid; v_perfil uuid; v_alumno text; v_grado text;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para registrar graduaciones'; end if;
  if not exists(select 1 from public.socios where club_id=p_club_id and id=p_socio_id) then raise exception 'Alumno no válido'; end if;
  if not exists(select 1 from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa) then raise exception 'El alumno no tiene matrícula activa en esa disciplina'; end if;
  if not exists(select 1 from public.grados where club_id=p_club_id and id=p_grado_id and disciplina_id=p_disciplina_id and activo) then raise exception 'El grado no pertenece a la disciplina'; end if;
  select grado_id into v_anterior from public.socio_disciplinas where club_id=p_club_id and socio_id=p_socio_id and disciplina_id=p_disciplina_id and activa order by fecha_inicio desc,id desc limit 1;
  insert into public.graduaciones(club_id,socio_id,disciplina_id,grado_id,grado_anterior_id,fecha,examinador,nota,registrado_por)
  values(p_club_id,p_socio_id,p_disciplina_id,p_grado_id,v_anterior,coalesce(p_fecha,current_date),nullif(trim(coalesce(p_examinador,'')),''),nullif(trim(coalesce(p_nota,'')),''),auth.uid()) returning id into v_id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos),g.nombre into v_perfil,v_alumno,v_grado
  from public.socios s join public.grados g on g.id=p_grado_id and g.club_id=s.club_id
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=p_socio_id and s.club_id=p_club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(p_club_id,v_perfil,'graduacion-'||v_id,'graduacion','Nuevo grado registrado',v_alumno||' ha alcanzado '||v_grado||'.','profile',jsonb_build_object('graduacion_id',v_id,'socio_id',p_socio_id,'disciplina_id',p_disciplina_id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_id;
end; $$;

create or replace function public.app_generar_sesiones_recurrentes(p_club_id uuid,p_horizonte_dias integer default 84)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare v_count integer:=0; v_s public.series_sesiones; v_d date;
begin
  if p_horizonte_dias<7 or p_horizonte_dias>180 then p_horizonte_dias:=84; end if;
  for v_s in select * from public.series_sesiones where club_id=p_club_id and activa loop
    for v_d in select gs::date from generate_series(greatest(current_date,v_s.fecha_inicio),least(current_date+p_horizonte_dias,coalesce(v_s.fecha_fin,current_date+p_horizonte_dias)),interval '1 day') gs where extract(isodow from gs)::int=any(v_s.dias_semana) loop
      insert into public.sesiones_entrenamiento(club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado,observacion_general,codigo_acceso,serie_id,sala)
      values(v_s.club_id,v_s.grupo_id,v_d,v_s.hora_inicio,v_s.hora_fin,v_s.monitor_nombre,'programada','Sesión recurrente',null,v_s.id,v_s.sala) on conflict do nothing;
      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;
  return v_count;
end; $$;

-- 6) Grants históricos de funciones restauradas.
revoke all on function public.monitor_asignado_a_grupo(uuid) from public,anon;
revoke all on function public.monitor_puede_ver_socio(uuid) from public,anon;
revoke all on function public.puede_ver_grupo(uuid) from public,anon;
grant execute on function public.monitor_asignado_a_grupo(uuid) to authenticated;
grant execute on function public.monitor_puede_ver_socio(uuid) to authenticated;
grant execute on function public.puede_ver_grupo(uuid) to authenticated;
revoke all on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) from public,anon;
grant execute on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) to authenticated;
revoke all on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) from public,anon;
grant execute on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) to authenticated;
revoke all on function public.app_registrar_checkin(uuid,uuid,text,text) from public,anon;
grant execute on function public.app_registrar_checkin(uuid,uuid,text,text) to authenticated;
revoke all on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) from public,anon;
grant execute on function public.app_registrar_graduacion(uuid,uuid,uuid,uuid,date,text,text) to authenticated;
revoke all on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon;
grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to authenticated,service_role;

-- 7) Eliminar objetos 057. Los ámbitos configurados se pierden si se ejecuta.
drop function if exists public.app_kombax_ambito_mutate_v057(text,jsonb,uuid);
drop function if exists public.app_kombax_ambitos_v057(uuid);
drop function if exists public.app_kombax_monitor_cobro_v057(uuid,numeric,date,text,text,text);
drop function if exists public.app_kombax_mi_cartera_v057(uuid);
drop function if exists public.app_kombax_mi_progreso_v057(uuid);
drop function if exists public.app_kombax_mis_alumnos_v057(uuid);
drop function if exists public.app_kombax_mi_ambito_v057(uuid);
drop function if exists public.app_kombax_finance_level_socio_v057(uuid);
drop function if exists public.app_kombax_monitor_puede_seguimiento_v057(uuid);
drop function if exists public.app_kombax_monitor_puede_asistencia_registro_v057(uuid,uuid);
drop function if exists public.app_kombax_monitor_puede_asistencia_socio_v057(uuid);
drop function if exists public.app_kombax_monitor_puede_asistencia_v057(uuid);
drop function if exists public.monitor_puede_ver_socio_v057(uuid);
drop function if exists public.monitor_asignado_a_grupo_v057(uuid);
drop function if exists public.app_kombax_es_monitor_restringido_v057(uuid);
drop function if exists public.app_kombax_puede_gestionar_ambitos_v057(uuid);
drop table if exists public.club_ambito_grupos cascade;
drop table if exists public.club_ambito_socios cascade;
drop table if exists public.club_ambito_equipo cascade;
drop table if exists public.club_ambitos_trabajo cascade;
notify pgrst,'reload schema';
commit;
