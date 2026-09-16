KOMBAX 20.101 R12 · GATEWAY REFRAME FINAL

BASE
- Working base: KOMBAX 20.101 R11 Real Alpha Smoke.

MISSION
- Keep the approved gateway image exactly as-is and improve only its framing, scale and visual balance for desktop/mobile.
- Re-check the smoke treatment with the new understanding that the gateway art already includes atmosphere; avoid over-processing.
- Preserve Social, Events, Showcase, Urban Warriors Jiu-Jitsu demo event and Android/PWA readiness.

SCOPE
1. Reposition and rescale the gateway multi-fighter hero artwork.
2. Reduce extra gateway smoke so the built-in atmospheric look of the artwork remains primary.
3. Keep the R11 alpha-smoke route intact for the product while refining the gateway specifically.
4. Rebuild and re-verify web, dist and Android bundles.

FILES EXPECTED TO CHANGE
- web/css/kombax-premium.css
- web/index.html
- web/service-worker.js
- package.json
- scripts/test-kombax-20101-gateway-reframe-r12.mjs

QA PLAN
- Run dedicated R12 regression test.
- Run full `npm run build`.
- Confirm `web = dist = Android`.
- Keep no backend or schema changes.

CLOSURE CRITERIA
- Gateway image no longer feels boxed/cropped awkwardly.
- Extra gateway smoke is softened and no longer competes with the art itself.
- Full build passes and ZIP is ready for local + APK signed validation.
