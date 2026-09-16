# KOMBAX 20.101 R12 · Gateway Reframe Final

## Summary
R12 keeps the approved gateway multi-fighter image and refines only its placement and scaling so the composition reads more naturally. Gateway atmospheric overlays are reduced because the artwork already includes its own smoke/atmosphere.

## Implemented
- Widened the gateway visual rail.
- Reframed the gateway hero artwork using `cover` instead of `contain` on desktop.
- Rescaled and repositioned the image to improve group balance and reduce the boxed/cropped feeling.
- Softened the gateway pulse overlay.
- Reduced added gateway smoke opacities and footprint so the image's own atmosphere remains primary.
- Tuned tablet/mobile gateway crop to align with the new desktop framing.
- Bumped cache bust to `20101r12` and `media-r12`.
- Added dedicated regression test for the gateway reframe.

## Preserved
- Social approved hero image.
- Real alpha smoke route introduced in R11.
- Events and Showcase heroes.
- Urban Warriors Jiu-Jitsu event assets and installer logic.
- No backend/schema changes.
