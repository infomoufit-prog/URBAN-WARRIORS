# KOMBAX 20077 · Cambios del candidato PILOT READINESS

Comparación contra el ZIP fuente de verdad recibido.

- Modificados: **19**
- Añadidos: **5**
- Eliminados: **0**

## Modificados

- `CHILD_SAFETY_RESPONSE_RUNBOOK_20071.md`
- `INCIDENT_RESPONSE_RUNBOOK_20070.md`
- `KOMBAX_CHILD_SAFETY_STANDARD_DRAFT_20071.md`
- `KOMBAX_PRIVACY_POLICY_DRAFT_20071.md`
- `MONITORING_RUNBOOK_20072.md`
- `PILOT_LEGAL_CONTROLLER_TEMPLATE_20070.md`
- `PRIVACY_PROCESSING_REGISTER_DRAFT_20071.md`
- `android/app/src/main/assets/www/child-safety.html`
- `android/app/src/main/assets/www/privacy.html`
- `android/app/src/main/assets/www/terms.html`
- `dist/child-safety.html`
- `dist/privacy.html`
- `dist/terms.html`
- `scripts/release-legal-gate.mjs`
- `scripts/test-kombax-20071-security-privacy-hardening.mjs`
- `scripts/test-kombax-20072-legal-child-safety-ops.mjs`
- `web/child-safety.html`
- `web/privacy.html`
- `web/terms.html`

## Añadidos

- `KOMBAX_CLUB_DPA_PILOT_20077.md`
- `LEGAL_RELEASE_GATE_20077.md`
- `PILOT_VALIDATION_EVIDENCE_20077.md`
- `PRODUCTION_READINESS_20077_PILOT.md`
- `SUPABASE_SECURITY_DEFINER_AUDIT_20077.md`

## Eliminados

- Ninguno.

## Nota

Los cambios dentro de `dist/` y `android/app/src/main/assets/www/` son copias generadas por el build para mantener paridad exacta con `web/`.
No se han añadido keystores, `keystore.properties`, claves privadas ni secretos de servicio.

## 24/08/2026 · Backup/Auth closure continuation

- Añadida migración `142_kombax_backup_run_tracking_20077.sql`.
- Añadidas/sincronizadas Edge Functions `backup-export-20077` y `backup-verify-20077`.
- Capability de backup movida de query string a cabecera `x-kombax-backup-token`.
- Añadido test `test-kombax-20077-backup-export-gateway.mjs` y enganchado a `npm test`.
- Certificado snapshot real verificado: 3 artefactos DB + 47 objetos Storage, 0 fallos.
- E2E Auth actualizado: registro/recuperación recibidos en español; Site URL alojada aún apunta al Netlify anterior.
- Health Watch horario activado.
