# KOMBAX · Auth Email Templates · build 20072

Estas plantillas están preparadas para el proyecto Supabase alojado de KOMBAX. No contienen secretos, claves de API, service-role ni recursos remotos.

## Mapeo en Supabase Dashboard

Configurar en **Authentication → Email Templates**:

| Plantilla Supabase | Archivo KOMBAX | Asunto recomendado |
| --- | --- | --- |
| Confirm signup | `confirmation_20072.html` | `Confirma tu correo en KOMBAX` |
| Reset password / Recovery | `recovery_otp_20072.html` | `Código KOMBAX para cambiar tu contraseña` |
| Magic Link | `magic_link_otp_20072.html` | `Tu código de acceso KOMBAX` |
| Invite user | `invite_20072.html` | `Invitación a KOMBAX` |
| Reauthentication | `reauthentication_otp_20072.html` | `Código de seguridad KOMBAX` |
| Password changed notification | `password_changed_20072.html` | `Tu contraseña de KOMBAX ha cambiado` |

## Contrato de cada flujo

### Alta de cuenta

KOMBAX usa `POST /auth/v1/signup`. La plantilla de confirmación conserva `{{ .ConfirmationURL }}` para que el usuario confirme su correo desde el enlace seguro generado por Supabase.

### Recuperación de contraseña

KOMBAX usa `POST /auth/v1/recover` y después verifica un código de **6 dígitos** mediante `POST /auth/v1/verify` con `type: recovery`. La plantilla Recovery debe contener `{{ .Token }}`. No sustituirla por una plantilla que muestre únicamente un enlace.

### Owner / administración global

Tras validar correo + contraseña y crear el challenge administrativo, KOMBAX solicita `POST /auth/v1/otp` con `create_user:false`. Supabase utiliza la plantilla **Magic Link** para este flujo, por lo que debe contener `{{ .Token }}` para entregar el código de 6 dígitos que la UI espera. Después KOMBAX verifica `type: email` y completa el challenge MFA de backend.

## Configuración adicional pendiente de producción

1. Configurar el remitente SMTP profesional (nombre visible `KOMBAX` y dirección corporativa verificada).
2. Confirmar la `Site URL` y Redirect URLs con `https://kombax.es` antes del deploy final.
3. Realizar E2E real de alta, recuperación y OTP Owner en un buzón controlado.
4. Comprobar entrega, spam, asunto, remitente y que ningún correo siga mostrando branding genérico de Supabase.
5. Mantener los códigos como información secreta de un solo uso: nunca registrarlos en logs de aplicación ni soporte.

**Estado build 20072:** plantillas preparadas localmente. Su activación en el proyecto Supabase alojado y la recepción E2E siguen siendo pasos de configuración/verificación externos.
