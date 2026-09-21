# Informe Bloque 1 · Fases 1-5 · R73

## A. Fases realizadas

- **F01 — PASS** · freeze, checksum, baseline técnico y auditoría.
- **F02 — PASS** · inventario reproducible de textos/valores/legal/assets sin OCR.
- **F03 — PASS** · núcleo i18n para el stack real ES Modules de KOMBAX.
- **F04 — PASS** · español maestro, 22 namespaces, superficies comunes migradas y equivalencia funcional ES. La migración profunda por producto continúa en F11-F15, tal como define el Prompt Maestro.
- **F05 — PASS** · selector, detección, persistencia, fallback y gate de activación.

No se inició F06.

## B. Implementaciones

Arquitectura transversal con 8 locales soportados; ES maestro y único enabled; claves semánticas; fallback selected→EN→ES; fallback visual seguro; metadata; resolver; storage; selector reutilizable; formateadores `Intl`; persistencia local y de cuenta; catálogo ES por namespaces; inventario; gates automáticos; documentación/handoff.

## C. Archivos principales modificados

- `web/js/app.js`
- `web/js/ui/components.js`
- `web/js/core/utils.js`
- `web/js/core/backend.js`
- `web/js/modules/admin.js`
- `web/index.html`
- `package.json`
- nuevos `web/js/i18n/*`, `web/css/kombax-i18n.css`, scripts, docs y migración.

Delta fuente auditado: **6 existentes modificados + 40 añadidos + 0 eliminados** dentro de web/supabase/scripts/android (sin assets Android generados).

## D. Dependencias

**0 dependencias añadidas / 0 eliminadas.** Se usa el stack ES Modules existente para evitar una segunda arquitectura o dependencia innecesaria.

## E. Migraciones

`supabase/migrations/20260914230000_kombax_i18n_locale_preference_b01.sql`

- aditiva;
- no reescribe datos históricos;
- `preferred_locale` nullable;
- validación de los 8 locales;
- RPC get/set autenticadas y security invoker;
- **no desplegada**.

## F. Tests ejecutados

- Integridad ZIP fuente: PASS.
- Baseline `npm test`: PASS.
- Test i18n B01: **23/23 PASS**.
- Regresión final `npm test`: **PASS**.
- Suites R73/R72 comerciales, identidad, Showcase, Events, reputación y accordions: PASS.
- Legal Gate: PASS.
- Android preflight: 4/5 por firma local ausente.

## G. Resultado de build

**PASS — 243 archivos · web = dist = Android.**

## H. Cobertura lingüística

- ES: catálogo B01 **229/229**, 56 referencias activas con 0 missing, enabled.
- EN/FR/PT/IT/DE/TH/FIL: arquitectura instalada, traducción pendiente y disabled.
- Los porcentajes se limitan al catálogo maestro creado; no se confunden con agotamiento de todos los candidatos históricos.

## I. Regresiones detectadas y corregidas

Dos tests históricos R72 dependían de literales concretos de UI. Se conservaron marcadores no renderizados para compatibilidad de QA mientras la UI visible usa claves i18n. No se reintrodujeron hardcodes visibles.

## J. Pendientes reales

Traducciones F06-F08, 64 hardcodes regionales para F09, validadores F10, migración Supabase no desplegada y firma Android local.

## K. Riesgos para el siguiente bloque

Longitud FR/DE, Unicode/wrapping TH, habilitación prematura de idiomas y mezcla indebida locale/moneda/país. Mantener `enabledLocales` estricto.

## L. ZIP completo

El artefacto de cierre debe ser el proyecto R73 completo + F01-F05, reabierto y verificado, y será la única base válida de F06-F10.
