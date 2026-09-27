# KOMBAX Fase 0 · Cambios sobre R81 build 20133

## Corrección funcional

- `android/app/src/main/java/com/urbanwarriors/app/KombaxTerminalManager.java`
  - elimina `BuildConfig.DEBUG`;
  - usa `ApplicationInfo.FLAG_DEBUGGABLE`.

## Gate anti-regresión

- `scripts/test-kombax-20134-phase0-audit-freeze.mjs` -> nuevo.
- `scripts/test-kombax-20133-r81-tap-to-pay.mjs` -> añade check específico contra la dependencia `BuildConfig.DEBUG`.
- `package.json` -> incorpora el gate Fase 0 en la regresión y script `test:20134:phase0`.

## Build 20134

Se actualiza la identidad/cache actual en:

- `web/config.js`;
- `web/service-worker.js`;
- `web/index.html`;
- páginas legales/públicas con cache-buster actual;
- `web/js/i18n/manifest-locale.js`;
- `android/app/build.gradle`;
- `android/app/src/main/java/com/urbanwarriors/app/MainActivity.java`;
- `ios/KombaxIOS/Info.plist`;
- `ios/project.yml`;
- `ios/README.md`;
- `supabase/functions/health/index.ts`;
- tests acumulativos que validan la identidad de la release actual.

El build vuelve a sincronizar esos cambios a `dist/` y `android/app/src/main/assets/www/`.

## Documentación de Fase 0

Se añaden:

- `docs/00_INDEX_R81_PHASE0.md`;
- auditoría maestra;
- QA scorecard;
- estado backend live;
- alcance pendiente del Plan Maestro;
- secret scan;
- logs de release build, preflight Android y intento Gradle;
- manifest/package report de cierre.

Los JSON de auditoría i18n se regeneran al ejecutar la regresión completa y reflejan la última ejecución.
