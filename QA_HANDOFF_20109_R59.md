# KOMBAX 20.109 R59 — QA handoff

Base: KOMBAX 20.108 R58.

## Alcance R59
- Migración/alta de alumnos separada de Auth.
- Fichas históricas pueden existir sin email/cuenta y seguir siendo administrables.
- Altas nuevas preparan activación KOMBAX desde la preinscripción.
- Alumno autónomo desde **16 años** con email propio.
- Menor de 16: ficha propia + acceso mediante padre/madre/tutor autorizado.
- 16–17: cuenta/membresía propia; se conservan las protecciones/consentimientos Social existentes para menores de 18 cuando correspondan.
- Vinculación de ficha existente sin crear duplicados.
- Espectador existente puede reclamar una ficha compatible; el club aprueba/rechaza.
- Multiclub: una cuenta global, membresías independientes por `club_id + socio_id`.
- Baja de una membresía no elimina la cuenta; si no quedan membresías/perfiles autorizados, opera como Espectador.
- Se conserva R58: Espectador, Media/Creador, restricciones Social/Showcase y contacto a clubes/Showcase.

## Migración Supabase
`supabase/migrations/250_kombax_enrollment_activation_accounts_r59.sql`

Debe revisarse/aplicarse en el entorno Supabase antes del QA autenticado de los nuevos RPC/flujos.

## Evidencia local
- `npm test`: PASS completo.
- QA R59 específico: 16/16 PASS.
- Build estático: 191 archivos; `web = dist = Android`.
- Android preflight: 4/5; pendiente únicamente firma local (`android/keystore.properties`).

Ver evidencias en `R59_FINAL_EVIDENCE/`.

## QA autenticado obligatorio
1. Alta 16+ -> aprobación -> invitación -> cuenta -> misma ficha.
2. Migrado 16+ sin email -> añadir email -> activar sin duplicar.
3. Menor <16 -> tutor -> acceso familiar; el menor conserva su ficha.
4. Alumno 16–17 -> cuenta propia y comprobación de consentimiento Social cuando corresponda.
5. Espectador -> ficha importada -> reclamación -> aprobación/rechazo.
6. Misma persona en dos clubes -> activación separada y aislamiento de Finance/documentos/notificaciones.
7. Baja en un club sin afectar al otro ni a perfiles Competidor/Profesional/Marca/Media.
8. Doble importación y concurrencia de activación.
9. RLS multiclub y ausencia de fuga cruzada de datos.

## Estado
Candidato QA / continuidad Work. No declarar producción-ready hasta cerrar Supabase autenticado/RLS y firma Android/Google Play/Netlify según el proceso habitual.
