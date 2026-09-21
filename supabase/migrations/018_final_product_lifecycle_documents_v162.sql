-- ==========================================================================
-- URBAN WARRIORS 2.0 FINAL · PRODUCT LIFECYCLE + DOCUMENT ARCHIVE · revision v162 · epoch 160
-- Ejecutar DESPUÉS de 017_persistence_recovery_v161.sql.
-- Idempotente. Mantiene backend 1.6.0 y app_mutate_v160 como puerta única.
-- ==========================================================================
begin;

-- 1) Metadatos de expediente documental.
alter table public.documentos_socios add column if not exists estado text not null default 'vigente';
alter table public.documentos_socios add column if not exists fecha_documento date;
alter table public.documentos_socios add column if not exists observaciones text;
alter table public.documentos_socios add column if not exists firmado boolean not null default false;
alter table public.documentos_socios add column if not exists archivado_en timestamptz;
alter table public.documentos_socios add column if not exists archivado_por uuid references public.perfiles(id);
alter table public.documentos_socios add column if not exists reemplazado_por uuid references public.documentos_socios(id) on delete set null;

do $$ begin
  alter table public.documentos_socios add constraint documentos_socios_estado_check check (estado in ('vigente','archivado','sustituido'));
exception when duplicate_object then null; end $$;
create index if not exists documentos_socios_club_estado on public.documentos_socios(club_id,estado,creado_en desc);

-- 2) Preservar la puerta certificada de 015 como implementación legacy.
do $$
begin
  if to_regprocedure('public.app_mutate_v160_legacy(text,jsonb,uuid)') is null
     and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_legacy;
  end if;
end $$;
revoke all on function public.app_mutate_v160_legacy(text,jsonb,uuid) from public,anon,authenticated;

-- 3) Mantener epoch 160 por compatibilidad hacia atrás con RC5 desplegada.
-- La revisión funcional es v162, pero no rompe el contrato 1.6.0/epoch 160.
update public.app_runtime_meta
set schema_epoch=160, updated_at=now()
where singleton=true;

-- 4) Contrato ampliado.
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
      'documento.actualizar','documento.archivar','documento.eliminar'
    )
  );
end; $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- 5) Puerta única: delega operaciones históricas y gobierna las nuevas.
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
  v_id uuid;
  v_dep integer := 0;
  v_path text;
  v_doc public.documentos_socios;
  v_new_ops constant text[] := array[
    'grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar',
    'disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular',
    'documento.actualizar','documento.archivar','documento.eliminar'
  ];
