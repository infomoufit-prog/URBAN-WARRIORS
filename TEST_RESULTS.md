# TEST RESULTS — KOMBAX 20.101 R25

- R25 dedicated: 24/24 PASS
- R22 regression: 30/30 PASS
- R23 regression: 15/15 PASS
- Full npm test: PASS, EXIT_CODE 0
- Build: PASS, 171 files
- Parity: web 171 / dist 171 / Android 171; missing 0 / extra 0 / different 0
- Android preflight: 4/5; signing properties pending locally
- Supabase backend: R23-compatible v189/v191 present; v192/v193 absent
- Seed isolation: R19 3 products only Urban; R20 1 seminar + 2 posts only Urban
- Security Advisor: run; inherited/global findings remain
- Performance Advisor: run; inherited/global unindexed FK/unused index findings and duplicate Finance index remain

Physical Android continuous-scroll / zero-flash acceptance is pending.

## KOMBAX 20.101 R26 · Privacy, Authorized Support & Events Navigation
- Dedicated: 24/24 PASS
- Full regression: PASS
- Build: 172 web = dist = Android
- Android preflight: 4/5 (firma local pendiente)
- Backend migrations: 194 + 195 aplicadas físicamente
- Security + Performance Advisors ejecutados; warnings existentes documentados
