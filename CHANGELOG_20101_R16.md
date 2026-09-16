# KOMBAX 20.101 R16 · Event Management UX Cleanup

## Summary
R16 cleans the event detail experience by removing the large organizer action wall from the modal footer and replacing it with one contextual management control anchored to the event hero.

## Implemented
- Added one `Gestionar evento` launcher, visible only for `event.can_manage`.
- Desktop/PWA: compact management popover in the upper-right of the event hero.
- Tablet: compact two-column management panel.
- Mobile: bottom-sheet management panel with scrim and safe-area padding.
- Grouped tools into Evento, Competición, Contenido and Utilidades.
- Preserved all previous destinations: Event Creator, Edit, Cover, Participants, Fight Card, Album, Organization and Visual Studio.
- Public actions remain separate and concise.
- Added Escape/scrim/close behavior and `aria-expanded`.
- Cache bust raised to `20101r16` / `media-r16`.

## Preserved
- R14 Event Creator and participant/media backend contract.
- R15 responsive visual tuning.
- Fight Cards, album, Urban Warriors event and multiclub permissions.
- No Supabase changes.
