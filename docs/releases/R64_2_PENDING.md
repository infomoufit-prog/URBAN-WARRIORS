# KOMBAX 20.113 R64.2 — Real pending items

The package is ready for local/manual QA, but it is not declared Production Ready.

Pending external/final decisions:
1. Apply/review the new Supabase migrations in the target environment. They are packaged but were not executed against production in this work.
2. Connect plan-request approval to the final recurring SaaS billing lifecycle when Stripe Billing for KOMBAX subscriptions is formally activated. R64.2 deliberately does not fake a recurring charge.
3. Define the Partner commission settlement rule when a referred Club pays annually. Attribution can be stored, but payout must remain pending until this commercial rule is approved.
4. Final legal/fiscal review of updated plan/platform-fee/ticketing wording before public launch.
5. Android local signing/keystore and subsequent release APK/AAB/Play process.
6. Manual authenticated QA against the real Supabase environment after migrations are approved/applied.
