# QA HANDOFF · KOMBAX 20.101 R44 · COMBAT EVENTS

## Objetivo
Validar manualmente, con sesión autenticada de Urban Warriors, que los cambios R44 eliminan cortes, dead-clicks, estado obsoleto y bloqueos de edición en condiciones reales de UI.

## Checklist prioritario
1. Entrar con un usuario de Urban Warriors con permiso real de gestión de Events.
2. Abrir `Urban Warriors · Interclub de Jiu-Jitsu · Palafolls` desde cartelera.
3. `Gestionar evento` → `Editar ficha` → guardar sin cambiar nada.
   - Debe conservar organizador/workspace.
   - No debe aparecer error de permiso/entitlement.
   - No debe bloquearse por cartel/banner demo.
4. Repetir edición cambiando un campo inocuo (p. ej. descripción) y guardar.
   - La ficha debe reaparecer inmediatamente con el dato nuevo.
   - No debe esperar a que discovery reconstruya la cartelera.
5. Editar Fight Card / un combate y volver al detalle.
   - El cambio debe verse inmediatamente, sin versión anterior de caché.
6. Abrir participantes y cambiar/editar un dato permitido; volver al detalle.
   - No debe reaparecer el estado anterior.
7. Abrir/cerrar `Gestionar evento` repetidamente; cerrar modal con back/cierre y abrir otro evento.
   - No debe quedar scrim, body bloqueado, menú fantasma ni listeners dobles.
8. Hacer dos clics rápidos en eventos diferentes.
   - Debe quedar abierto el evento correspondiente al último clic, no una respuesta antigua.
9. Cambiar una visibilidad/estado en un caso QA que haga que el evento deje de cumplir el filtro actual.
   - El detalle/gestión no debe depender de que siga presente en discovery.
10. Abrir gestor de álbum del demo.
   - Debe administrar solo media persistida real.
   - Las imágenes locales de presentación no deben consumir cuota ni aparecer como registros borrables falsos.
11. Repetir los puntos críticos en móvil/Android/PWA: scroll, back, cerrar modal, reabrir, navegación inferior.

## Gate recomendado
R44 puede congelarse para piloto solo si el checklist anterior pasa con sesión real y no aparecen errores de consola/red asociados a `event.save`, bundle, visibility, participantes, fights o media.

Si aparece un fallo, registrar: usuario/rol, evento, acción exacta, hora, mensaje UI, request/RPC si es visible y captura. Corregir sobre R44 en revisión aislada; no volver a R43 salvo regresión demostrada.
