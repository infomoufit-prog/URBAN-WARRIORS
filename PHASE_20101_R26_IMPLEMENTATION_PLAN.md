# KOMBAX 20.101 R26 · Privacy, Authorized Support & Events Navigation Stabilization

Internal implementation plan. Baseline: R25.

1. Objective: add customer-visible privacy/support authorization without weakening Owner control, plus a small Events navigation smoothness improvement.
2. Scope: Club Settings, personal account profile, direct/professional profile hub, support authorization backend, audit trail, Events discovery re-entry/render behavior.
3. Out of scope: email bot implementation, Gmail automation, Finance redesign, Auth redesign, Netlify/GitHub deploy, Play versionCode increment.
4. Files/modules: admin.js, gateway.js, repositories.js, new support-privacy.js, kombax-events.js, CSS, index cache-bust, service worker, migration 194, tests/docs.
5. Backend: additive tables/RPC only. Existing Owner platform admin/entity-session path remains authoritative and unchanged.
6. Risks: accidental weakening of RLS, conflating support with moderation, exposing authorization codes, breaking direct-profile hub, Events regressions.
7. Regression: R25, multiclub, owner access, Social/Showcase, Events R22/R23/R25.
8. Multiclub: club authorization must be created only by Dirección/Coordinación for that club; direct-profile authorization only by profile owner/manager.
9. Data: no deletes/truncates; codes stored hashed; plaintext code returned only once at creation.
10. Migration: additive/idempotent R194, explicit grants/revokes, security-definer search_path fixed.
11. Seed preservation: no seed changes.
12. QA: dedicated R26 test, full npm test/build, parity, backend live checks, advisors, Android preflight.
13. Closure: support UI visible in required locations; authorizations temporal/scoped/revocable/audited; Owner still independent/audited; Events re-entry uses cached discovery + scroll continuity without changing backend.
