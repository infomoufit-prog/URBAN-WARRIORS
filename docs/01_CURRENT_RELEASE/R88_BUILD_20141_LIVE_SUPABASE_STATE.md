# KOMBAX R88 · build 20141 · Live Supabase state

Project verified: `poggsobhtutbuagjiydc`.

## Applied cumulative migrations added in this release

- `20260921154230` · `kombax_r83_showcase_cart_checkout`
- `20260921161213` · `kombax_r84_finance_multientity_context`
- `20260921161247` · `kombax_r85_consulting_workflow`
- `20260921161329` · `kombax_r86_private_training_foundation`
- `20260921192549` · `kombax_r87_active_cart_stock_reconciliation`
- `20260921193108` · `kombax_r88_training_access_fk_hardening`
- `20260921193615` · `kombax_r87_event_finance_subject_context`

All seven migration records are represented by versioned SQL files in `supabase/migrations/`.

## Active Edge Functions verified

| Function | Version | JWT |
| --- | ---: | --- |
| health | 35 | custom/public health behavior |
| stripe-connect | 8 | required |
| stripe-checkout | 11 | required |
| stripe-webhook | 8 | Stripe signature/custom auth path |
| stripe-refund | 1 | required |
| stripe-account-finance | 1 | required |
| stripe-sepa | 1 | required |
| stripe-terminal | 1 | required |

`health` live source reports build 20141. `stripe-checkout` v11 includes Showcase cart checkout.

## Access checks

- R84 Finance context: `anon` execute denied; `authenticated` execute allowed with in-function subject authorization.
- R85 Consulting read/write RPCs: `anon` execute denied; authenticated users are constrained to their request/subject rules; owner operations require platform-admin check.
- R86 Training status: `anon` execute denied; authenticated access is constrained to supported Club/Federation subjects and subject authorization.
- Internal cart checkout and stock helpers remain service-role-only.

## Advisors

Final advisors were executed after the new migrations. The project still contains a large historical advisor backlog (RLS-with-no-direct-policy on private/internal schemas, authenticated SECURITY DEFINER RPCs, unused indexes, one duplicate historical index). These were not mass-modified because doing so could weaken established RLS/RPC boundaries. The R83–R88 functions added here retain explicit authorization checks and deny anonymous execution where applicable.

No real payment or refund was issued during live verification.
