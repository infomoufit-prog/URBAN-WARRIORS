# QA handoff — KOMBAX 20.101 R52.2

## Automated validation
- R52.2 focused regression: 10/10 PASS.
- R52 cover inheritance regression: 15/15 PASS.
- R52.1 Android runner regression: 13/13 PASS.
- R51 video covers/album regression: 54/54 PASS.
- Full `npm test`: EXIT 0.
- Build parity: web 190 = dist 190 = Android assets 190; 0 missing, 0 extra, 0 SHA differences.

## Android
`npm run android:debug:qa` now reaches the real Gradle wrapper after synchronizing web -> dist -> Android assets. In the current isolated validation environment it cannot complete because DNS cannot reach `services.gradle.org` to download Gradle 8.11.1. This is an environment/network limitation, not a project code failure.

Expected local output:
`android/app/build/outputs/apk/debug/app-debug.apk`

Named QA artifact:
`artifacts/KOMBAX_20101_R52_2_SOCIAL_ANDROID_POSTER_FIX_DEBUG.apk`

## Google Play
`npm run android:preflight` = 4/5. Pending only local release signing (`android/keystore.properties`). The Play AAB command is prepared as `npm run android:aab:play` and will create:
`artifacts/KOMBAX_20101_R52_2_SOCIAL_ANDROID_POSTER_FIX_GOOGLE_PLAY.aab`
when signing and Gradle dependencies are available.

## Manual QA required
1. Install the R52.2 debug APK generated locally.
2. Open KOMBAX Social and locate the 37 s video/any new video with a generated cover.
3. Confirm feed card shows the chosen/automatic poster before playback.
4. Confirm album and feed use the same cover/framing intent.
5. Open full-screen playback and confirm the original full video remains available.
