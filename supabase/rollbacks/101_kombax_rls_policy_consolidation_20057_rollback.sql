-- Rollback 101: restore exact post-migration-100 policy topology.

alter policy clubes_publico_registro on public.clubes to public;
alter policy disciplinas_publico_registro on public.disciplinas to public;
alter policy grupos_publico_registro on public.grupos to public;
alter policy tarifas_publico_registro on public.tarifas to public;
alter policy textos_legales_publicos_rc10 on public.textos_legales to anon, authenticated;
create policy horarios_publico_registro on public.horarios_grupo for select to authenticated using (EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = horarios_grupo.club_id AND c.activo));

-- asistencias
drop policy if exists asistencia_gestion_ins_v101 on public.asistencias;
drop policy if exists asistencia_gestion_upd_v101 on public.asistencias;
drop policy if exists asistencia_gestion_del_v101 on public.asistencias;
create policy asistencia_gestion on public.asistencias for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
alter policy asistencia_lectura on public.asistencias using ((puede_ver_socio(socio_id) OR monitor_puede_ver_socio_v057(socio_id)));

-- club_ambito_equipo
drop policy if exists ambito_equipo_gestion_v057_ins_v101 on public.club_ambito_equipo;
drop policy if exists ambito_equipo_gestion_v057_upd_v101 on public.club_ambito_equipo;
drop policy if exists ambito_equipo_gestion_v057_del_v101 on public.club_ambito_equipo;
create policy ambito_equipo_gestion_v057 on public.club_ambito_equipo for all to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_equipo_lectura_v057 on public.club_ambito_equipo using ((perfil_id = (SELECT auth.uid()) OR app_kombax_puede_gestionar_ambitos_v057(club_id)));

-- club_ambito_grupos
drop policy if exists ambito_grupos_gestion_v057_ins_v101 on public.club_ambito_grupos;
drop policy if exists ambito_grupos_gestion_v057_upd_v101 on public.club_ambito_grupos;
drop policy if exists ambito_grupos_gestion_v057_del_v101 on public.club_ambito_grupos;
create policy ambito_grupos_gestion_v057 on public.club_ambito_grupos for all to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_grupos_lectura_v057 on public.club_ambito_grupos using ((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambito_grupos.ambito_id AND ae.club_id = club_ambito_grupos.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)));

-- club_ambito_socios
drop policy if exists ambito_socios_gestion_v057_ins_v101 on public.club_ambito_socios;
drop policy if exists ambito_socios_gestion_v057_upd_v101 on public.club_ambito_socios;
drop policy if exists ambito_socios_gestion_v057_del_v101 on public.club_ambito_socios;
create policy ambito_socios_gestion_v057 on public.club_ambito_socios for all to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_socios_lectura_v057 on public.club_ambito_socios using ((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambito_socios.ambito_id AND ae.club_id = club_ambito_socios.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)));

-- club_ambitos_trabajo
drop policy if exists ambitos_gestion_v057_ins_v101 on public.club_ambitos_trabajo;
drop policy if exists ambitos_gestion_v057_upd_v101 on public.club_ambitos_trabajo;
drop policy if exists ambitos_gestion_v057_del_v101 on public.club_ambitos_trabajo;
create policy ambitos_gestion_v057 on public.club_ambitos_trabajo for all to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambitos_lectura_v057 on public.club_ambitos_trabajo using ((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambitos_trabajo.id AND ae.club_id = club_ambitos_trabajo.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)));

-- comunicaciones
drop policy if exists comunicaciones_gestion_ins_v101 on public.comunicaciones;
drop policy if exists comunicaciones_gestion_upd_v101 on public.comunicaciones;
drop policy if exists comunicaciones_gestion_del_v101 on public.comunicaciones;
create policy comunicaciones_gestion on public.comunicaciones for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club])));
alter policy comunicaciones_lectura on public.comunicaciones using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]) OR (es_miembro_club(club_id) AND (estado = 'publicada' OR (estado = 'programada' AND COALESCE(programada_para, evento_fecha, now()) <= now())) AND (audiencia = 'todos' OR (audiencia = 'familias' AND tiene_rol_club(club_id, VARIADIC ARRAY['familia'::rol_club, 'alumno'::rol_club])) OR (audiencia = 'monitores' AND tiene_rol_club(club_id, VARIADIC ARRAY['monitor'::rol_club]))))));

-- config_club
drop policy if exists config_gestion_ins_v101 on public.config_club;
drop policy if exists config_gestion_upd_v101 on public.config_club;
drop policy if exists config_gestion_del_v101 on public.config_club;
create policy config_gestion on public.config_club for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
alter policy config_lectura on public.config_club using ((es_miembro_club(club_id)));

-- configuracion_avisos_cuota
drop policy if exists config_avisos_gestion_ins_v101 on public.configuracion_avisos_cuota;
drop policy if exists config_avisos_gestion_upd_v101 on public.configuracion_avisos_cuota;
drop policy if exists config_avisos_gestion_del_v101 on public.configuracion_avisos_cuota;
create policy config_avisos_gestion on public.configuracion_avisos_cuota for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
alter policy config_avisos_lectura on public.configuracion_avisos_cuota using ((es_miembro_club(club_id)));

