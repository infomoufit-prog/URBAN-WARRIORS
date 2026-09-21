-- URBAN WARRIORS 1.5.2 — CORRECCIÓN DEL AUTOTEST, SIN NETLIFY
-- Ejecutar DESPUÉS de 012_operational_integrity_v152.sql.
-- Corrige exclusivamente la resolución de tipos del autotest (smallint/numeric/time/enum).
-- No modifica datos funcionales ni requiere deploy web.

create or replace function public.app_autotest_operativo_v152(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_direction uuid;
  v_tag text := 'UW-AUTOTEST-'||substr(replace(gen_random_uuid()::text,'-',''),1,10);
  v_disc uuid; v_grade uuid; v_group uuid; v_group2 uuid; v_tariff uuid; v_member uuid; v_grad uuid; v_enrollment2 uuid;
  v_session uuid; v_material uuid; v_variant uuid; v_order uuid; v_comm uuid;
  v_pre_reject uuid; v_pre_approve uuid; v_approved_member uuid;
  v_fee uuid; v_fee2 uuid; v_payment uuid; v_payment2 uuid; v_notification uuid; v_access uuid; v_doc uuid;
  v_tracking uuid; v_attendance uuid;
  v_old_sub text;
begin
  -- Preflight de firmas exactas para evitar ambigüedades de tipos en PostgreSQL.
  if to_regprocedure('public.app_guardar_disciplina(uuid,uuid,text,text,text,boolean,smallint)') is null then raise exception 'AUTOTEST: firma app_guardar_disciplina no disponible'; end if;
  if to_regprocedure('public.app_guardar_grado(uuid,uuid,uuid,text,smallint,text,smallint,boolean)') is null then raise exception 'AUTOTEST: firma app_guardar_grado no disponible'; end if;
  if to_regprocedure('public.app_guardar_grupo(uuid,uuid,uuid,text,text,text,smallint,smallint,integer,boolean,jsonb)') is null then raise exception 'AUTOTEST: firma app_guardar_grupo no disponible'; end if;
  if to_regprocedure('public.app_guardar_socio(uuid,uuid,text,text,date,text,text,text,uuid,uuid,uuid,text,uuid,text,text,text,text)') is null then raise exception 'AUTOTEST: firma app_guardar_socio no disponible'; end if;
  if to_regprocedure('public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text)') is null then raise exception 'AUTOTEST: firma app_guardar_comunicacion no disponible'; end if;
  select perfil_id into v_direction from public.miembros_club
   where club_id=p_club_id and rol='direccion' and activo order by creado_en limit 1;
  if v_direction is null then raise exception 'No existe un usuario de Dirección activo para ejecutar el autotest'; end if;
  if not exists(select 1 from storage.buckets where id='club-public-media') then raise exception 'AUTOTEST: falta bucket club-public-media'; end if;
  if not exists(select 1 from storage.buckets where id='justificantes-pago') then raise exception 'AUTOTEST: falta bucket justificantes-pago'; end if;
  if not exists(select 1 from storage.buckets where id='member-documents') then raise exception 'AUTOTEST: falta bucket member-documents'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert') then raise exception 'AUTOTEST: falta policy de subida de publicaciones'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete') then raise exception 'AUTOTEST: falta policy de borrado compensatorio de publicaciones'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios') then raise exception 'AUTOTEST: falta policy de subida de justificantes'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados') then raise exception 'AUTOTEST: falta policy de borrado compensatorio de justificantes'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert') then raise exception 'AUTOTEST: falta policy de subida de documentos'; end if;
  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete') then raise exception 'AUTOTEST: falta policy de borrado de documentos'; end if;
  v_old_sub := current_setting('request.jwt.claim.sub',true);
  perform set_config('request.jwt.claim.sub',v_direction::text,true);

  -- Catálogos y grupo/horarios.
  v_disc := public.app_guardar_disciplina(p_club_id,null::uuid,v_tag||'-DISC','Prueba temporal','#ffffff',true,999::smallint);
  v_grade := public.app_guardar_grado(p_club_id,null::uuid,v_disc,v_tag||'-GRADO',999::smallint,'#ffffff',0::smallint,true);
  v_group := public.app_guardar_grupo(p_club_id,null::uuid,v_disc,v_tag||'-GRUPO','Autotest','Sala test',16::smallint,60::smallint,20::integer,true,
    '[{"dia_semana":2,"hora_inicio":"18:00","hora_fin":"19:00"},{"dia_semana":4,"hora_inicio":"18:00","hora_fin":"19:00"}]'::jsonb);
  if (select count(*) from public.horarios_grupo where grupo_id=v_group)<>2 then raise exception 'AUTOTEST: horarios no guardados'; end if;
  v_group2 := public.app_guardar_grupo(p_club_id,null::uuid,v_disc,v_tag||'-GRUPO-2','Autotest','Sala test',16::smallint,60::smallint,20::integer,true,'[]'::jsonb);
  v_tariff := public.app_guardar_tarifa(p_club_id,null::uuid,v_tag||'-TARIFA','Prueba temporal',1::numeric,0::numeric,'mensual',true);

  -- Alumno + multigrupo + baja de una matrícula + graduación.
  v_member := public.app_guardar_socio(p_club_id,null::uuid,'Autotest','Alumno',date '2000-01-01','600000000',v_tag||'@invalid.local','',v_disc,v_group,null::uuid,'',v_tariff,'activo','','','Temporal');
  if not exists(select 1 from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and grupo_id=v_group and activa) then raise exception 'AUTOTEST: matrícula no guardada'; end if;
  perform public.app_guardar_socio(p_club_id,v_member,'Autotest','Alumno',date '2000-01-01','600000000',v_tag||'@invalid.local','',v_disc,v_group2,null::uuid,'',v_tariff,'activo','','','Temporal');
  if (select count(*) from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and activa)<>2 then raise exception 'AUTOTEST: multigrupo no conservó ambas matrículas'; end if;
  select id into v_enrollment2 from public.socio_disciplinas where socio_id=v_member and grupo_id=v_group2 and activa limit 1;
  perform public.app_desactivar_matricula(v_enrollment2);
  if exists(select 1 from public.socio_disciplinas where id=v_enrollment2 and activa) or not exists(select 1 from public.socio_disciplinas where socio_id=v_member and grupo_id=v_group and activa) then raise exception 'AUTOTEST: baja de matrícula afectó a otras matrículas'; end if;
  v_grad := public.app_registrar_graduacion(p_club_id,v_member,v_disc,v_grade,current_date,'Autotest','Temporal');
  if not exists(select 1 from public.socio_disciplinas where socio_id=v_member and disciplina_id=v_disc and grado_id=v_grade and activa) then raise exception 'AUTOTEST: graduación no aplicada'; end if;

  -- Sesión + asistencia servidor.
  v_session := public.app_guardar_sesion(p_club_id,null::uuid,v_group,current_date,'18:00'::time,'19:00'::time,'Autotest','programada','Temporal',v_tag);
  insert into public.tutores_socios(club_id,tutor_perfil_id,socio_id,parentesco,contacto_principal)
  values(p_club_id,v_direction,v_member,'Autotest',true) on conflict(club_id,tutor_perfil_id,socio_id) do nothing;
  v_access := public.app_registrar_checkin(v_session,v_member,v_tag,'codigo');
  if not exists(select 1 from public.registros_acceso_clase where id=v_access and resultado='permitido') then raise exception 'AUTOTEST: check-in no guardado'; end if;
  v_attendance := public.app_guardar_asistencia(v_session,v_member,'presente'::public.estado_asistencia,'Temporal');
  if not exists(select 1 from public.asistencias where id=v_attendance and estado='presente') then raise exception 'AUTOTEST: asistencia no guardada'; end if;

  -- Publicación inmediata y notificación.
  v_comm := public.app_guardar_comunicacion(p_club_id,null::uuid,'noticia',v_tag||'-PUBLICACION','Contenido temporal','todos','publicada',null::timestamptz,'','');
  if not exists(select 1 from public.comunicaciones where id=v_comm and estado='publicada' and notificada_en is not null) then raise exception 'AUTOTEST: publicación no guardada/notificada'; end if;

  -- Material + variante + pedido.
  v_material := public.app_guardar_material(p_club_id,null::uuid,v_disc,v_tag||'-MATERIAL','test','Temporal','',1::numeric,2::integer,false,v_tag,true);
  v_variant := public.app_guardar_variante_material(p_club_id,null::uuid,v_material,'M','',v_tag,2,true);
  v_order := public.app_solicitar_material(v_member,v_material,v_variant,1,'Temporal');
  if not exists(select 1 from public.material_pedidos where id=v_order and estado='reservado') then raise exception 'AUTOTEST: pedido de material no guardado'; end if;

  -- Seguimiento.
  v_tracking := public.app_guardar_seguimiento(p_club_id,v_member,'tecnico','Temporal','equipo'::public.visibilidad_seguimiento,current_date);
  if not exists(select 1 from public.seguimiento where id=v_tracking) then raise exception 'AUTOTEST: seguimiento no guardado'; end if;

  -- Preinscripción: rechazo y aprobación.
  v_pre_reject := public.app_crear_preinscripcion(p_club_id,'menor','Autotest','Rechazo',date '2012-01-01','Tutor Autotest',v_tag||'@invalid.local','600000001',v_disc,v_group,v_tariff,'Tutor','Temporal');
  perform public.app_rechazar_preinscripcion(v_pre_reject,'Autotest');
  if not exists(select 1 from public.preinscripciones where id=v_pre_reject and estado='rechazada') then raise exception 'AUTOTEST: rechazo no aplicado'; end if;
  v_pre_approve := public.app_crear_preinscripcion(p_club_id,'menor','Autotest','Aprobacion',date '2011-01-01','Tutor Autotest',v_tag||'@invalid.local','600000002',v_disc,v_group,v_tariff,'Tutor','Temporal');
  v_approved_member := public.app_aprobar_preinscripcion(v_pre_approve);
  if v_approved_member is null or not exists(select 1 from public.preinscripciones where id=v_pre_approve and estado='aprobada') then raise exception 'AUTOTEST: aprobación no aplicada'; end if;

  -- Cuota + pago comunicado + validación, y cobro administrativo.
  insert into public.cuotas(club_id,socio_id,tarifa_id,periodo,concepto,importe,vencimiento)
  values(p_club_id,v_member,v_tariff,date_trunc('month',current_date)::date,v_tag||'-CUOTA-USUARIO',1,current_date+7) returning id into v_fee;
  v_payment := (public.comunicar_pago_cuota(v_fee,1::numeric,current_date,'bizum',v_tag,'test/path.pdf','Temporal')).id;
  if not exists(select 1 from public.cuotas where id=v_fee and estado='pendiente_validacion' and avisos_pausados) then raise exception 'AUTOTEST: pago comunicado no pausó avisos'; end if;
  perform public.validar_pago_cuota(v_payment,'validado',null);
  if not exists(select 1 from public.cuotas where id=v_fee and estado='pagada') then raise exception 'AUTOTEST: validación de pago no actualizó cuota'; end if;
  insert into public.cuotas(club_id,socio_id,tarifa_id,periodo,concepto,importe,vencimiento)
  values(p_club_id,v_member,v_tariff,date_trunc('month',current_date)::date,v_tag||'-CUOTA-ADMIN',1,current_date+7) returning id into v_fee2;
  v_payment2 := (public.registrar_cobro_cuota(v_fee2,1::numeric,current_date,'efectivo',v_tag,'Temporal')).id;
  if not exists(select 1 from public.cuotas where id=v_fee2 and estado='pagada') then raise exception 'AUTOTEST: cobro administrativo no actualizó cuota'; end if;

  -- Notificación y lectura. Para notificaciones dirigidas directamente a un perfil,
  -- app_marcar_notificacion_leida actualiza notificaciones.leida/leida_en; la tabla
  -- notificaciones_lecturas se usa para notificaciones compartidas por rol/audiencia.
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,creada_por)
  values(p_club_id,v_direction,v_tag||'-NOTIF','sistema','Autotest','Temporal','notifications',v_direction) returning id into v_notification;
  perform public.app_marcar_notificacion_leida(v_notification);
  if not (
      exists(select 1 from public.notificaciones where id=v_notification and perfil_id=v_direction and leida=true and leida_en is not null)
      or exists(select 1 from public.notificaciones_lecturas where notificacion_id=v_notification and perfil_id=v_direction)
  ) then raise exception 'AUTOTEST: notificación no marcada como leída'; end if;

  -- Documento (solo metadato; Storage binario se comprueba con bucket/policy).
  v_doc := public.app_registrar_documento(p_club_id,v_member,v_tag||'.pdf','otro',p_club_id||'/'||v_member||'/'||v_tag||'.pdf','application/pdf',1,true);
  if not exists(select 1 from public.documentos_socios where id=v_doc) then raise exception 'AUTOTEST: documento no registrado'; end if;

  -- Limpieza explícita del caso exitoso. En caso de error, toda la llamada se revierte.
  delete from public.notificaciones_lecturas where notificacion_id=v_notification;
  delete from public.notificaciones where id=v_notification
     or clave in ('comunicacion-'||v_comm||'-todos','pedido-material-'||v_order||'-direccion','pedido-material-'||v_order||'-secretaria','pedido-material-'||v_order||'-economia')
     or clave like 'preinscripcion-'||v_pre_reject||'-%' or clave like 'preinscripcion-'||v_pre_approve||'-%'
     or clave like 'pago-pendiente-'||v_payment||'-%'
     or clave like 'pago-'||v_payment||'-%'
     or clave like 'pago-'||v_payment2||'-%'
     or clave='graduacion-'||v_grad;
  delete from public.documentos_socios where id=v_doc;
  delete from public.pagos where id in (v_payment,v_payment2);
  delete from public.cuotas where id in (v_fee,v_fee2);
  delete from public.preinscripciones where id in (v_pre_reject,v_pre_approve);
  delete from public.seguimiento where id=v_tracking;
  delete from public.material_pedidos where id=v_order;
  delete from public.material_variantes where id=v_variant;
  delete from public.material_catalogo where id=v_material;
  delete from public.asistencias where id=v_attendance;
  delete from public.registros_acceso_clase where sesion_id=v_session and socio_id=v_member;
  delete from public.sesiones_entrenamiento where id=v_session;
  delete from public.graduaciones where id=v_grad;
  delete from public.socio_disciplinas where socio_id in (v_member,v_approved_member);
  delete from public.tutores_socios where socio_id in (v_member,v_approved_member);
  delete from public.socios where id in (v_member,v_approved_member);
  delete from public.comunicaciones where id=v_comm;
  delete from public.horarios_grupo where grupo_id=v_group;
  delete from public.grupos where id in (v_group,v_group2);
  delete from public.grados where id=v_grade;
  delete from public.disciplinas where id=v_disc;
  delete from public.tarifas where id=v_tariff;

  if v_old_sub is not null then perform set_config('request.jwt.claim.sub',v_old_sub,true); end if;
  return jsonb_build_object(
    'ok',true,
    'version','1.5.2',
    'probado',jsonb_build_array('disciplina','grado','grupo','dos_horarios','alumno','matricula','multigrupo','baja_matricula','graduacion','sesion','checkin','asistencia','publicacion','notificacion_publicacion','material','variante','pedido_material','seguimiento','preinscripcion_rechazo','preinscripcion_aprobacion','cuota','pago_comunicado','validacion_pago','cobro_admin','notificacion_lectura','documento_metadato'),
    'storage',jsonb_build_object(
      'club-public-media',exists(select 1 from storage.buckets where id='club-public-media'),
      'justificantes-pago',exists(select 1 from storage.buckets where id='justificantes-pago'),
      'member-documents',exists(select 1 from storage.buckets where id='member-documents'),
      'public-media-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_insert') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='club_public_media_delete'),
      'justificantes-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_subir_propios') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='justificantes_borrar_autorizados'),
      'documentos-write-delete',exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_insert') and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='member_documents_delete')
    )
  );
end; $$;
revoke all on function public.app_autotest_operativo_v152(uuid) from public,anon,authenticated;
grant execute on function public.app_autotest_operativo_v152(uuid) to service_role,postgres;


notify pgrst, 'reload schema';
