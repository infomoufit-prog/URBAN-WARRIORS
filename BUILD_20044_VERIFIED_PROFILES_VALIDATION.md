# Validación build 20044 · Perfiles oficiales KOMBAX

Objetivo: certificar la arquitectura de perfiles oficiales aprobada para Club, Competidor, Marca y Federación.

Controles obligatorios: insignia no disponible para Miembro/Profesional; afiliación Miembro↔Club preservada; verificación y servicio independientes; documentación privada; solicitud específica por tipo; Competidor 16+; Contacto 18+; continuidad Social Miembro→Competidor; multigestor limitado por rol; RLS sin aperturas directas; Relaciones permanecen privadas; web/dist/Android idénticos.

Validación real Supabase: 0 Miembros con insignia; Club oficial conserva insignia; formularios Competidor/Marca/Federación validados transaccionalmente; upgrade Miembro→Competidor conserva el mismo ID Social al activar y desactivar servicio; pruebas transaccionales cerradas con ROLLBACK; helpers internos no expuestos a anon.
