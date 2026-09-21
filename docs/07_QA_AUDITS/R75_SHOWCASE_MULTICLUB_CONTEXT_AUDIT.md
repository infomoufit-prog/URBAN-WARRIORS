# R75 Showcase Multiclub Context Audit

## Invariant 1 — Public marketplace is always public
`Explorar Showcase` must never require, fetch, autoprovision or select a private seller workspace. Its source is the public Showcase catalog.

## Invariant 2 — Private workspace is explicit
`Mi Showcase` resolves only the private Showcase for the active club when entered from club context. Failure to resolve that private workspace must be shown as an explicit private error and must not alter the public catalog route.

## Invariant 3 — Multiclub isolation
The active `club_id` is the tenant key for Club Showcase management. Changing active club changes the private workspace resolution. One club cannot be selected because another club's provider was loaded first.

## Invariant 4 — Direct identities are separate
Marca, Federación and Competidor providers are resolved in direct-profile context, not while opening a club's `Mi Showcase`.

## Invariant 5 — Idempotency
Club provider creation/linking uses the existing unique club provider constraint and `app_kombax_showcase_ensure_club_v045`; repeated access must return the same provider, not create a second seller identity.

## Regression gate
`scripts/test-kombax-20126-r75-showcase-context-separation.mjs` enforces these invariants and is part of the main `npm test` chain.
