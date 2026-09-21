# Changelog · R60 Mobile Navigation + Events Flow + Profile Media + Hero Focus

## Frontend
- Barra inferior móvil oculta; menú lateral como navegación móvil única.
- Padding inferior recalculado sin reserva de tab bar.
- Events conserva el flujo optimizado con caché, deduplicación, prefetch, feedback no destructivo y carga progresiva.
- Fotos y vídeos de álbumes de perfiles abren en visor inmersivo a pantalla completa.
- El visor se superpone al álbum y al cerrar devuelve al usuario al mismo contexto.
- Nuevo botón de expansión en vídeos de álbum.
- Reencuadre CSS de hero Events para mostrar ambas caras.
- Reencuadre CSS de hero Social para centrar el peleador.

## Archivos fuente modificados
- `web/css/kombax-ui-stabilization-r60.css`
- `web/css/kombax-premium.css`
- `web/css/kombax-brand-heroes.css`
- `web/js/ui/components.js`
- `web/js/modules/public-profile.js`
- `web/js/modules/gateway.js`
- `scripts/test-kombax-20110-r60-mobile-nav-media-hero-flow.mjs`

`web/js/modules/kombax-events.js` conserva el Events Flow Fix auditado inmediatamente antes de esta intervención.

## No modificado
- backend.js / repositories.js / supabase.js
- árbol `supabase/`
- SQL / RPC / Edge Functions / RLS / Auth / Storage
- Hermes / Router / agentes
- `android/app/build.gradle`
