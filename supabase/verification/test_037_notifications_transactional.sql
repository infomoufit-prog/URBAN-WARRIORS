-- Ejecutar autenticado con una cuenta de prueba y sustituir los UUID.
-- La transacción se revierte para no dejar datos.
begin;
-- select public.app_marcar_notificacion_leida('NOTIFICACION_UUID'::uuid);
-- select * from public.app_notificaciones_centro_v037('CLUB_UUID'::uuid,100);
rollback;
