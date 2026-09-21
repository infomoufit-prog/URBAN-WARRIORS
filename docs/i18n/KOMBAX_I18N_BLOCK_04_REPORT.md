# KOMBAX i18n · Block 04 report · F16–F20

## F16 — QA visual internacional

**PARTIAL (runtime external gate).** CSS/i18n responsive, Thai/FR/DE resilience, safe areas y harness visual incluidos. El contenedor no completa Chromium headless por limitación DBus/gráfica; QA visual autenticado real queda documentado como manual device gate.

## F17 — QA funcional end-to-end

**PASS automatizado / PARTIAL externo.** Se usa la regresión acumulativa completa de KOMBAX y test B04. Flujos dependientes de credenciales reales, Stripe real, email/push y Android firmado quedan como gate externo.

## F18 — Regresión, seguridad e integridad

**PASS automatizado.** Migraciones i18n son aditivas; QR/tickets, rutas técnicas, Stripe IDs, contenido de usuario y agentes no se duplican/localizan indebidamente. Legal mantiene locale/jurisdiction/version separados.

## F19 — Piloto y rollout

**PASS.** ES/EN habilitados; FR/PT/IT/DE/TH/FIL supported pero disabled hasta QA manual autenticado.

## F20 — Freeze final internacional

**PASS como freeze candidate**, con gates externos explícitos. Se generan readiness, rollback, inventario de migraciones, QA final, changelog/handoff y ZIP completo verificado. No se despliega automáticamente.
