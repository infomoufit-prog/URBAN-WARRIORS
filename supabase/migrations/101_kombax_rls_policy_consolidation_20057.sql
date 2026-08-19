-- KOMBAX 20.057 · RLS policy consolidation (101)
-- Exact semantic consolidation of permissive policies; no authorization branch is removed.
-- Baseline: post migration 100. Generated from live pg_policies snapshot and reviewed table-by-table.

alter policy clubes_publico_registro on public.clubes to anon;
alter policy disciplinas_publico_registro on public.disciplinas to anon;
alter policy grupos_publico_registro on public.grupos to anon;
alter policy tarifas_publico_registro on public.tarifas to anon;
alter policy textos_legales_publicos_rc10 on public.textos_legales to anon;
drop policy if exists horarios_publico_registro on public.horarios_grupo;

-- asistencias: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists asistencia_gestion on public.asistencias;
create policy asistencia_gestion_ins_v101 on public.asistencias for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
create policy asistencia_gestion_upd_v101 on public.asistencias for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
create policy asistencia_gestion_del_v101 on public.asistencias for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
alter policy asistencia_lectura on public.asistencias using (((puede_ver_socio(socio_id) OR monitor_puede_ver_socio_v057(socio_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))));

-- club_ambito_equipo: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists ambito_equipo_gestion_v057 on public.club_ambito_equipo;
create policy ambito_equipo_gestion_v057_ins_v101 on public.club_ambito_equipo for insert to authenticated with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_equipo_gestion_v057_upd_v101 on public.club_ambito_equipo for update to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_equipo_gestion_v057_del_v101 on public.club_ambito_equipo for delete to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_equipo_lectura_v057 on public.club_ambito_equipo using (((perfil_id = (SELECT auth.uid()) OR app_kombax_puede_gestionar_ambitos_v057(club_id)) OR (app_kombax_puede_gestionar_ambitos_v057(club_id))));

-- club_ambito_grupos: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists ambito_grupos_gestion_v057 on public.club_ambito_grupos;
create policy ambito_grupos_gestion_v057_ins_v101 on public.club_ambito_grupos for insert to authenticated with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_grupos_gestion_v057_upd_v101 on public.club_ambito_grupos for update to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_grupos_gestion_v057_del_v101 on public.club_ambito_grupos for delete to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_grupos_lectura_v057 on public.club_ambito_grupos using (((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambito_grupos.ambito_id AND ae.club_id = club_ambito_grupos.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)) OR (app_kombax_puede_gestionar_ambitos_v057(club_id))));

-- club_ambito_socios: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists ambito_socios_gestion_v057 on public.club_ambito_socios;
create policy ambito_socios_gestion_v057_ins_v101 on public.club_ambito_socios for insert to authenticated with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_socios_gestion_v057_upd_v101 on public.club_ambito_socios for update to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambito_socios_gestion_v057_del_v101 on public.club_ambito_socios for delete to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambito_socios_lectura_v057 on public.club_ambito_socios using (((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambito_socios.ambito_id AND ae.club_id = club_ambito_socios.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)) OR (app_kombax_puede_gestionar_ambitos_v057(club_id))));

-- club_ambitos_trabajo: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists ambitos_gestion_v057 on public.club_ambitos_trabajo;
create policy ambitos_gestion_v057_ins_v101 on public.club_ambitos_trabajo for insert to authenticated with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambitos_gestion_v057_upd_v101 on public.club_ambitos_trabajo for update to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id))) with check ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
create policy ambitos_gestion_v057_del_v101 on public.club_ambitos_trabajo for delete to authenticated using ((app_kombax_puede_gestionar_ambitos_v057(club_id)));
alter policy ambitos_lectura_v057 on public.club_ambitos_trabajo using (((app_kombax_puede_gestionar_ambitos_v057(club_id) OR EXISTS (SELECT 1 FROM public.club_ambito_equipo ae WHERE ae.ambito_id = club_ambitos_trabajo.id AND ae.club_id = club_ambitos_trabajo.club_id AND ae.perfil_id = (SELECT auth.uid()) AND ae.activo)) OR (app_kombax_puede_gestionar_ambitos_v057(club_id))));

