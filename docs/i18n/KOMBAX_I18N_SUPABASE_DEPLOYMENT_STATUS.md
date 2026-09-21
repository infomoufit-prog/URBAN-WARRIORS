# KOMBAX i18n · Supabase deployment status

## Current state

**IMPLEMENTED + LOCAL QA PASSED / REMOTE DEPLOYMENT BLOCKED BY CONNECTOR 502**

Project ref identified from the source configuration: `poggsobhtutbuagjiydc`.

The Supabase connector returned HTTP 502 on project discovery, direct project lookup, migration listing and SQL verification. No remote DDL or Edge Function deployment is claimed.

## Deployment set

Apply in this order:

1. `supabase/migrations/20260914230000_kombax_i18n_locale_preference_b01.sql`
   - adds `perfiles.preferred_locale`;
   - authenticated get/set RPCs;
   - eight-locale check constraint.

2. `supabase/migrations/20260914233000_kombax_i18n_legal_metadata_b03.sql`
   - separates legal `locale`, `jurisdiction`, and existing legal version;
   - additive indexes only.

3. `supabase/migrations/20260915224500_kombax_universal_content_translation_u01.sql`
   - derived translation cache only;
   - source-authored tables are never overwritten;
   - RLS enabled; anon/authenticated can read only public derived translations.

4. Deploy Edge Function `kombax-content-translate` with JWT verification **enabled**.

## Runtime secrets

The Edge Function requires `OPENAI_API_KEY`; `KOMBAX_TRANSLATION_MODEL` is optional and defaults to `gpt-5.6-luna`. Existing Supabase-provided URL/key secrets are read from the Edge runtime. Secret values must never be copied into the ZIP.

## Required live verification after connector recovery

- confirm the three migrations appear in remote migration history;
- confirm `public.kombax_content_translations_u01` exists with RLS enabled;
- confirm public SELECT policy exposes only `visibility = public AND requester_id IS NULL`;
- confirm preferred-locale RPCs work only for authenticated users;
- confirm Edge Function requires a valid JWT;
- invoke a translation in each of the eight target locales;
- confirm a second identical request is a cache hit;
- edit source text and confirm the changed SHA-256 causes a new cache row;
- confirm private-message translation is requester-scoped and never anonymously readable;
- run Supabase security and performance advisors.

## Frontend/onboarding state

The first visible boot interface and the gateway/onboarding both expose ES/EN/FR/PT/IT/DE/TH/FIL before club/profile/account selection. The selected locale is stored locally and is included as `preferred_locale` at sign-up.

## Automated evidence

- universal content translation gate: **17/17 PASS**;
- i18n catalog: **1088/1088 × 8 locales**;
- full npm regression: **PASS**;
- Legal Gate: **PASS**;
- build: **PASS · 450 files · web = dist = Android**;
- Android preflight: **4/5**, local signing file intentionally external.
