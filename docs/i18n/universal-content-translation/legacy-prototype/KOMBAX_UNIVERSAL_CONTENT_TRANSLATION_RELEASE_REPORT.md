# KOMBAX Universal Content Translation — Release Report

Date: 2026-09-15

## Status

**IMPLEMENTED / AUTOMATED QA PASSED / NOT DEPLOYED**

KOMBAX now includes a derived translation layer for user-authored textual content across all eight enabled locales. The original user content remains the source of truth and is never overwritten by translation.

## Implemented surfaces

- Social posts and comments
- Club/community posts
- Showcase product names and descriptions
- Events names, descriptions, comments, reviews and organizer responses
- Public profile bio/description and editorial profile text
- Brand/club/federation editorial content
- Generic user-generated text
- Direct/private messages (authenticated, on-demand, non-persistent)

## Data and privacy model

Public/member derived translations may be cached in `kombax_content_translations`. The cache key includes a SHA-256 hash of the source, so an edit to original content prevents stale translations from being reused. The cache does not overwrite source rows. Direct/private-message translations are not persisted.

## Runtime/service

- Frontend runtime: `web/js/i18n/user-content-translation.js`
- Migration: `supabase/migrations/20260915224500_kombax_universal_content_translation.sql`
- Edge Function: `supabase/functions/content-translate/index.ts`
- QA: `scripts/test-kombax-i18n-universal-content.mjs`

## Automated evidence

- Universal-content test: PASS 8/8
- i18n catalogs: 1,084/1,084 direct keys in each of 8 locales
- ALL8 gate: PASS
- npm test: PASS
- Build: PASS, 449 files web = dist = Android
- Legal Gate: PASS
- Android preflight: 4/5, only external signing config pending
- Edge TypeScript syntax/transpile: 0 diagnostics

## Not performed

No Supabase migration or Edge deployment, GitHub push, Netlify deploy, or Google Play publication was performed.

## Required authorized staging/live QA

- Deploy migration and Edge Function through the approved process.
- Configure `OPENAI_API_KEY` (optional `KOMBAX_TRANSLATION_MODEL`).
- Validate cache/RLS and source-hash invalidation.
- Validate public/member translation in all eight locales.
- Validate direct/private translation never persists.
- Validate rate limits/provider failures/fallback UX.
- Perform real browser/PWA/Android QA with representative identities.

## Release conclusion

The universal translation capability is implementation-complete and suitable for staging validation. It must not be described as production-validated until the prepared migration/function are deployed in an authorized environment and the live privacy/provider flows pass QA.
