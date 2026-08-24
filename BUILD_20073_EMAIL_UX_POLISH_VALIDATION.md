# KOMBAX RC13 · build 20073 · Email UX Polish Validation

## Objetivo
Refinar la experiencia de los emails transaccionales KOMBAX sin modificar los contratos de Auth, MFA ni recuperación.

## Cambios
- Nuevas plantillas premium 20073 para confirmación, recovery OTP, OTP de acceso protegido, invitación, reautenticación y cambio de contraseña.
- Copy más claro, menos técnico y coherente con la voz KOMBAX.
- Preheaders específicos para bandeja de entrada.
- Layout robusto basado en tablas e inline styles; sin imágenes o recursos remotos.
- Mensajes de seguridad explícitos sin alarmismo.
- Asuntos recomendados revisados.
- Build/runtime incrementado a 20073 para trazabilidad de candidata.

## Contratos preservados
- Confirm signup: `{{ .ConfirmationURL }}`.
- Invite user: `{{ .ConfirmationURL }}`.
- Recovery: `{{ .Token }}` y sin `{{ .ConfirmationURL }}`.
- Magic Link usado por OTP Owner: `{{ .Token }}` y sin link-only.
- Reauthentication: `{{ .Token }}`.

## Validación
- `npm test`: PASS.
- `build.mjs`: PASS · 73 archivos · web = dist = Android.
- Auth templates 20073 test: PASS.
- Build identity 20073: PASS.
- Android preflight: 4/5; único pendiente keystore local.
- No se han activado estas plantillas en Supabase alojado todavía.
- No se ha tocado GitHub ni Netlify.

## Estado
Candidata local aprobada para pasar a E2E de correo. Activación alojada y recepción real siguen pendientes.
