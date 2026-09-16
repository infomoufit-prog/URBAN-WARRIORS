# Changelog · R60 Events Navigation Flow Stabilization

## Runtime frontend

### `web/js/modules/kombax-events.js`
- First paint de Events ya no espera organizer contexts/invitations.
- Revalidación de discovery evita repaint destructivo cuando los datos efectivos no cambian.
- Deduplicación de detalle en vuelo.
- Prefetch de detalle por hover/focus/touch-down.
- Estado visual `aria-busy` al abrir.
- Feedback retardado para aperturas lentas, transformado in-place en el detalle final.
- `competitionPreparation.eventRoster()` sale del critical path y se hidrata después del detalle.
- Guardas de secuencia/conexión para impedir que una respuesta tardía reabra o sobrescriba otro evento.

### `web/css/kombax-events.css`
- Feedback visual de apertura de tarjeta/evento.
- Spinner accesible y compatible con `prefers-reduced-motion`.
- Estado de carga responsive.
- Slot de acción del organizador compatible con render progresivo.

## Generados

`scripts/build.mjs` sincroniza los mismos cambios a:
- `dist/`
- `android/app/src/main/assets/www/`

## No modificado

Backend, Supabase, SQL, RPC, Edge Functions, RLS, Auth, Storage, Hermes, agentes, routing global y navegación del punto 7.
