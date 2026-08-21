# STATUS · KOMBAX 20.067 · OWNER PASSWORD-ONLY · DEPLOY / ANDROID QA

Candidata actual: **RC13 build 20067**.

## Contenido consolidado

- Conserva la línea funcional y QA hasta build 20066, incluidas las correcciones de registro, invitaciones de equipo y solicitud de Club.
- Acceso Maestro Owner: correo autorizado + contraseña; **sin Email OTP** en este flujo.
- Puerta móvil oculta: 8 taps dentro de 5 segundos sobre el símbolo KOMBAX desde el directorio de clubes.
- El acceso Owner usa `app_kombax_platform_admin_challenge_start_v108` y completa con `app_kombax_platform_admin_password_complete_v110`.
- Los emails normales de registro y recuperación de contraseña se conservan.

## Verificación local de esta entrega

- `node scripts/test-kombax-20067-owner-password-only.mjs`: PASS.
- `npm test`: PASS completo hasta 20067.
- `npm run build`: PASS.
- `web = dist = android/app/src/main/assets/www`: 68/68/68 y contenido idéntico.
- Android: `applicationId com.urbanwarriors.app`, `versionCode 20067`, `versionName 2.0.0-rc.13`.
- Preflight Android: 4/5; únicamente firma local pendiente porque JKS y `keystore.properties` no se distribuyen.

## Supabase LIVE verificado el 2026-08-21

- v107 mensajería Social/Showcase: activa.
- v109 invitaciones/equipo: activa.
- v108 challenge de administración: activa.
- v110 finalización Owner por contraseña: activa.
- `anon` no puede ejecutar v110; `authenticated` sí, con las comprobaciones internas Owner/AMR/challenge/sesión.

La migración 110 se incluye en esta ZIP como **fuente reproducible**. No debe reaplicarse al proyecto LIVE solo por desplegar esta build: el backend LIVE ya está preparado.

## Deploy / Android

Esta build es candidata para desplegar el frontend en Netlify y para generar APK/AAB signed localmente con el **JKS histórico existente**. No crear una clave nueva.

Después del deploy/instalación, realizar QA E2E real: login normal, solicitud Club, aprobación Owner, acceso al Club, Social, Showcase, mensajería, aislamiento multiclub y acceso maestro sin OTP.
