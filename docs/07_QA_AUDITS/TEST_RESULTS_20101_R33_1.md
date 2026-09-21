# KOMBAX 20.101 R33.1 · Resultados QA

## Targeted
- R32 Profile Matrix: **36/36 PASS**.
- R33 Federation Licenses Admin: **52/52 PASS**.
- R33.1 Federation UX All Profiles: **27/27 PASS**.

## Regresión completa
Comando: `npm test`
- Exit code: **0**.
- Scripts encadenados (pretest + test): **173**.
- Líneas OK/PASS registradas: **2371**.
- Líneas FAIL: **0**.
- Log completo: `TEST_RESULTS_20101_R33_1_FULL.log`.

## Build
Comando: `node scripts/build.mjs`
- Resultado: `OK build 184 archivos · web = dist = Android`.
- Log: `BUILD_20101_R33_1.log`.

## Smoke HTTP local
- `/` → 200
- `/social` → 200
- `/events` → 200
- `/service-worker.js` → 200
- `/manifest.webmanifest` → 200

Log: `LOCAL_SMOKE_20101_R33_1.log`.
