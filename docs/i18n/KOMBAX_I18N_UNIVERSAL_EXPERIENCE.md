# KOMBAX · Universal Multilingual Experience · U01–U05

## Mission
KOMBAX now treats multilingual support as an end-to-end experience, not only a system-UI catalog. All KOMBAX-generated copy remains strict i18n across ES/EN/FR/PT/IT/DE/TH/FIL, while authored content can be shown as a derived translation without overwriting the source.

## U01 · Derived translation service and cache
- Additive migration `20260915224500_kombax_universal_content_translation_u01.sql`.
- Cache key includes content type/id/field, source SHA-256 and target locale.
- Public translations are reusable; private translations are requester-scoped.
- Original authored content is never updated by the translation layer.

## U02 · Universal runtime and controls
- `Ver traducción / View original` controls use locale-specific UI copy.
- Public authored content may auto-translate according to the local preference.
- Private content is always opt-in.
- Locale changes restore the original first and request/reuse the translation for the new target locale.

## U03 · Social, profiles and private messaging
- Social posts and comments are translatable.
- Messages are private and manual-only.
- Public bios and identity/editorial profile content are translatable.

## U04 · Showcase, Events and organizational authored content
- Product names, summaries, descriptions and reviews are translatable.
- Event names, summaries, descriptions, community content and media captions are translatable.
- Club/brand/editorial copy, communications, material/product copy, tariffs/scopes and professional authored content are covered.
- Public content can be prewarmed to all eight locales after save/publish. Multi-field prewarm batches are supported.

## U05 · Full experience, onboarding and QA
- The eight-language selector is visible on the first KOMBAX gateway/onboarding screen before club/profile/account selection.
- The selected locale is stored locally and is included as `preferred_locale` during sign-up.
- Catalog: 1088/1088 direct keys in each of the eight enabled locales.
- Universal content gate: 15/15 PASS.
- Full regression and build/legal gates must remain PASS before packaging.

## Deployment boundary
This implementation is packaged but does not deploy the Supabase migration/Edge Function automatically. Authorized staging must configure `OPENAI_API_KEY` (and optionally `KOMBAX_TRANSLATION_MODEL`) and validate RLS, public cache reuse, requester-scoped private translations, cost/rate behavior and provider availability.
