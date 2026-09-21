# KOMBAX i18n · QA Bloque 1

## Fuente de verdad

- Base: **KOMBAX 20124 R73 SHOWCASE_REPUTATION_EVENTS_COMMUNITY_COMPLETION_PILOT_FREEZE**.
- SHA-256 ZIP de origen: `0623dff59c98076c0ee612ecbc6f4e436738b3eebb4080b9b347bc6ea1ed11be`.
- Integridad ZIP: **PASS**.
- No existía `KOMBAX_I18N_HANDOFF.json`; corresponde Bloque 1 F01-F05.

## Baseline R73 antes de cambios

- `npm test`: **PASS**.
- `node scripts/build.mjs`: **PASS — 206 archivos · web = dist = Android**.
- `npm run release:legal-gate`: **PASS**.
- `npm run android:preflight`: **PARTIAL 4/5**; único pendiente `android/keystore.properties`, que es material local de firma y no debe viajar en el ZIP.

## QA específico Bloque 1

- `npm run test:i18n:b01`: **23/23 PASS**.
- Soporte arquitectónico: ES, EN, FR, PT, IT, DE, TH, FIL.
- Enabled al cierre: **solo ES**.
- Fallback: **selected locale → EN → ES**.
- Missing key seguro: no filtra `undefined`, `null`, `missing_translation`, placeholders ni claves técnicas.
- 22 namespaces españoles independientes; no monolito de traducción.
- Catálogo maestro ES: **229 claves**.
- Referencias `t()` activas auditadas: **56**, missing ES: **0**.
- Persistencia local y de cuenta preparada.
- Migración Supabase: aditiva, autenticada y **no desplegada**.
- Rutas técnicas y nombres KOMBAX preservados.

## Inventario F02 reproducible

- Archivos fuente analizados: **723**.
- SYSTEM_UI candidates: **6589**.
- USER_CONTENT boundaries: **1791**.
- Assets contabilizados: **105**, sin OCR ni modificación.
- TECHNICAL_VALUE candidates: **2304**.
- LEGAL_CONTENT candidates: **1384**.
- Hardcodes regionales `es-ES`: **64**, registrados para F09/integración profunda.

Estos conteos son candidatos heurísticos de inventario, no porcentajes inventados de traducción.

## Regresión final acumulativa

- `npm test`: **PASS** incluyendo pretest histórico completo, R73 7/7 y todas las suites de continuidad R72.
- `npm run build`: **PASS — 243 archivos · web = dist = Android**.
- `npm run release:legal-gate`: **PASS**.
- `npm run android:preflight`: **PARTIAL 4/5**, únicamente por firma local ausente.

## No regresión R73

Los hashes finales son idénticos al baseline para:

- `web/js/modules/kombax-social.js`
- `web/js/modules/showcase.js`
- `web/js/modules/kombax-events.js`
- `web/js/core/repositories.js`

`web/js/core/backend.js` cambia deliberadamente para leer/escribir `preferred_locale`; el resto de su comportamiento queda cubierto por la regresión completa.

No se eliminó ningún archivo del baseline en los árboles auditados. El delta de código registra **6 archivos existentes modificados + 40 añadidos + 0 eliminados**; `package.json` también se actualizó para incorporar los gates i18n.

## Pendientes legítimos

- Firma Android definitiva: requiere `android/keystore.properties` local fuera del ZIP.
- Migración `preferred_locale`: preparada pero no desplegada.
- EN: F06.
- FR/PT/IT/DE: F07.
- TH/FIL y QA tipográfico: F08.
- Centralización restante de formatos regionales: F09.
- Validadores/cobertura/gate documental completo: F10.
- Integración profunda de Social/Showcase/Events/Assist/documentos: F11-F15 según Prompt Maestro.

## Block 2 · F06–F10

### Automated results
- `npm run i18n:validate` — **PASS**
  - 229/229 non-empty catalog keys for ES/EN/FR/PT/IT/DE/TH/FIL.
  - 0 missing keys, 0 extra keys, 0 placeholder mismatches, 0 technical translation leaks.
  - 0 active `t()` references missing in any locale.
  - 0 explicit UI `es-ES` hardcodes outside the canonical formatter map.
- `node scripts/test-kombax-i18n-b02.mjs` — **PASS 25/25**.
- `npm test` — **PASS**, including R73/R72 cumulative reputation, commercial, identity, Showcase, Events and accordion regressions.
- `npm run build` — **PASS, 397 files; web = dist = Android**.
- `npm run release:legal-gate` — **PASS**.
- `npm run android:preflight` — **PARTIAL 4/5** only because local signing config is intentionally excluded from portable ZIPs.

### Locale gates
- ES — enabled; regression PASS.
- EN — enabled; catalog/runtime/static QA PASS.
- FR/PT/IT/DE — catalog/structure/context checks PASS; kept disabled until phases 11–15 migrate deep product UI and later visual/E2E gates complete.
- TH/FIL — catalog/Unicode/static typography checks PASS; kept disabled until deep product integration and Phase 16 visual QA.

### Honest limitation
No claim is made that all historical application hardcodes are translated merely because catalog coverage is 100%. The current master catalog has 229 keys, while the original F02 inventory found thousands of UI candidates. Deep product surfaces are intentionally assigned to phases 11–15. Physical-device/browser visual QA for long strings and Thai belongs to Phase 16 and has not been falsely declared complete here.


