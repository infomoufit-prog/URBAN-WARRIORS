# KOMBAX · Plan de implementación 20.100 · Brand Heroes

## Alcance
Evolución visual transversal de las tres capas públicas KOMBAX: Social, Events y Showcase. No modifica contratos de negocio, RLS, RPC, storage ni flujos privados de Mi Club.

## Objetivos
1. Unificar las tres capas con un sistema Hero común.
2. Usar exclusivamente el símbolo oficial KOMBAX existente en `web/assets/brand/kombax-symbol-white.png`.
3. Prohibir logos alternativos generados (lobos, escudos u otros isotipos no oficiales).
4. Incorporar fotografía cinematográfica como fondo, separada del logo y copy HTML.
5. Mantener identidad propia por capa: rojo Social, cian Events, dorado Showcase.
6. Events conserva `FROM HYPE TO HISTORY` y el slogan `El espectáculo no empieza en el ring. Empieza aquí.`.
7. Añadir motion ambiental ligero y `prefers-reduced-motion`.
8. Garantizar responsive móvil/desktop y compatibilidad Android WebView/PWA.

## Riesgos
- Que assets generados contengan tipografía o símbolos que puedan confundirse con la marca oficial.
- Que el nuevo Hero rompa IDs funcionales de Events.
- Que copies históricos exigidos por regresión desaparezcan sin equivalente semántico.
- Que nuevas imágenes pesadas degraden Android/PWA.

## Mitigaciones
- Fondos preparados sin marca; logo y copy son HTML/CSS reales.
- IDs `kx-events-explore` y `kx-events-create` preservados.
- Tests históricos actualizados solo cuando estaban congelados a versiones/copy, manteniendo invariantes funcionales.
- Assets WebP locales optimizados; sin APIs, WebGL ni vídeos de fondo.

## QA y cierre
- `node --check` módulos modificados.
- test específico 20.100.
- regresión completa `npm test`.
- `npm run build` con paridad `web = dist = Android`.
- legal gate.
- Android preflight.
- higiene de secretos y firma local.
- manifiesto SHA-256 + ZIP íntegro.
