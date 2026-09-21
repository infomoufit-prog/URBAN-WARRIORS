# KOMBAX RC13 build 20088 · Mobile Finance Responsive + Rotation

## Scope
Build 20088 is a UI/responsive-only evolution of build 20087. It does not change financial accounting rules, database schema, receipts, report generation logic, or pilot/recurrence gates.

## Implemented
- Finance Premium mobile layout no longer uses a horizontal KPI carousel.
- KPI cards reflow into responsive vertical grids (2 columns on standard phones, 1 on very narrow screens, 3 in landscape where space allows).
- Finance charts remove forced 620–720 px minimum widths on mobile.
- Mobile histogram renders a compact 6-month view while desktop retains the 12-month view.
- Dashboard, breakdowns, filters, tabs, explorer controls, pagination and action groups reflow to the viewport width.
- Generic financial tables continue using the existing mobile card transformation.
- Landscape rules reorganize Finance Premium into 2-column panels where the viewport permits.
- Android portrait lock removed (`screenOrientation="unspecified"`), so device auto-rotation is respected.
- WebView already handles `orientation|screenSize`, preserving the session during rotation.

## Validation
- `npm run test:20088`: PASS
- historical Finance 20086 regression: PASS
- Finance Explorer 20087 regression: PASS (build marker changed to >=20087)
- `npm run release:build`: PASS
- Legal Gate: PASS
- Full RC13 regression: PASS
- Build synchronization: 79 files · web = dist = Android
- Android preflight: 4/5; signing intentionally PENDING because no local JKS/keystore.properties is bundled.
- Sensitive file scan: 0 JKS/keystore, 0 .env, 0 PEM/P12/PFX/private keys.

## Production note
No Supabase migration or Edge Function deployment is required for this responsive-only build. The local health source declares 20088 for deployment coherence, but production health should only be updated when build 20088 is actually deployed.
