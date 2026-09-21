# KOMBAX i18n · Next action after Universal U01–U05

No further implementation block is required before runtime validation. Use this ZIP as the only base.

Next authorized activity is staging/manual QA:
1. Deploy/review the additive universal translation cache migration and `kombax-content-translate` Edge Function.
2. Configure the translation provider secret/model in staging.
3. Open KOMBAX from the first gateway/onboarding screen and verify the 8-language selector before registration.
4. Test account creation and `preferred_locale` persistence.
5. Test public authored content translation/cache reuse in Social, Showcase, Events, profiles and organizational editorial content.
6. Test private messages/documents only through manual `View translation`, confirming requester isolation.
7. Verify edits change the source hash and do not reuse stale translations.
8. Repeat Chrome/mobile/PWA/Android and provider-failure QA before production approval.
