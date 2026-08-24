# KOMBAX RC13 · build 20070

## Pilot readiness sin Supabase Pro

- Separa moderación global de verificación documental privada.
- Corrige la asignación de roles para usar el ID canónico de cuenta y no el ID público Social.
- Añade panel Owner de preparación con siete controles auditables; comienza en `NO-GO`.
- Añade telemetría autenticada, sanitizada y limitada por frecuencia.
- Añade CSP, HSTS y aislamiento de apertura en Netlify.
- Endurece las dos Edge Functions: POST/JSON, tamaño máximo, comparación segura de secreto, versiones fijadas, `request_id` y errores externos genéricos.
- Corrige la detección moderna de `service_role` del generador recurrente. El worker pasó de 500 periódico a 200 real.
- Incluye runbooks de SMTP/MFA, legal, backup/restore e incidentes para operar en Supabase Free.
- Mantiene íntegros registro, confirmación de correo, recuperación y cambio de contraseña.

No incluye deploy web, APK/AAB, firma Android, compra de plan ni datos jurídicos/credenciales inventados.
