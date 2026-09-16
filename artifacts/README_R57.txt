KOMBAX 20.107 R57 · QA FREEZE CANDIDATE

Expected local artifacts after successful builds:
- KOMBAX_20107_R57_QA_FREEZE_DEBUG.apk
- KOMBAX_20107_R57_QA_FREEZE_GOOGLE_PLAY.aab

This sandbox did not emit either binary:
- Debug build blocked while Gradle wrapper tried to reach services.gradle.org.
- Play bundle stopped at release preflight because android/keystore.properties is intentionally local/private.

Use:
  npm run android:debug:qa
  npm run android:aab:play
