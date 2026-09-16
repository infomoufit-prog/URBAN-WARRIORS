# QA Validation · KOMBAX 20.101 R12

## Objective
Validate the final gateway reframe and ensure the build remains stable for browser, PWA and Android APK generation.

## Tests executed
1. `node scripts/test-kombax-20101-gateway-reframe-r12.mjs`
2. `npm run build`

## Result
- Dedicated R12 test: PASS
- Full regression suite: PASS
- Static build copy: PASS
- Deterministic copy: PASS (`web = dist = Android`)

## Key guarantees
- Approved gateway art preserved and reframed.
- Gateway smoke reduced and softened.
- Social hero preserved.
- Urban Warriors demo event preserved.
- No backend changes.
- Cache bust raised to R12.

## Ready for
- local browser validation
- APK Signed generation
- Android / PWA smoke-and-framing QA
