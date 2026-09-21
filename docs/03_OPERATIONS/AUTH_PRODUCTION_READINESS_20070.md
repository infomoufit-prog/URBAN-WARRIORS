# KOMBAX 20070 · correo y acceso para piloto

## SMTP real (obligatorio)

1. Contratar o seleccionar proveedor transaccional y un dominio controlado por KOMBAX.
2. Configurar SPF, DKIM y DMARC; no usar Mailinator para la certificación.
3. Configurar SMTP personalizado en Supabase Auth sin cambiar la confirmación normal de registro.
4. Probar registro, confirmación, recuperación y cambio de contraseña con Gmail, Outlook y un dominio corporativo.
5. Verificar entrega, remitente, enlaces, caducidad, rebotes y límites de frecuencia.
6. Registrar como evidencia el informe de entrega y la fecha. Solo entonces marcar `smtp`.

## MFA del propietario (obligatorio)

La persona titular debe activar MFA en su cuenta Supabase y conservar códigos de recuperación fuera del equipo. Esta acción no se automatiza ni se confirma por terceros. Registrar fecha y referencia de comprobación en `owner_mfa`.

## Seguridad Auth

- Mantener correos normales de registro, verificación y recuperación.
- Revisar límites de Auth antes del piloto y definir alertas por abuso.
- Activar protección de contraseñas filtradas únicamente si está disponible sin contratar un plan excluido.
- CAPTCHA queda recomendado antes de abrir registro público masivo; para piloto cerrado puede sustituirse temporalmente por invitación controlada y monitorización.
