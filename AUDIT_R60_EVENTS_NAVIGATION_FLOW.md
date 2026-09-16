# Auditoría R60 · KOMBAX Events · Flujo de navegación

Base auditada: `KOMBAX_20110_R60_MIGRATIONS_GUIDE_HISTORY_QA_ANDROID_FIX_FRONTEND_UI_STABILIZED`.

## Alcance

Auditoría y corrección exclusivamente frontend del flujo `KOMBAX Eventos → cartelera → abrir evento → detalle`. No se modifica backend, Supabase, RPC, SQL, Edge Functions, Auth, RLS, Storage, Hermes, agentes ni la jerarquía de navegación global.

## Causas identificadas

1. **Primer render bloqueado por datos auxiliares.** `renderKombaxEvents()` esperaba contextos de organización e invitaciones antes de pintar la pantalla. Una latencia de esas llamadas se percibía como lentitud de toda la sección Events.
2. **Revalidación destructiva de la cartelera.** Tras pintar datos cacheados, la revalidación podía volver a asignar `innerHTML` a toda la lista incluso cuando el contenido efectivo no había cambiado. Esto podía provocar parpadeo, recarga visual de imágenes y pérdida de sensación de continuidad.
3. **Apertura de evento con dos esperas en serie.** El detalle esperaba el bundle del evento y después el roster de preparación competitiva antes de mostrar el modal. El segundo recurso no es necesario para el primer paint del detalle.
4. **Sin deduplicación/prefetch de detalle.** Una precarga y un click podían terminar solicitando el mismo detalle más de una vez. Además, un tap lento no tenía feedback inmediato suficientemente claro.

## Correcciones implementadas

- La pantalla de KOMBAX Events se pinta inmediatamente; contextos de organizador e invitaciones se resuelven en paralelo y actualizan únicamente sus slots.
- Se mantiene la cartelera cacheada al reentrar y se evita reconstruir su DOM cuando la revalidación devuelve el mismo estado efectivo.
- Se añade caché + deduplicación de solicitudes de detalle en vuelo.
- Se precarga el detalle en `pointerenter`, `focusin` y `pointerdown`; el click reutiliza la misma promesa si ya existe.
- Al abrir se marca la tarjeta/botón como ocupado. Si la red tarda, aparece un estado de apertura; ese mismo modal se transforma en el detalle final sin cerrar y abrir una segunda capa.
- El roster de preparación competitiva se hidrata después del primer paint del evento. Se descarta automáticamente si el usuario ya abrió otro evento o cerró/cambió la capa.
- Se conservan la recuperación/reintento, control de aperturas fuera de orden, cache de detalle y lazy loading de media existentes.

## Verificación de rutas

Todas las aperturas internas de evento (tarjeta, botón, teclado, retry, retorno desde preparación, preview del constructor y retorno tras mutaciones) convergen en `openEvent()`, por lo que reciben el mismo flujo estabilizado.

La landing pública por deep link mantiene su ruta separada y ya pinta el contenido antes de hidratar media, por lo que no se introdujo un refactor adicional.

## Restricciones respetadas

- Punto 7 / navegación global: **sin cambios**.
- `web/js/app.js`: **sin cambios**.
- `web/js/ui/components.js`: **sin cambios**.
- `web/js/core/repositories.js`: **sin cambios**.
- `web/js/core/backend.js`: **sin cambios**.
- `web/js/core/supabase.js`: **sin cambios**.
- `supabase/`: **sin cambios**.
- `android/app/build.gradle`: **sin cambios**.

