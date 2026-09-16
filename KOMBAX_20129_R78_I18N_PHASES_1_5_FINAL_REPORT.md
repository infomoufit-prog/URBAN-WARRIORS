# KOMBAX R78 · build 20129 · i18n phases 1–5

Base: R77/build 20128. Cumulative release; no functionality removed.

## Scope closed
1. Global shell, authentication and onboarding.
2. KOMBAX Social and Discovery.
3. Showcase.
4. KOMBAX Events.
5. Daily club-management surfaces included in the audited inventory.

## Localization architecture
- 1,086 unique Spanish system-copy source strings are bundled in `web/js/i18n/r78-system-source.js`.
- Precomputed EN/FR/PT/IT/DE/TH/FIL catalogs exist in the existing universal translation cache in Supabase, 1,086/1,086 per locale.
- Runtime prioritizes exact R78 translations, then R78 dynamic `{VAR}` patterns, then the historical i18n catalogs.
- User-generated content remains excluded from system-copy DOM translation.
- Catalogs are cached locally for PWA/Android reuse; no AI call is made while rendering a screen.

## QA
- R78 dedicated gate: 20/20 PASS.
- Full cumulative `npm test`: PASS.
- `node scripts/build.mjs`: PASS, 453 files; web = dist = Android.

## Continuity
R75 Showcase public/private multiclub isolation and all R77 analytics/reports behavior remain covered by historical regression gates.
