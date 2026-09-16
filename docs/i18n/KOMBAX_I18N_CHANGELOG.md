# KOMBAX i18n · Changelog acumulativo

## BLOCK 1 · R73 · F01-F05

### F01 — Freeze, baseline y auditoría
- ZIP R73 validado y SHA-256 registrado.
- Baseline: `npm test` PASS; build 206 archivos PASS; Legal Gate PASS; Android preflight 4/5 por firma local ausente.
- Arquitectura real documentada: ES Modules + Supabase + PWA + Android.

### F02 — Inventario internacionalizable
- Añadido `scripts/i18n-inventory.mjs` y artefactos JSON/MD.
- 723 archivos fuente analizados; 105 assets contabilizados sin OCR.
- Inventariados UI, límites de contenido usuario, valores técnicos, legal y hardcodes regionales.

### F03 — Núcleo i18n
- Añadido `web/js/i18n/` con 8 locales soportados, metadata, storage, fallback, recursos y formatters.
- Sin dependencias nuevas.

### F04 — Español maestro
- 22 namespaces y 229 claves maestras iniciales.
- 56 referencias `t()` activas verificadas con 0 missing keys.
- Migrados shell compartido, navegación, login, formularios comunes, estados compartidos y ajustes de idioma sin alterar contenido de usuario.

### F05 — Selector, detección, persistencia y fallback
- Selector en login, shell y configuración.
- Solo ES enabled; 8 supported.
- Persistencia local y persistencia de cuenta preparada con migración aditiva.
- Cambio de locale preserva ruta; evita cerrar modales activos.

No se inició F06.

## BLOCK 2 — F06–F10 · 2026-09-14

### F06 — English
- Completed the English catalog against all 229 Spanish master keys across 22 namespaces.
- Preserved KOMBAX product names and interpolation placeholders.
- Enabled `en` only after structural/runtime QA.

### F07 — Français / Português / Italiano / Deutsch
- Added complete catalogs for FR/PT/IT/DE with the same namespace/key structure.
- Added long-label wrapping support for FR/DE.
- Kept these locales supported but hidden pending deep product integration and later rollout gates.

### F08 — ไทย / Filipino
- Added complete Thai and Filipino catalogs.
- Added Thai Unicode/font-stack/line-height/wrapping rules for web/PWA/Android WebView assets.
- Kept TH/FIL supported but hidden pending product integration and visual E2E gates.

### F09 — Regional formatting
- Replaced all UI-source `es-ES` literals with the central `localeTag(getLocale())` resolver.
- Canonical locale mapping remains in `web/js/i18n/formatters.js` only.
- Exposed locale-aware plural rules/category helpers from the i18n runtime.
- Language remains independent from currency/country/jurisdiction.

### F10 — Coverage, validators and documentation
- Added `scripts/i18n-validate.mjs` for missing/extra/empty keys, placeholder drift, active reference gaps, technical leaks and regional hardcodes.
- Added `scripts/test-kombax-i18n-b02.mjs` and integrated B02 validation into cumulative `npm test`.
- Added developer/activation documentation and refreshed cumulative coverage/handoff/QA.


## BLOCK 3 — F11–F15 · 2026-09-15

### F11 — KOMBAX Social
- Extended Social locale catalogs and migrated critical system UI surfaces to semantic keys while preserving posts/comments/user content.
- Kept future “View translation” out of scope.
- Conservative residual-source audit retained for Phase 16 visual closure instead of claiming zero historical hardcodes.

### F12 — KOMBAX Showcase / Commerce
- Extended Showcase/Commerce system UI localization for seller center, orders/statuses, marketplace and commercial guidance.
- Preserved seller-created product names/descriptions and Stripe object/business identities.

### F13 — KOMBAX Events / Ticketing
- Extended Events/Ticketing UI localization around event operations and tickets.
- QR/ticket IDs, tokens and access-control identity remain locale-invariant.

### F14 — Assist / Migrations / agents
- Propagated `user_locale` to Assist/Migrations functions and agent prompts without cloning Luna.
- Added localized system fallbacks and generated Migrations guide PDFs per locale.

