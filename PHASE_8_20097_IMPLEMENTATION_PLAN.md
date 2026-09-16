# Fase 8 · build 20.097 — Events Workspace Isolation

## Objetivo
Aislar la identidad organizadora de KOMBAX Eventos por workspace. Entrar desde Urban Warriors debe permitir actuar únicamente como Urban Warriors; un perfil Federación de la misma cuenta no puede aparecer ni otorgar gestión en ese contexto.

## Plan previo
1. Mantener 20.096 inmutable como base.
2. Añadir RPC de organizador contextual por `club_id`.
3. Añadir gate de gestión contextual por evento + club.
4. Crear gateway v171 que transporte `workspace_club_id` y bloquee `club ↔ perfil_directo` cruzados.
5. Conservar el dominio público de Eventos y la separación total con `Mi Club > Eventos`.
6. Preparar activación piloto de `events.public.organize` para Urban Warriors como paso POST-DEPLOY, no global para Club Básico.
7. Ejecutar regresión completa y build determinista.

## Riesgos a bloquear
- Crear accidentalmente como Federación QA desde el workspace Urban Warriors.
- Mostrar botones de gestión de un evento de otra identidad por compartir la misma cuenta.
- Conceder `events.public.organize` a todos los clubes Basic.
- Mezclar `eventos_competicion` con `kombax_eventos_publicos`.

## Criterio de cierre
Urban Warriors y Federación pueden pertenecer a la misma cuenta, pero nunca aparecen como organizadores simultáneos dentro del workspace Urban Warriors.
