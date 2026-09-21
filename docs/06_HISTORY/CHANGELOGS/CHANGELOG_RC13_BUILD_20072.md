# KOMBAX RC13 · build 20072 · Closure hardening

Build 20072 parte de la 20071 certificada y añade cierre legal, Child Safety, recuperación operativa y QA de aislamiento. La 20071 no se sobrescribe.

## Cambios principales

- Política de Privacidad global estructurada y bases/proveedores documentados.
- Estándares públicos Child Safety y runbook de respuesta/escalado.
- Condiciones globales de KOMBAX v1.0.0.
- Migración 128: Verificador de documentos pasa a mínimo privilegio; lectura sí, borrado no.
- Migración 129: aceptación global de Términos + reconocimiento de Política de Privacidad, separada del consentimiento Social.
- Gate de Términos para cuentas nuevas y existentes, tanto globales como vinculadas a club.
- Contraseña mínima de alta global/equipo alineada a 8 caracteres en UI.
- Plantillas Auth KOMBAX para confirmación, recuperación OTP, OTP de acceso, invitación, reautenticación y aviso de cambio de contraseña.
- Backup full DB + todos los buckets y restore DB protegido contra producción.
- Runbook de candidatos a multimedia huérfana; sin borrado automático.
- Edge Function `health` v2 con verificación real de DB mediante RPC público de solo lectura.
- QA real RLS: Dirección, Monitor, Alumno, Tutor, Moderador, Verificador y Owner sin MFA.
- Runtime canónico `https://kombax.es`; sin referencias `urban01.netlify.app` en runtime.

## Backend live aplicado

Además de 119–127 de la 20071, están aplicadas:

- 128 · `kombax_verifier_storage_least_privilege_20072`
- 129 · `kombax_platform_legal_acceptance_20072`

Edge Functions relevantes:

- notification-dispatch v10
- payment-reminders v7
- account-deletion-executor v2
- health v2

## Estado de build

- `npm test`: PASS.
- `build.mjs`: PASS.
- paridad: web = dist = Android.
- runtime antiguo: 0 referencias a `urban01.netlify.app`.
- secretos privados frontend: 0 detectados.
- Android preflight: 4/5; solo falta firma local.
- release legal gate: bloqueado deliberadamente por 7 datos de responsable/contacto pendientes.
