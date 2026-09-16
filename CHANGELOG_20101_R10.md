# KOMBAX 20.101 R10 · Social Hero + Smoke Hardening

## Summary
R10 implements the approved new KOMBAX Social hero image and replaces the previous barely visible smoke treatment with a more visible, still lightweight, asset-driven smoke system safe for web, PWA and Android APK generation.

## Implemented
- Replaced `web/assets/brand-heroes/hero-social.webp` with the newly approved social key art.
- Reframed Social desktop crop to keep the fighter dominant on the right while preserving copy space on the left.
- Reframed Social mobile crop for a cleaner upper-body focus.
- Added two optimized smoke textures:
  - `web/assets/brand-heroes/smoke-texture-a.webp`
  - `web/assets/brand-heroes/smoke-texture-b.webp`
- Hardened Brand Heroes smoke rendering to use texture-based layers animated with CSS only.
- Hardened gateway hero smoke rendering to use the same texture-based visible route.
- Preserved `prefers-reduced-motion` protections.
- Bumped web cache-busting to `20101r10`.
- Bumped service-worker media cache to `media-r10`.
- Added dedicated regression test `scripts/test-kombax-20101-social-smoke-r10.mjs`.
- Updated older R7 / R8 assertions so the new cache-busting level is accepted.
- Rebuilt `dist/` and `android/app/src/main/assets/www/` from the updated `web/` source.

## Compatibility Notes
- No video, GIF, WebGL or runtime animation library introduced.
- Approach remains compatible with Chrome / Chromium / Android WebView / PWA.
- Existing Events demo work and R8 assets remain preserved.
