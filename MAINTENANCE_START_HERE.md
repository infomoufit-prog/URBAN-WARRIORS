# KOMBAX · Maintenance Start Here

Current engineering baseline for QA stabilization: **KOMBAX 20.106 R56 · PROFILE PUBLIC UX QA FREEZE CANDIDATE**.

Begin with `maintenance/R56/INDEX.md` for the current-cycle scope, audit, QA handoff and freeze-readiness status. Raw evidence is in `QA_EVIDENCE_R56/`.

R54/R55 and older documentation remains historical engineering evidence. `scripts/build.mjs` deploys only `web/`, so maintenance/audit documents are not exposed in the PWA or Android runtime.

## R57 · 20.107 · Social information UX
Para el último cambio frontend de KOMBAX Social, empezar por `AUDIT_SOCIAL_INFO_UX_20107_R57.md`, `PLAN_IMPLEMENTACION_R57.md` y `QA_HANDOFF_20107_R57.md`. Código focal: `web/js/modules/kombax-social.js` y estilos R57 al final de `web/css/kombax-premium.css`. No tocar Events/Showcase/perfil público para esta incidencia salvo regresión demostrada.
