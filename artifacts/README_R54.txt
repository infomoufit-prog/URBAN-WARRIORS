KOMBAX 20104 R54 · BUILD 20104

This package contains the complete source project, built PWA (`dist`), Android project with synchronized embedded assets and the Google Play build pipeline.

No physical R54 APK is included because this execution environment cannot resolve services.gradle.org while Gradle Wrapper attempts to download Gradle 8.11.1.

Generate debug APK locally:
  npm run android:debug:qa
Expected outputs:
  android/app/build/outputs/apk/debug/app-debug.apk
  artifacts/KOMBAX_20104_R54_PILOT_DEBUG.apk

No signed AAB is included because android/keystore.properties is private local signing material and must not be invented or distributed.

With the legitimate release signing configuration:
  npm run android:aab:play
Expected output:
  artifacts/KOMBAX_20104_R54_PILOT_GOOGLE_PLAY.aab

Status: full automated project QA PASS; Web/PWA build PASS; Web=Dist=Android embedded assets; Android debug ready-to-build but blocked here only by external Gradle DNS; Google Play pipeline 4/5 pending local signing.
