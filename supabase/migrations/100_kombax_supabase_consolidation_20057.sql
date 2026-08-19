-- KOMBAX 20.057 · Supabase consolidation
-- Objetivo: cerrar fachadas superseded, estrechar RLS sin cambiar semántica,
-- optimizar auth initplan y retirar un índice duplicado. Sin cambios de producto.

-- 1) RPC superseded: siguen disponibles para postgres/service_role si una fachada
-- vigente delega internamente, pero dejan de ser superficie directa del cliente.
revoke execute on function public.app_kombax_social_mutate_v083(text,jsonb,uuid) from public, anon, authenticated;
revoke execute on function public.app_kombax_identity_mutate_v065(text,jsonb,uuid) from public, anon, authenticated;
revoke execute on function public.app_kombax_social_feed_v083(timestamptz,uuid,integer) from public, anon, authenticated;
revoke execute on function public.app_kombax_social_media_v053(uuid) from public, anon, authenticated;
revoke execute on function public.app_kombax_perfil_publico_v083(uuid) from public, anon, authenticated;

-- 2) Policies históricas declaradas TO PUBLIC aunque la tabla no concede privilegios
-- a anon. Se estrechan a authenticated; USING/WITH CHECK se mantienen equivalentes.
alter policy asistencia_gestion on public.asistencias to authenticated;
alter policy asistencia_lectura on public.asistencias to authenticated;
alter policy auditoria_lectura on public.auditoria to authenticated;
alter policy club_branding_history_select_v039 on public.club_branding_history to authenticated;
alter policy comunicaciones_gestion on public.comunicaciones to authenticated;
alter policy config_gestion on public.config_club to authenticated;
alter policy config_lectura on public.config_club to authenticated;
alter policy config_avisos_gestion on public.configuracion_avisos_cuota to authenticated;
alter policy config_avisos_lectura on public.configuracion_avisos_cuota to authenticated;
alter policy consentimientos_insertar on public.consentimientos to authenticated;
alter policy consentimientos_lectura on public.consentimientos to authenticated;
alter policy contenido_ciclo_auditoria_select_v038 on public.contenido_ciclo_auditoria to authenticated;
alter policy cuotas_gestion on public.cuotas to authenticated;
alter policy cuotas_lectura on public.cuotas to authenticated;
alter policy descuentos_gestion on public.descuentos to authenticated;
alter policy grados_gestion on public.grados to authenticated;
alter policy grados_lectura on public.grados to authenticated;
alter policy graduaciones_gestion on public.graduaciones to authenticated;
alter policy graduaciones_lectura on public.graduaciones to authenticated;
alter policy historial_avisos_lectura on public.historial_avisos_cuota to authenticated;
alter policy historial_tarifas_lectura on public.historial_tarifas to authenticated;
alter policy horarios_gestion on public.horarios_grupo to authenticated;
alter policy horarios_lectura on public.horarios_grupo to authenticated;
alter policy horarios_publico_registro on public.horarios_grupo to authenticated;
alter policy material_gestion on public.material_catalogo to authenticated;
alter policy material_lectura on public.material_catalogo to authenticated;
alter policy entregas_gestion on public.material_entregas to authenticated;
alter policy entregas_lectura on public.material_entregas to authenticated;
alter policy material_pedidos_gestion on public.material_pedidos to authenticated;
alter policy material_pedidos_lectura on public.material_pedidos to authenticated;
alter policy material_pedidos_solicitar on public.material_pedidos to authenticated;
alter policy variantes_gestion on public.material_variantes to authenticated;
alter policy variantes_lectura on public.material_variantes to authenticated;
alter policy miembros_gestion on public.miembros_club to authenticated;
alter policy miembros_lectura on public.miembros_club to authenticated;
alter policy notificaciones_gestion on public.notificaciones to authenticated;
alter policy notificaciones_marcar on public.notificaciones to authenticated;
alter policy notificaciones_propias on public.notificaciones to authenticated;
alter policy pagos_insertar on public.pagos to authenticated;
alter policy pagos_lectura on public.pagos to authenticated;
alter policy pagos_validar on public.pagos to authenticated;
alter policy perfil_actualizar on public.perfiles to authenticated;
alter policy perfil_propio on public.perfiles to authenticated;
alter policy preinscripciones_gestion on public.preinscripciones to authenticated;
alter policy preinscripciones_lectura on public.preinscripciones to authenticated;
alter policy recibos_contadores_sin_cliente on public.recibos_contadores to authenticated;
alter policy recibos_cuota_lectura on public.recibos_cuota to authenticated;
alter policy accesos_gestion_equipo on public.registros_acceso_clase to authenticated;
alter policy accesos_lectura on public.registros_acceso_clase to authenticated;
alter policy seguimiento_gestion on public.seguimiento to authenticated;
alter policy seguimiento_lectura on public.seguimiento to authenticated;
alter policy sesiones_gestion on public.sesiones_entrenamiento to authenticated;
alter policy sesiones_lectura on public.sesiones_entrenamiento to authenticated;
alter policy socio_descuentos_gestion on public.socio_descuentos to authenticated;
alter policy socio_disc_gestion on public.socio_disciplinas to authenticated;
alter policy socio_disc_lectura on public.socio_disciplinas to authenticated;
alter policy socios_gestion on public.socios to authenticated;
alter policy socios_lectura on public.socios to authenticated;
alter policy tutores_gestion on public.tutores_socios to authenticated;
alter policy tutores_lectura on public.tutores_socios to authenticated;

