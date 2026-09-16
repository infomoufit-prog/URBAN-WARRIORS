# Universal content translation QA

Required after authorized deployment:
1. Apply migration `20260915224500_kombax_universal_content_translation.sql`.
2. Deploy `content-translate` with `OPENAI_API_KEY` and optional `KOMBAX_TRANSLATION_MODEL`.
3. In each of ES/EN/FR/PT/IT/DE/TH/FIL verify Social post, comment, product name/description, event name/description/comment/review, profile bio and Club Community post.
4. Confirm automatic translation is shown for public content and “View original” restores exact authored text.
5. Edit an original text and confirm the old translation is not reused (hash invalidation).
6. Translate a direct chat message and verify no `privacy_scope=private` row is written to `kombax_content_translations`.
7. Verify names, URLs, QR/Stripe IDs, amounts and KOMBAX trademarks are unchanged.
8. Confirm RLS blocks direct anon/authenticated reads of `kombax_content_translations`.
9. Verify mobile/PWA/Android wrapping, especially DE/FR/TH.