-- comunicaciones: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists comunicaciones_gestion on public.comunicaciones;
create policy comunicaciones_gestion_ins_v101 on public.comunicaciones for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club])));
create policy comunicaciones_gestion_upd_v101 on public.comunicaciones for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club])));
create policy comunicaciones_gestion_del_v101 on public.comunicaciones for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club])));
alter policy comunicaciones_lectura on public.comunicaciones using (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]) OR (es_miembro_club(club_id) AND (estado = 'publicada' OR (estado = 'programada' AND COALESCE(programada_para, evento_fecha, now()) <= now())) AND (audiencia = 'todos' OR (audiencia = 'familias' AND tiene_rol_club(club_id, VARIADIC ARRAY['familia'::rol_club, 'alumno'::rol_club])) OR (audiencia = 'monitores' AND tiene_rol_club(club_id, VARIADIC ARRAY['monitor'::rol_club]))))) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'comunicacion'::rol_club]))));

-- config_club: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists config_gestion on public.config_club;
create policy config_gestion_ins_v101 on public.config_club for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
create policy config_gestion_upd_v101 on public.config_club for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
create policy config_gestion_del_v101 on public.config_club for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
alter policy config_lectura on public.config_club using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]))));

-- configuracion_avisos_cuota: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists config_avisos_gestion on public.configuracion_avisos_cuota;
create policy config_avisos_gestion_ins_v101 on public.configuracion_avisos_cuota for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
create policy config_avisos_gestion_upd_v101 on public.configuracion_avisos_cuota for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
create policy config_avisos_gestion_del_v101 on public.configuracion_avisos_cuota for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
alter policy config_avisos_lectura on public.configuracion_avisos_cuota using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))));

-- cuotas: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists cuotas_gestion on public.cuotas;
create policy cuotas_gestion_ins_v101 on public.cuotas for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
create policy cuotas_gestion_upd_v101 on public.cuotas for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
create policy cuotas_gestion_del_v101 on public.cuotas for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])));
alter policy cuotas_lectura on public.cuotas using (((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]))));

-- disciplinas: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists disciplinas_gestion on public.disciplinas;
create policy disciplinas_gestion_ins_v101 on public.disciplinas for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy disciplinas_gestion_upd_v101 on public.disciplinas for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy disciplinas_gestion_del_v101 on public.disciplinas for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy disciplinas_lectura on public.disciplinas using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (activa AND EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = disciplinas.club_id AND c.activo))));

-- grados: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists grados_gestion on public.grados;
create policy grados_gestion_ins_v101 on public.grados for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy grados_gestion_upd_v101 on public.grados for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy grados_gestion_del_v101 on public.grados for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy grados_lectura on public.grados using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))));

-- grupos: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists grupos_gestion on public.grupos;
create policy grupos_gestion_ins_v101 on public.grupos for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy grupos_gestion_upd_v101 on public.grupos for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy grupos_gestion_del_v101 on public.grupos for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy grupos_lectura on public.grupos using (((((NOT app_kombax_es_monitor_restringido_v057(club_id)) AND es_miembro_club(club_id)) OR puede_ver_grupo(id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (activo AND EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = grupos.club_id AND c.activo))));

-- horarios_grupo: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists horarios_gestion on public.horarios_grupo;
create policy horarios_gestion_ins_v101 on public.horarios_grupo for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy horarios_gestion_upd_v101 on public.horarios_grupo for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy horarios_gestion_del_v101 on public.horarios_grupo for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy horarios_lectura on public.horarios_grupo using (((((NOT app_kombax_es_monitor_restringido_v057(club_id)) AND es_miembro_club(club_id)) OR puede_ver_grupo(grupo_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = horarios_grupo.club_id AND c.activo))));

-- invitaciones_club: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists invitaciones_gestion on public.invitaciones_club;
create policy invitaciones_gestion_ins_v101 on public.invitaciones_club for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
create policy invitaciones_gestion_upd_v101 on public.invitaciones_club for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
create policy invitaciones_gestion_del_v101 on public.invitaciones_club for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
alter policy invitaciones_lectura on public.invitaciones_club using (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR (lower(email) = lower(COALESCE(((SELECT auth.jwt()) ->> 'email'), '')) AND estado = 'pendiente')) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))));

