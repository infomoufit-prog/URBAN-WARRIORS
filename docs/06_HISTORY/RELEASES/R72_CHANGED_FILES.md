# KOMBAX R72 · Cambios respecto a R71

- Base comparada: `KOMBAX_20122_R71_SIDEBAR_PRODUCT_ACCORDIONS_READY.zip`.
- Añadidos: **44**.
- Modificados: **48**.
- Eliminados: **0**.

El detalle máquina-a-máquina completo está en `R72_DIFF.json`.

## Núcleo funcional/documental añadido o modificado
- `web/js/core/commercial-pricing.js`
- `web/js/core/repositories.js`
- `web/js/modules/showcase.js`
- `web/js/modules/kombax-events.js`
- `web/js/modules/events-kombax.js`
- `web/js/modules/plan-services.js`
- `web/js/core/media.js`
- `web/css/kombax-premium.css`
- `web/terms.html`, `web/privacy.html` y páginas legales/cache bust.
- Espejos equivalentes en `dist/` y `android/app/src/main/assets/www/`.
- `android/app/build.gradle` y `MainActivity.java` para build 20123.
- `docs/commercial/KOMBAX_COMMERCIAL_REFERENCE_R72.md`.
- `docs/legal/KOMBAX_CONTRACT_MATRIX_R72.md`.
- `docs/legal/KOMBAX_EVENTS_COMMUNITY_R72_QA.md`.
- `docs/legal/KOMBAX_SHOWCASE_REPUTATION_CATALOG_R72_QA.md`.
- Suites `scripts/test-kombax-20123-r72-*.mjs`.
- Once migraciones `supabase/migrations/2026091418*_kombax_r72_*.sql` y `20260914190143_kombax_r72_11_reputation_fk_indexes.sql`.
- `supabase/reference_migrations/R72_MONOLITHIC_REFERENCE_20123.sql`.
- `supabase/functions/health/index.ts`.
- Informes R72 de auditoría, arquitectura, QA, rollback, Advisors, Supabase live, paridad e integridad.
