# KOMBAX RC13 build 20071 · SECURITY, PRIVACY & CHILD SAFETY HARDENING

Base: build 20070 PILOT_READINESS. Esta build no se ha subido a GitHub ni desplegado en Netlify.

## Implementado

- Owner: contraseña + challenge + OTP + sesión privilegiada; frontend ya no llama a password-only.
- Readiness: migración 127 informa build 20071 y mide MFA/password-only por privilegios efectivos.
- Android: CAMERA eliminado, WebView restringida, externos al navegador, App Links `kombax.es`/`www`, deep links preservados y notificaciones PRIVATE.
- Mi club: push operativo obligatorio; no existen selectores de Finanzas/Sesiones/Comunidad/General para desactivarlos en KOMBAX.
- Push financiero: lockscreen sin nombre ni importe; detalle únicamente dentro de la app autenticada.
- Eliminación de cuenta: cola Owner/Privacidad, separación del Moderador, plan de Storage, Auth soft-delete, anonimización y cierre auditado.
- Menores: autorización de tutor <18 para Social, recordatorio de seguridad obligatorio y revocación efectiva; chat privado sigue bloqueado <18.
- Moderación: denuncia de mensaje concreto con evidencia mínima; sin acceso global a conversaciones privadas.
- Normas KOMBAX Social 1.4.0 con estándares EASI/CSAE/CSAM y separación de funciones.
- Dominio canónico de la fuente 20071: `https://kombax.es`; eliminadas referencias runtime al host Netlify antiguo.
- Recursos públicos preparados: `/privacy`, `/child-safety`, `/delete-account`.
- Gate de release: Netlify usa `npm run release:build`, que se bloquea mientras falten datos jurídicos/contacto de seguridad.
- Backup/restore: herramientas DB/Storage con inventario, SHA-256 y restauración solo en destino aislado.
- Trigger functions de menores retiradas de la superficie RPC `anon/authenticated`.
- Validador histórico de códigos retirado de `anon`.

## Supabase LIVE

Migraciones 119–127 aplicadas. Edge Functions activas:
- `notification-dispatch` v10 — posteriores ejecuciones cron HTTP 200.
- `payment-reminders` v7 — posterior ejecución cron HTTP 200.
- `account-deletion-executor` v2 — JWT obligatorio.

## QA

- `npm run build`: PASS.
- Regresión histórica RC13: PASS.
- Gate 20071: PASS.
- Paridad: **71 archivos · web = dist = Android**.
- Old-domain runtime scan: PASS.
- Secret scan: PASS.
- Release legal gate: PASS como protección (bloquea intencionadamente hasta completar datos legales).
- Android preflight: 4/5; firma local pendiente.

## Pendientes externos/humanos

- Completar responsable legal, NIF/CIF, domicilio, contacto de privacidad, bases jurídicas/proveedores y DPO si corresponde.
- Designar contacto de seguridad infantil y correo público.
- Recibir y validar un email real KOMBAX desde el remitente de producción (registro/recovery/OTP Owner).
- Verificar Site URL/redirect allowlist de Supabase Auth en el E2E posterior al deploy.
- Ejecutar backup real DB + Storage y restore drill aislado.
- Activar leaked-password protection si el plan/capacidad de Supabase lo permite.
- Hacer GitHub Private antes del próximo push.
- Android Studio: firma final APK/AAB y QA móvil real.
- No desplegar Netlify hasta autorización expresa.
