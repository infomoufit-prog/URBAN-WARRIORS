# Local + Mobile Checklist · KOMBAX 20.101 R13

## Local browser
1. Start the project using the normal local development command.
2. Open the platform gateway.
3. At a mobile-width viewport verify that the image fades into the intro instead of ending as a separate card.
4. Open KOMBAX Social, Events and Showcase at mobile width and confirm the photos show more context / less crop than R12.
5. Open Noche de Impacto.
6. Immediately after the event navigation verify a Fight Card section showing 6 fights.
7. Open Urban Warriors Jiu-Jitsu.
8. Verify a Fight Card section showing 6 fights.
9. Confirm fights without custom photos still show a placeholder and remain fully readable.
10. Tap a Fight Card and verify its fight preview opens.

## Android APK
1. Restore local signing configuration from `LOCAL_RELEASE_SIGNING`.
2. Generate the Signed APK from the R13 project.
3. Install/update on the test Android device.
4. Repeat gateway + Social + Events + Showcase mobile checks.
5. Repeat both event Fight Card checks.
6. Verify navigation, back/close, scroll and touch targets.

## Smoke acceptance
- Gateway: subtle; must not obscure the multi-fighter artwork.
- Social: medium-light.
- Events: strongest of the three branded heroes.
- Showcase: lightest.
- No horizontal R10-style bands should appear.
