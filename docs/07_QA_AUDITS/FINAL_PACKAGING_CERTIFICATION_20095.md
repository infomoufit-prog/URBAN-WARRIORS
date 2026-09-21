# Final packaging certification · KOMBAX RC13 build 20.095

## Candidate

`KOMBAX_RC13_build_20095_INTEGRATION_HARDENING_FINAL_CANDIDATE`

## Certified gates

- historical `npm test`: PASS through build 20.095;
- `npm run build`: PASS;
- deterministic frontend parity: 101 web = 101 dist = 101 Android assets;
- `npm run release:legal-gate`: PASS;
- Android preflight: 4/5, with only local signing deliberately absent;
- deep-link Android `event` / `fight`: covered by 20.095 test;
- signed event media: refresh/retry path covered by 20.095 test;
- Supabase production reconciliation: `event-media-url` v1 ACTIVE, private bucket, internal asset resolver service-role-only;
- production `health` intentionally remains 20094 until Netlify 20095 is actually deployed;
- Spectator remains disabled.

## Package hygiene

- no `.env` files;
- no JKS/keystore/P12/PFX/PEM;
- no `keystore.properties`;
- no `node_modules`;
- no literal service-role secret assignment detected;
- `google-services.json` remains as Android/Firebase application configuration, not as a signing credential.

## Integrity rule

The final folder contains one current integrity manifest: `BUILD_MANIFEST_SHA256_20095.txt`. It covers every regular file in the final folder except the manifest itself. The external ZIP is additionally distributed with its own `.sha256` file.

## External actions not certified here

Netlify deployment, production browser/PWA QA, local JKS signing, APK/AAB generation, physical device update and Google Play promotion remain controlled next-step validations. Verified Android App Links remain gated on the real Google Play App Signing SHA-256 and Digital Asset Links.
