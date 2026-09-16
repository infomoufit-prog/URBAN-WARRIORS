# QA Validation · KOMBAX 20.101 R11

## Smoke architecture
- R10 band/halo smoke path removed from active CSS.
- Four transparent WEBP smoke sprites are included: red, cyan, neutral and warm.
- Brand Heroes use three independent smoke layers.
- Gateway uses three independent smoke layers.
- No hue-rotate smoke recoloring remains.
- No video, GIF, WebGL or external animation dependency was introduced.
- Motion uses long transform/opacity animations and respects `prefers-reduced-motion`.

## Automated validation
- `node scripts/test-kombax-20101-real-alpha-smoke-r11.mjs`: PASS.
- Full `npm run build`: PASS.
- Result: `152 archivos · web = dist = Android`.
- R7 atmospheric regression: PASS after compatibility assertion update.
- R8 Urban Warriors Jiu-Jitsu regression: PASS.
- Web/dist/Android SHA256 identity checked for all R11 smoke assets, Social hero and both relevant CSS files.
- Alpha channel checked on generated smoke assets.

## Android / PWA
- Static assets are embedded in Android under `android/app/src/main/assets/www`.
- Cache bust raised to `20101r11` and service worker media cache to `media-r11`.
- Android signing material continuity remains unchanged; `keystore.properties` secrets are intentionally not embedded.

## Manual visual gate still required
Automated tests can prove the smoke is rendered, transparent, animated and packaged consistently, but the aesthetic judgment must be made in local/browser/APK visual QA. R11 should be accepted only if the smoke reads as smoke rather than a light band on the actual target displays.
