# CHANGELOG 20.101 R34 — KOMBAX Assist Migration + Mi preparación

## KOMBAX Assist · migración
- Nueva comunicación visible de “Te ayudamos a migrar” en Mi Club y hubs de identidades gestionadas.
- El selector de migración ya no es solo visual: crea ticket, sube de forma privada PDF/XLSX/XLS/CSV/JPG/PNG/WEBP y registra cada archivo contra el ticket.
- Staging privado `kombax-migration-staging`, máximo 10 MB por archivo y sin importación automática.
- Preview/revisión y confirmación siguen siendo obligatorios antes de cualquier importación.
- El soporte formal por `soporte@kombax.es` se conserva sin cambios.

## Mi preparación · peso de competición
- Nuevo módulo privado para perfil Competidor, miembro/alumno y Club.
- Preparación opcionalmente vinculada a KOMBAX Events.
- Registro de peso, fecha/hora, contexto, nota y foto privada opcional de báscula.
- Histórico, gráfica de evolución, objetivo/límite, cuenta atrás al pesaje y estado de actualización según frecuencia.
- Frecuencia semanal, tres veces por semana, diaria o personalizada.
- Acceso del entrenador/equipo/representación por permisos explícitos; revocable.
- Verificación de equipo y soporte backend para pesaje oficial.
- KOMBAX Events incorpora acceso de gestión a “Preparación y peso” cuando el organizador trabaja desde un Club.
- El peso nunca se expone en Social, Showcase ni perfil público.
- Se incluye aviso expreso: seguimiento deportivo, no asesoramiento médico ni protocolos de pérdida rápida/deshidratación.

## Backend
- `v216`: preparación, accesos, pesajes, RPCs y bucket privado de evidencia.
- `v217`: staging privado de migración y metadatos ticket-scoped.
- Migraciones aplicadas al Supabase principal.
