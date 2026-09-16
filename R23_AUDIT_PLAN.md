# KOMBAX 20.101 R23 — AUDIT PLAN

## Objetivo
Auditar R23 sin modificar comportamiento para localizar causas raíz de inestabilidad de navegación en KOMBAX Events antes de crear R25 Pilot Stabilization.

## Alcance
Events: listado, detalle, tabs, Main Event, Co-Main/Fight Card, participantes, álbum, barra inferior, Me interesa/guardados, compartir, QR, resolución multimedia, lazy loading, lifecycle, cachés y llamadas backend relacionadas.

## Fuera de alcance
Nuevas features. Finanzas/Auth/Social/Showcase solo regresión posterior. Netlify/GitHub/versionCode/firma Android no se modifican durante auditoría.

## Síntomas reportados
1. Flashes negros durante scroll continuo en detalle de evento Android.
2. Flujo percibido menos estable/lento tras revisiones recientes.
3. Error al pulsar Me interesa: `Cannot set properties of null (setting 'textContent')`.
4. Historial reciente de imágenes Urban rotas, resuelto en R23.

## Hipótesis
- Rerender destructivo de secciones/media durante operaciones async.
- Handler async de interés conserva referencias DOM o busca nodos ya desmontados.
- Observers/listeners/timers sobreviven al lifecycle de la vista.
- Lazy hydration reemplaza contenido visible en vez de estabilizar el nodo.
- Carga/decodificación de imágenes en main thread produce huecos durante scroll.
- Repetición innecesaria de requests al reabrir/scroll.
- Interacción entre sticky action bar y rerender de detail.
- Problema backend solo si medición demuestra latencia/repetición real.

## Archivos/módulos a auditar
- `web/js/modules/kombax-events.js`
- `web/js/core/repositories.js`
- `web/js/core/backend.js`
- `web/js/app.js`
- CSS Events/global relacionado
- service worker/cache si interviene
- scripts/tests R22/R23/Events

## Riesgos frontend
DOM stale, race conditions, observers duplicados, listeners no limpiados, reflows/repaints pesados, cache sin límite, reconstrucción innecesaria.

## Riesgos backend
N+1, payload redundante, RPC no acotadas, URLs firmadas/resolución media repetida. No se tocará backend sin evidencia.

## Riesgos multiclub
Cualquier corrección debe ser genérica por IDs/permisos; prohibidas excepciones demo en lógica real. RLS/ownership se preservan.

## Riesgos de datos
Ningún DELETE/TRUNCATE/reseed. No modificar eventos, participantes, álbum o interés durante auditoría.

## Riesgos de memoria
Observers/listeners/timers/caches pueden acumularse tras entrar/salir repetidamente.

## Riesgos Android/WebView
Decode de imágenes, GPU texture eviction, DOM replacement, filtros/gradientes pesados, scroll + sticky layers.

## Metodología de reproducción
- Revisar vídeo y capturas aportadas.
- Instrumentación estática y dinámica local cuando sea posible.
- Seguir rutas `render/open/detail/interest/media` y lifecycle.
- Contar requests potenciales y puntos de rerender.
- Ejecutar pruebas existentes sin modificar producto.

## Métricas
- Número de render completos por apertura/interacción.
- Número de llamadas backend por detalle/interés/media.
- Número de observers/listeners creados y limpieza.
- Puntos que escriben `textContent` tras await.
- Puntos que reemplazan `innerHTML`/`replaceChildren` durante scroll.
- Caches y límites.
- Peso/dimensiones de assets demo usados en reproducción.

## Criterios de aceptación para intervención
- Causa raíz reproducida/identificada con evidencia de código o runtime.
- Solución mínima y estructural delimitada.
- Rollback claro.
- Sin dependencia demo.
- Regresión específica definida antes de editar.

## Estrategia de rollback
R23 ZIP original permanece inmutable. R25 se construirá en copia independiente. Backend R23 no se modifica salvo GO explícito derivado de auditoría.

## Criterio para retroceder implementación anterior
Si una técnica R22/R23 demuestra mayor complejidad/rerender sin beneficio medible, se permite reversión selectiva a una implementación anterior más simple y estable, preservando APIs/datos actuales.
