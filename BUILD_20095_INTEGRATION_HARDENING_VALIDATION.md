# KOMBAX RC13 build 20.095 · Integration / Hardening Final Candidate · Validation

## Scope

20.095 is a hardening/integration build based on the certified 20.094 source. It does not activate Spectator and does not add a new Supabase schema migration.

## Changes validated

1. Android deep-links now preserve validated `event` and `fight` parameters.
2. Public event landing still resolves before authentication restoration.
3. Event media signed URLs refresh after media load failure; download requests a fresh signature.
4. Failed media degrades to an explicit non-blocking state with manual retry.
5. Service Worker does not cache cross-origin signed URLs.
6. Netlify retains SPA fallback and Supabase-compatible CSP.
7. Release identity is 20095 in web, PWA, Android and local health source.
8. Spectator remains disabled.

## Gates executed

- `node --check web/js/modules/kombax-events.js`: PASS.
- `node scripts/test-kombax-20094-live-results-highlights-history.mjs`: PASS.
- `node scripts/test-kombax-20095-integration-hardening.mjs`: PASS.
- `npm test`: PASS, including historical regression through 20.095.
- `npm run build`: PASS.
- Deterministic build: `101 archivos · web = dist = Android`.
- `npm run release:legal-gate`: PASS.
- `npm run android:preflight`: 4/5; only local signing is pending because credentials/JKS are intentionally not shipped.

## Backend reconciliation

Production was read-only checked during this closure:

- `health`: v14 ACTIVE, build 20094; deliberately not advanced before frontend deployment.
- `event-media-url`: v1 ACTIVE, signed URL TTL 900 seconds.
- `app_kombax_evento_media_asset_v165(uuid)`: anon=false, authenticated=false, service_role=true.
- `kombax-events-media`: private (`public=false`).

No Supabase migration or production mutation was required by 20.095.

## Release blockers outside this environment

- Android local signing must reach preflight 5/5 using the existing keystore.
- Netlify deployment and real production browser/PWA QA are not executed here.
- APK/AAB generation and device/Google Play validation are not executed here.
- Verified Android App Links remain gated on the actual Google Play App Signing SHA-256 + Digital Asset Links publication.

## Verdict

**PASS as integration candidate.** Ready to move to controlled Netlify and signed Android validation, with no claim that external deployment/signing has already been completed.
