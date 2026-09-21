-- Ejecutar tras 038 en un entorno con al menos una sesión. Todo se revierte.
begin;
do $$ declare v_uid uuid; v_club uuid; v_id uuid; v_result jsonb; v_state text;
begin
  select m.perfil_id,m.club_id into v_uid,v_club from public.miembros_club m
  where m.activo and (m.rol in ('direccion','secretaria') or coalesce(m.coordinacion,false)) order by m.creado_en limit 1;
  if v_uid is null then raise exception 'TEST_FIXTURE_REQUIRED: falta gestor de ciclo'; end if;
  select id into v_id from public.sesiones_entrenamiento where club_id=v_club order by creado_en desc limit 1;
  if v_id is null then raise exception 'TEST_FIXTURE_REQUIRED: falta sesión'; end if;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  v_result:=public.app_ciclo_accion_v038(v_club,'sesion',array[v_id],'archivar','test transaccional');
  select ciclo_estado into v_state from public.sesiones_entrenamiento where id=v_id;
  if v_state<>'archivado' or (v_result->>'actualizados')::integer<>1 then raise exception 'ARCHIVO_FALLIDO'; end if;
  perform public.app_ciclo_accion_v038(v_club,'sesion',array[v_id],'papelera','test transaccional');
  if not exists(select 1 from public.sesiones_entrenamiento where id=v_id and ciclo_estado='papelera' and restaurar_hasta>now()) then raise exception 'PAPELERA_FALLIDA'; end if;
  perform public.app_ciclo_accion_v038(v_club,'sesion',array[v_id],'restaurar','test transaccional');
  if not exists(select 1 from public.sesiones_entrenamiento where id=v_id and ciclo_estado='activo' and restaurar_hasta is null) then raise exception 'RESTAURACION_FALLIDA'; end if;
  if (select count(*) from public.contenido_ciclo_auditoria where recurso_id=v_id and motivo='test transaccional')<>3 then raise exception 'AUDITORIA_FALLIDA'; end if;
end $$;
rollback;
