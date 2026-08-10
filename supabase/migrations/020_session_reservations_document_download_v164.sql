-- ============================================================================
-- URBAN WARRIORS 2.0 RC8 · SESSION RESERVATIONS + DOCUMENT DOWNLOAD · v164
-- Ejecutar DESPUÉS de 019_final_deletion_media_cleanup_v163.sql.
-- Idempotente. Mantiene backend 1.6.0 / epoch 160 / app_mutate_v160.
-- ============================================================================
begin;

-- 1) Reserva/confirmación previa de asistencia. Independiente del check-in real.
create table if not exists public.reservas_sesion (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  sesion_id uuid not null,
  socio_id uuid not null,
  estado text not null default 'confirmada' check (estado in ('confirmada','cancelada')),
  solicitada_por uuid references public.perfiles(id) on delete set null,
  confirmada_en timestamptz,
  cancelada_en timestamptz,
  actualizado_en timestamptz not null default now(),
  creado_en timestamptz not null default now(),
  foreign key (club_id, sesion_id) references public.sesiones_entrenamiento(club_id,id) on delete cascade,
  foreign key (club_id, socio_id) references public.socios(club_id,id) on delete cascade,
  unique (club_id, sesion_id, socio_id),
  unique (club_id, id)
);
create index if not exists reservas_sesion_club_sesion on public.reservas_sesion(club_id,sesion_id,estado);
create index if not exists reservas_sesion_club_socio on public.reservas_sesion(club_id,socio_id,estado,creado_en desc);

alter table public.reservas_sesion enable row level security;
drop policy if exists reservas_sesion_lectura on public.reservas_sesion;
create policy reservas_sesion_lectura on public.reservas_sesion for select to authenticated using (
  public.puede_ver_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria','monitor')
);
revoke all on public.reservas_sesion from public,anon;
grant select on public.reservas_sesion to authenticated;

-- Limpiar avisos vinculados cuando una reserva desaparece por borrado de sesión/alumno.
create or replace function public.cleanup_reserva_sesion_notificaciones()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  delete from public.notificaciones where club_id=old.club_id and datos->>'reserva_sesion_id'=old.id::text;
  return old;
end; $$;
drop trigger if exists reservas_sesion_cleanup_notifs on public.reservas_sesion;
create trigger reservas_sesion_cleanup_notifs after delete on public.reservas_sesion
for each row execute function public.cleanup_reserva_sesion_notificaciones();

-- 2) Encapsular RC7 y mantener la puerta única de mutación.
do $$
begin
  if to_regprocedure('public.app_mutate_v160_v163(text,jsonb,uuid)') is null
     and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_v163;
  end if;
end $$;
revoke all on function public.app_mutate_v160_v163(text,jsonb,uuid) from public,anon,authenticated;

