# KOMBAX 20.110 R62.5 — Validation Result

Date: 2026-09-10
Base: KOMBAX_20110_R62_4_STRIPE_CONNECT_HARDENED_TEST_READY
Scope: Showcase orders + KOMBAX Events ticketing + Stripe Connect seller routing

## Result

- CODE READY: PASS
- LOCAL STATIC QA: PASS
- FULL REGRESSION SUITE: PASS
- R61 PAYMENTS + SHOWCASE COMMERCE: PASS
- R62.4 STRIPE CONNECT HARDENING: PASS
- R62.4 SQL INTEGRITY: PASS
- R62.5 SHOWCASE + EVENTS TICKETING: PASS
- BUILD: PASS
- WEB = DIST = ANDROID: PASS (197 files)
- PUBLIC STRIPE SECRET SCAN: PASS
- DIRECT CHARGE / ZERO PLATFORM FEE STATIC GUARD: PASS
- REMOTE SUPABASE MIGRATION APPLIED: NO (intentionally not applied)
- STRIPE TEST PAYMENT VERIFIED END-TO-END: PENDING MANUAL TEST
- PILOT READY FOR REAL MONEY: NOT YET CERTIFIED

## Implemented

### Showcase
- Keeps **Me interesa** as a commercial conversation path.
- Keeps **Comprar** as the Stripe Checkout purchase path.
- Buyer portal with order states and progress.
- Seller order panel with preparation, shipment, delivery, incidents and tracking.
- Shipping contact/address captured through Stripe Checkout when fulfillment requires it.
- Server-side amount and seller resolution remain authoritative.

### KOMBAX Events
- Ticket modes: none, external link, or internal KOMBAX sale.
- Organizer management: **Entradas y cobros**.
- Public/internal CTA: **Comprar entradas** when KOMBAX ticketing is active.
- Buyer wallet: **Mis entradas**.
- Organizer sales view and ticket check-in/use flow.
- Capacity reservations prevent overselling while a Checkout is pending.
- Paid webhook emits individual tickets exactly once.
- Refund/dispute state propagates to orders/tickets.

### Stripe Connect seller routing
- Club -> club Connected Account.
- Marca -> Showcase provider Connected Account.
- Federación -> federation Connected Account.
- Verified Profesional/Competidor organizing Events -> event_organizer Connected Account when entitled to organize public Events.
- Stripe account IDs are resolved server-side; the client cannot choose the beneficiary.
- No application_fee_amount, transfer_data.destination or on_behalf_of is introduced by R62.5.

## Historical regression tests updated

The following legacy assertions were updated only where their old requirement contradicted the current intended product behavior:

- 20063: accepts the current Showcase contact CTA **Me interesa** instead of requiring the old literal **Consultar en Showcase**.
- R55 / R56 preservation tests: same CTA compatibility update.
- 20098 Events Large Format: preserves secure external ticket links but no longer forbids internal KOMBAX ticket sales; instead it requires the new server-side `event_ticket` Checkout path.
- R62.4 Connect test: still requires Club/Marca/Federación and now accepts the additive `event_organizer` subject.

No legacy security check was removed to make the suite pass.

## Required TEST validation after installing this ZIP

1. Apply the R62.5 migration to the TEST Supabase project.
2. Run `supabase/verification/verify_r62_5_showcase_events_ticketing.sql` read-only verification.
3. Deploy/update TEST Edge Functions `stripe-connect`, `stripe-checkout`, `stripe-webhook`.
4. Test a Showcase order in Stripe TEST mode through payment -> webhook -> order status -> shipment/delivery.
5. Test an Event configured as `kombax` through Connect -> ticket Checkout -> webhook -> ticket issuance -> check-in.
6. Test sold-out/reservation behavior, failed card, cancelled Checkout, refund and duplicate webhook.
7. Verify one Club, one Marca, one Federación and one eligible direct organizer cannot cross-charge another entity's Connected Account.

Only after those remote TEST cases pass should this build be promoted toward real-money pilot validation.
