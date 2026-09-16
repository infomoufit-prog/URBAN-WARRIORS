# R54 QA Handoff

## Identity
- Web/PWA build: **20104**
- Android `versionCode`: **20104**
- Android `versionName`: **2.0.0-rc.13-r54-pilot**
- Debug artifact target: `artifacts/KOMBAX_20104_R54_PILOT_DEBUG.apk`
- Play artifact target: `artifacts/KOMBAX_20104_R54_PILOT_GOOGLE_PLAY.aab`

## Automated validation completed
- Full `npm test`: **EXIT 0**.
- R44 Events Flow: **25/25 PASS**.
- R48 Events Premium: **28/28 PASS**.
- R49 Social + Events: **29/29 PASS**.
- R51 media/video covers: **54/54 PASS**.
- R52: **15/15 PASS**.
- R52.2: **10/10 PASS**.
- R53: **21/21 PASS**.
- R54 Events quality/mobile: **14/14 PASS**.
- Deterministic build: **191 Web = 191 Dist = 191 Android; 0 missing, 0 extras, 0 SHA differences**.

## Commands
```bash
npm test
node scripts/build.mjs
npm run android:preflight
npm run android:debug:qa
npm run android:aab:play
```

## Android environment result in this handoff environment
`android:preflight` completed 4/5 checks; only local release signing is intentionally absent (`android/keystore.properties`).

The debug APK pipeline reached Gradle, then the environment failed while downloading Gradle 8.11.1 because `services.gradle.org` could not be resolved (`UnknownHostException`). No APK binary is claimed from this environment.

Use the project owner's established local signing environment for the final debug/release binary and Play AAB.

## Manual pilot checks recommended after local APK generation
1. Open Events on a 360–390 px wide Android screen and verify a complete compact event card is visible without an oversized poster/body.
2. Open the card; verify the full event detail contains registration/ticket/map/fight-card actions omitted from the compact card.
3. Simulate a temporary network failure while refreshing discovery; existing cards must remain visible.
4. Open an event with a temporary read failure; verify in-context retry and successful recovery.
5. Select an invalid/oversized media batch; verify the batch is rejected before uploads start.
6. Upload valid portrait, landscape and square images plus a <=1 minute video and verify framing/cover behavior.
7. Verify KOMBAX Social, Showcase and public profile navigation remains unchanged.
