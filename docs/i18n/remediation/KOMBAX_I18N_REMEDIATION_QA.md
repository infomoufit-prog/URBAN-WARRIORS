# KOMBAX i18n · QA RB01

## Gates

- `node scripts/i18n-hardcode-audit.mjs` — genera evidencia, no pretende que la deuda esté a cero en RB01.
- `node scripts/i18n-validate.mjs` — ES/EN estrictos; locales ocultos pueden usar fallback EN→ES.
- `node scripts/test-kombax-i18n-remediation-rb01.mjs` — gate específico de remediación.
- `npm test` — regresión acumulativa completa.
- `npm run build` — web/dist/Android sync.
- `npm run release:legal-gate`.
- `npm run android:preflight` — la firma local sigue siendo un requisito externo y no debe viajar en el ZIP.

## Métrica de auditoría

El auditor es deliberadamente conservador y **cuenta líneas candidatas**, no garantiza que cada línea corresponda a una única string visible. Sirve como detector de deuda y debe complementarse con revisión/QA visual.

Baseline RB01 antes de remediar:
- 2.583 líneas `SYSTEM_UI_CANDIDATE` globales.
- 641 líneas candidatas en las 10 superficies objetivo iniciales.

Estado de código antes del cierre final de RB01:
- 2.410 líneas candidatas globales.
- 468 líneas candidatas en targets RB01.
- reducción verificable: 173 líneas candidatas en las superficies trabajadas.

No se interpreta esta cifra como «número de traducciones pendientes». Incluye falsos positivos, literales de compatibilidad y líneas minificadas que pueden contener varios conceptos.

## Resultado final RB01

- hardcode audit: PASS como evidencia (gate global sigue abierto por diseño de RB01): 2.410 líneas candidatas globales; 468 en targets RB01.
- i18n validation: PASS.
  - ES: 1.077/1.077, 100 %.
  - EN: 1.077/1.077, 100 %.
  - active references: 645.
  - FR/PT/IT/DE/TH/FIL: 474/1.077 (44,01 % del nuevo master) y permanecen desactivados con fallback.
- remediation test: PASS 16/16.
- `npm test`: PASS, incluida regresión histórica R73/R72 y B02/B03/B04.
- build: PASS · 408 archivos · web = dist = Android.
- Legal Gate: PASS.
- Android preflight: PARTIAL 4/5 únicamente por `android/keystore.properties` local no incluido.
- delta contra B04: 0 archivos eliminados; 35 añadidos y 90 modificados incluyendo mirrors de build; 17 añadidos y 38 modificados a nivel fuente/documentación excluyendo `dist/` y el mirror Android.


## Resultado final RB02 · R06-R10

- `node scripts/i18n-en-quality-gate.mjs`: **PASS** — 2.180/2.180 frases auditadas con traducción EN exacta; 0 drift de placeholders; 0 residuo fuerte de castellano.
- `node scripts/i18n-runtime-copy-audit.mjs --all --strict`: **PASS** — 4.715/4.715 piezas de copy KOMBAX cubiertas; 0 unresolved; 366 fixtures/valores técnicos/contenido de usuario clasificados y excluidos.
- `node scripts/i18n-public-surface-audit.mjs`: **PASS** — 4 páginas; 92 strings de sistema; 0 unresolved.
- `node scripts/i18n-system-channel-audit.mjs`: **PASS 8/8**.
- `node scripts/test-kombax-i18n-remediation-rb02.mjs`: **PASS 10/10**.
- `node scripts/i18n-validate.mjs`: **PASS** — ES/EN 1.077/1.077; 645 referencias activas; otros locales hidden/fallback-aware.
- `npm test`: **PASS**.
- build: **PASS — 417 archivos; web = dist = Android**.
- Legal Gate: **PASS**.
- Android preflight: **PARTIAL 4/5** únicamente por `android/keystore.properties` local deliberadamente excluido del ZIP.
- delta vs RB01: **0 archivos eliminados**; 56 añadidos y 47 modificados incluyendo mirrors; 38 añadidos / 23 modificados a nivel fuente excluyendo mirrors.

### Interpretación del gate
RB02 cierra la **implementación de copy de software en inglés bajo auditoría automatizada**, incluyendo SPA, páginas públicas y canales de sistema auditados. Esto no sustituye QA visual/E2E autenticado con cuentas reales, PWA/Android físico, Stripe/email/push reales. Por tanto EN queda **implementation-complete / QA-ready**, no falsamente “release-validated” hasta completar esos gates externos/manuales.

### Idiomas no ingleses
FR/PT/IT/DE/TH/FIL permanecen `supported=true`, `enabled=false`. Tienen 474/1.077 claves directas y usan fallback EN/ES para el copy añadido en remediación. No se consideran listos para activación hasta traducir el delta de remediación y superar QA por locale.