### F15 — Email / Push / Documents / Legal
- Added locale-aware invitation email, notification/push and finance-document system presentation.
- Added legal metadata migration separating `locale`, `jurisdiction` and `legal_version`.
- Added explicit Thai fallback for dynamic finance PDFs when standard PDF fonts cannot render Thai safely.
- No production deployment performed.

## BLOCK 4 — F16–F20 · 2026-09-15

### F16 — QA visual internacional
- Añadido harness `web/qa/i18n-visual-b04.html` para stress de 8 locales, tamaños y wrapping.
- Verificados estáticamente CSS Thai/FR/DE, safe areas y reglas responsive.
- Chromium headless del contenedor no puede completar runtime por limitación DBus/gráfica; el QA visual autenticado se conserva como gate manual explícito, no como falso PASS.

### F17 — QA funcional end-to-end
- Regresión acumulativa completa `npm test` PASS.
- Añadido `test-kombax-i18n-b04.mjs` con 20 gates de i18n/release.
- Flujos que requieren cuentas reales, Stripe real, email/push real y Android firmado quedan en checklist de dispositivo.

### F18 — Regresión, seguridad e integridad
- Confirmadas migraciones i18n aditivas/no destructivas.
- QR/ticket IDs, rutas, Stripe IDs y contenido de usuario siguen independientes del locale.
- Assist mantiene un único agente locale-aware.
- Build, legal gate e integridad automatizada PASS.

### F19 — Configuración de piloto y rollout
- Añadido `web/js/i18n/rollout.js` con estado explícito por locale.
- ES/EN enabled.
- FR/PT/IT/DE/TH/FIL supported/disabled hasta QA manual autenticado.

### F20 — Freeze final internacional
- Añadidos readiness, rollback, inventario de migraciones, QA de dispositivo y release report.
- Handoff marcado `completed_through_phase = 20`.
- ZIP final completo pendiente únicamente de empaquetado/verificación al cierre de esta ejecución.

## POST-FREEZE REMEDIATION RB01 · R01-R05 · 2026-09-15

The Work/device audit showed that 475/475 catalog coverage was not equivalent to full application extraction. A new two-block remediation was opened without rewriting the completed 20-phase history. RB01 adds a conservative hardcode audit, strict ES/EN gates, the `marketing` namespace, landing/gateway/auth migration, common/profile/finance/Social priority migration, and a safe future user-content translation request contract. See `docs/i18n/remediation/`.


## POST-FREEZE REMEDIATION RB02 · R06-R10 · 2026-09-15

RB02 closes the English software-copy extraction/remediation gate across runtime JS, public surfaces and audited system channels. Final automated evidence: 4,715/4,715 runtime copy covered, 2,180/2,180 exact historical EN phrases, 92/92 public-page system strings, system channels 8/8, npm test/build/legal PASS, Android 4/5 only for local signing. English is implementation-complete and ready for authenticated/manual release QA. Other supported locales remain disabled pending remediation-era translation and locale-specific QA.


## ALL-8 LANGUAGE ACTIVATION · 2026-09-15

- Activated ES/EN/FR/PT/IT/DE/TH/FIL after direct strict catalog completion.
- 1,077/1,077 direct keys per locale.
- Added 2,580 direct legacy-copy mappings per FR/PT/IT/DE/TH/FIL, preventing English legacy fallback for these active locales.
- Extended public legal strings (133 direct strings per non-ES locale), Supabase Auth templates and PWA manifests to all eight locales.
- Added permanent `i18n-all8-activation-gate` to cumulative `npm test`.
- Added Thai Unicode finance-PDF runtime font strategy with safe fallback; no font binary bundled.
- Automated npm/build/legal gates PASS; Android 4/5 only for external signing config.

## UNIVERSAL U01–U05 · 2026-09-15
- Added derived universal translation cache + Edge Function for authored content while preserving originals.
- Added automatic/manual translation controls and private-content opt-in policy.
- Integrated Social, comments, messaging, profiles, Showcase, Events, club/brand/editorial and operational authored content.
- Added public-content translation prewarming for all eight locales, including multi-field batch support.
- Added the language selector to the very first gateway/onboarding interface before club/profile/account selection.
- Catalog increased to 1088 direct keys × 8 locales; universal gate 15/15.
