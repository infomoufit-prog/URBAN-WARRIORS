# KOMBAX Universal Content Translation

## Goal
Every textual experience can be viewed in the selected locale. KOMBAX-owned UI uses the static i18n catalog. User-authored text uses derived AI translations without overwriting the original.

## Covered content
Social posts/comments, Club Community posts, Showcase product names/descriptions, Events names/descriptions/comments/reviews/organizer responses, public profile bios/descriptions, Brand/Club/Federation editorial text, and direct-message text.

## Privacy
- Original text remains the source of truth in the original source table.
- Public/member content translations may be cached using content type + content id + field + SHA-256 source hash + target locale.
- Direct-message/private-note translations are opt-in and are never persisted in the translation cache.
- The cache table has RLS enabled and no anon/authenticated direct policies.

## Invalidation
Editing the original changes its SHA-256 hash; old cached translations are therefore never selected for the new text.

## Runtime
A MutationObserver discovers supported user-content surfaces. Public content is translated automatically when visible (IntersectionObserver) and always exposes “View original”. Chat/private messages remain on-demand. Locale changes restore the original first and request a translation for the new target locale.

## Provider
The Edge Function uses OPENAI_API_KEY and KOMBAX_TRANSLATION_MODEL (default gpt-5.6-luna). It preserves KOMBAX/Stripe/QR, URLs, IDs, amounts, handles, hashtags, emoji and proper names.

## Deployment
Migration and Edge Function are prepared but not deployed automatically. Deploy only through an authorized release process.
