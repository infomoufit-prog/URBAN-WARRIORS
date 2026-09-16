# AUDITORÍA COMBAT EVENTS · KOMBAX 20.101 R44

## Conclusión ejecutiva
Borrar los eventos demo **no solucionaba por sí solo** los fallos observados. La auditoría encontró dos clases de problemas:

1. **Defectos generales del flujo Events**, capaces de afectar también a eventos creados normalmente desde el portal.
2. **Incompatibilidades específicas de los seeds demo**, principalmente por recursos visuales locales y media sintética de presentación.

R44 corrige ambos grupos sin modificar el esquema/backend de Events.

## Hallazgos generales corregidos
- **Dead click al abrir**: `openEvent()` dependía de que el evento siguiera presente en la caché de discovery. Si un cambio de estado/visibilidad/filtro lo sacaba de la cartelera, el clic podía no hacer nada. R44 resuelve el detalle por ID independientemente de discovery y muestra error explícito si ya no es accesible.
- **Edición sin identidad organizadora**: `Organiza como` está deshabilitado al editar. Los controles HTML `disabled` no forman parte de `FormData`, por lo que el guardado podía llegar sin `sujeto_tipo/sujeto_id`. R44 conserva/resuelve la identidad organizadora activa antes de enviar `event.save`.
- **Contexto de Club demasiado genérico**: ahora se prioriza el contexto cuyo `sujeto_id` coincide exactamente con el workspace activo.
- **Detalle obsoleto**: existía una caché de detalle de hasta ~60 s sin invalidación uniforme tras mutaciones. R44 centraliza la invalidación después de cambios de evento, Fight Card, resultados, participantes, media, framing, visibilidad y partners.
- **Corte tras guardar**: el flujo esperaba a reconstruir discovery antes de reabrir. R44 refresca discovery en paralelo y abre directamente por ID con detalle forzado.
- **Clicks rápidos fuera de orden**: dos aperturas asíncronas podían resolver en orden inverso. R44 incorpora secuencia de apertura y descarta respuestas obsoletas.
- **Listeners del menú de gestión**: el menú podía conservar listeners globales si el modal se cerraba/reemplazaba. R44 limpia listeners, scrim, ARIA y estado de `body` en `kx:modal-before-close`.

## Hallazgos específicos de los demos corregidos
- Los carteles/banners demo se guardan como rutas locales `./assets/...`. Esas rutas no son URLs absolutas válidas para un `input[type=url]` y podían bloquear validación del editor. R44 no coloca esas rutas en el control URL, pero preserva el recurso demo existente si no se reemplaza.
- El gestor de álbum mezclaba media sintética/local usada para presentar el demo con media realmente persistida. R44 mantiene la presentación demo, pero el **gestor y las cuotas operan solo sobre registros persistidos**.

## Integridad de los eventos vivos
Auditoría de lectura en el Supabase principal:
- Total de eventos actuales: **3**.
- Eventos demo: **3**.
- Eventos no-demo: **0**.
- Eventos propiedad de Urban Warriors: **2**.

Urban Warriors · Interclub Jiu-Jitsu:
- 10 participantes.
- 5 combates.
- 1 Main Event.
- 1 organizador principal.
- 0 combates con participantes huérfanos.
- 0 media persistida rota.

Urban Warriors · Seminario Muay Thai:
- 1 participante.
- 0 combates, coherente con tipo seminario.
- 1 organizador principal.
- 0 referencias rotas.

Por tanto, los fallos observados **no proceden de corrupción relacional de estos registros**.

## Demo vs evento normal
No existe actualmente en el Supabase principal un evento no-demo con el que realizar una comparación A/B real: los tres registros vivos son demos. Sin embargo, creación/edición normal y demos atraviesan el mismo gateway de mutación y el mismo bundle de detalle. Los defectos de FormData, discovery, caché, listeners y carreras de apertura estaban en ese flujo compartido y podían afectar a un evento normal.

## Backend
R44 no modifica migraciones ni DDL. Comparación del árbol `supabase/` R43→R44:
- R43: 540 archivos.
- R44: 540 archivos.
- Cambiados: 0.
- Faltantes: 0.
- Extra: 0.

Verificación viva de privilegios relevantes:
- `app_kombax_eventos_mutate_v191`: authenticated sí / anon no.
- `app_kombax_event_visibility_v236`: authenticated sí / anon no.
- `app_kombax_event_visibility_mutate_v236`: authenticated sí / anon no.
- `app_kombax_evento_contexto_gestion_v171`: authenticated sí / anon no.
- `app_kombax_evento_bundle_v189`: authenticated sí / anon sí, manteniendo la lectura pública prevista cuando corresponde.

## QA automatizado
- R44 Events Flow Stability: **25/25 PASS**.
- R25 Pilot Stabilization: **24/24 PASS**.
- R40 Social + Events Visibility: **74/74 PASS**.
- R42 Freeze Candidate: **24/24 PASS**.
- R43 Organization Assist Priority: **18/18 PASS**.
- `npm test`: **EXIT 0**.
- `npm run build`: **EXIT 0**.
- Runtime parity: **189 web = 189 dist = 189 Android**, 0 diferencias, SHA agregado idéntico.
- Secret-pattern scan: **1596 archivos, 0 hallazgos**.

## Qué puede afirmarse y qué no
**Verificado:** los defectos estructurales identificados están corregidos en código y cubiertos por regresiones automatizadas; los datos vivos actuales son relacionalmente consistentes; el build y los tres runtimes son idénticos.

**Pendiente antes de garantía de producción/piloto real:** QA manual autenticado con una identidad organizativa real de Urban Warriors, porque esta sesión no dispone de sus credenciales para ejecutar clic-a-clic en navegador/móvil contra el backend vivo. Por rigor, R44 se clasifica como **PRE-QA FREEZE CANDIDATE**, no como producción garantizada.
