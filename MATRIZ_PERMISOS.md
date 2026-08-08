# Matriz de permisos de interfaz

El backend es siempre la autoridad final. Esta matriz controla qué acciones se muestran en el frontend reconstruido.

| Capacidad | Dirección | Secretaría | Economía | Comunicación | Monitor |
|---|---:|---:|---:|---:|---:|
| Disciplinas | ✓ | ✓ | | | |
| Grados | ✓ | ✓ | | | ✓ |
| Grupos | ✓ | ✓ | | | |
| Alumnos | ✓ | ✓ | | | |
| Matrículas | ✓ | ✓ | | | |
| Graduaciones | ✓ | ✓ | | | ✓ |
| Tarifas | ✓ | | ✓ | | |
| Cuotas: generar | ✓ | | ✓ | | |
| Pagos: administración | ✓ | ✓ | ✓ | | |
| Avisos de cobro | ✓ | ✓ | ✓ | | |
| Material | ✓ | ✓ | ✓ | | |
| Comunicaciones | ✓ | | | ✓ | |
| Sesiones | ✓ | ✓ | | | ✓ |
| Asistencia / check-in | ✓ | ✓ | | | ✓* |
| Seguimiento | ✓ | ✓ | | | ✓* |
| Documentos de alumnos | ✓ | ✓ | | | |
| Invitaciones | ✓ | | | | |
| Configuración club | ✓ | ✓ | ✓ | ✓ | |
| Certificación E2E | ✓ | | | | |

`*` El backend aplica además el ámbito/asignación real del monitor.

Familia y alumno disponen de navegación restringida y las políticas RLS determinan los registros que pueden leer/comunicar.
