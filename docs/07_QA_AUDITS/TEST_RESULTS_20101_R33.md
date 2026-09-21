# KOMBAX 20.101 R33 · Resultados de pruebas

- `npm test`: PASS, 0 líneas FAIL en el log final.
- R32 profile matrix: 36/36 PASS.
- R33 Federation Licenses Admin: 52/52 PASS.
- Build: `OK build 184 archivos · web = dist = Android`.
- Paridad SHA-256: web 184 / dist 184 / Android assets/www 184 / 0 mismatches.
- Smoke local HTTP: `/`, `/social`, `/events`, `/service-worker.js`, `/manifest.webmanifest` => 200.
- Backend cross-federation: PASS en los siete invariantes críticos.
- Equipo federativo: PASS en invitación, aceptación, capabilities y revocación.

El log completo está en `TEST_RESULTS_20101_R33_FULL.log`.