-- 3) Auth RLS initplan: misma lógica, auth.uid()/auth.jwt() calculados una vez por query.
alter policy aceptaciones_legales_propias on public.aceptaciones_legales
  using ((perfil_id = (select auth.uid())) or tiene_rol_club(club_id, variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));

alter policy ambito_equipo_lectura_v057 on public.club_ambito_equipo
  using ((perfil_id = (select auth.uid())) or app_kombax_puede_gestionar_ambitos_v057(club_id));

alter policy ambito_grupos_lectura_v057 on public.club_ambito_grupos
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae
    where ae.ambito_id=club_ambito_grupos.ambito_id and ae.club_id=club_ambito_grupos.club_id
      and ae.perfil_id=(select auth.uid()) and ae.activo));

alter policy ambito_socios_lectura_v057 on public.club_ambito_socios
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae
    where ae.ambito_id=club_ambito_socios.ambito_id and ae.club_id=club_ambito_socios.club_id
      and ae.perfil_id=(select auth.uid()) and ae.activo));

alter policy ambitos_lectura_v057 on public.club_ambitos_trabajo
  using (app_kombax_puede_gestionar_ambitos_v057(club_id) or exists (
    select 1 from public.club_ambito_equipo ae
    where ae.ambito_id=club_ambitos_trabajo.id and ae.club_id=club_ambitos_trabajo.club_id
      and ae.perfil_id=(select auth.uid()) and ae.activo));

alter policy club_branding_history_select_v039 on public.club_branding_history
  using (exists (select 1 from public.miembros_club m
    where m.club_id=club_branding_history.club_id and m.perfil_id=(select auth.uid()) and m.activo
      and (m.rol='direccion'::public.rol_club or coalesce(m.coordinacion,false))));

alter policy comunidad_likes_propios_v032 on public.comunidad_likes
  using ((perfil_id=(select auth.uid())) and es_miembro_club(club_id));

alter policy contenido_ciclo_auditoria_select_v038 on public.contenido_ciclo_auditoria
  using (exists (select 1 from public.miembros_club m
    where m.club_id=contenido_ciclo_auditoria.club_id and m.perfil_id=(select auth.uid()) and m.activo
      and (m.rol=any(array['direccion'::public.rol_club,'secretaria'::public.rol_club]) or coalesce(m.coordinacion,false))));

alter policy dispositivos_propios_v030 on public.dispositivos_push
  using ((perfil_id=(select auth.uid())) and es_miembro_club(club_id))
  with check ((perfil_id=(select auth.uid())) and es_miembro_club(club_id));

