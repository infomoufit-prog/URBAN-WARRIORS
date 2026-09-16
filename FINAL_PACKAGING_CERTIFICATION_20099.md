# KOMBAX 20.099 · Final Packaging Certification

- regular files: 1338
- manifest entries: 1336 (manifest excludes itself and the verification log)
- manifest verification: PASS
- npm test final: PASS
- npm run build: PASS · 102 archivos · web = dist = Android
- legal gate: PASS
- Android preflight: 4/5; only local keystore.properties credentials are pending by design
- release JKS included intentionally under LOCAL_RELEASE_SIGNING/
- JKS SHA-256: 7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415
- no .env, PEM, P12/PFX or real keystore.properties in the package
- Supabase migrations 175 and 176 applied; frontend deploy not performed
