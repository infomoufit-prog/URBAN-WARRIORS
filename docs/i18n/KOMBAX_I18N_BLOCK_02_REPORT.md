# KOMBAX i18n · Block 02 report · F06–F10

## A. Fases realizadas
- F06 English — **PASS**
- F07 FR/PT/IT/DE — **PASS** (catalog/context static gate; public activation intentionally deferred)
- F08 TH/FIL + typography — **PASS** (catalog/Unicode/static typography gate; visual device gate deferred to F16)
- F09 Regional formats — **PASS**
- F10 Coverage/validators/docs — **PASS**

## B. Implementaciones
Complete 8-locale catalogs, EN activation, Thai/long-string CSS, locale-aware regional formatting, plural helpers, automated validator, B02 QA harness and continuity documentation.

## C. Archivos principales modificados
`web/js/i18n/**`, `web/css/kombax-i18n.css`, 19 web JS files with regional formatting calls, `scripts/i18n-validate.mjs`, `scripts/test-kombax-i18n-b02.mjs`, `package.json`, `/docs/i18n/**`.

## D. Dependencias
No dependencies added or removed.

## E. Migraciones
No new database migration in B02. The additive B01 `preferred_locale` migration remains packaged and **not deployed automatically**.

## F. Tests
Validator PASS; B02 25/25 PASS; cumulative `npm test` PASS; legal gate PASS.

## G. Build
`npm run build` PASS — **397 files; web = dist = Android**.

## H. Cobertura lingüística
229/229 catalog keys in every supported locale. This is catalog coverage, not a false claim that all legacy product-source hardcodes are already migrated.

## I. Regresiones
No cumulative R73/R72 regression failure detected. Regional format changes were isolated to locale selection, not business values.

## J. Pendientes reales
Deep product UI F11–F15; visual/device international QA F16; end-to-end locale workflows F17; final security/integrity F18 and rollout F19.

## K. Riesgos siguiente bloque
User-generated content boundaries, Stripe/KOMBAX-copy separation, QR identity invariance, AI locale propagation and legal locale/jurisdiction separation must be preserved.

## L. ZIP
B02 must be packaged as a complete self-contained project and used as the only base for F11–F15.