begin
  if not (p_operation=any(v_new_ops)) then
    return public.app_mutate_v160_legacy(p_operation,p_payload,p_request_id);
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

  case p_operation
    when 'grupo.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar grupos'; end if;
      v_id := (v_payload->>'grupo_id')::uuid;
      select (select count(*) from public.sesiones_entrenamiento where club_id=v_club_id and grupo_id=v_id)
           + (select count(*) from public.socio_disciplinas where club_id=v_club_id and grupo_id=v_id)
           + (select count(*) from public.preinscripciones where club_id=v_club_id and grupo_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar el grupo: tiene sesiones, matrículas o solicitudes relacionadas. Desactívalo.'; end if;
      delete from public.grupos where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Grupo no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'alumno.archivar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para dar de baja alumnos'; end if;
      v_id := (v_payload->>'socio_id')::uuid;
      update public.socios set estado='baja',fecha_baja=coalesce(nullif(v_payload->>'fecha_baja','')::date,current_date),motivo_baja=nullif(v_payload->>'motivo',''),actualizado_en=now()
       where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Alumno no encontrado'; end if;
      update public.socio_disciplinas set activa=false,fecha_fin=coalesce(fecha_fin,current_date) where club_id=v_club_id and socio_id=v_id and activa;
      v_result:=jsonb_build_object('id',v_id,'estado','baja');

    when 'alumno.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar alumnos'; end if;
      v_id := (v_payload->>'socio_id')::uuid;
      select (select count(*) from public.cuotas where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.asistencias where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.registros_acceso_clase where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.seguimiento where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.graduaciones where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.documentos_socios where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.material_pedidos where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.material_entregas where club_id=v_club_id and socio_id=v_id)
           + (select count(*) from public.recibos_cuota where club_id=v_club_id and socio_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar el alumno: existe histórico deportivo, financiero, documental o de material. Dale de baja.'; end if;
      delete from public.socios where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Alumno no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'preinscripcion.cancelar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para cancelar solicitudes'; end if;
      v_id := (v_payload->>'preinscripcion_id')::uuid;
      update public.preinscripciones set estado='cancelada',observaciones=coalesce(nullif(v_payload->>'motivo',''),observaciones),revisada_por=v_uid,revisada_en=now()
       where club_id=v_club_id and id=v_id and estado<>'aprobada';
      if not found then raise exception 'Solicitud no encontrada o ya aprobada'; end if;
      v_result:=jsonb_build_object('id',v_id,'estado','cancelada');

    when 'preinscripcion.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar solicitudes'; end if;
      v_id := (v_payload->>'preinscripcion_id')::uuid;
      delete from public.preinscripciones where club_id=v_club_id and id=v_id and estado in ('borrador','enviada','rechazada','cancelada');
      if not found then raise exception 'Solo se pueden eliminar solicitudes no aprobadas en estado borrador, enviada, rechazada o cancelada'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'sesion.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar sesiones'; end if;
      v_id := (v_payload->>'sesion_id')::uuid;
      select (select count(*) from public.asistencias where club_id=v_club_id and sesion_id=v_id)
           + (select count(*) from public.registros_acceso_clase where club_id=v_club_id and sesion_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar la sesión: tiene asistencia o accesos registrados. Cancélala.'; end if;
      delete from public.sesiones_entrenamiento where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Sesión no encontrada'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'disciplina.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar disciplinas'; end if;
      v_id := (v_payload->>'disciplina_id')::uuid;
      select (select count(*) from public.grados where club_id=v_club_id and disciplina_id=v_id)
           + (select count(*) from public.grupos where club_id=v_club_id and disciplina_id=v_id)
           + (select count(*) from public.socio_disciplinas where club_id=v_club_id and disciplina_id=v_id)
           + (select count(*) from public.material_catalogo where club_id=v_club_id and disciplina_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar la disciplina: tiene grados, grupos, matrículas o material. Desactívala.'; end if;
      delete from public.disciplinas where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Disciplina no encontrada'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'grado.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar grados'; end if;
      v_id := (v_payload->>'grado_id')::uuid;
      select (select count(*) from public.socio_disciplinas where club_id=v_club_id and grado_id=v_id)
           + (select count(*) from public.graduaciones where club_id=v_club_id and grado_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar el grado: está usado en matrículas o graduaciones. Desactívalo.'; end if;
      delete from public.grados where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Grado no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'tarifa.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','economia') then raise exception 'Sin permiso para eliminar tarifas'; end if;
      v_id := (v_payload->>'tarifa_id')::uuid;
      select (select count(*) from public.socios where club_id=v_club_id and tarifa_id=v_id)
           + (select count(*) from public.preinscripciones where club_id=v_club_id and tarifa_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar la tarifa: está asignada a alumnos o solicitudes. Desactívala.'; end if;
      delete from public.tarifas where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Tarifa no encontrada'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'material.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria','economia') then raise exception 'Sin permiso para eliminar material'; end if;
      v_id := (v_payload->>'material_id')::uuid;
      select (select count(*) from public.material_pedidos where club_id=v_club_id and material_id=v_id)
           + (select count(*) from public.material_entregas where club_id=v_club_id and material_id=v_id) into v_dep;
      if v_dep>0 then raise exception 'No se puede eliminar el artículo: tiene pedidos o entregas. Desactívalo.'; end if;
      delete from public.material_catalogo where club_id=v_club_id and id=v_id;
      if not found then raise exception 'Material no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'publicacion.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','comunicacion') then raise exception 'Sin permiso para eliminar publicaciones'; end if;
      v_id := (v_payload->>'publicacion_id')::uuid;
      delete from public.comunicaciones where club_id=v_club_id and id=v_id and estado in ('borrador','archivada');
      if not found then raise exception 'Las publicaciones publicadas/programadas se archivan antes de poder eliminarlas'; end if;
      v_result:=jsonb_build_object('id',v_id,'deleted',true);

    when 'recibo.anular' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria','economia') then raise exception 'Sin permiso para anular recibos'; end if;
      v_id := (v_payload->>'recibo_id')::uuid;
      if nullif(trim(coalesce(v_payload->>'motivo','')),'') is null then raise exception 'Indica el motivo de anulación'; end if;
      update public.recibos_cuota set anulado_en=coalesce(anulado_en,now()),motivo_anulacion=coalesce(motivo_anulacion,v_payload->>'motivo')
       where club_id=v_club_id and id=v_id returning id into v_id;
      if v_id is null then raise exception 'Recibo no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'anulado',true);

    when 'documento.actualizar' then
      v_id := (v_payload->>'documento_id')::uuid;
      select * into v_doc from public.documentos_socios where club_id=v_club_id and id=v_id;
      if v_doc.id is null then raise exception 'Documento no encontrado'; end if;
      if not (public.tiene_rol_club(v_club_id,'direccion','secretaria') or (v_doc.subido_por=v_uid and public.puede_ver_socio(v_doc.socio_id))) then raise exception 'Sin permiso para actualizar el documento'; end if;
      update public.documentos_socios d set
        nombre=case when v_payload ? 'nombre' then coalesce(nullif(v_payload->>'nombre',''),d.nombre) else d.nombre end,
        tipo=case when v_payload ? 'tipo' then coalesce(nullif(v_payload->>'tipo',''),'otro') else d.tipo end,
        fecha_documento=case when v_payload ? 'fecha_documento' then nullif(v_payload->>'fecha_documento','')::date else d.fecha_documento end,
        observaciones=case when v_payload ? 'observaciones' then nullif(v_payload->>'observaciones','') else d.observaciones end,
        firmado=case when v_payload ? 'firmado' then coalesce((v_payload->>'firmado')::boolean,false) else d.firmado end,
        visible_familia=case when v_payload ? 'visible_familia' then coalesce((v_payload->>'visible_familia')::boolean,true) else d.visible_familia end
      where d.club_id=v_club_id and d.id=v_id
      returning to_jsonb(d) into v_result;

    when 'documento.archivar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para archivar documentos'; end if;
      v_id := (v_payload->>'documento_id')::uuid;
      update public.documentos_socios set
        estado=case when coalesce(v_payload->>'estado','archivado')='sustituido' then 'sustituido' else 'archivado' end,
        archivado_en=now(),archivado_por=v_uid,
        reemplazado_por=nullif(v_payload->>'reemplazado_por','')::uuid
      where club_id=v_club_id and id=v_id returning storage_path into v_path;
      if v_path is null then raise exception 'Documento no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'storage_path',v_path,'estado',coalesce(v_payload->>'estado','archivado'));

    when 'documento.eliminar' then
      if not public.tiene_rol_club(v_club_id,'direccion','secretaria') then raise exception 'Sin permiso para eliminar documentos'; end if;
      v_id := (v_payload->>'documento_id')::uuid;
      delete from public.documentos_socios where club_id=v_club_id and id=v_id returning storage_path into v_path;
      if v_path is null then raise exception 'Documento no encontrado'; end if;
      v_result:=jsonb_build_object('id',v_id,'storage_path',v_path,'deleted',true);
  end case;

  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_club_id,v_uid,p_operation,split_part(p_operation,'.',1),coalesce(v_id::text,''),v_payload);

  v_result := jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club_id where request_id=p_request_id;
  return v_result;
exception when others then
  -- No dejar una idempotency-key incompleta si la operación falla.
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end; $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- 6) Diagnóstico final del producto.
create or replace function public.app_diagnostico_final_v162()
returns table(control text,estado text,detalle text)
language plpgsql security definer set search_path=public,auth,storage
as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return query
    select 'contrato epoch 160 + revisión v162',case when (select schema_epoch from public.app_runtime_meta where singleton)=160 then 'OK' else 'FALLO' end,'app_mutate_v160 ampliado sin romper RC5' union all
    select 'archivo documental',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='documentos_socios' and column_name='estado') then 'OK' else 'FALLO' end,'metadatos de expediente' union all
    select 'bucket documentos',case when exists(select 1 from storage.buckets where id='member-documents') then 'OK' else 'FALLO' end,'privado' union all
    select 'bucket multimedia',case when exists(select 1 from storage.buckets where id='club-public-media') then 'OK' else 'FALLO' end,'público' union all
    select 'recibos anulables',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='recibos_cuota' and column_name='anulado_en') then 'OK' else 'FALLO' end,'trazabilidad conservada' union all
    select 'legacy encapsulado',case when to_regprocedure('public.app_mutate_v160_legacy(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'operaciones 001-017 preservadas';
end; $$;
revoke all on function public.app_diagnostico_final_v162() from public,anon;
grant execute on function public.app_diagnostico_final_v162() to authenticated;

commit;
