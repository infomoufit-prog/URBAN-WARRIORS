# RC13 build 20049 · Auth recovery + multi-club receipts

## Recuperación de contraseña
- Añadido `¿Has olvidado tu contraseña?` al login Club y `He olvidado mi contraseña` al login KOMBAX.
- Flujo de código OTP de 6 dígitos mediante Supabase Auth recovery.
- Verificación `type=recovery`, actualización de contraseña con sesión temporal y logout obligatorio después del cambio.
- Respuesta anti-enumeración de cuentas.
- Plantilla KOMBAX incluida en `supabase/auth_templates/recovery_otp_20049.html`.
- La plantilla alojada de Supabase queda como ajuste manual previo al E2E real.

## Recibos multi-club
- Eliminado fallback de logo Urban Warriors de los recibos y del shell genérico.
- Migración 096 aplicada y verificada en Supabase real.
- Cada Club dispone de `recibo_prefijo` propio.
- Cada recibo conserva snapshot de nombre/logo/CIF/contacto/dirección/web del emisor.
- Los recibos históricos conservan sus números; no se altera trazabilidad financiera.
- Los nuevos recibos normalizan `PREFIJO-AAAA-######` mediante trigger `BEFORE INSERT`.
- Urban Warriors mantiene `UW` únicamente como prefijo propio, no como valor global.

## QA
- Regresión completa: PASS.
- Test conductual Auth REST: PASS.
- Smoke financiero real con ROLLBACK: PASS; 0 fixtures persistidos.
- `npm run build`: PASS.
- web/dist/Android: 63/63/63, 0 diferencias.
- Android preflight 4/5; firma local deliberadamente no incluida.

## Release
- Build/versionCode 20049.
- Sin GitHub, Netlify, firma APK/AAB ni Google Play.
- Candidata final; falta plantilla Auth alojada + E2E real + Leaked Password Protection antes de certificación de producción.
