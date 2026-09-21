# Plan de implementación R49

## Alcance
- Social: Like público separado de preferencia privada, UI 4 acciones, aviso temático, denuncia fuera de temática, ranking actualizado.
- Events: reforzar herencia visual de R48, poster micro-motion + lightbox, validar fight cards con/sin fotos.

## Riesgos
- R47 mezcló interés positivo con Like: R49 debe desacoplarlo sin borrar históricos.
- Cambiar RPC de feed/mutación puede romper paginación o compatibilidad con clientes anteriores.
- Animación del cartel no debe interferir con click/touch de navegación ni accesibilidad.
- No introducir una segunda fuente de verdad para carteles de Events.

## Archivos previstos
- `web/js/modules/kombax-social.js`
- `web/js/core/repositories.js`
- `web/js/ui/icons.js`
- `web/css/kombax-premium.css`
- `web/js/modules/kombax-events.js`
- `web/css/kombax-events.css`
- `supabase/migrations/240_kombax_social_like_interest_separation_r49.sql`
- `scripts/test-kombax-20101-r49-social-events-final-polish.mjs`
- documentación R49.

## Criterios de cierre
- Like no modifica preferencia y preferencia no modifica Like.
- Autor solo ve métricas públicas de Like/comentarios; interés permanece privado.
- Aviso temático visible en feed y publicación; motivo de moderación disponible.
- Pósters Events tienen microinteracción y visor; eventos existentes heredan el render.
- Main/Co-Main/Undercard siguen funcionando con fotos opcionales.
- QA completo, build/paridad, backend y ZIP smoke aprobados.
