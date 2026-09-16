# QA Handoff · KOMBAX R60 Frontend UI Stabilization

## Restricciones verificadas

- Backend Supabase: **sin cambios**.
- Edge Functions / SQL / RLS / Auth / Storage: **sin cambios**.
- `web/js/core/backend.js`: **sin cambios**.
- `web/js/core/repositories.js`: **sin cambios**.
- `web/js/core/supabase.js`: **sin cambios**.
- `web/js/app.js`: **sin cambios**.
- `web/js/ui/components.js`: **sin cambios**; navegación del punto 7 preservada.
- `android/app/build.gradle`: **sin cambios**; conserva el fix Android R60, SHA-256 `37c818ed4785f970595800a7ac128e49cd4acf990232f6e0717d2af73e03997a`.
- `MainActivity.java`: **sin cambios**.

Hash árbol `supabase/` verificado idéntico a la R60 corregida:
`c4d550ea01a00de3cbd768a0b0c9a1c7700ee64c8782225f7999b205ce7aaf6c`

## QA ejecutado

PASS:
- `test-release-b-safe-areas.mjs`
- `test-rc13-responsive.mjs`
- `test-kombax-20078-public-product-overview.mjs`
- `test-kombax-20101-mobile-events-fightcards-r13.mjs`
- `test-kombax-20101-responsive-visual-tuning-r15.mjs`
- `test-kombax-20101-event-management-r16.mjs`
- `test-kombax-20101-r45-showcase-mobile-visual.mjs`
- `test-kombax-20107-r57-social-info-ux.mjs`
- `test-kombax-20110-r60-migrations-guide-history.mjs` — 32/32 PASS
- `scripts/build.mjs` — `web = dist = Android`, 192 archivos
- sintaxis JS de los tres módulos editados
- balance de llaves CSS y `viewport-fit=cover`

El `npm test` acumulativo completo se inició y avanzó sin fallos hasta las suites 20084, pero excedió el tiempo de ejecución disponible del entorno; no se usa como certificación final.

Android preflight:
- 4/5 preparado.
- Único pendiente: firma local (`android/keystore.properties`), que deliberadamente no se empaqueta con credenciales.

## QA manual recomendado en dispositivo

Validar en 320 / 360 / 390 / 412 px y al menos una tablet:
1. Cabecera bajo reloj/señal Android.
2. Último post de Social completamente visible.
3. Showcase: input + Buscar y categorías.
4. Events: tabs, `Gestionar evento`, MAIN EVENT y nombres largos.
5. Mi Club: tarjeta KOMBAX Migrations.
6. Selector de perfiles: orden, densidad y textos.
7. Solicitud en estados Enviada / En revisión / Falta información.
8. Confirmar que la tab bar y el menú lateral conservan exactamente la navegación anterior.