-- material_catalogo: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists material_gestion on public.material_catalogo;
create policy material_gestion_ins_v101 on public.material_catalogo for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy material_gestion_upd_v101 on public.material_catalogo for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy material_gestion_del_v101 on public.material_catalogo for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy material_lectura on public.material_catalogo using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))));

-- material_entregas: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists entregas_gestion on public.material_entregas;
create policy entregas_gestion_ins_v101 on public.material_entregas for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy entregas_gestion_upd_v101 on public.material_entregas for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy entregas_gestion_del_v101 on public.material_entregas for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy entregas_lectura on public.material_entregas using (((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club])) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))));

-- material_variantes: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists variantes_gestion on public.material_variantes;
create policy variantes_gestion_ins_v101 on public.material_variantes for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy variantes_gestion_upd_v101 on public.material_variantes for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
create policy variantes_gestion_del_v101 on public.material_variantes for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club])));
alter policy variantes_lectura on public.material_variantes using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club, 'secretaria'::rol_club]))));

-- miembros_club: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists miembros_gestion on public.miembros_club;
create policy miembros_gestion_ins_v101 on public.miembros_club for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
create policy miembros_gestion_upd_v101 on public.miembros_club for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
create policy miembros_gestion_del_v101 on public.miembros_club for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club])));
alter policy miembros_lectura on public.miembros_club using (((perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]))));

-- seguimiento: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists seguimiento_gestion on public.seguimiento;
create policy seguimiento_gestion_ins_v101 on public.seguimiento for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id)));
create policy seguimiento_gestion_upd_v101 on public.seguimiento for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id)));
create policy seguimiento_gestion_del_v101 on public.seguimiento for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id)));
alter policy seguimiento_lectura on public.seguimiento using (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_puede_ver_socio_v057(socio_id) OR (visibilidad = 'familia'::visibilidad_seguimiento AND puede_aportar_pago_socio(socio_id))) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club]) OR app_kombax_monitor_puede_seguimiento_v057(socio_id))));

-- sesiones_entrenamiento: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists sesiones_gestion on public.sesiones_entrenamiento;
create policy sesiones_gestion_ins_v101 on public.sesiones_entrenamiento for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id)));
create policy sesiones_gestion_upd_v101 on public.sesiones_entrenamiento for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id)));
create policy sesiones_gestion_del_v101 on public.sesiones_entrenamiento for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id)));
alter policy sesiones_lectura on public.sesiones_entrenamiento using (((puede_ver_grupo(grupo_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR monitor_asignado_a_grupo(grupo_id))));

-- socio_disciplinas: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists socio_disc_gestion on public.socio_disciplinas;
create policy socio_disc_gestion_ins_v101 on public.socio_disciplinas for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy socio_disc_gestion_upd_v101 on public.socio_disciplinas for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy socio_disc_gestion_del_v101 on public.socio_disciplinas for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy socio_disc_lectura on public.socio_disciplinas using (((puede_ver_socio(socio_id) OR monitor_puede_ver_socio_v057(socio_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))));

-- socios: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists socios_gestion on public.socios;
create policy socios_gestion_ins_v101 on public.socios for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy socios_gestion_upd_v101 on public.socios for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy socios_gestion_del_v101 on public.socios for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy socios_lectura on public.socios using (((perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club]) OR EXISTS (SELECT 1 FROM public.tutores_socios t WHERE t.club_id = socios.club_id AND t.socio_id = socios.id AND t.tutor_perfil_id = (SELECT auth.uid()))) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))));

-- tarifas: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists tarifas_gestion on public.tarifas;
create policy tarifas_gestion_ins_v101 on public.tarifas for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club])));
create policy tarifas_gestion_upd_v101 on public.tarifas for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club])));
create policy tarifas_gestion_del_v101 on public.tarifas for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club])));
alter policy tarifas_lectura on public.tarifas using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'economia'::rol_club])) OR (activa AND EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = tarifas.club_id AND c.activo))));

