# KOMBAX i18n · Release readiness B04

## Estado de rollout

- **ES**: supported + enabled. Catálogo 475/475, validadores automáticos PASS.
- **EN**: supported + enabled. Catálogo 475/475, validadores automáticos PASS.
- **FR/PT/IT/DE/TH/FIL**: supported, instalados y con catálogo 475/475, **disabled** hasta completar QA visual autenticado y E2E en dispositivo real.

## Gates automáticos ejecutables en este entorno

- Catálogos/keys/placeholders: PASS.
- Regresión funcional acumulativa (`npm test`): ejecutar al freeze final.
- Build web/dist/Android mirror: ejecutar al freeze final.
- Legal gate: ejecutar al freeze final.
- Android release preflight: firma local esperada fuera del ZIP.
- QR/ticket IDs: invariantes respecto al locale.
- Stripe IDs/webhooks: no localizados.
- RLS/auth/roles: no se introducen migraciones destructivas en i18n.

## Gate visual

Existe `web/qa/i18n-visual-b04.html` como harness reproducible para los 8 locales. El contenedor actual no puede completar Chromium headless por limitaciones DBus/gráficas, por lo que el QA visual runtime autenticado queda como **manual device gate**, no se falsea como ejecutado.

## Recomendación de piloto

Piloto seguro: **ES + EN habilitados**. Mantener el resto oculto hasta completar el checklist `KOMBAX_I18N_MANUAL_DEVICE_QA.md` sin defectos críticos.
