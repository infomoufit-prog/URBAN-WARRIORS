# R26 · Certificación de empaquetado

Base: R25 Pilot Stabilization.

Incluye código fuente, `web`, `dist`, Android, assets, migraciones, scripts de pruebas, documentación y el JKS de release ya preservado por el proyecto cuando está presente.

No debe incluir:
- `.git`
- `node_modules`
- `android/keystore.properties`
- contraseñas o secretos de firma

Estado funcional antes del ZIP:
- R26 dedicado 24/24 PASS.
- Regresión global final PASS.
- Build 172 archivos.
- Paridad web/dist/Android: 0 diferencias.
- Android preflight 4/5; firma local pendiente.
- Security y Performance Advisors ejecutados.
