# Matriz RLS / acceso · RC13 build 20018

“Gateway” = escritura exclusivamente por `app_mutate_v160`; “RPC segura” = lectura sin SELECT directo de la tabla sensible.

## Cobertura CRUD explícita

La auditoría tenant debe revisar siempre **SELECT**, **INSERT**, **UPDATE** y **DELETE**. Cuando una celda indica `Gateway`, INSERT/UPDATE/DELETE directos quedan cerrados al cliente y la mutación autorizada se realiza mediante `app_mutate_v160`.

| Recurso / acción | Dirección | Coordinación | Secretaría | Economía | Comunicación | Monitor | Alumno | Familia |
|---|---|---|---|---|---|---|---|---|
| Finanzas 031 | Club | según permiso | Club | Club | — | — | propio | vinculados |
| Perfil deportivo 032 lectura | mismo club | mismo club | mismo club | mismo club | mismo club | mismo club | visibles mismo club | visibles mismo club |
| Perfil deportivo editar | Gateway | Gateway moderación | moderación según función | — | moderación según función | — | propio | menor vinculado |
| Likes | propio | propio | propio | propio | propio | propio | propio | propio |
| Eventos 033 gestión | Gateway | Gateway | Gateway | según permiso | según permiso | según permiso | solicitud | solicitud vinculada |
| Participantes/combates | RPC segura | RPC segura | RPC segura | RPC segura | RPC segura | RPC segura | lectura permitida | lectura permitida |
| Notificaciones informativas | propias/rol | propias/rol | propias/rol | propias/rol | propias/rol | propias/rol | propias | propias |
| Notificación accionable | **Revisar** | **Revisar** | **Revisar** | **Revisar** | **Revisar** | **Revisar** | **Revisar** si aplica | **Revisar** si aplica |
| Perfil público del club lectura | RPC campos públicos | RPC | RPC | RPC | RPC | RPC | RPC | RPC |
| Perfil público club editar | Gateway | Gateway | No | No | No | No | No | No |
| Identidad/búsqueda pública 035 | RPC segura | RPC | RPC | RPC | RPC | RPC | RPC | RPC |
| Activar Comunidad General 036 | no por rol | no por rol | no por rol | no | no | no | alumno elegible | **No** |
| Denunciar/bloquear | Sí | Sí | Sí | Sí | Sí | Sí | Sí | Comunidad interna según cuenta |
| Revisar denuncias | Sí | Sí | Sí | No | Sí | No | No | No |
| Suspender/reactivar acceso social | Sí | Sí | Sí | No | Sí | No | No | No |

## Garantías nuevas

- `perfiles_club_publicos`, `identidades_sociales`, `reportes_comunidad` y auditoría de suspensión no conceden SELECT directo al cliente cuando contienen estado interno.
- las tablas sociales de escritura no conceden DML directo; el gateway vuelve a validar club, rol, objeto e idempotencia;
- una lectura masiva de notificaciones nunca puede convertir una tarea accionable en leída;
- edad y rol social se verifican en backend desde el socio activo, no desde un valor manipulable del frontend;
- la suspensión social no revoca acceso administrativo al club.

La matriz debe validarse con sesiones reales antes del freeze.
