# KOMBAX build 20065 · Validation
## Role Invitations + Team Filter

Fecha: 2026-08-21

### Validación automatizada
- `npm test`: **PASS**.
- `npm run build`: **PASS**.
- Test específico `test-kombax-20065-role-invitations.mjs`: **PASS**.
- Build reproducido: **68 archivos**.
- Paridad: **web = dist = Android**.

### Validación backend 109
Preflight confirmado antes de aplicar:
- tablas de miembros, solicitudes y códigos presentes;
- contratos v060/v051 presentes;
- v109 ausente antes de la migración.

Después de aplicar 109:
- `app_kombax_equipo_solicitar_v109(text,text,text)`: presente;
- `app_kombax_solicitudes_equipo_v109(uuid)`: presente;
- columna `rol_solicitado`: presente;
- índice de solicitudes pendientes v109: presente;
- roles solicitados inválidos: 0.

### Prueba real transaccional sin persistencia
Con una sesión autenticada simulada y `ROLLBACK`:
- Equipo de Urban Warriors devolvió únicamente Dirección/Gestor.
- Los perfiles con rol Alumno no fueron devueltos.
- Un alumno existente pudo crear una solicitud **pendiente** para rol Monitor.
- El resultado conservó `rol_solicitado=monitor`.
- Tras rollback quedaron 0 solicitudes QA nuevas.

### Seguridad funcional
- El código de equipo no concede permisos.
- El rol de la invitación no concede permisos.
- La solicitud requiere revisión posterior.
- Coordinación solo puede ser concedida por Dirección/Gestor.
- Los contratos v109 son para usuarios autenticados y realizan validación interna de identidad/código.

### Advisors
Security Advisor y Performance Advisor ejecutados tras DDL.
No se detectó un bloqueo específico nuevo que invalide 109. Persisten avisos históricos del proyecto sobre funciones `SECURITY DEFINER`, políticas/índices y protección de contraseñas que deben gestionarse dentro de la auditoría transversal, no mediante cambios improvisados en esta release.

Referencias generales de Advisor:
- https://supabase.com/docs/guides/database/database-linter
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

### Pendiente para cierre móvil
Generar APK release signed con:
- `applicationId`: `com.urbanwarriors.app`
- `versionCode`: `20065`
- `versionName`: `2.0.0-rc.13`
- mismo JKS/alias de releases anteriores.
