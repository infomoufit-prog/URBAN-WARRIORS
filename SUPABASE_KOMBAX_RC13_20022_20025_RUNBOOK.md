# Runbook Supabase · KOMBAX builds 20022–20025

## Estado de partida

Este paquete contiene migraciones nuevas 037–042. No se han ejecutado contra el proyecto Supabase remoto durante la implementación. No continuar si la copia de seguridad, el entorno o la autorización no están confirmados.

## Reglas

- Ejecutar una migración cada vez y detenerse ante el primer `FAIL` o error.
- Copiar y conservar la salida de preflight, migración, verify y test.
- No ejecutar `supabase/fixtures/040_demo_clubs.sql` ni `supabase/fixtures/load/*` en producción.
- No usar rollbacks para “probar”; solo ante incidencia confirmada y siempre en orden inverso.
- No desactivar RLS ni conceder acceso directo para superar una prueba.

## Secuencia exacta

Para cada número, ejecutar en este orden:

| Fase | Preflight | Migración | Verificación | Prueba transaccional |
|---|---|---|---|---|
| 037 Notificaciones | `preflight_037_notifications.sql` | `037_notification_read_consistency.sql` | `verify_037_notifications.sql` | `test_037_notifications_transactional.sql` |
| 038 Ciclo de contenido | `preflight_038_lifecycle.sql` | `038_content_lifecycle.sql` | `verify_038_lifecycle.sql` | `test_038_lifecycle_transactional.sql` |
| 039 Branding | `preflight_039_branding.sql` | `039_club_branding_themes.sql` | `verify_039_branding.sql` | `test_039_branding_transactional.sql` |
| 040 Puerta/contextos | `preflight_040_gateway.sql` | `040_kombax_gateway_multiclub.sql` | `verify_040_gateway.sql` | `test_040_gateway_transactional.sql` |
| 041 KOMBAX Social | `preflight_041_kombax_social.sql` | `041_kombax_social_alpha.sql` | `verify_041_kombax_social.sql` | `test_041_kombax_social_transactional.sql` |
| 042 Showcase | `preflight_042_showcase.sql` | `042_kombax_showcase.sql` | `verify_042_showcase.sql` | `test_042_showcase_transactional.sql` |

Los preflight/verify/test están en `supabase/verification`; las migraciones, en `supabase/migrations`.

## Pruebas funcionales posteriores

- Un usuario con dos clubes cambia de tenant sin arrastrar datos, permisos, notificaciones o caché.
- Un usuario de club A no puede consultar socios, cuotas, asistencia, documentos ni Comunidad del Club B.
- Notificaciones informativas persisten como leídas y el contador baja sin recargar.
- Archivo/papelera restaura durante 30 días y no incluye finanzas.
- Branding publica una versión y restaura otra.
- KOMBAX Social: adulto publica/like/contacta; menor elegible no puede enviar ni recibir contacto; bloqueo/denuncia funcionan.
- KOMBAX Showcase: público lee solo publicado; gestor modifica su marca; usuario normal no publica; enlaces no HTTPS son rechazados.

## Rollback

Si 042 ya está aplicada, revertir 042 antes de 041; continuar 040, 039, 038 y 037 en orden descendente solo si es necesario. Los rollbacks 038, 039, 041 y 042 son conservadores y priorizan no destruir datos. Documentar toda reversión.
