# R105 · Owner Operations y Pilot Intelligence

## Cambios

- Dos chats internos integrados en el Owner existente.
- GPT-6 Luna con razonamiento bajo y medio.
- Mensaje Owner visible inmediatamente y estado de análisis.
- Análisis contextual de solicitudes de perfil y vendedor.
- Métricas agregadas como contexto de Pilot Intelligence.
- Persistencia privada y auditable.
- Preparación de informes diarios, semanales, de incidente y release gate.
- UI responsive para escritorio, tablet y móvil.

## Límites conocidos

- La generación y publicación automática de PDF queda sujeta al despliegue backend y revisión Owner.
- Las acciones críticas no se ejecutan desde el modelo.
- La validación en vivo queda pendiente hasta aplicar la migración y desplegar la función en Supabase.

## Rollback

Retirar el frontend R105 y la Edge Function deshabilita el uso. Las tablas privadas pueden conservarse para auditoría sin exposición al cliente.

