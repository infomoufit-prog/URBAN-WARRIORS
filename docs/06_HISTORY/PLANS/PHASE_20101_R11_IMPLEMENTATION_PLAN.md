KOMBAX 20.101 R11 · REAL ALPHA SMOKE
BASE: 20.101 R10 Social Hero + Smoke Hardening

OBJECTIVE
Replace the R10 colored texture/filter treatment that appeared as bands/halos with true smoke-shaped transparent alpha sprites, keeping the solution lightweight and compatible with browser, PWA and Android WebView/APK.

SCOPE
- Keep approved Social / Events / Showcase / gateway photography unchanged.
- Create several local transparent smoke sprites with irregular cloud contours.
- Animate them as independent layers using transform + opacity only.
- No hue-rotate, no CSS-generated radial smoke blobs, no video, GIF or WebGL.
- Events = strongest smoke presence; Social = medium; Showcase = restrained; Gateway = dual red/cool neutral atmospheric smoke.
- Preserve reduced-motion.
- Preserve R8 Urban Warriors Jiu-Jitsu installer and all multiclub/event logic.

RISKS
- Overdraw/GPU cost on mobile.
- Smoke could obscure text/faces.
- PWA static cache could show R10 assets.

MITIGATIONS
- Sprites are small optimized transparent WEBP assets.
- Maximum 4 smoke layers per hero; transforms only, long durations.
- Position smoke away from primary copy/faces.
- Use opacity caps per product area.
- Cache bust to 20101r11 and media-r11.
- Full regression plus deterministic web=dist=Android build.

QA
- Verify alpha sprites actually contain transparency and non-uniform forms.
- Verify no hue-rotate/filter-based R10 smoke path remains active.
- Verify animations use transform/opacity only.
- Verify reduced-motion disables animation.
- Run full npm build.
- Verify web/dist/Android hashes of new assets and CSS.

CLOSURE
R11 is complete only when the old band/halo implementation is removed, true alpha smoke is wired to gateway + Brand Heroes, and full regression/build passes.
