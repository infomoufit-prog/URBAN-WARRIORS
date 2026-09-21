# KOMBAX · Auth Email Templates · build 20073

Plantillas de correo transaccional de KOMBAX refinadas para una experiencia más clara, premium y coherente con la marca. Mantienen intactos los contratos de seguridad de Supabase y no contienen secretos, claves privadas, service-role ni recursos remotos.

## Mapeo en Supabase Dashboard

Configurar en **Authentication → Email Templates**:

| Plantilla Supabase | Archivo KOMBAX | Asunto recomendado |
| --- | --- | --- |
| Confirm signup | `confirmation_20073.html` | `Activa tu cuenta KOMBAX` |
| Reset password / Recovery | `recovery_otp_20073.html` | `Código para recuperar tu cuenta · KOMBAX` |
| Magic Link | `magic_link_otp_20073.html` | `Tu código de seguridad · KOMBAX` |
| Invite user | `invite_20073.html` | `Te han invitado a KOMBAX` |
| Reauthentication | `reauthentication_otp_20073.html` | `Confirma que eres tú · KOMBAX` |
| Password changed notification | `password_changed_20073.html` | `Contraseña actualizada · KOMBAX` |

## Criterios de copy y diseño

- Voz breve, directa y profesional: seguridad sin alarmismo.
- Jerarquía visual KOMBAX negro/rojo/blanco sin imágenes externas ni trackers añadidos.
- Preheader específico para que la bandeja de entrada explique el propósito antes de abrir el correo.
- Los códigos OTP se presentan como información personal de un solo uso y nunca se solicitan por canales externos.
- Las invitaciones piden reconocer el contexto antes de aceptar, reduciendo riesgo de phishing o invitaciones inesperadas.
- El aviso de cambio de contraseña diferencia claramente entre un cambio reconocido y uno sospechoso.

## Contrato de cada flujo

### Alta de cuenta
KOMBAX usa `POST /auth/v1/signup`. `confirmation_20073.html` conserva `{{ .ConfirmationURL }}` y no sustituye el enlace de confirmación por un código.

### Recuperación de contraseña
KOMBAX usa `POST /auth/v1/recover` y verifica un código de **6 dígitos** con `POST /auth/v1/verify` y `type: recovery`. `recovery_otp_20073.html` conserva `{{ .Token }}` y no incluye `{{ .ConfirmationURL }}`.

### Owner / administración global
Tras validar correo + contraseña y crear el challenge administrativo, KOMBAX solicita `POST /auth/v1/otp` con `create_user:false`. Supabase utiliza la plantilla **Magic Link**, por lo que `magic_link_otp_20073.html` conserva `{{ .Token }}`. La UI verifica `type: email` antes de completar el challenge MFA de backend.

### Reautenticación
`reauthentication_otp_20073.html` conserva `{{ .Token }}` y está redactada para operaciones sensibles, sin revelar detalles administrativos innecesarios.

## Pendientes de activación real

1. Configurar estas plantillas 20073 en el proyecto Supabase alojado.
2. Configurar remitente SMTP profesional con nombre visible `KOMBAX` y dirección corporativa verificada.
3. Confirmar `Site URL` y Redirect URLs con `https://kombax.es` antes del deploy final.
4. Ejecutar E2E real de alta, recuperación, invitación, reautenticación y OTP Owner en un buzón controlado.
5. Comprobar asunto, remitente, spam, render móvil/escritorio y ausencia de branding genérico de Supabase.
6. No registrar jamás OTP, enlaces de confirmación ni secretos en logs de aplicación o soporte.

**Estado build 20073:** copy y HTML finalizados localmente. La activación en Supabase alojado y la recepción E2E continúan como gates externos de producción.
