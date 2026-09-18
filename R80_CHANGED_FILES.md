# KOMBAX R80 · principales archivos añadidos/modificados

## Backend / Supabase
- `supabase/migrations/269_kombax_stripe_sepa_payment_center_r80.sql`
- `supabase/functions/stripe-sepa/index.ts`
- `supabase/functions/stripe-connect/index.ts`
- `supabase/functions/stripe-webhook/index.ts`
- `supabase/functions/stripe-checkout/index.ts`
- `supabase/functions/_shared/stripe.ts`
- `supabase/functions/health/index.ts`
- `supabase/config.toml`

## Frontend
- `web/js/modules/payments-center.js`
- `web/js/modules/finance.js`
- `web/js/modules/finance-premium.js`
- `web/js/modules/managed-profile-hub.js`
- `web/js/modules/showcase.js`
- `web/js/modules/kombax-events.js`
- `web/js/modules/plan-services.js`
- `web/js/modules/customer-operations.js`
- `web/js/core/repositories.js`
- `web/js/core/assist-specialists.js`
- `web/css/kombax-premium.css`
- `web/js/i18n/locales/{es,en,fr,pt,it,de,th,fil}/payments.js`

## Documentación / QA
- `web/assets/docs/GUIA_KOMBAX_COBROS_STRIPE_SEPA_R80.pdf`
- `R80_STRIPE_SEPA_PREIMPLEMENTATION_AUDIT.md`
- `R80_STRIPE_SEPA_FINAL_REPORT.md`
- `R80_STRIPE_SEPA_QA_SCORECARD.md`
- `scripts/test-kombax-20131-r80-stripe-sepa-payments.mjs`
- `scripts/build-r80-payments-guide.py`

`dist/` y `android/app/src/main/assets/www/` se regeneran automáticamente desde `web/` mediante `scripts/build.mjs`.
