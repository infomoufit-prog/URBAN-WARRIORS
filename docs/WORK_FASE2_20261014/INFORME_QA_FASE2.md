# Fase 2 — Informe de QA y limitaciones

## Superadas (ejecución local)

- `node scripts/test-kombax-phase2-inscripciones-licenses.mjs`: **32/32 PASS**. Incluye pruebas unitarias del clasificador interno y comprobaciones de integración estática en los módulos.
- `node scripts/test-kombax-phase1-multi-space.mjs`: **26/26 PASS**.
- `node scripts/test-kombax-phase1-finance-scope.mjs`: **17/17 PASS**.
- `node scripts/test-workspace-access-fix14.mjs`: **13/13 PASS**.
- `node scripts/test-kombax-20142-r89-inventory-lifecycle.mjs`: **52/52 PASS**.
- `node scripts/test-release-metadata.mjs`: **PASS**.
- `node scripts/test-kombax-20177-r118-pilot-stabilization.mjs`: **PASS**.
- `node --check` de `gateway.js`, `federation-licenses.js` y `internal-club-license.js`: **PASS**.
- Mirror `web` / `dist` / Android de 3 módulos: **PASS, idénticos por SHA-256**.

## No ejecutadas o bloqueadas

- 5 suites históricas específicas (`test-student-personal-invitation-fix16`, `test-preinscription-lifecycle-fix16`, `test-account-code-gateway-fix16`, `test-member-batch-family-r120`, `test-registration-validation-r119`) **no pudieron arrancar** por falta de dependencia `@electric-sql/pglite` en la copia. No son fallos funcionales demostrados; están sin validar.
- Se intentó instalar dependencias mediante `npm ci`; no pudo completarse en el tiempo disponible. No se conservará un `node_modules` parcial.
- Las suites R33 necesitan documentos históricos no presentes en esta copia. Su ausencia es un bloqueo previo, no un fallo introducido por Fase 2.
- No se hicieron operaciones reales E2E, aprobaciones reales ni pruebas de cuentas piloto.
- No se compiló APK/AAB.
- No se han verificado visualmente todas las anchuras de pantalla.

**No confundir PASS estático/local con validación de usuario real en producción.**
