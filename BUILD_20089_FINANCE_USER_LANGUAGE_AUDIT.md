# KOMBAX RC13 build 20089 · Auditoría de lenguaje visible en Finanzas Premium

## Objetivo
Eliminar de la experiencia de club cualquier tecnicismo de desarrollo, versionado interno o diagnóstico de infraestructura que pudiera aparecer en Finanzas Premium.

## Hallazgos retirados de la UI
- `QA 20083 · FINAL PILOT GATE`
- referencias visibles a `20.083`
- `finance_pilot_live_enabled`
- `Recurring`, `Pilot live`, `LIVE/READY/CLOSED`
- `Shadow QA`, `Shadow`, `fingerprint/huella`
- `flag del club`, `gate`, referencias al backend o a desajustes de versión
- `Preview` sustituido por `Revisión`

## Sustitución UX
- `Comprobación de automatizaciones`
- `Automatización de cargos protegida / preparada / activa`
- `Incidencias que impiden activar`
- `Dos simulaciones coincidentes`
- `Ejecutar comprobación`
- `Aprobar comprobaciones / Revocar aprobación`
- Mensaje de actualización del servicio sin exponer backend, versión, RPC o nombres internos.

## Diagnóstico interno
Los nombres técnicos de RPC, operaciones y códigos siguen existiendo en la capa interna, consola, tests y backend para soporte y trazabilidad, pero no forman parte del texto visible al usuario final.

## Validación
- Test específico 20089: PASS
- Finanzas 20080–20088: PASS
- Regresión RC13 completa: PASS
- Legal Gate: PASS
- release:build: PASS
- web = dist = Android: 79/79/79
- Android preflight: 4/5, pendiente únicamente firma local
- Sin JKS/keystore/.env/PEM/P12/PFX incluidos