## Block 3 · F11–F15

### Automated results
- `npm run i18n:validate` — **PASS**: 475/475 non-empty keys in ES/EN/FR/PT/IT/DE/TH/FIL; 0 missing/extra/empty; 0 placeholder drift; 223 active references; 0 UI `es-ES` hardcodes.
- `node scripts/test-kombax-i18n-b03.mjs` — **PASS 25/25**.
- `npm test` — **PASS**, including R73/R72 cumulative commercial, identity, Showcase, Events, reputation and accordion regressions.
- `npm run build` — **PASS, 397 files; web = dist = Android**.
- `npm run release:legal-gate` — **PASS**.
- `npm run android:preflight` — **PARTIAL 4/5** only because local signing config is intentionally excluded from portable ZIPs.

### Scope / honesty gate
The catalog and active-reference validation are complete, but a conservative B03 source scan still reports historical Spanish-literal candidates in deep product files. Those counts include demo/user-content literals and are **not verified visible-string counts**. Therefore B03 does not claim “0 hardcodes application-wide”. Phase 16 visual QA and Phase 17 E2E must close any user-visible residuals before rollout.

### Protected invariants
- User-created posts/comments/product descriptions/event content remain original.
- KOMBAX product names remain unchanged.
- QR/ticket identifiers/tokens remain invariant.
- Stripe/business identifiers remain invariant.
- Language does not determine currency, country or jurisdiction.
- No Supabase/Netlify/GitHub/Google Play deployment was performed.

## Block 4 · F16–F20

### Automatizado final
- `node scripts/test-kombax-i18n-b04.mjs` — **PASS 20/20**.
- `node scripts/i18n-validate.mjs` — **PASS**: 475/475 × 8; 0 missing/extra/empty; 0 placeholder drift; 223 active refs; 0 UI `es-ES` hardcodes.
- `npm test` — **PASS** acumulativo.
- `node scripts/build.mjs` — **PASS: 399 archivos; web = dist = Android**.
- `npm run release:legal-gate` — **PASS**.
- `npm run android:preflight` — **PARTIAL 4/5** únicamente por `android/keystore.properties` local fuera del ZIP.

### Visual/runtime
- CSS Thai/FR/DE, safe areas y wrapping: **PASS estático**.
- Harness manual: `web/qa/i18n-visual-b04.html`.
- Chromium headless en este contenedor: **BLOCKED por entorno DBus/gráfico**, incluso para documento mínimo. No se declara QA visual runtime autenticado como ejecutado.
- Android/PWA autenticado real: **PENDIENTE gate de dispositivo**.

### Rollout
- ES: enabled.
- EN: enabled.
- FR/PT/IT/DE/TH/FIL: supported, catalog complete, disabled hasta checklist manual autenticado.

### Integridad
- Delta B04 vs B03: **0 archivos eliminados**.
- QR/ticket IDs, rutas técnicas, Stripe IDs y user content no se localizan.
- Migraciones i18n preparadas, no desplegadas automáticamente.

## Post-freeze remediation RB01 · R01-R05

- i18n hardcode audit: 2.410 candidate UI lines globally; 468 in the initial target set, down from 2.583 / 641 baseline.
- active ES/EN catalog: 1.077/1.077 each, 100 %; 645 active refs.
- hidden locales: 474/1.077 legacy keys, fallback-enabled and disabled from public rollout.
- remediation regression: 16/16 PASS.
- full `npm test`: PASS.
- build: PASS 408 files (`web = dist = Android`).
- Legal Gate: PASS.
- Android preflight: 4/5, local signing config pending outside portable ZIP.
- full English application gate: OPEN; must be closed in RB02 R06-R10.


## Post-freeze remediation RB02 · R06-R10

- English exact-copy quality: **PASS 2,180/2,180**, 0 placeholder drift, 0 strong Spanish residue.
- Global runtime copy audit: **PASS 4,715/4,715**, 0 unresolved; 366 classified technical/user fixtures skipped.
- Public surfaces: **PASS 4 pages / 92 strings / 0 unresolved**.
- System channels: **PASS 8/8**.
- ES/EN catalog: **1,077/1,077 each**; 645 active refs.
- `npm test`: **PASS**.
- Build: **PASS 417 files (`web = dist = Android`)**.
- Legal Gate: **PASS**.
- Android preflight: **4/5**, local signing config pending outside portable ZIP.
- English status: **implementation-complete / ready for authenticated manual QA**, not falsely claimed as manually release-validated.
- FR/PT/IT/DE/TH/FIL remain disabled pending translation of remediation-era copy and per-locale QA.


## All-8 language activation

- Direct catalogs: **1,077/1,077 × 8 locales — PASS**.
- Legacy direct maps: **2,580 × 6 newly activated locales — PASS**.
- Public legal: **133 direct strings × 7 non-ES locales — PASS**.
- Auth templates/PWA: **8 locales — PASS static gate**.
- All-8 activation gate: **PASS**.
- Final cumulative `npm test`: **PASS**.
- Final build: **PASS, 449 files (`web = dist = Android`)**.
- Legal Gate: **PASS**.
- Android preflight: **4/5**, signing configuration intentionally external.
- Remaining release gate: authenticated/manual visual/E2E QA on real roles/devices/services for all 8 locales.
- Thai finance PDF: Unicode path implemented; validate runtime font reachability in authorized deployed environment.
