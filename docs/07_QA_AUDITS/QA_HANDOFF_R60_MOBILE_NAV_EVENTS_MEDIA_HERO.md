# QA Handoff · R60 Mobile Navigation / Events / Profile Media / Hero Focus

## Automatizado
PASS:
- `test-kombax-20110-r60-mobile-nav-media-hero-flow.mjs` 16/16
- `test-kombax-20110-r60-events-navigation-flow.mjs` 12/12
- `test-kombax-20101-r44-events-flow-stability.mjs` 25/25
- `test-kombax-20104-r54-events-flow-mobile-quality.mjs` 14/14
- `test-kombax-20105-r55-events-media-load-budget.mjs` 5/5
- `test-kombax-20101-r53-pilot-network-profile-events.mjs` 21/21
- `test-kombax-20107-r57-social-info-ux.mjs` 25/25
- `test-kombax-20110-r60-migrations-guide-history.mjs` 32/32
- `scripts/build.mjs`: 192 archivos · web = dist = Android

## QA manual Android recomendado
1. Abrir/cerrar el menú móvil y recorrer Mi perfil, Social, Events, Showcase y Mi Club; no debe aparecer barra inferior.
2. Entrar a Events varias veces y comprobar que la cartelera reaparece sin salto de scroll.
3. Abrir 5–10 eventos seguidos con Wi‑Fi y red móvil; cada tap debe dar feedback y una respuesta vieja no debe sustituir el evento actual.
4. Reabrir un evento recién visto; debe aprovechar caché de detalle.
5. Abrir fotos y vídeos de álbumes desde perfil público, Miembro y perfil directo; deben ocupar pantalla completa y volver al mismo álbum al cerrar.
6. Verificar orientación vertical y horizontal del vídeo inmersivo.
7. En móvil vertical comprobar que en el hero Events se ven las dos caras y en Social el peleador queda centrado.
8. Revisar 320/360/390/412 px y tablet.

## Inmutabilidad backend
Hashes de backend core y árbol Supabase comparados con la base: idénticos.
`android/app/build.gradle` conserva SHA-256:
`37c818ed4785f970595800a7ac128e49cd4acf990232f6e0717d2af73e03997a`
