# KOMBAX 20.101 R23 — AUDIT REPORT

## Alcance y evidencia
Base auditada: ZIP R23 original, sin cambios de producto durante la auditoría.
Evidencia de usuario: vídeo `97622.mp4` (15.184 s) y captura del error de `Me interesa`.
Baseline automatizada: R22 30/30 PASS; R23 15/15 PASS.

## Resultado ejecutivo
**GO controlado para R25 Pilot Stabilization**, limitado a causas demostradas de frontend/lifecycle. **NO-GO para cambios backend**: el síntoma de flash se reproduce sobre media demo local empaquetada, por lo que Supabase no puede ser la causa primaria del caso Urban observado.

| Síntoma | Reproducido / evidencia | Causa raíz | Frontend/Backend | Riesgo | Solución propuesta | Regresión necesaria |
|---|---|---|---|---|---|---|
| `Me interesa` lanza `Cannot set properties of null (setting 'textContent')` | Sí, captura + código R23 línea del handler | El listener async consulta `event.currentTarget` después de `await`; fuera del tramo síncrono `currentTarget` es `null` | Frontend | P0 | Capturar el botón antes del primer `await`; deshabilitar mientras muta; actualizar solo si sigue conectado; restaurar en error | Test específico async currentTarget + estado/reintento |
| Vídeo externo de Events tiene el mismo patrón latente en error | Código | Usa `button.currentTarget` después de `await` en catch | Frontend | P0 latente | Capturar botón antes de await | Test estático de clase causal |
| Showcase Guardar tiene el mismo patrón latente | Código | Usa `e.currentTarget` después de `await toggleSaved` | Frontend | P0 latente piloto | Capturar botón antes de await y comprobar conexión | Regresión Showcase |
| Flashes/jank durante scroll del detalle Urban | Reporte físico + auditoría de código. El vídeo confirma scroll continuo con las imágenes disponibles; el flash es demasiado breve para atribuirlo a una pérdida de URL en los fotogramas muestreados | Composición móvil cara: modal fullscreen con `backdrop-filter: blur(8px)` sobre fondo animado + filtros/transiciones/animaciones por Fight Card. Esto afecta WebView aun con media local | Frontend/compositor | P1 alto | En detalle Events móvil: eliminar backdrop blur, reducir filtros/animaciones de tarjetas/imagenes sin alterar diseño estructural | Prueba Android física + CSS/test estático |
| Álbum ejecuta trabajo en ráfaga a los 1.4 s | Sí, código `hydrateEventMedia` | IntersectionObserver desconecta y fuerza hidratación de **todas** las cards no visibles tras 1400 ms | Frontend | P1 alto / escala | Eliminar el forced hydrate-all; hidratar únicamente proximidad al viewport | Test de ausencia de timeout global |
| Apertura de detalle espera la inicialización completa del hidratador antes de enlazar acciones | Sí, `await hydrateEventMedia(wrap)` precede a bindings | Acopla interactividad del detalle a pipeline media | Frontend | P1 | Registrar acciones inmediatamente y lanzar hidratación no bloqueante | Test de orden/binding |
| Hydration reemplaza el stage antes de saber si la imagen está lista | Sí, `stage.innerHTML=Preparando…`, luego `replaceChildren(media)` inmediatamente después de asignar src | Existe ventana en que el nodo de imagen está presente pero no decodificado; reintento vuelve a vaciar stage | Frontend | P1 | Pipeline idempotente: mantener placeholder estable, cargar/decodificar fuera del DOM y sustituir solo cuando está listo; no volver a blank si ya está resuelto | Test estructural + físico Android |
| Observer puede conservar cards si modal se cierra antes de hidratar todas | Sí, no existe hook de cierre que desconecte observer | Lifecycle incompleto del modal | Frontend/memoria | P1 | Emitir evento de cierre del modal; desconectar observer y evitar mutar nodos desconectados | Test lifecycle |
| Cache de detalle crece sin límite durante la sesión | Sí, `eventDetailCache=new Map()` sin cap | Cache TTL pero sin límite de cardinalidad | Frontend/memoria | P1 escala | Límite LRU/simple de 24 detalles manteniendo TTL | Test de límite |
| Backend como causa primaria del flash Urban | Refutado para el caso observado | R23 prioriza assets demo locales dentro de APK para esos peleadores/álbum | No backend | — | No modificar Supabase para resolver este síntoma | Verificación de que R25 no añade migraciones/RPC |