-- textos_legales: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists legales_gestion on public.textos_legales;
create policy legales_gestion_ins_v101 on public.textos_legales for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy legales_gestion_upd_v101 on public.textos_legales for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy legales_gestion_del_v101 on public.textos_legales for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy legales_lectura on public.textos_legales using (((es_miembro_club(club_id)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (vigente = true)));

-- tutores_socios: split ALL management policy so SELECT has one exact OR policy.
drop policy if exists tutores_gestion on public.tutores_socios;
create policy tutores_gestion_ins_v101 on public.tutores_socios for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy tutores_gestion_upd_v101 on public.tutores_socios for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
create policy tutores_gestion_del_v101 on public.tutores_socios for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])));
alter policy tutores_lectura on public.tutores_socios using (((tutor_perfil_id = (SELECT auth.uid()) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))));

-- notificaciones: preserve management + recipient semantics with one policy per action.
drop policy if exists notificaciones_gestion on public.notificaciones;
drop policy if exists notificaciones_marcar on public.notificaciones;
create policy notificaciones_gestion_ins_v101 on public.notificaciones for insert to authenticated with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
create policy notificaciones_update_v101 on public.notificaciones for update to authenticated using (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])) OR (perfil_id = (SELECT auth.uid())))) with check (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])) OR (perfil_id = (SELECT auth.uid()))));
create policy notificaciones_gestion_del_v101 on public.notificaciones for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club])));
alter policy notificaciones_propias on public.notificaciones using (((perfil_id = (SELECT auth.uid()) OR (rol_destino IS NOT NULL AND tiene_rol_club(club_id, VARIADIC ARRAY[rol_destino])) OR (audiencia = 'todos' AND es_miembro_club(club_id))) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club, 'economia'::rol_club, 'comunicacion'::rol_club]))));

-- registros_acceso_clase: merge legitimate staff/user INSERT paths and one SELECT path.
drop policy if exists accesos_gestion_equipo on public.registros_acceso_clase;
drop policy if exists accesos_registro_usuario on public.registros_acceso_clase;
create policy accesos_insert_v101 on public.registros_acceso_clase for insert to authenticated with check (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)) OR (puede_ver_socio(socio_id) AND EXISTS (SELECT 1 FROM public.sesiones_entrenamiento s WHERE s.id = registros_acceso_clase.sesion_id AND s.club_id = registros_acceso_clase.club_id AND s.fecha = CURRENT_DATE AND s.estado <> 'cancelada'))));
create policy accesos_update_v101 on public.registros_acceso_clase for update to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))) with check ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
create policy accesos_delete_v101 on public.registros_acceso_clase for delete to authenticated using ((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id)));
alter policy accesos_lectura on public.registros_acceso_clase using (((puede_aportar_pago_socio(socio_id) OR tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR EXISTS (SELECT 1 FROM public.sesiones_entrenamiento se WHERE se.club_id = registros_acceso_clase.club_id AND se.id = registros_acceso_clase.sesion_id AND monitor_asignado_a_grupo_v057(se.grupo_id))) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]) OR app_kombax_monitor_puede_asistencia_registro_v057(sesion_id, socio_id))));

-- preinscripciones: combine exact OR branches per action.
alter policy preinscripcion_publica on public.preinscripciones with check (((solicitante_perfil_id = (SELECT auth.uid()) AND EXISTS (SELECT 1 FROM public.clubes c WHERE c.id = preinscripciones.club_id AND c.activo)) OR (tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club]))));
drop policy if exists preinscripciones_crear_equipo on public.preinscripciones;
alter policy preinscripciones_lectura on public.preinscripciones using (((tiene_rol_club(club_id, VARIADIC ARRAY['direccion'::rol_club, 'secretaria'::rol_club])) OR (solicitante_perfil_id = (SELECT auth.uid()))));
drop policy if exists preinscripciones_solicitante_lectura on public.preinscripciones;

-- perfiles: perfiles_lectura_equipo already contains the own-profile branch exactly.
drop policy if exists perfil_propio on public.perfiles;

notify pgrst, 'reload schema';
