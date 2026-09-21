# R25 LOCAL / PWA / ANDROID / PC CHECKLIST

## Local PC / Chrome
1. Extract R25 to a fresh folder.
2. Start using the project's normal local command.
3. Open Events and repeat: list → detail → scroll → back → reopen, at least 10 cycles.
4. Verify no console error from `Me interesa`.
5. Verify Main Event, Fight Cards, participants and album retain loaded images during repeated scroll.
6. Verify Social, Showcase, Community, Profile, Auth and Finance smoke flows still open.

## Android signed test
1. Keep `versionCode 20101` unless Play requires a new code for a new uploaded artifact.
2. Restore your local `android/keystore.properties`; do not share its passwords.
3. Build/sign locally in Android Studio.
4. Install R25 over/alongside the current test according to your normal release workflow.
5. Test Urban Events continuous scroll for several minutes.
6. After each image appears, scroll away and back; it must not deliberately blank/re-hydrate.
7. Tap `Me interesa`; verify no red JS error and the saved state persists after reopening.
8. Repeat open/back/reopen at least 10 times.
9. Test one non-demo/real-URL event if available.

## Tablet / responsive
- portrait and landscape
- no horizontal overflow
- bottom actions reachable
- Main Event hierarchy preserved
- Fight Cards do not clip text/faces

## PWA
- hard refresh after deploy when authorized
- verify R25 cache revision is active
- repeat Events scroll and Me interesa

## Acceptance
Do not mark Android zero-flash PASS until the physical device test above succeeds.