## Auditoría de navegación / render

### `openEvent`
- Abre el detalle con `openDetail` y crea un scroll container grande.
- Después ejecuta `await hydrateEventMedia(wrap)` antes de terminar de enlazar acciones del detalle.
- El modal móvil hereda `backdrop-filter: blur(8px)` de `.modal-layer`.
- Fight Cards aplican `filter:saturate/contrast`, transiciones de transform/filter, sombras y animación del VS.

### `hydrateEventMedia`
- Cada card comienza con reemplazo destructivo del stage.
- La imagen se inserta inmediatamente al DOM después de asignar `src`, sin esperar `load/decode`.
- Si falla, vuelve a invocar el hidratador y vuelve a sustituir el stage.
- El observer utiliza `rootMargin: 280px` pero tras 1400 ms desconecta y fuerza todas las cards restantes. En un álbum de 30 fotos esto puede disparar una ráfaga de resoluciones/cargas fuera de viewport.
- No existe cleanup explícito si el modal se elimina antes de terminar.

### Modal lifecycle
`closeModal()` elimina directamente `#modal-layer` sin notificación a tareas asíncronas/observers. Las Promises pueden terminar después y conservar referencias a nodos desmontados.

## Auditoría backend
R23 usa para detalle el bundle existente `app_kombax_evento_bundle_v189` con fallback histórico y una lectura de framing de participantes. La media privada real se resuelve bajo demanda mediante `event-media-url`.

Para el caso Urban reportado, los assets demo prioritarios son rutas locales. Por ello no se justifica otra intervención de Supabase para eliminar el flash.

**Decisión:** R25 no añadirá migraciones, RPC ni Edge Functions.

## Auditoría de memoria
Problemas concretos detectados:
1. `eventDetailCache` tiene TTL pero no límite de entradas.
2. `IntersectionObserver` no tiene hook de cleanup al cerrar modal.
3. Async handlers pueden terminar sobre nodos ya desmontados.

R25 debe resolver estos tres puntos sin crear un sistema de lifecycle paralelo.

## Demos vs contenido real
La corrección de lifecycle/render será genérica y no dependerá de nombres/IDs/slugs demo. El único comportamiento demo existente que se conserva es el routing de assets R23, necesario para las fixtures actuales y eliminable junto con ellas posteriormente.

## Cambios R25 autorizados por evidencia
1. Fix async target (`Me interesa`, vídeo externo Events, Guardar Showcase por misma causa exacta).
2. Lifecycle de modal: evento de cierre no destructivo para cleanup de observers.
3. Hydration media estable/idempotente y no bloqueante.
4. Eliminar forced hydrate-all de 1.4 s.
5. Desconectar observer al cerrar detalle.
6. Límite de cache de detalle.
7. Reducción de coste del compositor exclusivamente en detail Events móvil.
8. Tests R25 específicos y regresión completa.

## Cambios NO autorizados
- Backend/Supabase.
- Nuevos caches de URLs o RPC batch.
- Cambios de datos/seeds.
- Cambios de funcionalidad Events/Finance/Auth.
- Netlify/GitHub/versionCode.

## Criterios R25 de cierre
- `Me interesa` no accede a `currentTarget` después de await.
- No quedan patrones equivalentes conocidos en Events/Showcase auditados.
- Hydration no fuerza media fuera de viewport por timeout.
- Media se sustituye tras estar lista, no antes.
- Observer se desconecta en cierre de modal.
- Cache detalle <= 24 entradas.
- R22/R23 preservados.
- R25 dedicado PASS.
- `npm test` global EXIT 0.
- build + paridad web/dist/Android.
- Android físico Zero-Flash seguirá marcado PENDIENTE hasta prueba del usuario.
