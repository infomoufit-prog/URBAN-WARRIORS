# QA Validation · KOMBAX 20.101 R10

## Objective
Validate that the approved Social hero image and the alternative visible smoke route are implemented safely and that the build remains ready for browser, PWA and Android APK generation.

## Tests executed
1. `node scripts/test-kombax-20101-social-smoke-r10.mjs`
2. `npm run build`

## Result
- Dedicated R10 test: PASS
- Full regression suite: PASS
- Static build copy: PASS
- Deterministic asset copy: PASS (`web = dist = Android`)

## Key assertions covered
- Gateway keeps module-relative hero asset resolution.
- Gateway uses texture-based smoke assets with visible timing and opacity.
- Social uses the new hero asset and updated crop values.
- Shared smoke textures exist and are wired into Brand Heroes.
- Social smoke intensity is strengthened.
- Event hero safe organization rail remains preserved.
- Urban Warriors Jiu-Jitsu demo assets remain preserved.
- Cache-busting is raised to R10.
- Older R7/R8 suites still pass after accepting the new cache level.

## Output status
Ready for:
- local browser validation
- PWA validation
- Android APK / AAB generation flow
- Google Play internal testing flow
