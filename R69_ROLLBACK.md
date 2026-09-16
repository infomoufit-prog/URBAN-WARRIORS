# KOMBAX R69 · Rollback

## Frontend

R69 parte de R68 build 20119. Para revertir la capa visual basta restaurar los archivos R68 de:

- `web/js/modules/kombax-events.js`
- `web/js/core/repositories.js`
- `web/css/kombax-premium.css`
- versión/configuración Web/Android/Service Worker
- `dist/**`
- `android/app/src/main/assets/www/**`

## Supabase

R69 añade una RPC de lectura privada y no altera tablas ni datos existentes.

La función nueva es:

`public.app_kombax_event_center_list_r69(integer)`

Si hubiera que retirar R69, se puede revocar su uso o eliminar únicamente esa función después de volver el frontend a R68. No deben revertirse las migraciones R65-R68 ni la infraestructura de Ticketing existente.

## Health

El health público se versionó a build 20120. Si se vuelve a R68, restaurar build 20119 en la función `health`.
