# KOMBAX 20.110 R60 — MIGRATIONS GUIDE + HISTORY HARDENING

Base conservadora: **KOMBAX 20.109 R59**. R60 es aditiva y está preparada como candidata de estabilización QA; no implica despliegue automático.

## Implementado

### 1. Guía de migración exclusiva de Club y Federación
- Nueva guía `KOMBAX_GUIA_MIGRACIONES_CLUB_FEDERACION_R60.pdf`.
- El PDF **no está dentro de `web/`, `dist/` ni de los assets Android** y por tanto no queda publicado como asset estático.
- Nueva Edge Function `migration-guide-r60` que entrega el PDF únicamente después de validar `app_kombax_org_guide_access_r60`.
- Backend autorizado solo para:
  - Club: roles operativos ya admitidos por `org_assist_access_allowed` (`direccion`, `coordinacion`, `secretaria`, `economia`).
  - Federación: propietario del perfil directo activo `federacion` exacto.
- Miembro, Competidor, Marca, Profesional, Media/Creador y Espectador no reciben el módulo y el backend deniega el acceso aunque se intente invocar manualmente.
- Club: tarjeta **Guía de migración** dentro del perfil del Club.
- Federación: módulo **Guía de migración** dentro de Mi Federación.

### 2. Contexto organizativo exacto
- Club usa `club:<club_id>`.
- Federación usa `profile:<federation_profile_id>`.
- Nuevo RPC `app_kombax_customer_ops_tickets_r60` lista casos solo del tenant exacto.
- Se evita mezclar historial, archivos, cuotas de uso o conversaciones cuando una cuenta administra más de una organización/perfil.

### 3. Eliminación de conversaciones e historial
- Acción individual **Eliminar conversación** en Assist y Migrations.
- Acción **Borrar historial** para el contexto actual.
- Nueva Edge Function `kombax-history-delete-r60`:
  1. obtiene un plan de borrado autenticado y limitado al usuario + tenant;
  2. elimina primero los objetos físicos de `kombax-migration-staging`;
  3. finaliza el borrado de contenido en base de datos con RPC service-only.
- El borrado elimina mensajes, análisis, previews derivados, archivos, outbox/eventos del ticket, sesiones guiadas y el ticket.
- Se conserva solo auditoría mínima de borrado/consumo, sin texto, asunto, nombre de archivo ni ticket ID.
- `assistance_turns` se desacopla del contenido borrado (`ticket_id/session_id = null`) y conserva metering.
- **Borrar historial no devuelve cupos**: no se eliminan `assistance_periods`, `migration_allowance_cases` ni métricas de uso.
- Protección adicional contra lotes que mezclen tenants.
- Reintentos vacíos son idempotentes.

### 4. Flujo de migración/cuentas R59 preservado
R60 mantiene sin reescritura las reglas estabilizadas en R59:
- alta autónoma desde 16 años con email;
- menor de 16 mediante tutor, manteniendo la ficha administrativa propia del menor;
- alumno histórico/migrado puede permanecer temporalmente sin email y sin cuenta;
- activar KOMBAX vincula la ficha existente, no crea otro alumno;
- prevención de duplicados;
- reclamación de membresía para cuentas ya existentes con aprobación/rechazo del Club;
- multiclub aislado por membresía/Club.

### 5. Identidad de build
- Web build: `20110`.
- Service Worker: `uw2-build-20110`, revisión `r60-migrations-guide-history`.
- Android `versionCode 20110`.
- Android `versionName 2.0.0-rc.13-r60-migrations-guide-history`.
- User-Agent Android: `KOMBAXRevision/r60-migrations-guide-history ... /20110`.
- Health endpoint: build `20110`.

## Estado real del entorno al cierre del paquete (07/09/2026)
- Supabase live: migración `kombax_r60_migrations_guide_history` aplicada.
- Supabase live: hardening `kombax_r60_history_performance_hardening` aplicado.
- Supabase live: Edge Function `kombax-history-delete-r60` activa con `verify_jwt=true`.
- Supabase live: Edge Function `migration-guide-r60` **todavía no desplegada**; su código y el PDF profesional protegido sí están incluidos y validados en este ZIP.
- Netlify: no desplegado desde R60.
- GitHub: sin push R60.
- Android: sin firma release R60 y sin publicación APK/AAB R60.

R60 se entrega como candidata completa para continuar estabilización. No debe declararse production-ready hasta desplegar y validar la guía protegida, cerrar QA autenticada/RLS, revisar advisors pendientes y completar firma/smoke Android + Play Internal.