-- cuotas
drop policy if exists cuotas_gestion_ins_v101 on public.cuotas;
drop policy if exists cuotas_gestion_upd_v101 on public.cuotas;
drop policy if exists cuotas_gestion_del_v101 on public.cuotas;
create policy cuotas_gestion on public.cuotas for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
alter policy cuotas_lectura on public.cuotas using ((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));

-- disciplinas
drop policy if exists disciplinas_gestion_ins_v101 on public.disciplinas;
drop policy if exists disciplinas_gestion_upd_v101 on public.disciplinas;
drop policy if exists disciplinas_gestion_del_v101 on public.disciplinas;
create policy disciplinas_gestion on public.disciplinas for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy disciplinas_lectura on public.disciplinas using ((es_miembro_club(club_id)));

-- grados
drop policy if exists grados_gestion_ins_v101 on public.grados;
drop policy if exists grados_gestion_upd_v101 on public.grados;
drop policy if exists grados_gestion_del_v101 on public.grados;
create policy grados_gestion on public.grados for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy grados_lectura on public.grados using ((es_miembro_club(club_id)));

-- grupos
drop policy if exists grupos_gestion_ins_v101 on public.grupos;
drop policy if exists grupos_gestion_upd_v101 on public.grupos;
drop policy if exists grupos_gestion_del_v101 on public.grupos;
create policy grupos_gestion on public.grupos for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy grupos_lectura on public.grupos using ((((NOT app_kombax_es_monitor_restringido_v057(club_id)) AND es_miembro_club(club_id)) OR puede_ver_grupo(id)));

-- horarios_grupo
drop policy if exists horarios_gestion_ins_v101 on public.horarios_grupo;
drop policy if exists horarios_gestion_upd_v101 on public.horarios_grupo;
drop policy if exists horarios_gestion_del_v101 on public.horarios_grupo;
create policy horarios_gestion on public.horarios_grupo for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy horarios_lectura on public.horarios_grupo using ((((NOT app_kombax_es_monitor_restringido_v057(club_id)) AND es_miembro_club(club_id)) OR puede_ver_grupo(grupo_id)));

-- invitaciones_club
drop policy if exists invitaciones_gestion_ins_v101 on public.invitaciones_club;
drop policy if exists invitaciones_gestion_upd_v101 on public.invitaciones_club;
drop policy if exists invitaciones_gestion_del_v101 on public.invitaciones_club;
create policy invitaciones_gestion on public.invitaciones_club for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
alter policy invitaciones_lectura on public.invitaciones_club using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR (lower(email) = lower(COALESCE(((SELECT auth.jwt()) ->> 'email'), '')) AND estado = 'pendiente')));

-- material_catalogo
drop policy if exists material_gestion_ins_v101 on public.material_catalogo;
drop policy if exists material_gestion_upd_v101 on public.material_catalogo;
drop policy if exists material_gestion_del_v101 on public.material_catalogo;
create policy material_gestion on public.material_catalogo for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy material_lectura on public.material_catalogo using ((es_miembro_club(club_id)));

-- material_entregas
drop policy if exists entregas_gestion_ins_v101 on public.material_entregas;
drop policy if exists entregas_gestion_upd_v101 on public.material_entregas;
drop policy if exists entregas_gestion_del_v101 on public.material_entregas;
create policy entregas_gestion on public.material_entregas for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy entregas_lectura on public.material_entregas using ((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));

-- material_variantes
drop policy if exists variantes_gestion_ins_v101 on public.material_variantes;
drop policy if exists variantes_gestion_upd_v101 on public.material_variantes;
drop policy if exists variantes_gestion_del_v101 on public.material_variantes;
create policy variantes_gestion on public.material_variantes for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy variantes_lectura on public.material_variantes using ((es_miembro_club(club_id)));

-- miembros_club
drop policy if exists miembros_gestion_ins_v101 on public.miembros_club;
drop policy if exists miembros_gestion_upd_v101 on public.miembros_club;
drop policy if exists miembros_gestion_del_v101 on public.miembros_club;
create policy miembros_gestion on public.miembros_club for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
alter policy miembros_lectura on public.miembros_club using ((perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));

-- seguimiento
drop policy if exists seguimiento_gestion_ins_v101 on public.seguimiento;
drop policy if exists seguimiento_gestion_upd_v101 on public.seguimiento;
drop policy if exists seguimiento_gestion_del_v101 on public.seguimiento;
create policy seguimiento_gestion on public.seguimiento for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id)));
alter policy seguimiento_lectura on public.seguimiento using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_puede_ver_socio_v057(socio_id) OR (visibilidad = 'familia'::visibilidad_seguimiento AND puede_aportar_pago_socio(socio_id))));

