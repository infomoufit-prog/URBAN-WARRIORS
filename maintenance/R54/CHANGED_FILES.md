# R53 → R54 Changed Files

## Functional source
- `web/js/modules/kombax-events.js`
- `web/css/kombax-events.css`
- `scripts/test-kombax-20104-r54-events-flow-mobile-quality.mjs` (new)

## Build/version plumbing
- `web/config.js`
- `web/service-worker.js`
- `web/index.html`
- `web/privacy.html`
- `web/terms.html`
- `web/child-safety.html`
- `web/delete-account.html`
- `android/app/build.gradle`
- `android/app/src/main/java/com/urbanwarriors/app/MainActivity.java`
- `scripts/android-debug-qa.mjs`
- `scripts/android-play-bundle.mjs`
- `supabase/functions/health/index.ts` (source identity only; deployment is separate)
- `package.json`
- `scripts/test-kombax-20101-r53-pilot-network-profile-events.mjs` (monotonic build compatibility only)

## Deliberately unchanged working product areas
R54 does not change the working Social/Showcase/public-profile implementation:
- `web/js/modules/kombax-social.js` SHA-256 `ae13f44791d240519291be80ecc6a497fb3b0e344e24787f884471447a413c9e`
- `web/js/modules/showcase.js` SHA-256 `af769c24f454393515da9822077d62159953d263405178a7952edd6b8f0edbae`
- `web/js/modules/public-profile.js` SHA-256 `0f27c88e82bb78f0c309fb534de912c7e353e7e89d27f0646f74c35993e59d16`
- `web/css/kombax-premium.css` SHA-256 `4507c58c99b65fa2e729cb837d40d9ed07443b989c79d45c6a3118cb63f01f73`