-- 3) Contrato ampliado RC8. Se conserva epoch 160 para compatibilidad.
update public.app_runtime_meta set schema_epoch=160, updated_at=now() where singleton=true;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_uid uuid := auth.uid();
  v_roles jsonb;
  v_meta public.app_runtime_meta;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if not public.es_miembro_club(p_club_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED: la cuenta no pertenece al club activo'; end if;
  select * into v_meta from public.app_runtime_meta where singleton=true;
  if v_meta.singleton is null then raise exception 'BACKEND_META_MISSING'; end if;
  select coalesce(jsonb_agg(m.rol order by m.rol::text),'[]'::jsonb) into v_roles
  from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo;
  return jsonb_build_object(
    'ok',true,'backend_version',v_meta.backend_version,'schema_epoch',v_meta.schema_epoch,
    'mutation_endpoint',v_meta.mutation_endpoint,'club_id',p_club_id,'user_id',v_uid,'roles',v_roles,'write_ready',true,
    'operations',jsonb_build_array(
      'cuenta.registrar','invitacion.aceptar','invitacion.crear','perfil.guardar','disciplina.guardar','grado.guardar','grupo.guardar',
      'alumno.guardar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar',
      'matricula.solicitar','matricula.desactivar','graduacion.registrar','tarifa.guardar','material.guardar','material.variante.guardar',
      'material.solicitar','material.pedido.estado','publicacion.guardar','sesion.guardar','asistencia.guardar','checkin.registrar',
      'seguimiento.guardar','documento.registrar','notificacion.leer','pago.comunicar','pago.registrar_admin','pago.validar',
      'cuota.pausar_avisos','cuota.reactivar_avisos','avisos.configurar','cuotas.generar','avisos.procesar','club.configurar','push.registrar',
      'grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar',
      'disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular',
      'documento.actualizar','documento.archivar','documento.eliminar',
      'grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado','disciplina.eliminar_forzado','grado.eliminar_forzado',
      'tarifa.eliminar_forzado','material.eliminar_forzado','publicacion.limpiar_antiguas',
      'sesion.reserva.confirmar','sesion.reserva.cancelar'
    )
  );
end; $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- 4) Wrapper RC8: solo gobierna las reservas; todo lo demás delega en RC7 v163.
create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid := auth.uid();
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_club_id uuid;
  v_existing public.app_mutation_requests;
  v_result jsonb;
  v_reserva public.reservas_sesion;
  v_id uuid;
  v_sesion_id uuid;
  v_socio_id uuid;
  v_grupo_id uuid;
  v_fecha date;
  v_hora time;
  v_sesion_estado text;
  v_grupo_nombre text;
  v_socio_nombre text;
  v_capacity integer;
  v_reserved integer;
  v_status text;
  v_action text;
