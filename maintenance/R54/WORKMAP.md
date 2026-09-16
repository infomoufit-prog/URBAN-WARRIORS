# R54 Work Map · KOMBAX Events

## Primary runtime files
- `web/js/modules/kombax-events.js` — discovery, event detail, builder, album, participants, fight card, visibility, sharing and recovery flows.
- `web/css/kombax-events.css` — Events visual system, event cards, detail, album and responsive/mobile rules.
- `web/js/core/repositories.js` — repository/API boundary, event media preparation, mutations, storage and rollback behavior.
- `web/js/modules/kombax-event-visuals.js` — shareable event/fight visual generation.
- `web/js/ui/media-framing.js` — shared media framing rules.
- `web/js/ui/video-cover.js` — shared video cover selection.

## Build surfaces
- PWA source: `web/`
- Generated deploy output: `dist/`
- Android embedded web: `android/app/src/main/assets/www/`
- Android native version: `android/app/build.gradle`
- Android UA/build identity: `android/app/src/main/java/com/urbanwarriors/app/MainActivity.java`

`node scripts/build.mjs` is the canonical sync operation. It copies `web/` into both generated surfaces and fails if SHA parity differs.

## Current R54 focus
1. Do not blank an existing Events list because of a transient read failure.
2. Do not leave event opening as a toast-only dead end; offer retry in context.
3. Validate a media batch before the first upload and keep progress/errors inside the album workflow.
4. Keep discovery cards compact on vertical phones; full information remains in event detail.
5. Keep audit/revision/QA language out of user-facing product UI.
6. Preserve KOMBAX Social, Showcase and public-profile behavior unless a cross-module fix is explicitly required.

## Regression compatibility
Some historical regression tests search exact source strings. R54 retains those strings only in source comments/data metadata when needed. Do not turn them back into visible labels.
