# KOMBAX R76 · Social Discovery Premium Visual Audit

Build: 20127
Baseline: R75 / build 20126
Scope: Front visual only — KOMBAX Social → Descubrir → competitor/professional search.

## Root cause
1. `web/css/kombax-social.css` contained the Discovery-specific visual layer, but `web/index.html` did not load that stylesheet.
2. `openKombaxDiscovery()` therefore rendered primarily through the generic `.modal` surface (`#101318`), producing the reported grey, flat, superimposed appearance.
3. The R62.6 Discovery CSS itself used mostly flat neutral surfaces and small circular avatars, so even when loaded it did not reach the current KOMBAX premium visual standard.

## R76 correction
- `web/index.html` now loads `./css/kombax-social.css?v=20127`.
- `openKombaxDiscovery()` marks its modal layer with `kx-discovery-layer`, creating an isolated Social workspace instead of inheriting the generic modal presentation.
- New dark premium Social workspace: deep black surfaces, red/orange Social glow, restrained cyan secondary signal, grid texture and dedicated header separation.
- Filters are grouped inside an elevated panel with strong input focus states and a Social gradient search action.
- Fighter/profile cards have increased breathing room, 70px portrait framing, top-biased image focus, stronger type hierarchy, state chips, tags, location, declared record and separated actions.
- Desktop: 2-column result grid. Tablet/mobile: 1-column grid.
- Mobile no longer behaves visually like a bottom sheet glued to the bottom edge; Discovery is centered within safe-area constraints.
- Search logic, RPCs, permissions, privacy, PII rules, contact flow and Events reuse are unchanged.

## Validation
- R76 visual/static gate: 10/10 PASS.
- Historical R62.6 Social Discovery functional test: PASS.
- Full `npm test`: PASS.
- i18n runtime audit: 4687/4687, 0 unresolved.
- CSS parsed with `tinycss2`: 83 top-level rules, 0 parse errors.
- `node --check web/js/modules/kombax-discovery.js`: PASS.
- Build parity: 450 files, Web = dist = Android.
- Android preflight: 4/5; only local release signing file is intentionally absent.

## Visual-capture limitation
Chromium headless in the execution container did not complete screenshot capture because the process stalled in the container DBus/sandbox environment. No screenshot PASS is claimed. Structural CSS, responsive rules, runtime code, full regression and deterministic Web/Android build were verified.
