KOMBAX 20.101 R10 · SOCIAL HERO + SMOKE HARDENING

BASE
- Working base: KOMBAX 20.101 R9 Visual Hero Fix.
- Goal: implement the approved new KOMBAX Social hero image and replace the barely visible smoke approach with a safer and more visible alternative that remains lightweight for PWA, browser and Android APK / Google Play WebView.

SCOPE
1. Replace the Social Brand Hero asset with the approved new composition.
2. Reframe Social desktop/mobile crop so headline space remains clean and the fighter remains dominant.
3. Replace the previous too-subtle smoke approach with asset-driven animated smoke layers.
4. Apply the same hardened smoke route to the gateway hero so the atmospheric effect is visibly present.
5. Preserve Events / Showcase / demo event / owner bootstrap / existing navigation and branding flows.
6. Rebuild web, dist and Android static bundle from the same source tree.

WHY THIS ROUTE
- The prior smoke implementation was technically correct but visually too soft on some devices.
- The new route uses optimized static WEBP smoke textures animated with CSS only.
- This avoids video/GIF/WebGL/runtime libraries and stays safe for Android System WebView, Chrome, PWA and desktop browsers.

RISKS
- Cache persistence could hide the new hero or smoke layers on previously installed PWA/APK sessions.
- Reframing Social could accidentally reduce text legibility on some breakpoints.
- Changing smoke constants could break prior visual regression tests.

MITIGATIONS
- Bump cache-busting from 20101r9 to 20101r10 and update service-worker media cache.
- Keep copy mask and legibility gradients intact.
- Add dedicated R10 regression test and update older R7/R8 cache assertions to accept R10.
- Keep motion CSS-only and reduced-motion compliant.

FILES EXPECTED TO CHANGE
- web/assets/brand-heroes/hero-social.webp
- web/assets/brand-heroes/smoke-texture-a.webp
- web/assets/brand-heroes/smoke-texture-b.webp
- web/css/kombax-brand-heroes.css
- web/css/kombax-premium.css
- web/index.html
- web/service-worker.js
- package.json
- scripts/test-kombax-20101-gateway-atmospheric-r7.mjs
- scripts/test-kombax-20101-urban-warriors-jiujitsu-r8.mjs
- scripts/test-kombax-20101-social-smoke-r10.mjs

QA / VALIDATION PLAN
- Run dedicated R10 visual regression test.
- Run full npm build (which includes pretest, full regression suite and static build copy).
- Confirm build determinism web = dist = Android.
- Verify reduced-motion protections remain present.
- Verify no video/GIF/WebGL introduced.

CLOSURE CRITERIA
- Approved Social hero asset is present in codebase.
- Smoke is implemented through the new visible route.
- npm run build passes.
- dist and android bundles are regenerated.
- Handoff ZIP is ready for local validation / APK generation.
