-- Emergency rollback for 087. Restores the immediate 20.045 client privilege baseline.
begin;

grant execute on function public.app_kombax_mis_perfiles_v043() to authenticated;
grant execute on function public.app_kombax_mis_solicitudes_v043() to authenticated;
grant execute on function public.app_diagnostico_v150(uuid) to anon, authenticated;
grant execute on function public.app_diagnostico_integridad_v152(uuid) to anon, authenticated;

grant execute on function public.actualizar_grado_actual() to public, anon, authenticated;
grant execute on function public.cleanup_reserva_sesion_notificaciones() to public, anon, authenticated;
grant execute on function public.crear_perfil_usuario() to public, anon, authenticated;
grant execute on function public.notificar_pago_validado() to public, anon, authenticated;
grant execute on function public.registrar_auditoria() to public, anon, authenticated;
grant execute on function public.registrar_cambio_tarifa() to public, anon, authenticated;
grant execute on function public.es_miembro_club(uuid) to public, anon;
grant execute on function public.puede_gestionar_socio(uuid) to public, anon;
grant execute on function public.puede_ver_socio(uuid) to public, anon;
grant execute on function public.tiene_rol_club(uuid, variadic public.rol_club[]) to public, anon;
grant execute on function public.generar_alertas_cuotas(uuid,integer) to public, anon;

-- Restore legacy public-role policy targets.
drop policy if exists clubes_gestion on public.clubes;
create policy clubes_gestion on public.clubes for update to public
  using (public.tiene_rol_club(id,'direccion')) with check (public.tiene_rol_club(id,'direccion'));
drop policy if exists clubes_publicos on public.clubes;
create policy clubes_publicos on public.clubes for select to public using (activo or public.es_miembro_club(id));
drop policy if exists disciplinas_gestion on public.disciplinas;
create policy disciplinas_gestion on public.disciplinas for all to public using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
drop policy if exists disciplinas_lectura on public.disciplinas;
create policy disciplinas_lectura on public.disciplinas for select to public using (public.es_miembro_club(club_id));
drop policy if exists grupos_gestion on public.grupos;
create policy grupos_gestion on public.grupos for all to public using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
drop policy if exists grupos_lectura on public.grupos;
create policy grupos_lectura on public.grupos for select to public using (((not public.app_kombax_es_monitor_restringido_v057(club_id)) and public.es_miembro_club(club_id)) or public.puede_ver_grupo(id));
drop policy if exists tarifas_gestion on public.tarifas;
create policy tarifas_gestion on public.tarifas for all to public using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));
drop policy if exists tarifas_lectura on public.tarifas;
create policy tarifas_lectura on public.tarifas for select to public using (public.es_miembro_club(club_id));
drop policy if exists legales_gestion on public.textos_legales;
create policy legales_gestion on public.textos_legales for all to public using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
drop policy if exists legales_lectura on public.textos_legales;
create policy legales_lectura on public.textos_legales for select to public using (public.es_miembro_club(club_id));

drop policy if exists ambitos_lectura_v057 on public.club_ambitos_trabajo;
create policy ambitos_lectura_v057 on public.club_ambitos_trabajo for select to authenticated
using (public.app_kombax_puede_gestionar_ambitos_v057(club_id) or exists(select 1 from public.club_ambito_equipo ae where ae.ambito_id=club_ambitos_trabajo.id and ae.club_id=ae.club_id and ae.perfil_id=auth.uid() and ae.activo));

drop policy if exists accesos_registro_usuario on public.registros_acceso_clase;
create policy accesos_registro_usuario on public.registros_acceso_clase
for insert to public
with check (
  public.puede_ver_socio(socio_id)
  and exists (
    select 1 from public.sesiones_entrenamiento s
    where s.id=registros_acceso_clase.sesion_id
      and s.club_id=s.club_id
      and s.fecha=current_date
      and s.estado<>'cancelada'
  )
);

-- Restore only the explicit direct anon grants observed immediately before 087.
grant select on public.asistencias,public.clubes,public.comunicaciones,public.config_club,public.configuracion_avisos_cuota,public.consentimientos,public.cuotas,public.disciplinas,public.dispositivos_push,public.documentos_socios,public.grados,public.graduaciones,public.grupos,public.historial_avisos_cuota,public.horarios_grupo,public.invitaciones_club,public.material_catalogo,public.material_entregas,public.material_pedidos,public.material_variantes,public.miembros_club,public.notificaciones,public.notificaciones_lecturas,public.pagos,public.perfiles,public.preinscripciones,public.recibos_cuota,public.registros_acceso_clase,public.seguimiento,public.sesiones_entrenamiento,public.socio_disciplinas,public.socios,public.tarifas,public.textos_legales,public.tutores_socios to anon;
grant select,insert,update,delete on public.auditoria,public.club_ambito_equipo,public.club_ambito_grupos,public.club_ambito_socios,public.club_ambitos_trabajo,public.descuentos,public.historial_tarifas,public.socio_descuentos,public.textos_legales to anon;

commit;
