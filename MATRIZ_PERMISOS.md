# Matriz de permisos · RC9

| Área | Gestor de la app | Coordinación | Secretaría | Economía | Comunicación | Monitor | Familia/Alumno |
|---|---|---|---|---|---|---|---|
| Panel global | Sí | Sí | Sí | financiero | editorial | hoy | personal |
| Disciplinas | Sí | Sí | Sí | — | — | grados | — |
| Grupos | Sí | Sí | Sí | — | — | lectura/operativa | horarios propios |
| Alumnos | Sí | Sí | Sí | — | — | ámbito deportivo | propios/vinculados |
| Solicitudes/matrículas | Sí | Sí | Sí | — | — | — | solicitar |
| Sesiones | Sí | Sí | Sí | — | — | Sí | ver/reservar |
| Asistencia/check-in | Sí | Sí | Sí | — | — | Sí | check-in propio |
| Progreso/seguimiento | Sí | Sí | Sí | — | — | Sí | visible propio |
| Finanzas/pagos | Sí | Sí | operativa | Sí | — | — | propias |
| Avisos de cobro | Sí | Sí | Sí | Sí | — | — | recibe |
| Publicaciones | Sí | Sí | Sí | — | Sí | lectura | lectura según audiencia |
| Material/solicitudes | Sí | Sí | Sí | Sí | — | — | solicitar |
| Archivo documental | Sí | Sí | Sí | — | — | — | documentos autorizados |
| Personalización club | Sí | Sí | Sí | Sí | Sí | — | — |
| Ver equipo | Sí | Sí | Sí | según RLS | según RLS | según RLS | — |
| Invitar personal | **Sí** | **No** | No | No | No | No | No |
| Borrado total | **Sí** | **No** | No | No | No | No | No |
| Diagnóstico técnico | **Sí** | **No** | No | No | No | No | No |
| Certificación E2E | **Sí** | **No** | No | No | No | No | No |

## Nota técnica

`direccion` continúa siendo la clave interna del máximo nivel y se muestra siempre como **Gestor de la app**. `Coordinación` no recibe `direccion`; reutiliza de forma controlada permisos backend de `secretaria`, `economia` y `comunicacion`, que en UI se colapsan en un único rol.