alter policy historial_avisos_lectura on public.historial_avisos_cuota
  using ((perfil_id=(select auth.uid())) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'economia'::public.rol_club]));

alter policy invitaciones_lectura on public.invitaciones_club
  using (tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club])
    or (lower(email)=lower(coalesce(((select auth.jwt())->>'email'),'')) and estado='pendiente'));

alter policy kombax_solicitud_equipo_select_v060 on public.kombax_solicitudes_equipo_club
  using ((perfil_id=(select auth.uid())) or app_puede_gestionar_perfil_club_v035(club_id));

alter policy miembros_lectura on public.miembros_club
  using ((perfil_id=(select auth.uid())) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));

alter policy notificaciones_marcar on public.notificaciones
  using (perfil_id=(select auth.uid()))
  with check (perfil_id=(select auth.uid()));

alter policy notificaciones_propias on public.notificaciones
  using ((perfil_id=(select auth.uid()))
    or (rol_destino is not null and tiene_rol_club(club_id,variadic array[rol_destino]))
    or (audiencia='todos' and es_miembro_club(club_id)));

alter policy notificaciones_lecturas_insertar_v030 on public.notificaciones_lecturas
  with check ((perfil_id=(select auth.uid())) and exists (
    select 1 from public.notificaciones n where n.id=notificaciones_lecturas.notificacion_id
      and (n.perfil_id=(select auth.uid())
        or (n.rol_destino is not null and tiene_rol_club(n.club_id,variadic array[n.rol_destino]))
        or (n.audiencia='todos' and es_miembro_club(n.club_id)))));

alter policy notificaciones_lecturas_propias on public.notificaciones_lecturas
  using (perfil_id=(select auth.uid()));

alter policy notificaciones_revisiones_propias_v034 on public.notificaciones_revisiones
  using ((perfil_id=(select auth.uid())) and es_miembro_club(club_id));

alter policy perfil_actualizar on public.perfiles
  using (id=(select auth.uid())) with check (id=(select auth.uid()));
alter policy perfil_propio on public.perfiles
  using (id=(select auth.uid()));
alter policy perfiles_lectura_equipo on public.perfiles
  using ((id=(select auth.uid())) or exists (
    select 1 from public.miembros_club mc_usuario
    join public.miembros_club mc_objetivo on mc_objetivo.club_id=mc_usuario.club_id and mc_objetivo.perfil_id=perfiles.id
    where mc_usuario.perfil_id=(select auth.uid()) and mc_usuario.activo
      and mc_usuario.rol=any(array['direccion'::public.rol_club,'secretaria'::public.rol_club])));

alter policy preferencias_notificacion_propias_v030 on public.preferencias_notificacion
  using ((perfil_id=(select auth.uid())) and es_miembro_club(club_id));

alter policy preinscripcion_publica on public.preinscripciones
  with check ((solicitante_perfil_id=(select auth.uid())) and exists (
    select 1 from public.clubes c where c.id=preinscripciones.club_id and c.activo));
alter policy preinscripciones_solicitante_lectura on public.preinscripciones
  using (solicitante_perfil_id=(select auth.uid()));

alter policy comunidad_lectura_rc10 on public.publicaciones_comunidad
  using (es_miembro_club(club_id) and (estado='publicada' or autor_perfil_id=(select auth.uid())
    or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'comunicacion'::public.rol_club])));

alter policy socios_lectura on public.socios
  using ((perfil_id=(select auth.uid()))
    or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club,'economia'::public.rol_club])
    or exists (select 1 from public.tutores_socios t where t.club_id=socios.club_id and t.socio_id=socios.id and t.tutor_perfil_id=(select auth.uid())));

alter policy tutores_lectura on public.tutores_socios
  using ((tutor_perfil_id=(select auth.uid())) or tiene_rol_club(club_id,variadic array['direccion'::public.rol_club,'secretaria'::public.rol_club]));

