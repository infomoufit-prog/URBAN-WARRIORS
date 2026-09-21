# GOOGLE PLAY RELEASE CHECKLIST · KOMBAX 20.101 R21

R21 is currently a REAL-TEST APK candidate, not a declared production Play release.

Automated state:
- applicationId/package: com.urbanwarriors.app PASS
- versionCode: 20101 PASS for local/manual testing
- web/dist/android parity: PASS
- Firebase asset: PASS
- JKS inherited: present
- keystore.properties: intentionally absent
- Signed APK/AAB R21: NOT GENERATED in this delivery

Before any future Play upload:
1. Complete real-device R21 visual acceptance.
2. Check which versionCode is already uploaded to Play.
3. Increment versionCode only if required.
4. Restore local signing configuration; never commit passwords.
5. Generate release AAB/APK and verify signature.
6. Upload only after explicit release decision.
