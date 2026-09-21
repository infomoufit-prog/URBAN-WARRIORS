# QA Validation · KOMBAX 20.101 R16

## Objective
Validate the event-management UI cleanup without changing permissions or backend behavior.

## Tests executed
1. `node scripts/test-kombax-20101-event-management-r16.mjs` → PASS
2. `npm run build` → PASS
3. Build copy parity → PASS · `152 archivos · web = dist = Android`
4. `npm run android:preflight` → 4/5 expected
5. Supabase directory diff against R15 → 0 differences
6. Release JKS SHA-256 verified → `7c70adc0d8e7b9426990d86a3f4743e2794e391f725dd708082e48264183a415`

## Verified
- One `Gestionar evento` launcher replaces the previous management action wall.
- Launcher is permission-gated by `event.can_manage`.
- All previous management destinations remain reachable.
- Desktop/PWA uses an anchored popover.
- Tablet uses a compact responsive panel.
- Mobile uses a bottom sheet with scrim and safe-area padding.
- Escape, outside click, scrim and explicit close are implemented.
- R14 Event Creator and R15 Responsive Visual Tuning remain present.
- No Supabase/schema changes were introduced.

## Android preflight
4/5 is intentional in the distributable ZIP because `android/keystore.properties` is not bundled with passwords/secrets. Restore it locally from the example/restore workflow before generating the Signed APK/AAB.
