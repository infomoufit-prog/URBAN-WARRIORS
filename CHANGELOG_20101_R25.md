# CHANGELOG — KOMBAX 20.101 R25 · PILOT STABILIZATION

## Base
R23 · Urban Fighter Image Recovery.

## Added
- R23 no-code audit plan and audit report.
- R25 dedicated stabilization test.
- Modal pre-close lifecycle event for cleanup.
- Bounded Events detail cache.
- Image ready/decode pipeline for Events media.

## Fixed
- Events `Me interesa` null `currentTarget` error after asynchronous mutation.
- Equivalent async target lifetime risk in Events external-video action.
- Equivalent async target lifetime risk in Showcase saved-state action.
- Album media blank/retry lifecycle that could replace visible content before image decode.
- Forced album-wide hydration after 1.4 seconds.
- Observer lifecycle leak risk when an Events detail modal closes.
- Excess compositor work on mobile Events detail during continuous scroll.

## Preserved
- R22 keyset pagination and Fight Card hierarchy.
- R23 Urban packaged-image routing for temporary fixtures.
- Main Event / Co-Main / undercard hierarchy.
- 30 fights and 30-photo album rules.
- Existing backend/RLS/data model.
- R19/R20 demo seed isolation.

## Not changed
- Supabase schema/data/RPCs by R25.
- Finance/Auth behavior.
- Netlify or GitHub remote.
- Android versionCode/versionName.
- Release signing configuration.
