KOMBAX 20.101 R18 · DEMO EVENT IMAGE ROUTING HARDENING

BASE
- KOMBAX 20.101 R17 Android Fighter Image Hardening.

OBSERVED FAILURE
- Urban Warriors images validate on device after R17.
- Noche de Impacto · Barcelona Fight Cards remain broken on device.
- Supabase RPC returns all 12 BCN fighter image URLs under https://kombax.es/assets/demo-events/noche-impacto-barcelona/...
- The corresponding 12 WEBP files are already bundled in web and Android assets.

SCOPE
1. Make demo-event kombax.es asset URLs resolve to bundled relative assets on every runtime, not localhost only.
2. Preserve HTTPS handling for non-demo/real external fighter URLs.
3. Validate all 12 BCN fighter files exist in web and Android asset bundles.
4. Validate all 6 BCN Fight Cards pass through the hardened image resolver.
5. Preserve Urban Warriors R17 hardening and all R16/R15/R14 functionality.

RISKS
- Over-broad URL rewriting could affect real external media. Mitigation: rewrite only the exact kombax.es /assets/demo-events/ namespace.
- Cache may preserve old JS. Mitigation: bump cache key to R18.

BACKEND
- No schema/RLS change required. This is a renderer/routing defect; Supabase already returns the expected URLs.

QA / CLOSURE
- Dedicated R18 test PASS.
- 12/12 BCN fighter local assets present in web and Android.
- 6/6 Fight Cards use safeImage / fighter resolver path.
- Urban R17 test PASS.
- Full npm run build PASS.
- web = dist = Android.
- Device visual validation remains required after installing an APK built from R18.
