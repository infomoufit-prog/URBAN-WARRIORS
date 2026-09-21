# KOMBAX 20.101 R42 · Freeze Candidate from R40

## Base
R40 is the sole functional baseline. R41 is not promoted as a baseline.

## Scope
Only two R41 deltas are selectively ported onto R40:
1. Mobile safe-viewport containment for the public “¿Qué es KOMBAX?” explainer.
2. Neutral KOMBAX structural watermark for shell/sidebar/generic heroes while preserving explicit tenant branding.

## Non-scope / freeze guard
No intentional changes to Supabase, SQL migrations, RLS, RPC, Edge Functions, entitlements, Social business logic, Events business logic, Assist, Finance, authentication, account security, or data model.

## QA gates
- Targeted R42 assertions.
- Full inherited npm regression suite.
- Build web → dist → Android assets.
- SHA-256 parity across runtime targets.
- Static secret-path audit.
- Android preflight.
- Clean ZIP extraction smoke.

## Pilot rule
R42 may be called “freeze candidate” only after all static/local gates pass. Live Supabase production readiness, real-account E2E, device visual QA, signing and external cybersecurity review remain separate deployment gates.
