# KOMBAX RC13 build 20.097 · Events Workspace Isolation — Validation

## Resultado
PASS funcional y de regresión.

## Caso Urban Warriors auditado
- Urban Warriors existe como club activo con perfil Social público activo.
- La cuenta de Dirección auditada tiene una única membresía activa de club en Urban Warriors y además un perfil directo Federación QA verificado.
- En 20.096 el lector global de organizadores podía devolver ambas identidades y la Federación podía quedar primera por ordenación.
- 20.097 sustituye ese comportamiento dentro del workspace Club por `app_kombax_eventos_organizador_contexto_v171(p_club_id)`.
- Dentro de Urban Warriors solo puede devolverse el perfil público de Urban Warriors.
- La gestión de un evento se revalida con `app_kombax_evento_contexto_gestion_v171(evento_id, club_id)`.
- Las invitaciones se filtran con `app_kombax_eventos_invitaciones_contexto_v172(club_id)`.
- Las mutaciones envían `workspace_club_id` y el gateway v171 bloquea cruces club ↔ perfil directo.

## Backend real
- Migración 171 aplicada: PASS.
- Migración 172 aplicada: PASS.
- anon EXECUTE en RPC privadas nuevas: false.
- authenticated EXECUTE en gateway v171: true.
- Urban Warriors `events.public.organize`: deliberadamente false hasta POST-DEPLOY de 20.097.

## QA
- `npm test`: PASS completo hasta 20.097.
- `npm run build`: PASS.
- web = dist = Android: 102 archivos.
- `release:legal-gate`: PASS.
- Android preflight: 4/5; firma local pendiente de restaurar mediante `LOCAL_RELEASE_SIGNING`, sin contraseñas dentro del ZIP.

## Activación piloto segura
Después de desplegar 20.097, ejecutar `POSTDEPLOY_ENABLE_URBAN_WARRIORS_EVENTS_20097.sql`. No activa la capacidad globalmente para Club Básico; solo añade un entitlement promocional al club `urban-warriors`.
