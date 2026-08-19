-- Emergency rollback for 20.057 Supabase consolidation.
-- WARNING: restores superseded client RPC exposure and previous RLS planner form.

grant execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) to authenticated,service_role;
grant execute on function public.app_kombax_identity_mutate_v065(text,jsonb,uuid) to authenticated,service_role;
grant execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) to authenticated,service_role;
grant execute on function public.app_kombax_social_media_v053(uuid) to authenticated,service_role;
grant execute on function public.app_kombax_perfil_publico_v083(uuid) to authenticated,service_role;

-- Restore role scope from the pre-100 snapshot.
do $$
declare r record;
begin
  for r in select * from (values
    ('asistencias','asistencia_gestion'),('asistencias','asistencia_lectura'),('auditoria','auditoria_lectura'),
    ('club_branding_history','club_branding_history_select_v039'),('comunicaciones','comunicaciones_gestion'),
    ('config_club','config_gestion'),('config_club','config_lectura'),('configuracion_avisos_cuota','config_avisos_gestion'),
    ('configuracion_avisos_cuota','config_avisos_lectura'),('consentimientos','consentimientos_insertar'),
    ('consentimientos','consentimientos_lectura'),('contenido_ciclo_auditoria','contenido_ciclo_auditoria_select_v038'),
    ('cuotas','cuotas_gestion'),('cuotas','cuotas_lectura'),('descuentos','descuentos_gestion'),('grados','grados_gestion'),
    ('grados','grados_lectura'),('graduaciones','graduaciones_gestion'),('graduaciones','graduaciones_lectura'),
    ('historial_avisos_cuota','historial_avisos_lectura'),('historial_tarifas','historial_tarifas_lectura'),
    ('horarios_grupo','horarios_gestion'),('horarios_grupo','horarios_lectura'),('horarios_grupo','horarios_publico_registro'),
    ('material_catalogo','material_gestion'),('material_catalogo','material_lectura'),('material_entregas','entregas_gestion'),
    ('material_entregas','entregas_lectura'),('material_pedidos','material_pedidos_gestion'),
    ('material_pedidos','material_pedidos_lectura'),('material_pedidos','material_pedidos_solicitar'),
    ('material_variantes','variantes_gestion'),('material_variantes','variantes_lectura'),('miembros_club','miembros_gestion'),
    ('miembros_club','miembros_lectura'),('notificaciones','notificaciones_gestion'),('notificaciones','notificaciones_marcar'),
    ('notificaciones','notificaciones_propias'),('pagos','pagos_insertar'),('pagos','pagos_lectura'),('pagos','pagos_validar'),
    ('perfiles','perfil_actualizar'),('perfiles','perfil_propio'),('preinscripciones','preinscripciones_gestion'),
    ('preinscripciones','preinscripciones_lectura'),('recibos_contadores','recibos_contadores_sin_cliente'),
    ('recibos_cuota','recibos_cuota_lectura'),('registros_acceso_clase','accesos_gestion_equipo'),
    ('registros_acceso_clase','accesos_lectura'),('seguimiento','seguimiento_gestion'),('seguimiento','seguimiento_lectura'),
    ('sesiones_entrenamiento','sesiones_gestion'),('sesiones_entrenamiento','sesiones_lectura'),
    ('socio_descuentos','socio_descuentos_gestion'),('socio_disciplinas','socio_disc_gestion'),
    ('socio_disciplinas','socio_disc_lectura'),('socios','socios_gestion'),('socios','socios_lectura'),
    ('tutores_socios','tutores_gestion'),('tutores_socios','tutores_lectura')
  ) as x(tbl,pol)
  loop execute format('alter policy %I on public.%I to public',r.pol,r.tbl); end loop;
end$$;

-- Recreate duplicate index removed by migration 100.
create index if not exists idx_material_pedidos_club_validacion on public.material_pedidos(club_id,estado,creado_en desc);

-- Drop v100-only FK indexes.
drop index if exists public.idx_socios_perfil_fk_v100;
drop index if exists public.idx_dispositivos_push_perfil_fk_v100;
drop index if exists public.idx_sesiones_monitor_fk_v100;
drop index if exists public.idx_sesiones_serie_fk_v100;
drop index if exists public.idx_publicaciones_comunidad_autor_perfil_fk_v100;
drop index if exists public.idx_publicaciones_comunidad_autor_socio_fk_v100;
drop index if exists public.idx_kombax_social_posts_audiencia_club_fk_v100;
drop index if exists public.idx_kombax_social_posts_audiencia_fed_fk_v100;
drop index if exists public.idx_kombax_social_posts_social_media_fk_v100;
drop index if exists public.idx_kombax_social_posts_media_fk_v100;
drop index if exists public.idx_kombax_actor_audit_actor_fk_v100;
drop index if exists public.idx_cuotas_club_tarifa_fk_v100;
drop index if exists public.idx_grupos_club_disciplina_fk_v100;
drop index if exists public.idx_series_club_grupo_fk_v100;
drop index if exists public.idx_socio_disciplinas_club_disciplina_fk_v100;
drop index if exists public.idx_socio_disciplinas_club_grado_fk_v100;
drop index if exists public.idx_asistencias_club_socio_fk_v100;
drop index if exists public.idx_registros_acceso_club_socio_fk_v100;
drop index if exists public.idx_tutores_club_socio_fk_v100;
drop index if exists public.idx_evento_participantes_club_socio_fk_v100;
drop index if exists public.idx_material_pedidos_club_material_fk_v100;
drop index if exists public.idx_material_pedidos_club_socio_fk_v100;
drop index if exists public.idx_material_pedidos_club_cuota_fk_v100;
drop index if exists public.idx_material_entregas_club_material_fk_v100;
drop index if exists public.idx_preinscripciones_club_disciplina_fk_v100;
drop index if exists public.idx_preinscripciones_club_grupo_fk_v100;


