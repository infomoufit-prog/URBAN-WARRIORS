# R109 · Identidad, perfiles, verificación y permisos

**Base:** R108 build 20161. **Resultado:** R109 build 20162. **Criterio:** cambio incremental pre-piloto.

## Mapa de cierre

| Estado R108 | Contradicción / riesgo | Cambio mínimo R109 |
|---|---|---|
| Signup podía fijar `competidor` desde `raw_user_meta_data` | El tipo sensible nacía antes de la solicitud/verificación | El trigger R100 ignora `competidor` en signup; la intención UX se conserva y el tipo queda fijado por los triggers existentes al crear perfil/solicitud |
| Miembro, Competidor y Profesional podían depender de membresía para publicar | Competidor/Profesional perdían autonomía | Miembro conserva membresía; Competidor usa verificación + edad 16+; Profesional usa verificación + edad privada 18+ |
| Contacto de Competidor/Profesional dependía de Club | Contradicción con identidad autónoma | Contacto 18+ usa edad verificada/privada sin afiliación obligatoria |
| Media podía guardar borrador pero `submit` terminaba en validador sin tipo `media` | Flujo de verificación incompleto | Se reutiliza `app_kombax_application_validate_v072`; Media exige evidencia proporcional y documento opcional |
| Promotor/Organizador ya era especialidad Profesional | Riesgo de identidad paralela | Se conserva `promotor_organizador`; no se crea tipo nuevo |
| R98/R100/R102 ya separaban identidad, presencia, badge y plan | Riesgo de rediseño | Se conservan; ningún gate nuevo usa badge visual como autorización |

## Reglas resultantes

- Una cuenta/correo mantiene una identidad principal bajo la exclusividad R100.
- Cuenta personal gratuita puede existir antes de cualquier membresía.
- Miembro operativo deriva de membresía confirmada y necesita esa membresía para actuar como Miembro.
- Competidor es condición deportiva individual verificada y puede existir sin Club KOMBAX.
- Profesional conserva especialidades; `promotor_organizador` sigue siendo especialidad, no identidad.
- Club, Marca y Federación conservan presencia gratuita y gates de verificación/capabilities existentes.
- Verificación, suscripción, capability, Stripe y badge público siguen siendo capas distintas.

## Archivos principales

- `supabase/migrations/296_kombax_prepilot_identity_permissions_r109.sql`
- `web/js/core/backend.js`
- `web/js/modules/gateway.js`
- `web/js/core/utils.js`
- `scripts/test-kombax-20162-r109-prepilot-identity.mjs`

No se ha creado una identidad `practicante`, `organizador` ni un motor paralelo de verificación.
