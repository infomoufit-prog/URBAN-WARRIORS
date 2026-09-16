# KOMBAX 20.101 R47 · Plan de consolidación Social

## Objetivo
Corregir el contrato introducido en R46 y estabilizar KOMBAX Social para que la experiencia móvil se aproxime a un feed social continuo sin confundir relevancia personal, visibilidad de publicación y moderación.

## Alcance
1. Retirar del flujo activo «Ocultar para mí».
2. Sustituirlo por «Me interesa / No me interesa / Sin preferencia», reversible y usado únicamente como señal de ranking.
3. Mantener «Visibilidad» como control independiente del autor/gestor, tanto al publicar como después desde `··· > Visibilidad`.
4. Ampliar audiencias a perfiles concretos y tipos de perfil, preservando Todo KOMBAX, Mi red, club, federación, clubes seleccionados y exclusiones R40.
5. Mejorar media móvil: vertical 4:5, cuadrada 1:1, horizontal 16:9; tap/expansión a visor inmersivo 100dvh con `contain`.
6. Mantener confidencialidad de media entre bucket público y restringido.

## Riesgos controlados
- Regresión de visibilidad Social R40.
- Ocultación accidental por «No me interesa».
- Pérdida de compatibilidad con likes históricos.
- Exposición de media restringida al cambiar audiencia.
- Editor de una publicación existente que no recargue o no persista selecciones avanzadas.
- Recorte excesivo de contenido vertical o fullscreen que siga usando `cover`.

## Archivos principales
- `web/js/modules/kombax-social.js`
- `web/js/core/repositories.js`
- `web/css/kombax-premium.css`
- `supabase/migrations/237_kombax_social_visibility_core_r47.sql`
- `supabase/migrations/238_kombax_social_feed_preferences_r47.sql`
- `supabase/migrations/239_kombax_social_mutation_visibility_r47.sql`
- `scripts/test-kombax-20101-r47-social-visibility-media-flow.mjs`

## Criterios de cierre automatizado
- R47 focal 28/28.
- R40 74/74, R44 25/25, R45 6/6 y R46 15/15.
- `npm test` exit 0.
- build y paridad web/dist/Android 189/189/189.
- migraciones R47 registradas en Supabase principal.
- RLS/ACL y contratos RPC R47 verificados en vivo.
- secret scan local sin hallazgos.
- Android preflight documentado.

## Gate manual separado
QA autenticado en móvil/Android con dos identidades distintas y cierre de advisors/ciberseguridad. No se simula ni se declara completado desde este entorno.