-- Restore pre-100 RLS expressions (same logic, previous per-row auth form).
alter policy aceptaciones_legales_propias on public.aceptaciones_legales
  using ((perfil_id = auth.uid()) or tiene_rol_club(club_id, variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));
alter policy ambito_equipo_lectura_v057 on public.club_ambito_equipo
  using ((perfil_id = auth.uid()) or app_kombax_puede_gestionar_ambitos_v057(club_id));
alter policy ambito_grupos_lectura_v057 on public.club_ambito_grupos
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambito_grupos.ambito_id and ae.club_id=club_ambito_grupos.club_id and ae.perfil_id=auth.uid() and ae.activo));
alter policy ambito_socios_lectura_v057 on public.club_ambito_socios
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambito_socios.ambito_id and ae.club_id=club_ambito_socios.club_id and ae.perfil_id=auth.uid() and ae.activo));
alter policy ambitos_lectura_v057 on public.club_ambitos_trabajo
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambitos_trabajo.id and ae.club_id=club_ambitos_trabajo.club_id and ae.perfil_id=auth.uid() and ae.activo));
alter policy club_branding_history_select_v039 on public.club_branding_history
  using (exists (select 1 from public.miembros_club m where m.club_id=club_branding_history.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol='direccion'::public.rol_club or coalesce(m.coordinacion,false))));
alter policy comunidad_likes_propios_v032 on public.comunidad_likes using ((perfil_id=auth.uid()) and es_miembro_club(club_id));
alter policy contenido_ciclo_auditoria_select_v038 on public.contenido_ciclo_auditoria
  using (exists (select 1 from public.miembros_club m where m.club_id=contenido_ciclo_auditoria.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol=any(array['direccion'::public.rol_club,'secretaria'::public.rol_club]) or coalesce(m.coordinacion,false))));
alter policy dispositivos_propios_v030 on public.dispositivos_push using ((perfil_id=auth.uid()) and es_miembro_club(club_id)) with check ((perfil_id=auth.uid()) and es_miembro_club(club_id));
alter policy historial_avisos_lectura on public.historial_avisos_cuota using ((perfil_id=auth.uid()) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'economia'::public.rol_club]));
alter policy invitaciones_lectura on public.invitaciones_club using (tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]) or (lower(email)=lower(coalesce((auth.jwt()->>'email'),'')) and estado='pendiente'));
alter policy kombax_solicitud_equipo_select_v060 on public.kombax_solicitudes_equipo_club using ((perfil_id=auth.uid()) or app_puede_gestionar_perfil_club_v035(club_id));
alter policy miembros_lectura on public.miembros_club using ((perfil_id=auth.uid()) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));
alter policy notificaciones_marcar on public.notificaciones using (perfil_id=auth.uid()) with check (perfil_id=auth.uid());
alter policy notificaciones_propias on public.notificaciones using ((perfil_id=auth.uid()) or (rol_destino is not null and tiene_rol_club(club_id,variadic array[rol_destino])) or (audiencia='todos' and es_miembro_club(club_id)));
alter policy notificaciones_lecturas_insertar_v030 on public.notificaciones_lecturas with check ((perfil_id=auth.uid()) and exists (select 1 from public.notificaciones n where n.id=notificaciones_lecturas.notificacion_id and (n.perfil_id=auth.uid() or (n.rol_destino is not null and tiene_rol_club(n.club_id,variadic array[n.rol_destino])) or (n.audiencia='todos' and es_miembro_club(n.club_id)))));
alter policy notificaciones_lecturas_propias on public.notificaciones_lecturas using (perfil_id=auth.uid());
alter policy notificaciones_revisiones_propias_v034 on public.notificaciones_revisiones using ((perfil_id=auth.uid()) and es_miembro_club(club_id));
alter policy perfil_actualizar on public.perfiles using (id=auth.uid()) with check (id=auth.uid());
alter policy perfil_propio on public.perfiles using (id=auth.uid());
alter policy perfiles_lectura_equipo on public.perfiles using ((id=auth.uid()) or exists (select 1 from public.miembros_club mc_usuario join public.miembros_club mc_objetivo on mc_objetivo.club_id=mc_usuario.club_id and mc_objetivo.perfil_id=perfiles.id where mc_usuario.perfil_id=auth.uid() and mc_usuario.activo and mc_usuario.rol=any(array['direccion'::public.rol_club,'secretaria'::public.rol_club])));
alter policy preferencias_notificacion_propias_v030 on public.preferencias_notificacion using ((perfil_id=auth.uid()) and es_miembro_club(club_id));
alter policy preinscripcion_publica on public.preinscripciones with check ((solicitante_perfil_id=auth.uid()) and exists (select 1 from public.clubes c where c.id=preinscripciones.club_id and c.activo));
alter policy preinscripciones_solicitante_lectura on public.preinscripciones using (solicitante_perfil_id=auth.uid());
alter policy comunidad_lectura_rc10 on public.publicaciones_comunidad using (es_miembro_club(club_id) and (estado='publicada' or autor_perfil_id=auth.uid() or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'comunicacion'::public.rol_club])));
alter policy socios_lectura on public.socios using ((perfil_id=auth.uid()) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'economia'::public.rol_club]) or exists (select 1 from public.tutores_socios t where t.club_id=socios.club_id and t.socio_id=socios.id and t.tutor_perfil_id=auth.uid()));
alter policy tutores_lectura on public.tutores_socios using ((tutor_perfil_id=auth.uid()) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));

notify pgrst,'reload schema';
