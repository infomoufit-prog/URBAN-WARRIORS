KOMBAX 20.101 R15 · RESPONSIVE VISUAL TUNING

BASE
- Working base: KOMBAX 20.101 R14 Event Creator Complete.

MISSION
- Tune the visual distribution of the main gateway hero and the three product heroes (Social, Events, Showcase) across desktop/PWA, tablet, mobile portrait and mobile landscape.
- Preserve Event Creator R14, Fight Cards, multiclub logic and all backend work.

SCOPE
1. Gateway: better fusion between image and text on mobile, less boxed feeling, more natural crop.
2. Social / Events / Showcase: reduce apparent mobile zoom and add explicit tablet + landscape rules.
3. Keep desktop look intact unless a responsive override is needed.
4. Verify PWA/browser + Android bundle parity.

NO-GO
- No new backend/schema changes.
- No replacement of approved artwork.

FILES CHANGED
- web/css/kombax-brand-heroes.css
- web/css/kombax-premium.css
- web/index.html
- web/service-worker.js
- package.json
- scripts/test-kombax-20101-responsive-visual-tuning-r15.mjs
- historical R11/R12/R13/R14 cache assertions updated to accept R15.

QA PLAN
- Dedicated R15 responsive test.
- Full npm run build.
- Confirm web = dist = Android.

CLOSURE
- Mobile heroes feel less zoomed.
- Gateway mobile image is visually fused with the text block.
- Tablet and landscape phone have their own tuning.
- Existing Event Creator / Fight Cards remain functional.
