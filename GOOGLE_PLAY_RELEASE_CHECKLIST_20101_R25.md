# GOOGLE PLAY RELEASE CHECKLIST — R25

R25 is a pilot stabilization source candidate, not a claim of Play-production readiness by itself.

Before any Play upload:
- Physical Android R25 validation complete.
- `Me interesa` verified on installed release build.
- Continuous Events scroll accepted on device.
- package remains `com.urbanwarriors.app`.
- Confirm current Play Console versionCode before changing local versionCode.
- Use the existing local release signing setup; keep passwords private.
- Generate signed AAB/APK locally and verify signing certificate.
- Run Android preflight after local signing config is restored.
- Smoke test login, Mi Club, Social, Showcase, Events, Community and Finance.
- Confirm legal/Play declarations remain current before production rollout.

Current automated state:
- package: PASS
- versionCode 20101: PASS
- assets/www: PASS
- Firebase: PASS
- signing config in delivery: PENDING by design (`android/keystore.properties` absent)
