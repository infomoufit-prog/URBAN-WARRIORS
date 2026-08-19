-- KOMBAX 20.046 / 092
-- Internalize SECURITY DEFINER helpers that are not called directly by either
-- 20.045 or 20.046 clients and are not referenced by RLS/Storage policies.
-- service_role remains allowed for operational/Edge-function compatibility.
begin;

revoke execute on function public.app_kombax_social_avatar_path_v058(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_social_banner_path_v058(uuid) from public,anon,authenticated;
revoke execute on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon,authenticated;
revoke execute on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) from public,anon,authenticated;
revoke execute on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) from public,anon,authenticated;
revoke execute on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) from public,anon,authenticated;
revoke execute on function public.app_kombax_monitor_puede_asistencia_v057(uuid) from public,anon,authenticated;
revoke execute on function public.app_marcar_notificacion_leida(uuid) from public,anon,authenticated;
revoke execute on function public.app_notificacion_requiere_accion_v034(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_club_permiso_v051(uuid,text) from public,anon,authenticated;
revoke execute on function public.app_kombax_codigo_validar_seguro_v086(text,text,text) from public,anon,authenticated;
revoke execute on function public.app_puede_publicar_branding_v039(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_finance_level_socio_v057(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_showcase_ensure_brand_v048(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_showcase_ensure_club_v045(uuid) from public,anon,authenticated;
revoke execute on function public.app_puede_gestionar_ciclo_v038(uuid) from public,anon,authenticated;
revoke execute on function public.app_puede_moderar_comunidad_v036(uuid) from public,anon,authenticated;
revoke execute on function public.app_puede_moderar_perfil_deportivo_v032(uuid) from public,anon,authenticated;
revoke execute on function public.app_comunidad_general_estado_v036(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_capacidad_club_v041(uuid,text) from public,anon,authenticated;
revoke execute on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) from public,anon,authenticated;
revoke execute on function public.app_kombax_monitor_puede_asistencia_socio_v057(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_showcase_mis_marcas_v042() from public,anon,authenticated;
revoke execute on function public.app_kombax_social_contactos_v041() from public,anon,authenticated;
revoke execute on function public.app_mis_contextos_kombax_v040() from public,anon,authenticated;
revoke execute on function public.app_multiclub_audit_v030() from public,anon,authenticated;
revoke execute on function public.app_perfil_club_publico_v035(uuid) from public,anon,authenticated;
revoke execute on function public.generar_alertas_cuotas(uuid,integer) from public,anon,authenticated;
revoke execute on function public.puede_gestionar_socio(uuid) from public,anon,authenticated;

-- Preserve operational service access. SECURITY DEFINER gateways owned by postgres
-- do not depend on these grants, but Edge/service jobs may.
grant execute on function public.app_kombax_social_avatar_path_v058(uuid) to service_role;
grant execute on function public.app_kombax_social_banner_path_v058(uuid) to service_role;
grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to service_role;
grant execute on function public.app_guardar_asistencia(uuid,uuid,public.estado_asistencia,text) to service_role;
grant execute on function public.app_guardar_comunicacion(uuid,uuid,text,text,text,text,text,timestamptz,text,text) to service_role;
grant execute on function public.app_guardar_seguimiento(uuid,uuid,text,text,public.visibilidad_seguimiento,date) to service_role;
grant execute on function public.app_kombax_monitor_puede_asistencia_v057(uuid) to service_role;
grant execute on function public.app_marcar_notificacion_leida(uuid) to service_role;
grant execute on function public.app_notificacion_requiere_accion_v034(uuid) to service_role;
grant execute on function public.app_kombax_club_permiso_v051(uuid,text) to service_role;
grant execute on function public.app_kombax_codigo_validar_seguro_v086(text,text,text) to service_role;
grant execute on function public.app_puede_publicar_branding_v039(uuid) to service_role;
grant execute on function public.app_kombax_finance_level_socio_v057(uuid) to service_role;
grant execute on function public.app_kombax_showcase_ensure_brand_v048(uuid) to service_role;
grant execute on function public.app_kombax_showcase_ensure_club_v045(uuid) to service_role;
grant execute on function public.app_puede_gestionar_ciclo_v038(uuid) to service_role;
grant execute on function public.app_puede_moderar_comunidad_v036(uuid) to service_role;
grant execute on function public.app_puede_moderar_perfil_deportivo_v032(uuid) to service_role;
grant execute on function public.app_comunidad_general_estado_v036(uuid) to service_role;
grant execute on function public.app_kombax_capacidad_club_v041(uuid,text) to service_role;
grant execute on function public.app_kombax_relacion_tipo_valido_v045(uuid,uuid,text) to service_role;
grant execute on function public.app_kombax_monitor_puede_asistencia_socio_v057(uuid) to service_role;
grant execute on function public.app_kombax_showcase_mis_marcas_v042() to service_role;
grant execute on function public.app_kombax_social_contactos_v041() to service_role;
grant execute on function public.app_mis_contextos_kombax_v040() to service_role;
grant execute on function public.app_multiclub_audit_v030() to service_role;
grant execute on function public.app_perfil_club_publico_v035(uuid) to service_role;
grant execute on function public.generar_alertas_cuotas(uuid,integer) to service_role;
grant execute on function public.puede_gestionar_socio(uuid) to service_role;

notify pgrst,'reload schema';
commit;
