# KOMBAX 20.109 R59 — Enrollment Activation & Account Flow

Base: KOMBAX 20.108 R58.

## Implementado
- Preinscripción nueva: fecha de nacimiento + email de acceso obligatorios.
- Alumnos de 16 años o más: email propio y membresía autónoma, preservando la regla existente de alumno autónomo 16+.
- Menores de 16: email del tutor; la ficha del menor permanece separada de la cuenta adulta.
- Aprobación de preinscripción crea/reutiliza la ficha y prepara una invitación personal ligada a `socio_id`.
- Migraciones históricas siguen permitiendo fichas sin email/Auth.
- Estados UX `Falta email` y `Tutor pendiente`.
- Detección preventiva de posibles duplicados de altas autónomas 16+.
- Espectador con ficha importada puede solicitar vinculación; el club ahora puede aprobar/rechazar desde Alumnos.
- Aceptación de invitación actualizada a R59 y regla de tutor para menor <16.
- Se preserva el modelo R58 de Espectador, multiclub, Media/Creador y aislamiento por membresía.

## Base de datos
Nueva migración: `250_kombax_enrollment_activation_accounts_r59.sql`.
Debe revisarse/aplicarse antes de QA autenticado de estos flujos.

## Documento interno
`INTERNAL_ACCOUNT_MEMBERSHIP_FLOW_20109_R59.md`.
