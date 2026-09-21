# KOMBAX R62.5.1 · Remote Validation Result

Supabase migrations: APPLIED
R62.4 verifier: PASS
R62.5 verifier: PASS
Pilot hardening verifier: PASS
stripe-connect: ACTIVE v6 / verify_jwt=true
stripe-checkout: ACTIVE v5 / verify_jwt=true
stripe-webhook: ACTIVE v5 / verify_jwt=false + Stripe-Signature verification
Direct Charges invariant: PASS
Platform transaction fee = 0 invariant: PASS
Connected-account uniqueness: PASS
Ticket tables direct client access: BLOCKED
Ticket RLS: ENABLED
New ticket FK performance indexes: PRESENT
Public ticket state visibility guard: PRESENT
Stripe TEST end-to-end payment: PENDING MANUAL/AUTHENTICATED QA
Global production pilot gates: PENDING (7 historical controls)

Local full npm test after migration-history alignment: PASS
Local npm run build after migration-history alignment: PASS
Build synchronization: OK build 197 archivos · web = dist = Android
