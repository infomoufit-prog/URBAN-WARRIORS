# KOMBAX 20.101 R7 · Gateway Atmospheric Hero — Plan de implementación

## Base única de continuidad
- Origen: `KOMBAX_20101_R6_EVENTS_FILTER_CREATE_FIX_WITH_SIGNING.zip`.
- Regla: evolución no destructiva sobre R6; no se rehacen módulos, rutas, permisos, filtros, Events, Social ni Showcase.
- Activo aprobado por producto: composición KOMBAX multi-deportista aprobada en conversación; se integra como recurso de entrada, sin generar nuevas imágenes.

## Alcance de esta fase
1. Sustituir el gran watermark/logotipo editorial del gateway inicial por la composición multi-deportista aprobada.
2. Reequilibrar la jerarquía del encabezado para dar más protagonismo a la imagen sin perder legibilidad ni identidad KOMBAX.
3. Crear atmósfera animada ligera sobre la imagen mediante CSS (humo/bruma, glow y respiración ambiental), sin GIF, vídeo, WebGL ni nuevas dependencias.
4. Adaptar la composición a desktop, tablet y móvil con crop controlado, overlays de legibilidad y CTA siempre por encima del arte.
5. Respetar `prefers-reduced-motion` y asegurar que las capas visuales no reciben eventos táctiles.
6. Mantener sin cambios la lógica de acceso a club, identidad global, login, administración oculta y navegación posterior.

## Decisiones técnicas
- Imagen base optimizada a WebP para reducir peso de descarga.
- Capas de humo generadas con gradientes CSS y filtros; animación exclusiva de `transform`/`opacity` cuando sea posible.
- `pointer-events:none`, `aria-hidden=true` y stacking aislado.
- Desktop: visual a la derecha y copy a la izquierda con headline ligeramente menor.
- Móvil: visual panorámico dentro del hero, antes del copy, con crop centrado en atletas y altura limitada para no desplazar los accesos críticos.
- Sin migraciones de Supabase ni cambios de backend: fase puramente frontend/asset.

## Archivos previstos
- `web/js/modules/gateway.js`
- `web/css/kombax-premium.css`
- `web/assets/brand-heroes/gateway-kombax-community.webp` (derivado optimizado del asset aprobado)
- `web/index.html` (cache-busting de revisión)
- `web/service-worker.js` (versión de cache de assets)
- `scripts/test-kombax-20101-gateway-atmospheric-r7.mjs`
- `package.json` (test específico R7)
- Documentación de cierre, auditoría y manifest.

## Riesgos
- Competencia visual entre el texto de entrada y el propio wordmark incorporado en la imagen.
- Crop agresivo en móviles estrechos.
- Incremento de peso del primer render.
- Animación excesiva en hardware modesto.
- Solape accidental con botones o trigger de navegación.

## Mitigaciones
- Máscara/degradado lateral y control de opacidad; headline reducido solo en gateway.
- Breakpoints específicos 1100/900/620/420 px y `object-position` diferenciado.
- WebP con presupuesto objetivo < 500 KB.
- Humo CSS con pocas capas y reduced-motion.
- Capas decorativas fuera del árbol interactivo y con `pointer-events:none`.

## QA obligatorio
1. Test específico R7 de estructura, asset, accesibilidad y no-interferencia.
2. Suite completa `npm test`.
3. `npm run build` y verificación determinista `web = dist = android assets`.
4. Comprobación de peso y dimensiones del asset.
5. Inspección estática de breakpoints y reduced-motion.
6. Auditoría de que no cambian funciones ni bindings del gateway.
7. Empaquetado ZIP autocontenido con firma local existente preservada.

## Criterios de cierre
- Imagen aprobada integrada y visible en entrada.
- Headline mejor equilibrado y legible en desktop/móvil.
- Humo/glow animados sin GIF/vídeo y con fallback reduced-motion.
- Botones de acceso y navegación intactos.
- Suite y build en PASS.
- ZIP completo + changelog + auditoría + checklist de validación local/móvil.

## Ampliación de alcance confirmada antes del refinamiento de Brand Heroes
Tras revisar los assets ya existentes de Social, Events y Showcase, esta misma R7 incorpora también movimiento atmosférico en sus banners sin generar imágenes adicionales:
- Social: humo rojo/anaranjado muy contenido; prioridad a rostro, claim y acceso a Comunidad / Actualidad / Mi red / Mensajes.
- Events: humo cian más visible y vivo; será el hero con mayor intensidad ambiental.
- Showcase: bruma dorada más lenta y elegante, evitando sensación de efecto recargado.
- Se reutiliza el componente `brandHero()` existente; no se bifurcan tres implementaciones.
- No se cambia lógica de Social, Events ni Showcase; solo capa CSS/branding y copy menor de coherencia cuando proceda.
