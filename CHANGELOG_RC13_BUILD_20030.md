# CHANGELOG · KOMBAX RC13 build 20030

Fecha: 2026-08-17
Base: build 20029 IMPLEMENTED

## Privacidad por monitor y ámbitos de trabajo

- Nuevo modelo **Ámbitos y privacidad** para separar alumnos, grupos y capacidades entre varios monitores del mismo club.
- Un ámbito puede contener varios monitores, alumnos y grupos; un alumno puede pertenecer a varios ámbitos y tener un único ámbito principal activo.
- Compatibilidad con la asignación histórica `monitor_principal_id`: los grupos ya asignados siguen funcionando durante la transición.
- El monitor deja de heredar acceso a la ficha administrativa completa por el helper genérico `puede_ver_socio()`.
- Nueva proyección segura `Mis alumnos`: nombre, edad calculada, actividad/grupos, estado y contacto solo si el ámbito lo autoriza.
- Documentos privados de socios y Storage `member-documents` dejan de depender del acceso deportivo del monitor.
- Recibos y datos administrativos permanecen fuera del alcance del monitor salvo capacidades financieras explícitas.

## Privacidad financiera

Niveles configurables por ámbito/monitor:

- `none`: sin información financiera.
- `status`: solo estado/vencimiento; importes y recibos ocultos.
- `portfolio`: cartera de sus alumnos con importes/saldo.
- `collect`: cartera + registro controlado de cobros.
- `receipts`: cartera + cobros + referencia de recibos disponibles.

El registro de cobro pasa por RPC `app_kombax_monitor_cobro_v057`, comprueba ámbito, nivel financiero, importe, saldo y deja auditoría/notificación.

## Operativa deportiva

- Asistencia y check-in limitados al alumno y grupo autorizados y a `gestionar_asistencia`.
- Seguimiento y graduaciones limitados a alumnos del ámbito y a `gestionar_seguimiento`.
- Reservas y series de sesiones ya no son globalmente visibles para cualquier monitor del club.
- Mutaciones de series/excepciones/recurrentes quedan protegidas por el wrapper de gateway 057 y devuelven `MONITOR_SCOPE_REQUIRED` fuera de ámbito.
- Generación recurrente mantiene capacidad global para Dirección/Secretaría/service_role y se restringe a grupos propios para monitores.

## UI

- Nueva ruta **Ámbitos y privacidad** para Gestor/Coordinación.
- Gestión de miembros del equipo, alumnos, grupos, responsable, visibilidad de contacto, asistencia, seguimiento y nivel financiero.
- Monitor: navegación contextual **Mis alumnos / Mis grupos / Mi cartera**.
- `Mis alumnos` no ofrece expediente, documentos ni controles administrativos.
- `Mi cartera` adapta columnas y acciones al nivel financiero autorizado.

## Backend

Se añade el ciclo:

- `057_club_work_scopes_finance_privacy.sql`
- `preflight_057_work_scopes.sql`
- `verify_057_work_scopes.sql`
- `test_057_work_scopes_transactional.sql`
- `057_club_work_scopes_finance_privacy_rollback.sql`

No se reescriben 051–055. Como 056 todavía no está aplicado al remoto, su release contract refleja build 20030.

## Validación local

- `npm test`: PASS.
- `npm run build`: PASS.
- `71 archivos · web = dist = Android`.
- JS modificado/nuevo: `node --check` PASS.
- SQL 057/rollback: transacciones y delimitadores estáticos PASS; sin conflicto `position`.
- Smoke local: HTTP 200 y assets `?v=20030`.
- Android preflight: 3/5; faltan únicamente `google-services.json` real y configuración JKS local.
