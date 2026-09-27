# KOMBAX Block 1 · Phase 1 audit/freeze

Base: R81 build 20134.

## Verified baseline
- `npm test`: PASS from the untouched R81 source tree.
- Showcase Display and Commerce coexist; public Explore remains independent from private seller-center failures.
- Commerce has product/order/stock/refund foundations and a direct Stripe Checkout path, but the buyer path is single-product / quantity=1 and has no persistent cart UX.
- Stripe Connect uses server-resolved connected accounts and direct charges. Current fee resolver remains authoritative; no fee rule is changed by Block 1.
- Signed Stripe webhook is authoritative for successful payment state; frontend success redirects are not payment truth.
- Existing order-item and webhook stock loops are structurally compatible with multi-line Showcase orders.
- R80 card/SEPA payment-center and R81 Terminal/Tap-to-Pay foundations are present.
- Android Terminal uses `ApplicationInfo.FLAG_DEBUGGABLE`; the forbidden Stripe Terminal `BuildConfig` import is absent.
- Finance is mature for Club plus separate Showcase/Event projections, but the shared frontend finance adapter exposes only Club/Professional scopes. Block 1 will add an identity-aware adapter without replacing Club finance.
- Eight locales are installed: ES, EN, FR, PT, IT, DE, TH, FIL.

## Blockers resolved by plan
1. Add single-seller cart UX and explicit quantity/variant selection without inventing multi-seller settlement.
2. Add an additive server-side cart checkout RPC and Edge Function path; preserve legacy single-product checkout.
3. Add identity-scoped finance adapters/transaction projection while retaining existing Club/Showcase/Event engines.
4. Normalize payment-method/channel presentation from existing payment-attempt/Terminal data.

## Freeze rules
- No real charges/refunds/mandates are executed by QA.
- No platform-fee policy is changed.
- No RLS is weakened.
- No signing secrets, JKS, provisioning profiles or payment secrets enter the package.
