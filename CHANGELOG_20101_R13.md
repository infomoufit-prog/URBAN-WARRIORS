# KOMBAX 20.101 R13 · Mobile UX + Events Fight Cards

## Scope
R13 closes the visibility/presentation gap detected in the two current KOMBAX Events and improves mobile-only hero composition without changing the desktop/PWA layouts that were already working well.

## Events / Fight Cards
- Fight Card section is now placed immediately after the event navigation so it is visible before the long information blocks.
- Fight rows are sorted by `orden` and the section displays the real number of fights.
- Fight Card rendering no longer depends on the decorative `fight-card-square.svg` background to be visible.
- Cards have their own CSS surface and forced visible grid state.
- Missing fighter photography no longer compromises the card: local fighter placeholder is used.
- Broken fighter image URLs are automatically replaced by the local placeholder.
- Main Event remains a dedicated feature while the complete Fight Card remains visible independently.
- Mobile Fight Cards are one-column, shorter and easier to scan/tap.

## Mobile hero UX
- Gateway mobile artwork now visually blends into the intro copy instead of appearing as a detached card above the text.
- Mobile gateway smoke is further restrained because the approved artwork already contains atmosphere.
- Social mobile hero removes additional scale and shows more of the approved fighter image.
- Events mobile hero removes additional scale and provides more breathing room around fighters.
- Showcase mobile hero removes additional scale and shows more context around the subject.
- Desktop hero rules remain unchanged.

## Smoke
- R11 real-alpha smoke sprites are preserved.
- Old R10 texture/hue-rotate route remains removed.
- Mobile smoke intensity is reduced and constrained mostly to the image area.
- `prefers-reduced-motion` support remains intact.

## Backend / multiclub
- No Supabase migrations or backend code changed in R13.
- Supabase tree is byte-for-byte structurally identical to R12.
- Existing club/event ownership model is unchanged.

## Build
- Full regression suite PASS.
- R11 smoke regression PASS.
- R12 gateway regression PASS.
- R13 dedicated regression PASS.
- Static build PASS: 152 files · web = dist = Android.
