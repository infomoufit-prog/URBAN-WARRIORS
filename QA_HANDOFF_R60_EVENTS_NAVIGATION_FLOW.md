# QA Handoff · R60 Events Navigation Flow

## QA automatizado específico

PASS:
- `test-kombax-20110-r60-events-navigation-flow.mjs` — 12/12
- `test-kombax-20101-r44-events-flow-stability.mjs` — 25/25
- `test-kombax-20104-r54-events-flow-mobile-quality.mjs` — 14/14
- `test-kombax-20105-r55-events-media-load-budget.mjs` — 5/5
- `test-kombax-20101-r53-pilot-network-profile-events.mjs` — 21/21
- `test-kombax-20110-r60-migrations-guide-history.mjs` — 32/32
- `test-rc13-events.mjs` — PASS
- `test-kombax-20107-r57-social-info-ux.mjs` — 25/25
- `scripts/build.mjs` — 192 archivos; `web = dist = Android`
- `node --check web/js/modules/kombax-events.js` — PASS

También pasan las suites históricas de Events ejecutadas desde Foundation R20090 hasta R54, salvo una aserción de congelación por hash en `test-kombax-20105-r55-events-media-architecture.mjs`: esa prueba exige literalmente que `kombax-events.js` permanezca byte-a-byte igual a R55, por lo que debe fallar ante cualquier evolución deliberada posterior. Sus comprobaciones funcionales de arquitectura R55 pasan antes de la aserción de hash.

La suite global `npm test` no se usa como certificación de este cambio porque se detiene más adelante en una aserción textual R28 ya incompatible con la estabilización UI previa de R60 (`Competidor not professional subtype`). No está relacionada con Events ni con esta intervención.

## Inmutabilidad verificada

Comparación SHA-256 antes/después sin diferencias para:
- `web/js/core/backend.js`
- `web/js/core/repositories.js`
- `web/js/core/supabase.js`
- `web/js/app.js`
- `web/js/ui/components.js`
- `android/app/build.gradle`
- árbol completo `supabase/`

`android/app/build.gradle` conserva SHA-256:
`37c818ed4785f970595800a7ac128e49cd4acf990232f6e0717d2af73e03997a`

## QA manual recomendado en Android real

1. Entrar y salir de KOMBAX Events varias veces: la cartelera cacheada debe aparecer de inmediato y conservar scroll.
2. Abrir consecutivamente 5–10 eventos distintos: ningún tap debe quedar sin feedback y una respuesta antigua no debe reemplazar el evento actual.
3. Reabrir un evento recién visto: debe aprovechar la caché de detalle durante la ventana activa.
4. Probar red Wi-Fi normal y red móvil lenta: el estado de apertura debe aparecer sin simular una recarga completa de la cartelera.
5. Abrir un evento con preparación competitiva: la ficha debe aparecer antes que los controles de preparación, que se completan después.
6. Cerrar una apertura lenta antes de terminar: la respuesta tardía no debe forzar la reapertura.
7. Confirmar que tab bar y menú lateral mantienen exactamente el routing anterior.

No se afirma una cifra de milisegundos de dispositivo: la mejora está verificada a nivel de critical path y regresión automatizada; la latencia física final debe medirse en el APK del dispositivo piloto.
