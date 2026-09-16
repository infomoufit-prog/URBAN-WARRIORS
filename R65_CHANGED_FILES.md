# KOMBAX R65 · Archivos cambiados respecto a R64.4

Base: `KOMBAX_20115_R64_4_FINAL_PRICING_QA_READY`  
Release: `KOMBAX_20116_R65_COMMERCE_EVENTS_OPERATIONS_READY`

## Añadidos
- `R65_FINAL_REPORT.md`
- `R65_RELEASE_NOTES.md`
- `R65_ROLLBACK.md`
- `R65_SUPABASE_LIVE_STATE.md`
- `scripts/test-kombax-20116-r65-commerce-events-operations.mjs`
- `scripts/test-kombax-20116-r65-release-regression.mjs`
- `supabase/functions/stripe-account-finance/index.ts`
- `supabase/functions/stripe-refund/index.ts`
- `supabase/migration_archive/R65_CONSOLIDATED_REFERENCE_20260914003000.sql`
- `supabase/migrations/20260913223620_kombax_r65_commerce_events_operations_part1.sql`
- `supabase/migrations/20260913223644_kombax_r65_commerce_events_operations_part2.sql`
- `supabase/migrations/20260913223707_kombax_r65_refund_prepare.sql`
- `supabase/migrations/20260913223732_kombax_r65_refund_finalize_and_batches.sql`
- `supabase/migrations/20260913223753_kombax_r65_sales_and_finance.sql`
- `supabase/migrations/20260913223819_kombax_r65_bi_qr_order_operations.sql`
- `supabase/migrations/20260913223837_kombax_r65_webhook_v265.sql`
- `supabase/migrations/20260913223848_kombax_r65_outbox_hardening.sql`

## Modificados
- `android/app/build.gradle`
- `android/app/src/main/java/com/urbanwarriors/app/MainActivity.java`
- `package.json`
- `supabase/config.toml`
- `supabase/functions/health/index.ts`
- `supabase/functions/notification-dispatch/index.ts`
- `supabase/functions/stripe-webhook/index.ts`
- `web/child-safety.html`
- `web/config.js`
- `web/css/kombax-commercial.css`
- `web/delete-account.html`
- `web/index.html`
- `web/js/core/repositories.js`
- `web/js/modules/kombax-events.js`
- `web/js/modules/showcase.js`
- `web/privacy.html`
- `web/service-worker.js`
- `web/terms.html`

## Generados/sincronizados
- `dist/`: 11 archivos modificados por build.
- `android/app/src/main/assets/www/`: 11 archivos sincronizados.
- `R65_FINAL_EVIDENCE/`: 12 evidencias de QA/build/preflight.

## Eliminados
- Ninguno.