-- 4) Índice duplicado exacto: se conserva el nombre histórico club_estado.
drop index if exists public.idx_material_pedidos_club_validacion;

-- 5) Índices FK de relaciones de alto crecimiento / resolución frecuente.
-- Se evitan intencionadamente FKs puramente de auditoría (*_por) de tablas pequeñas.
create index if not exists idx_socios_perfil_fk_v100 on public.socios(perfil_id);
create index if not exists idx_dispositivos_push_perfil_fk_v100 on public.dispositivos_push(perfil_id);
create index if not exists idx_sesiones_monitor_fk_v100 on public.sesiones_entrenamiento(monitor_id) where monitor_id is not null;
create index if not exists idx_sesiones_serie_fk_v100 on public.sesiones_entrenamiento(serie_id) where serie_id is not null;
create index if not exists idx_publicaciones_comunidad_autor_perfil_fk_v100 on public.publicaciones_comunidad(autor_perfil_id) where autor_perfil_id is not null;
create index if not exists idx_publicaciones_comunidad_autor_socio_fk_v100 on public.publicaciones_comunidad(autor_socio_id) where autor_socio_id is not null;
create index if not exists idx_kombax_social_posts_audiencia_club_fk_v100 on public.kombax_social_publicaciones(audiencia_club_id) where audiencia_club_id is not null;
create index if not exists idx_kombax_social_posts_audiencia_fed_fk_v100 on public.kombax_social_publicaciones(audiencia_federacion_social_id) where audiencia_federacion_social_id is not null;
create index if not exists idx_kombax_social_posts_social_media_fk_v100 on public.kombax_social_publicaciones(social_media_id) where social_media_id is not null;
create index if not exists idx_kombax_social_posts_media_fk_v100 on public.kombax_social_publicaciones(media_id) where media_id is not null;
create index if not exists idx_kombax_actor_audit_actor_fk_v100 on public.kombax_actor_audit(actor_perfil_id) where actor_perfil_id is not null;
create index if not exists idx_cuotas_club_tarifa_fk_v100 on public.cuotas(club_id,tarifa_id) where tarifa_id is not null;
create index if not exists idx_grupos_club_disciplina_fk_v100 on public.grupos(club_id,disciplina_id) where disciplina_id is not null;
create index if not exists idx_series_club_grupo_fk_v100 on public.series_sesiones(club_id,grupo_id) where grupo_id is not null;
create index if not exists idx_socio_disciplinas_club_disciplina_fk_v100 on public.socio_disciplinas(club_id,disciplina_id) where disciplina_id is not null;
create index if not exists idx_socio_disciplinas_club_grado_fk_v100 on public.socio_disciplinas(club_id,grado_id) where grado_id is not null;
create index if not exists idx_asistencias_club_socio_fk_v100 on public.asistencias(club_id,socio_id);
create index if not exists idx_registros_acceso_club_socio_fk_v100 on public.registros_acceso_clase(club_id,socio_id);
create index if not exists idx_tutores_club_socio_fk_v100 on public.tutores_socios(club_id,socio_id);
create index if not exists idx_evento_participantes_club_socio_fk_v100 on public.evento_participantes(club_id,socio_id) where socio_id is not null;
create index if not exists idx_material_pedidos_club_material_fk_v100 on public.material_pedidos(club_id,material_id);
create index if not exists idx_material_pedidos_club_socio_fk_v100 on public.material_pedidos(club_id,socio_id);
create index if not exists idx_material_pedidos_club_cuota_fk_v100 on public.material_pedidos(club_id,cuota_id) where cuota_id is not null;
create index if not exists idx_material_entregas_club_material_fk_v100 on public.material_entregas(club_id,material_id);
create index if not exists idx_preinscripciones_club_disciplina_fk_v100 on public.preinscripciones(club_id,disciplina_id) where disciplina_id is not null;
create index if not exists idx_preinscripciones_club_grupo_fk_v100 on public.preinscripciones(club_id,grupo_id) where grupo_id is not null;

notify pgrst,'reload schema';
