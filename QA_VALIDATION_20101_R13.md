# QA Validation · KOMBAX 20.101 R13

## Purpose
Certify the mobile UX and Fight Card visibility intervention before local validation and APK Signed generation.

## Automated validation
### Dedicated R13 test
`node scripts/test-kombax-20101-mobile-events-fightcards-r13.mjs`

Result: PASS

Validated assertions:
- Fight Card rows are sorted and counted.
- Fight Card section is promoted before information blocks.
- Cards do not depend on the decorative SVG template to remain visible.
- Fighter image fallback is wired in both authenticated detail and public event landing.
- Fight grid is explicitly visible.
- Mobile Fight Cards become a single-column compact layout.
- Mobile Social, Events and Showcase use reduced-zoom crops.
- Gateway mobile image blends into copy.
- Gateway mobile smoke is restrained.
- R11 alpha smoke assets remain and R10 texture route remains absent.
- Urban Warriors Jiu-Jitsu assets remain.
- Cache-busting is R13.

### Full build
`npm run build`

Result: PASS

Final static result:
`OK build 152 archivos · web = dist = Android`

## Deterministic critical-file checks
The following files were hashed after build and are byte-identical in `web`, `dist` and `android/app/src/main/assets/www`:
- `css/kombax-events.css`
- `css/kombax-brand-heroes.css`
- `css/kombax-premium.css`
- `js/modules/kombax-events.js`
- `assets/brand-heroes/hero-social.webp`
- `assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp`

## Backend verification
No backend change was made in R13. A direct Supabase verification confirms that both current event records retain six public fights:
- Noche de Impacto · Barcelona: 6 fights.
- Urban Warriors · Interclub de Jiu-Jitsu · Palafolls: 6 fights.

At the time of this certification, both event media catalogs still report 0 active Storage media rows. Their local/demo cover assets remain available in the application bundle; album upload remains a separate media-bootstrap step and is not confused with Fight Card visibility.

## Multiclub / safety
- R12 and R13 `supabase/` trees compare identical.
- No RLS, ownership, entitlement or workspace changes in this phase.
- Urban Warriors event ownership remains in the existing backend model.

## Android preflight
Result: 4/5 prepared.

PASS:
- Android identity stable.
- versionCode 20101.
- embedded web assets present.
- Firebase configuration present.

Expected local pending item:
- `android/keystore.properties` is intentionally not bundled with secrets.
- Restore it locally using `LOCAL_RELEASE_SIGNING/RESTORE_SIGNING_WINDOWS.cmd` or the documented PowerShell equivalent before generating the signed release.

JKS SHA-256 remains:
`7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415`

## Manual validation still required
Automated tests can certify code paths and bundles, but the following remain visual acceptance checks on the user's devices:
- gateway image/text fusion on the target Android screen;
- desired amount of zoom in Social / Events / Showcase;
- visual smoke intensity;
- Fight Card aesthetics and readability on the installed APK.
