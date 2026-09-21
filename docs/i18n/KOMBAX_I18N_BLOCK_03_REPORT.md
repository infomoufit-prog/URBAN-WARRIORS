# KOMBAX i18n · Informe Bloque 3 — F11–F15

## A. Fases realizadas
- F11 Social — **PARTIAL/PASS técnico**: integración crítica realizada y validada; quedan candidatos conservadores de literales para cierre visual F16.
- F12 Showcase/Commerce — **PARTIAL/PASS técnico**: integración crítica realizada y validada; quedan candidatos conservadores para F16/F17.
- F13 Events/Ticketing — **PARTIAL/PASS técnico**: UI crítica migrada; QR/ticket identity protegida; cierre visual pendiente F16.
- F14 Assist/Migrations — **PASS**: `user_locale` propagado, sin agentes duplicados.
- F15 Email/Push/Documents/Legal — **PASS con limitación documentada**: integración locale/legal realizada; Thai dynamic finance PDF uses explicit EN fallback under current font constraint.

## B. Implementaciones
- Master catalog expanded to 475 keys across 8 locales.
- Product UI localization expanded for Social, Showcase/Commerce and Events/Ticketing.
- Assist/Migrations locale propagated to backend/agent instructions.
- Locale-aware invitation email, notification/push and generated finance report presentation.
- Legal metadata split into locale/jurisdiction/legal_version.

## C. Archivos principales modificados
See `KOMBAX_I18N_CODE_DELTA_B03.json`: 24 added files, 260 modified including build mirrors; 92 modified source files excluding build mirrors; 0 deleted.

## D. Dependencias
No new runtime dependency added for i18n.

## E. Migraciones
- Existing B01: `20260914230000_kombax_i18n_locale_preference_b01.sql` — prepared, not deployed.
- New B03: `20260914233000_kombax_i18n_legal_metadata_b03.sql` — additive, prepared, not deployed.

## F. Tests ejecutados
- i18n validation: PASS.
- B03 test: 25/25 PASS.
- cumulative `npm test`: PASS.
- Legal Gate: PASS.
- Android preflight: PARTIAL 4/5 only local signing file absent.

## G. Build
PASS — 397 files, web = dist = Android.

## H. Cobertura lingüística
475/475 catalog keys in ES/EN/FR/PT/IT/DE/TH/FIL; 223 active references; zero active missing keys. ES/EN enabled; other locales remain hidden pending final QA gates.

## I. Regresiones
No cumulative regression suite failure remains. Two invalid translation references found during implementation were corrected before final QA.

## J. Pendientes reales
Visual/E2E verification of conservative residual-source candidates; Android local signing; Thai dynamic-finance-PDF font limitation; deploy migrations only under explicit authorization.

## K. Riesgos siguiente bloque
Long strings/Thai visual rendering, deep historical literals, authenticated E2E coverage and release-environment dependencies.

## L. ZIP completo
Target: `KOMBAX_20124_R73_SHOWCASE_REPUTATION_EVENTS_COMMUNITY_COMPLETION_PILOT_FREEZE_I18N_B03_F11-15.zip`
Source B02 SHA-256: `73fd0b5fb8663b8034ef56865af085b408f35ee3ed6c7b87048c6f2484f59cb8`