begin
  if p_operation not in ('sesion.reserva.confirmar','sesion.reserva.cancelar') then
    return public.app_mutate_v160_v163(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club_id := nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
  exception when invalid_text_representation then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club_id is null or not public.es_miembro_club(v_club_id) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club_id,p_operation);
  end if;

  v_sesion_id := nullif(v_payload->>'sesion_id','')::uuid;
  v_socio_id := nullif(v_payload->>'socio_id','')::uuid;
  if v_sesion_id is null or v_socio_id is null then raise exception 'Sesión y alumno son obligatorios'; end if;
  if not public.puede_ver_socio(v_socio_id) then raise exception 'No puedes gestionar la asistencia de este alumno'; end if;

  select s.grupo_id,s.fecha,s.hora_inicio,s.estado,g.nombre,g.plazas
    into v_grupo_id,v_fecha,v_hora,v_sesion_estado,v_grupo_nombre,v_capacity
  from public.sesiones_entrenamiento s
  join public.grupos g on g.club_id=s.club_id and g.id=s.grupo_id
  where s.club_id=v_club_id and s.id=v_sesion_id
  for update of s;
  if v_grupo_id is null then raise exception 'Sesión no encontrada'; end if;

  select trim(concat_ws(' ',nombre,apellidos)) into v_socio_nombre
  from public.socios where club_id=v_club_id and id=v_socio_id;
  if v_socio_nombre is null then raise exception 'Alumno no encontrado'; end if;

  if p_operation='sesion.reserva.confirmar' then
    if v_sesion_estado<>'programada' then raise exception 'Solo se puede confirmar asistencia en sesiones programadas'; end if;
    if not exists(
      select 1 from public.socio_disciplinas sd
      where sd.club_id=v_club_id and sd.socio_id=v_socio_id and sd.grupo_id=v_grupo_id and sd.activa
    ) then raise exception 'El alumno no tiene una matrícula activa en el grupo de esta sesión'; end if;

    select count(*) into v_reserved from public.reservas_sesion
      where club_id=v_club_id and sesion_id=v_sesion_id and estado='confirmada' and socio_id<>v_socio_id;
    if coalesce(v_capacity,0)>0 and v_reserved>=v_capacity then raise exception 'Aforo completo para esta sesión'; end if;

    insert into public.reservas_sesion(club_id,sesion_id,socio_id,estado,solicitada_por,confirmada_en,cancelada_en,actualizado_en)
    values(v_club_id,v_sesion_id,v_socio_id,'confirmada',v_uid,now(),null,now())
    on conflict (club_id,sesion_id,socio_id) do update set
      estado='confirmada',solicitada_por=excluded.solicitada_por,confirmada_en=now(),cancelada_en=null,actualizado_en=now()
    returning * into v_reserva;
    v_id:=v_reserva.id; v_status:='confirmada'; v_action:='confirmada';
  else
    update public.reservas_sesion set estado='cancelada',cancelada_en=now(),actualizado_en=now(),solicitada_por=v_uid
    where club_id=v_club_id and sesion_id=v_sesion_id and socio_id=v_socio_id
    returning * into v_reserva;
    if v_reserva.id is null then raise exception 'No existe una asistencia confirmada para cancelar'; end if;
    v_id:=v_reserva.id; v_status:='cancelada'; v_action:='cancelada';
  end if;

  -- Sustituir el aviso anterior de esta reserva por el estado vigente.
  delete from public.notificaciones where club_id=v_club_id and datos->>'reserva_sesion_id'=v_id::text;

  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  values(
    v_club_id,v_uid,'reserva-sesion-'||v_id::text,'reserva_sesion',
    case when v_status='confirmada' then 'Asistencia confirmada' else 'Asistencia cancelada' end,
    v_socio_nombre||' · '||coalesce(v_grupo_nombre,'Clase')||' · '||to_char(v_fecha,'DD/MM/YYYY')||' · '||to_char(v_hora,'HH24:MI'),
    'groups',jsonb_build_object('reserva_sesion_id',v_id,'sesion_id',v_sesion_id,'socio_id',v_socio_id,'estado',v_status),v_uid
  );

  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select v_club_id,r.rol, 'reserva-sesion-'||v_id::text||'-'||r.rol::text, 'reserva_sesion',
    case when v_status='confirmada' then 'Nueva asistencia confirmada' else 'Asistencia cancelada' end,
    v_socio_nombre||' · '||coalesce(v_grupo_nombre,'Clase')||' · '||to_char(v_fecha,'DD/MM/YYYY')||' · '||to_char(v_hora,'HH24:MI'),
    'attendance',jsonb_build_object('reserva_sesion_id',v_id,'sesion_id',v_sesion_id,'socio_id',v_socio_id,'estado',v_status),v_uid
  from (values ('direccion'::public.rol_club),('secretaria'::public.rol_club),('monitor'::public.rol_club)) r(rol);

  select count(*) into v_reserved from public.reservas_sesion where club_id=v_club_id and sesion_id=v_sesion_id and estado='confirmada';
  v_result:=jsonb_build_object('id',v_id,'sesion_id',v_sesion_id,'socio_id',v_socio_id,'estado',v_status,'confirmados',v_reserved,'aforo',v_capacity);

  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_club_id,v_uid,p_operation,'reserva_sesion',v_id::text,v_payload||jsonb_build_object('estado',v_status));

  v_result := jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',v_result);
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club_id where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end; $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- 5) Diagnóstico RC8.
create or replace function public.app_diagnostico_final_v164()
returns table(control text,estado text,detalle text)
language plpgsql security definer set search_path=public,auth
as $$
begin
  return query
    select 'tabla reservas sesión',case when to_regclass('public.reservas_sesion') is not null then 'OK' else 'FALLO' end,'confirmación previa separada del check-in' union all
    select 'gateway RC8',case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'puerta única activa' union all
    select 'RC7 encapsulado',case when to_regprocedure('public.app_mutate_v160_v163(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'operaciones anteriores preservadas' union all
    select 'RLS reservas',case when exists(select 1 from pg_policies where schemaname='public' and tablename='reservas_sesion' and policyname='reservas_sesion_lectura') then 'OK' else 'FALLO' end,'familia/alumno solo ve socios permitidos; equipo ve gestión' union all
    select 'contrato reservas',case when (public.app_runtime_contract_v160((select club_id from public.miembros_club where perfil_id=auth.uid() and activo limit 1))->'operations') ? 'sesion.reserva.confirmar' then 'OK' else 'FALLO' end,'confirmar/cancelar publicados en contrato';
end; $$;
revoke all on function public.app_diagnostico_final_v164() from public,anon;
grant execute on function public.app_diagnostico_final_v164() to authenticated;

commit;

select * from public.app_diagnostico_final_v164();