-- sesiones_entrenamiento
drop policy if exists sesiones_gestion_ins_v101 on public.sesiones_entrenamiento;
drop policy if exists sesiones_gestion_upd_v101 on public.sesiones_entrenamiento;
drop policy if exists sesiones_gestion_del_v101 on public.sesiones_entrenamiento;
create policy sesiones_gestion on public.sesiones_entrenamiento for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id)));
alter policy sesiones_lectura on public.sesiones_entrenamiento using ((puede_ver_grupo(grupo_id)));

-- socio_disciplinas
drop policy if exists socio_disc_gestion_ins_v101 on public.socio_disciplinas;
drop policy if exists socio_disc_gestion_upd_v101 on public.socio_disciplinas;
drop policy if exists socio_disc_gestion_del_v101 on public.socio_disciplinas;
create policy socio_disc_gestion on public.socio_disciplinas for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy socio_disc_lectura on public.socio_disciplinas using ((puede_ver_socio(socio_id) OR monitor_puede_ver_socio_v057(socio_id)));

-- socios
drop policy if exists socios_gestion_ins_v101 on public.socios;
drop policy if exists socios_gestion_upd_v101 on public.socios;
drop policy if exists socios_gestion_del_v101 on public.socios;
create policy socios_gestion on public.socios for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy socios_lectura on public.socios using ((perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]) OR EXISTS (SELECT 1 FROM public.tutores_socios t WHERE t.club_id = socios.club_id AND t.socio_id = socios.id AND t.tutor_perfil_id = (SELECT auth.uid()))));

-- tarifas
drop policy if exists tarifas_gestion_ins_v101 on public.tarifas;
drop policy if exists tarifas_gestion_upd_v101 on public.tarifas;
drop policy if exists tarifas_gestion_del_v101 on public.tarifas;
create policy tarifas_gestion on public.tarifas for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club])));
alter policy tarifas_lectura on public.tarifas using ((es_miembro_club(club_id)));

-- textos_legales
drop policy if exists legales_gestion_ins_v101 on public.textos_legales;
drop policy if exists legales_gestion_upd_v101 on public.textos_legales;
drop policy if exists legales_gestion_del_v101 on public.textos_legales;
create policy legales_gestion on public.textos_legales for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy legales_lectura on public.textos_legales using ((es_miembro_club(club_id)));

-- tutores_socios
drop policy if exists tutores_gestion_ins_v101 on public.tutores_socios;
drop policy if exists tutores_gestion_upd_v101 on public.tutores_socios;
drop policy if exists tutores_gestion_del_v101 on public.tutores_socios;
create policy tutores_gestion on public.tutores_socios for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy tutores_lectura on public.tutores_socios using ((tutor_perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));

-- notificaciones
drop policy if exists notificaciones_gestion_ins_v101 on public.notificaciones;
drop policy if exists notificaciones_update_v101 on public.notificaciones;
drop policy if exists notificaciones_gestion_del_v101 on public.notificaciones;
create policy notificaciones_gestion on public.notificaciones for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
create policy notificaciones_marcar on public.notificaciones for update to authenticated using ((perfil_id = (SELECT auth.uid()))) with check ((perfil_id = (SELECT auth.uid())));
alter policy notificaciones_propias on public.notificaciones using ((perfil_id = (SELECT auth.uid()) OR (rol_destino IS NOT NULL AND tiene_rol_club(club_id, VARIADIC ARRAY[rol_destino])) OR (audiencia = 'todos' AND es_miembro_club(club_id))));

-- registros_acceso_clase
drop policy if exists accesos_insert_v101 on public.registros_acceso_clase;
drop policy if exists accesos_update_v101 on public.registros_acceso_clase;
drop policy if exists accesos_delete_v101 on public.registros_acceso_clase;
create policy accesos_gestion_equipo on public.registros_acceso_clase for all to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
create policy accesos_registro_usuario on public.registros_acceso_clase for insert to authenticated with check ((puede_ver_socio(socio_id) AND EXISTS (SELECT 1 FROM public.sesiones_entrenamiento s WHERE s.id = registros_acceso_clase.sesion_id AND s.club_id = registros_acceso_clase.club_id AND s.fecha = CURRENT_DATE AND s.estado <> 'cancelada')));
alter policy accesos_lectura on public.registros_acceso_clase using ((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR EXISTS (SELECT 1 FROM public.sesiones_entrenamiento se WHERE se.club_id = registros_acceso_clase.club_id AND se.id = registros_acceso_clase.sesion_id AND monitor_asignado_a_grupo_v057(se.grupo_id))));

-- preinscripciones
alter policy preinscripcion_publica on public.preinscripciones with check ((solicitante_perfil_id = (SELECT auth.uid()) AND EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = preinscripciones.club_id AND c.activo)));
create policy preinscripciones_crear_equipo on public.preinscripciones for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy preinscripciones_lectura on public.preinscripciones using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy preinscripciones_solicitante_lectura on public.preinscripciones for select to authenticated using (solicitante_perfil_id = (SELECT auth.uid()));

-- perfiles
create policy perfil_propio on public.perfiles for select to authenticated using (id = (SELECT auth.uid()));

notify pgrst, 'reload schema';
