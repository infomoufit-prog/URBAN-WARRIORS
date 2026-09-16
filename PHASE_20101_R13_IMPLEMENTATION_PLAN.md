KOMBAX 20.101 R13 · MOBILE UX + EVENTS FIGHT CARD VISIBILITY HARDENING

BASE
- KOMBAX 20.101 R12 Gateway Reframe Final.

MISSION
- Make Fight Cards reliably visible in both current public events.
- Improve mobile-only composition of gateway + Social + Events + Showcase without degrading desktop/PWA.
- Re-audit alpha-smoke integration and remove/soften any remaining intrusive treatment.
- Preserve multiclub ownership, Urban Warriors event data and all working flows.

SCOPE
1. Audit and fix fight-card hydration/render path in event detail.
2. Ensure a card renders even when participant photography is absent.
3. Keep Main Event and full Fight Card visible at the same time.
4. Mobile gateway: blend photo and copy instead of a detached top image card.
5. Mobile Social/Events/Showcase: reduce zoom and retune object-position only on small breakpoints.
6. Preserve desktop hero composition.
7. Keep R11 alpha-smoke system; reduce only where it competes with photography.
8. Add R13 regression test and run full build.

NON-GOALS
- No Event Creator 10/10 builder in this phase.
- No brackets/tree generation.
- No schema rewrite.
- No new backend ownership model.

RISKS
- Fight cards may be hidden by a frontend condition despite valid backend data.
- A mobile crop change could leak into desktop through selector specificity.
- New layout may introduce overflow or safe-area regressions.

MITIGATIONS
- Use explicit mobile-only selectors.
- Keep existing backend contracts untouched.
- Add tests for fight-card visibility, no-photo cards, Main Event coexistence and mobile crops.
- Run full regression + deterministic web=dist=Android build.

CLOSURE CRITERIA
- Both current events render fight-card sections from existing fight data.
- Cards remain visible without photos.
- Main Event does not suppress remaining fight cards.
- Mobile gateway photo/copy are visually integrated.
- Social/Events/Showcase mobile crops are less zoomed.
- Desktop remains unchanged by mobile overrides.
- Smoke system remains alpha-sprite based and reduced-motion safe.
- npm run build PASS.
- web = dist = Android.
- Complete ZIP WITH_SIGNING produced.
