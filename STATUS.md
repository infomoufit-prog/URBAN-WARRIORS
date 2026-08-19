# STATUS · KOMBAX 20.050 ACCOUNT SECURITY

Candidata actual de validación: **build 20050**.

Último cambio: cambio de contraseña autenticado desde perfil/cuenta, con verificación explícita de contraseña actual y cierre de sesión posterior. No requiere migración Supabase.

# Estado del proyecto · KOMBAX RC13 build 20049 FINAL CANDIDATE

## Candidata actual

- Versión: **2.0.0-rc.13**.
- Build web / Android `versionCode`: **20049**.
- applicationId: `com.urbanwarriors.app`.
- Perfil Miembro: identidad KOMBAX Social canónica única, arquitectura 20048 preservada.
- Recuperación de contraseña: código de 6 dígitos + verificación + nueva contraseña + cierre de sesión temporal, implementado en ambos logins.
- Recibos: branding y prefijo propios por Club, con snapshot histórico del emisor.
- Supabase 094/095/096: aplicadas y verificadas en vivo.
- Seguridad 20.046: revalidada después de 096.
- `npm test`: PASS.
- `npm run build`: PASS.
- `web = dist = Android`: 63/63/63, 0 diferencias.
- Android preflight: 4/5; firma local pendiente deliberadamente fuera del paquete.

## Estado de release

**FINAL CANDIDATE / PRE-FREEZE.** Los dos últimos cambios funcionales están implementados. Para declarar `KOMBAX BASE FREEZE` falta la validación manual final y completar el E2E alojado de recuperación de contraseña.

No se ha modificado GitHub, no se ha desplegado Netlify y no se ha generado/publicado APK/AAB de producción.

### Pendientes pre-producción conocidos

1. En Supabase: `Authentication → Email Templates → Reset password`, instalar `supabase/auth_templates/recovery_otp_20049.html` para que el correo muestre `{{ .Token }}`.
2. Ejecutar E2E real de recuperación: solicitar código, recibir correo, verificar, cambiar contraseña y entrar de nuevo.
3. Activar **Leaked Password Protection** en Supabase Auth y repetir smoke Auth.
4. Validación manual final PC + móvil, incluyendo un recibo visual.
5. Mantener la deuda del Performance Advisor como fase separada; no mezclar refactor masivo de índices/RLS con el freeze.
6. Tras freeze: GitHub → Netlify/PWA → APK Release → AAB → Google Play.

## Evidencia 20049

- Migración viva: `20260819005526 kombax_multiclub_receipt_branding_20049`.
- Recibos reales existentes: 4; todos con snapshot de emisor y números históricos intactos.
- Smoke financiero transaccional: PASS; 0 fixtures.
- Usuarios `auth.users` después de QA: 3; no se crearon cuentas de prueba.
- Test conductual Auth REST: PASS.
- SHA agregado web/dist/Android: `dde0d09ac4448cd80b95924222c80e620a0dfc8403ec205c46d5b2c48420e415`.

Ver detalle en `BUILD_20049_FINAL_AUTH_RECEIPTS_VALIDATION.md` y `CHANGELOG_RC13_BUILD_20049.md`.
